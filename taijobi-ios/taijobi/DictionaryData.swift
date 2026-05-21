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

    private let baseURL = "https://taijobi.com/data"

    /// 10-minute resource timeout — the wall-clock budget for an entire
    /// download. The 19s/60s defaults aren't enough for 135 MB endict on
    /// patchy networks. The byte-by-byte `bytes(from:)` API doesn't expose
    /// these knobs, so we build our own configuration. We instantiate a
    /// fresh URLSession per download because the async
    /// `session.download(from:delegate:)` overload only forwards
    /// task-level delegate callbacks — `URLSessionDownloadDelegate`
    /// methods like `didWriteData` never fire, so the progress bar stays
    /// at 0 forever. A session created with a session-level delegate
    /// reliably invokes the download callbacks.
    private var sessionConfig: URLSessionConfiguration {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60       // per-segment timeout
        cfg.timeoutIntervalForResource = 600     // total budget for one file
        cfg.waitsForConnectivity = true          // wait through brief loss of signal
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return cfg
    }

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

    private func downloadFile(
        name: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> Data {
        let url = URL(string: "\(baseURL)/\(name)")!
        return try await withCheckedThrowingContinuation { continuation in
            // Session-per-download so the delegate is set at the session
            // level (where URLSessionDownloadDelegate callbacks actually
            // fire, unlike the per-task delegate of the async overload).
            // finishTasksAndInvalidate from the delegate frees both the
            // session and the delegate's strong refs once the task ends.
            let delegate = StreamingDownloadDelegate(
                onProgress: onProgress,
                continuation: continuation
            )
            let session = URLSession(
                configuration: sessionConfig,
                delegate: delegate,
                delegateQueue: nil
            )
            session.downloadTask(with: url).resume()
        }
    }
}

/// One-shot delegate scoped to a single download. Forwards
/// `didWriteData` as a 0…1 fraction, resumes the parent continuation
/// from `didFinishDownloadingTo` (success) or `didCompleteWithError`
/// (failure). NSObject-backed because URLSession delegates predate
/// Swift protocols.
private final class StreamingDownloadDelegate: NSObject,
	URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate
{
	let onProgress: @Sendable (Double) -> Void
	// Stored as Optional so we can null it out after resuming — Swift
	// will trap if a CheckedContinuation is resumed twice (e.g. by both
	// didFinishDownloading and a tail didCompleteWithError on the same
	// task).
	private var continuation: CheckedContinuation<Data, Error>?

	init(
		onProgress: @escaping @Sendable (Double) -> Void,
		continuation: CheckedContinuation<Data, Error>
	) {
		self.onProgress = onProgress
		self.continuation = continuation
	}

	func urlSession(
		_: URLSession,
		downloadTask _: URLSessionDownloadTask,
		didWriteData _: Int64,
		totalBytesWritten: Int64,
		totalBytesExpectedToWrite: Int64
	) {
		guard totalBytesExpectedToWrite > 0 else { return }
		let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
		onProgress(min(max(fraction, 0), 1))
	}

	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didFinishDownloadingTo location: URL
	) {
		defer { session.finishTasksAndInvalidate() }
		guard let cont = continuation else { return }
		continuation = nil
		// Reject non-200 responses so callers see a real error instead of
		// a corrupted body. CF returns text/plain "404 not found" for
		// missing dict files, which would otherwise pass through and
		// fail later at the WASM magic check with a less obvious message.
		if let http = downloadTask.response as? HTTPURLResponse,
		   http.statusCode != 200
		{
			cont.resume(throwing: NSError(
				domain: "taijobi.dict",
				code: http.statusCode,
				userInfo: [
					NSLocalizedDescriptionKey:
						"HTTP \(http.statusCode) für \(downloadTask.originalRequest?.url?.lastPathComponent ?? "?")",
				]
			))
			return
		}
		do {
			let data = try Data(contentsOf: location)
			cont.resume(returning: data)
		} catch {
			cont.resume(throwing: error)
		}
	}

	func urlSession(
		_ session: URLSession,
		task _: URLSessionTask,
		didCompleteWithError error: Error?
	) {
		// `didFinishDownloadingTo` resolved the continuation already on
		// the success path; only act here if the request failed before
		// the download finished (no temp file written).
		guard let error, let cont = continuation else { return }
		continuation = nil
		session.finishTasksAndInvalidate()
		cont.resume(throwing: error)
	}
}
