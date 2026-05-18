import Foundation

/// Swift wrapper over the libtaijobi C ABI. Mirrors taijobi-web/src/lib/wasm.ts
/// for the subset the iOS shell needs (lexicon CRUD; sync + drill land later).
///
/// Call pattern for every export:
///   1. acquire `abiLock` (libtaijobi uses a process-wide FBA — concurrent
///      calls invalidate each other's returned pointers)
///   2. invoke the C function
///   3. copy the length-prefixed JSON payload into Swift-owned memory
///   4. call `hanzi_reset_alloc()` so the next call has scratch space
///   5. decode the JSON
enum TaijobiError: Error {
    case notInitialized
    case initFailed(String)
    case callFailed(String)
    case decodeFailed
}

struct AddWordResult: Codable {
    let word: String
    let language: String
    let status: String
    let pinyin: String?
    let translation: String?
}

struct LexiconEntry: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let language: String
    let pinyin: String?
    let translation: String?
    let context: String?
    let reps: Int
    let stability: Double
}

final class LibTaijobi {
    static let shared = LibTaijobi()
    private init() {}

    private var initialized = false
    private let abiLock = NSRecursiveLock()

    private func withAbi<R>(_ body: () throws -> R) rethrows -> R {
        abiLock.lock()
        defer { abiLock.unlock() }
        return try body()
    }

    // MARK: - Lifecycle

    /// Resolves the SQLite path inside the App Group container so the main
    /// app, the share extension, and the widget all see the same database.
    private static func dbPath() -> String {
        let group = TaijobiConfig.appGroup
        if let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: group)
        {
            return container.appendingPathComponent("taijobi.db").path
        }
        // Fallback for SwiftUI previews / unit tests where the App Group
        // entitlement isn't active.
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("taijobi.db").path
    }

    func initialize() throws {
        try withAbi {
            if initialized { return }
            let path = LibTaijobi.dbPath()
            let rc = path.withCString { hanzi_init($0) }
            if rc != 0 {
                throw TaijobiError.initFailed(lastErrorLocked() ?? "hanzi_init returned \(rc)")
            }
            initialized = true
        }
    }

    func close() {
        withAbi {
            guard initialized else { return }
            hanzi_close()
            initialized = false
        }
    }

    // MARK: - Lexicon

    /// Adds `word` to the lexicon. Returns the enrichment result, or `nil` if
    /// the word was empty / already present (check `lastError()` for which).
    @discardableResult
    func addWord(_ word: String) throws -> AddWordResult? {
        try withAbi {
            try ensureInitLocked()
            let bytes = Data(word.utf8)
            let payload: Data? = bytes.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Data? in
                guard let base = raw.baseAddress,
                      let returned = hanzi_add_word(base, bytes.count)
                else { return nil }
                return Self.copyLengthPrefixed(returned)
            }
            hanzi_reset_alloc()
            guard let data = payload else { return nil }
            return try? JSONDecoder().decode(AddWordResult.self, from: data)
        }
    }

    func getLexicon() throws -> [LexiconEntry] {
        try withAbi {
            try ensureInitLocked()
            guard let raw = hanzi_get_lexicon() else { return [] }
            let data = Self.copyLengthPrefixed(raw)
            hanzi_reset_alloc()
            return (try? JSONDecoder().decode([LexiconEntry].self, from: data)) ?? []
        }
    }

    @discardableResult
    func removeWord(id: String) throws -> Bool {
        try withAbi {
            try ensureInitLocked()
            let bytes = Data(id.utf8)
            let rc: Int32 = bytes.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return Int32(-1) }
                return hanzi_remove_word(base, bytes.count)
            }
            return rc == 0
        }
    }

    // MARK: - Errors

    /// Last error set by libtaijobi. Returns nil if no error was recorded
    /// since the last successful call.
    func lastError() -> String? {
        withAbi { lastErrorLocked() }
    }

    private func lastErrorLocked() -> String? {
        guard let raw = hanzi_get_error() else { return nil }
        let data = Self.copyLengthPrefixed(raw)
        return data.isEmpty ? nil : String(data: data, encoding: .utf8)
    }

    // MARK: - Helpers

    private func ensureInitLocked() throws {
        if !initialized { try initialize() }
    }

    /// Reads a length-prefixed payload returned by a libtaijobi export:
    /// 4 little-endian bytes for the length, then `length` bytes of payload.
    /// Copies into a Swift-owned `Data` so the caller can safely reset the FBA.
    private static func copyLengthPrefixed(_ raw: UnsafeRawPointer) -> Data {
        let rawLen = raw.load(fromByteOffset: 0, as: UInt32.self)
        let len = Int(UInt32(littleEndian: rawLen))
        return Data(bytes: raw.advanced(by: 4), count: len)
    }
}
