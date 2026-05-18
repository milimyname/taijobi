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
        /// rather than exact compressed-on-the-wire byte counts.
        var approxSizeMB: Int {
            switch self {
            case .zh: return 18  // cedict + decomp + strokes
            case .en: return 19
            case .de: return 5
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

    private let baseURL = "https://taijobi.com/data"

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
            let ok = LibTaijobi.shared.loadDictionary(file.kind, bytes: bytes)
            if !ok { allLoaded = false }
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

    /// Downloads one `Kind` (1 file for en/de, 3 for zh), persists to the App
    /// Group cache, and loads each blob into the WASM persist arena. No-op if
    /// another download is in flight.
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
                let bytes = try await downloadFile(name: file.name) { fraction in
                    Task { @MainActor in
                        // Each file contributes 1/totalFiles to the overall bar.
                        self.progress = (doneFiles + fraction) / totalFiles
                    }
                }
                try Self.writeCache(name: file.name, bytes: bytes)
                let ok = LibTaijobi.shared.loadDictionary(file.kind, bytes: bytes)
                if !ok {
                    lastError = "Konnte \(file.name) nicht laden (Magic-Prüfung fehlgeschlagen)"
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

    private func downloadFile(
        name: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> Data {
        let url = URL(string: "\(baseURL)/\(name)")!
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        let expected = response.expectedContentLength
        var collected = Data()
        if expected > 0 { collected.reserveCapacity(Int(expected)) }
        var nextEmitAt: Int64 = 0
        for try await byte in asyncBytes {
            collected.append(byte)
            if expected > 0, Int64(collected.count) >= nextEmitAt {
                onProgress(Double(collected.count) / Double(expected))
                // Emit ~30 progress callbacks total to keep the UI smooth
                // without flooding the run loop. expected/30 spacing.
                nextEmitAt = Int64(collected.count) + max(1, expected / 30)
            }
        }
        onProgress(1.0)
        return collected
    }
}
