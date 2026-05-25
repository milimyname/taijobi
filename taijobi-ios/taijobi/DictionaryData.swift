import Foundation

/// On-demand dictionary download + cache, mirroring
/// taijobi-web/src/lib/dictionary-data.ts. Three responsibilities:
///   1. Download .bin files from the public R2-backed origin
///   2. Cache them in the App Group container so share extension + widget
///      see the same data without re-downloading
///   3. Hand bytes to `LibTaijobi.loadDictionary(...)` on launch
///
/// File sizes (April 2026): cedict ~8 MB, decomp ~1 MB, strokes ~9 MB,
/// endict ~19 MB, dedict ~5 MB. Total worst case ~42 MB. We download
/// lazily — the user explicitly taps "Wörterbuch installieren" before
/// the first lookup.
@MainActor
final class DictionaryData: ObservableObject {
    static let shared = DictionaryData()
    private init() {}

    enum Kind: String, CaseIterable, Identifiable {
        case zh    // cedict + decomp + strokes
        case en    // endict
        case de    // dedict

        var id: String { rawValue }

        var label: String {
            switch self {
            case .zh: return "Chinesisch"
            case .en: return "Englisch"
            case .de: return "Deutsch"
            }
        }

        /// Approximate download size in MB — surfaced in the install prompt so
        /// users on cellular can decline. Tracks production binary sizes
        /// rather than exact compressed-on-the-wire byte counts. These are
        /// fallback values shown before the HEAD probe lands; once `liveSizes`
        /// is populated, the UI prefers those.
        var approxSizeMB: Int {
            switch self {
            case .zh: return 18  // cedict + decomp + strokes
            case .en: return 135 // kaikki English Wiktextract (v3, May 2026)
            case .de: return 12  // kaikki German Wiktextract (v3)
            }
        }

        var files: [(name: String, kind: LibTaijobi.DictKind)] {
            switch self {
            case .zh:
                return [
                    ("cedict.bin", .cedict),
                    ("decomp.bin", .decomp),
                    ("strokes.bin", .strokes)
                ]
            case .en: return [("endict.bin", .endict)]
            case .de: return [("dedict.bin", .dedict)]
            }
        }
    }

    @Published var zhLoaded = false
    @Published var enLoaded = false
    @Published var deLoaded = false
    @Published var active: Kind?
    @Published var progress: Double = 0
    @Published var lastError: String?

    // MARK: - Filesystem

    /// Shared cache directory inside the App Group container so the share
    /// extension can read the same blobs the main app downloaded.
    private static func cacheDir() throws -> URL {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: TaijobiConfig.appGroup)
        else {
            throw NSError(
                domain: "taijobi.dict",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "App Group container nicht verfügbar"]
            )
        }
        let dir = container.appendingPathComponent("dictionaries", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(_ name: String) throws -> URL {
        try cacheDir().appendingPathComponent(name)
    }

    private static func cachedBytes(_ name: String) -> Data? {
        guard let url = try? fileURL(name) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Public so BackgroundDownloader can drop bytes into the App-Group
    /// cache from inside its delegate callbacks — including the relaunch
    /// path where this process has no live `install()` continuation. The
    /// cache is the source of truth; `loadCachedOnBoot()` picks the file
    /// up the next time the user opens the app.
    func writeCache(file: String, bytes: Data) {
        do {
            try Self.writeCache(name: file, bytes: bytes)
        } catch {
            lastError = "Konnte \(file) nicht in den Cache schreiben: \(error.localizedDescription)"
        }
    }

    // MARK: - Boot

    /// Loads whatever's already cached, in order. Called from `taijobiApp.init`
    /// right after `LibTaijobi.initialize()`. Silent — first-time users with
    /// no cache see `zhLoaded == false` and tap "Installieren" to download.
    func loadCachedOnBoot() {
        for kind in Kind.allCases {
            let loaded = loadKindFromCache(kind)
            updateLoadedFlag(kind, loaded)
        }
    }

    private func loadKindFromCache(_ kind: Kind) -> Bool {
        var allLoaded = true
        for file in kind.files {
            guard let bytes = Self.cachedBytes(file.name) else {
                allLoaded = false
                continue
            }
            let result = LibTaijobi.shared.loadDictionary(file.kind, bytes: bytes)
            if result != .ok {
                allLoaded = false
                // Boot path is silent — log so devtools see why a cached dict
                // didn't apply, but don't surface an error banner.
                print("[taijobi] cached \(file.name) skipped: \(result)")
            }
        }
        return allLoaded
    }

    private func updateLoadedFlag(_ kind: Kind, _ value: Bool) {
        switch kind {
        case .zh: zhLoaded = LibTaijobi.shared.isChineseDataLoaded
        case .en: enLoaded = LibTaijobi.shared.isEndictLoaded
        case .de: deLoaded = LibTaijobi.shared.isDedictLoaded
        }
        _ = value
    }

    // MARK: - Download

    /// Downloads one `Kind` (1 file for en/de, 3 for zh) via the
    /// background URLSession in `BackgroundDownloader`, persists each to
    /// the App-Group cache, and loads each blob into the WASM persist
    /// arena. No-op if another download is in flight.
    ///
    /// Because the underlying session is `URLSessionConfiguration.background`,
    /// the file transfer keeps going if the user backgrounds or even
    /// kills the app. The completion notification fires whenever the OS
    /// finishes the transfer; `loadCachedOnBoot()` on the next launch
    /// picks up bytes the relaunched process couldn't load (no live
    /// continuation, WASM allocator possibly not initialised yet).
    func install(_ kind: Kind) async {
        guard active == nil else { return }
        active = kind
        progress = 0
        lastError = nil

        defer {
            active = nil
            progress = 0
        }

        let totalFiles = Double(kind.files.count)
        var doneFiles = 0.0

        for file in kind.files {
            do {
                // Mirror BackgroundDownloader's per-file progress onto our
                // own multi-file bar by polling its @Published value at
                // ~10 Hz. Capture doneFiles as an immutable snapshot for
                // this iteration so the concurrent Task can't race the
                // mutation at the end of the loop.
                let completedSoFar = doneFiles
                let progressTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    while !Task.isCancelled {
                        self.progress = (completedSoFar + BackgroundDownloader.shared.activeFileProgress) / totalFiles
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                }
                defer { progressTask.cancel() }

                let bytes = try await BackgroundDownloader.shared.download(
                    file: file.name, kind: kind
                )
                // BackgroundDownloader already wrote bytes to the cache;
                // load them into the WASM persist arena here so the user
                // can search immediately without an app reload.
                switch LibTaijobi.shared.loadDictionary(file.kind, bytes: bytes) {
                case .ok:
                    break
                case .allocFailed(let needed):
                    let mb = Double(needed) / 1024 / 1024
                    lastError = String(
                        format:
                            "%@ konnte nicht in den Wörterbuch-Speicher passen (%.0f MB benötigt). PERSIST_SIZE in libtaijobi/src/root.zig anheben.",
                        file.name, mb)
                    return
                case .magicMismatch(let expected, let gotHex):
                    lastError =
                        "\(file.name) hat falsches Magic (\(gotHex) statt \(expected)). Vermutlich ein veralteter CF-Edge-Cache — bitte später erneut versuchen."
                    return
                case .emptyInput:
                    lastError = "\(file.name): leere Daten heruntergeladen."
                    return
                }
                doneFiles += 1
            } catch {
                lastError = "Download fehlgeschlagen: \(error.localizedDescription)"
                return
            }
        }

        updateLoadedFlag(kind, true)
    }

    private static func writeCache(name: String, bytes: Data) throws {
        let url = try fileURL(name)
        try bytes.write(to: url, options: .atomic)
    }
}
