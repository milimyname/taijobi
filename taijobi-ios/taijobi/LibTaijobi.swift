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

/// One CC-CEDICT hit. Returned by `hanzi_lookup`.
struct CedictResult: Codable, Identifiable, Hashable {
    let traditional: String
    let simplified: String
    let pinyin: String
    let english: String

    /// Synthesized — CEDICT doesn't carry a primary key.
    var id: String { "\(simplified)|\(pinyin)" }
}

/// One Wiktionary sense (translation slot inside a POS group).
struct DictSense: Codable, Hashable {
    let tags: [String]
    let gloss: String
    let example: String
    let synonyms: [String]
    let antonyms: [String]
    let hypernyms: [String]
}

/// One POS group within a Wiktionary entry (noun / verb / adj / …).
struct DictPosGroup: Codable, Hashable {
    let pos: String
    let etymology: String
    let senses: [DictSense]
}

/// One Wiktionary headword with all its POS groups.
struct DictResult: Codable, Identifiable, Hashable {
    let word: String
    let groups: [DictPosGroup]

    var id: String { word }
}

final class LibTaijobi {
    static let shared = LibTaijobi()
    private init() {}

    private var initialized = false
    private let abiLock = NSRecursiveLock()

    /// Fires after every write that mutates the SQLite store. SyncService
    /// hooks this to push diffs to the server without the user having to
    /// tap the Sync button — same pattern as web's `setOnDataChanged`.
    /// Called inside the abi lock; callers should dispatch any real work
    /// off-thread to avoid blocking the write that just completed.
    private var onMutate: (() -> Void)?

    func setOnMutate(_ callback: (() -> Void)?) {
        withAbi { onMutate = callback }
    }

    private func fireMutate() {
        onMutate?()
    }

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
        let result: AddWordResult? = try withAbi {
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
        // Fire outside the abi lock in withAbi epilogue — the callback may
        // hop to a Task, but we still want it called from inside withAbi so
        // the lock guarantees the row is durably written by the time the
        // sync push runs.
        if result != nil { withAbi { fireMutate() } }
        return result
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
        let ok: Bool = try withAbi {
            try ensureInitLocked()
            let bytes = Data(id.utf8)
            let rc: Int32 = bytes.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return Int32(-1) }
                return hanzi_remove_word(base, bytes.count)
            }
            return rc == 0
        }
        if ok { withAbi { fireMutate() } }
        return ok
    }

    // MARK: - Dictionary lookup

    /// CC-CEDICT lookup (Chinese ↔ English). Empty array if no CEDICT data is
    /// loaded, or if no entry matches `query` (which can be hanzi, pinyin
    /// without tone marks, or any English token).
    func lookupCedict(_ query: String) -> [CedictResult] {
        withAbi {
            guard initialized, !query.isEmpty else { return [] }
            let bytes = Data(query.utf8)
            let payload: Data? = bytes.withUnsafeBytes { raw -> Data? in
                guard let base = raw.baseAddress,
                      let returned = hanzi_lookup(base, bytes.count)
                else { return nil }
                return Self.copyLengthPrefixed(returned)
            }
            hanzi_reset_alloc()
            guard let data = payload else { return [] }
            return (try? JSONDecoder().decode([CedictResult].self, from: data)) ?? []
        }
    }

    /// Wiktionary lookup against whichever EN/DE dictionary is loaded.
    /// Returns structured `DictResult` (POS groups, senses, etymology,
    /// examples, syn/ant/hyp) — the same v3 shape the web client renders.
    func lookupWord(_ query: String) -> [DictResult] {
        withAbi {
            guard initialized, !query.isEmpty else { return [] }
            let bytes = Data(query.utf8)
            let payload: Data? = bytes.withUnsafeBytes { raw -> Data? in
                guard let base = raw.baseAddress,
                      let returned = hanzi_lookup_word(base, bytes.count)
                else { return nil }
                return Self.copyLengthPrefixed(returned)
            }
            hanzi_reset_alloc()
            guard let data = payload else { return [] }
            return (try? JSONDecoder().decode([DictResult].self, from: data)) ?? []
        }
    }

    // MARK: - Dictionary data loading
    //
    // libtaijobi keeps dictionary blobs in a separate "persistent" allocator
    // arena — distinct from the FBA reset on every call — so the bytes
    // survive across requests. To load a .bin file:
    //   1. `hanzi_persist_alloc(byteCount)` returns a pointer into the arena
    //   2. copy raw bytes into that pointer
    //   3. call the per-dict loader, which stores the slice and reads the magic

    enum DictKind {
        case cedict
        case decomp
        case strokes
        case endict
        case dedict

        /// Expected first 4 bytes of the binary. Used for pre-load magic
        /// validation so stale OPFS/App-Group caches and stale CF-edge
        /// downloads surface as a clear "magic mismatch" error rather than
        /// being attributed to allocator pressure. Chinese binaries don't
        /// carry a magic header today — return nil for those.
        var expectedMagic: [UInt8]? {
            switch self {
            case .cedict, .decomp, .strokes: return nil
            case .endict: return [0x57, 0x4B, 0x45, 0x33] // "WKE3"
            case .dedict: return [0x57, 0x4B, 0x44, 0x33] // "WKD3"
            }
        }
    }

    /// Outcome of `loadDictionary`. Splits "couldn't fit in the persist
    /// arena" from "loaded but the bytes weren't the format we expected" so
    /// callers can surface honest error messages instead of conflating both
    /// into a single "magic check failed".
    enum LoadResult: Equatable {
        case ok
        /// The persistent allocator couldn't satisfy `bytesNeeded`. Either
        /// PERSIST_SIZE needs a bump or another dict is hogging the arena.
        case allocFailed(bytesNeeded: Int)
        /// Bytes loaded but the first 4 bytes didn't match the expected
        /// format magic. Typically a stale on-disk cache.
        case magicMismatch(expected: String, gotHex: String)
        /// Caller passed empty bytes.
        case emptyInput
    }

    /// Copies `bytes` into the persistent arena and hands the slice to the
    /// matching Zig loader.
    func loadDictionary(_ kind: DictKind, bytes: Data) -> LoadResult {
        withAbi {
            guard !bytes.isEmpty else { return .emptyInput }

            // Pre-load magic check: cheaper than allocating the arena slot
            // first only to discover the bytes were stale.
            if let want = kind.expectedMagic, bytes.count >= want.count {
                let head = Array(bytes.prefix(want.count))
                if head != want {
                    return .magicMismatch(
                        expected: String(bytes: want, encoding: .ascii) ?? "?",
                        gotHex: head.map { String(format: "%02X", $0) }.joined()
                    )
                }
            }

            guard let dst = hanzi_persist_alloc(bytes.count) else {
                return .allocFailed(bytesNeeded: bytes.count)
            }
            bytes.withUnsafeBytes { raw in
                if let src = raw.baseAddress {
                    memcpy(dst, src, bytes.count)
                }
            }
            let typed = dst.assumingMemoryBound(to: UInt8.self)
            let rc: Int32
            switch kind {
            case .cedict: rc = hanzi_load_cedict(typed, bytes.count)
            case .decomp: rc = hanzi_load_decomp(typed, bytes.count)
            case .strokes: rc = hanzi_load_strokes(typed, bytes.count)
            case .endict: rc = hanzi_load_endict(typed, bytes.count)
            case .dedict: rc = hanzi_load_dedict(typed, bytes.count)
            }
            // The Zig loaders currently always return 0 — they just set the
            // slice. Wiktdict magic validation happens lazily in
            // `is{En,De}Loaded()`. Treat non-zero as a future-proofed error.
            return rc == 0 ? .ok : .magicMismatch(expected: "load rc=0", gotHex: String(rc))
        }
    }

    var isChineseDataLoaded: Bool { withAbi { hanzi_chinese_data_loaded() == 1 } }
    var isEndictLoaded: Bool { withAbi { hanzi_endict_loaded() == 1 } }
    var isDedictLoaded: Bool { withAbi { hanzi_dedict_loaded() == 1 } }

    // MARK: - Sync (E2E-encrypted change log)
    //
    // Mirrors taijobi-web/src/lib/sync.ts: derive a 32-byte symmetric key
    // from the user's sync passphrase via HKDF-SHA256, fetch changed rows
    // since the last sync timestamp, encrypt them with XChaCha20-Poly1305
    // before they leave the device, and decrypt incoming rows after
    // pulling. Server only sees ciphertext.

    /// Length-prefixed JSON of `{rows:[{table, id, updated_at, data:{…}}]}`
    /// that changed since `sinceTs` (ms epoch). Each row's `data` payload
    /// is plaintext at this point — the caller encrypts before upload.
    func getChanges(sinceMs: Int64) -> Data? {
        withAbi {
            guard initialized,
                  let ptr = hanzi_get_changes(sinceMs)
            else { return nil }
            let bytes = Self.copyLengthPrefixed(ptr)
            hanzi_reset_alloc()
            return bytes
        }
    }

    /// Applies a length-prefixed JSON change set pulled from the server
    /// (rows already decrypted in Swift). Returns true on success.
    @discardableResult
    func applyChanges(_ json: Data) -> Bool {
        withAbi {
            guard initialized else { return false }
            let rc: Int32 = json.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return Int32(-1) }
                return hanzi_apply_changes(base, UInt32(json.count))
            }
            return rc == 0
        }
    }

    /// Derives the 32-byte symmetric encryption key from the user's sync
    /// passphrase. Cache the result — derivation is HKDF and not free.
    func deriveEncryptionKey(syncKey: String) -> Data? {
        withAbi {
            let bytes = Data(syncKey.utf8)
            return bytes.withUnsafeBytes { raw -> Data? in
                guard let base = raw.baseAddress,
                      let ptr = hanzi_derive_key(base, UInt32(bytes.count))
                else { return nil }
                let data = Self.copyLengthPrefixed(ptr)
                hanzi_reset_alloc()
                return data
            }
        }
    }

    /// Encrypts `plaintext` with the derived key + a fresh 24-byte nonce.
    /// Returns the base64-encoded `nonce ‖ ciphertext ‖ tag` payload.
    func encryptField(_ plaintext: String, key: Data) -> String? {
        guard key.count == 32 else { return nil }
        var nonce = Data(count: 24)
        let status = nonce.withUnsafeMutableBytes { b in
            SecRandomCopyBytes(kSecRandomDefault, 24, b.baseAddress!)
        }
        guard status == errSecSuccess else { return nil }
        return withAbi {
            let pt = Data(plaintext.utf8)
            return pt.withUnsafeBytes { ptRaw -> String? in
                key.withUnsafeBytes { keyRaw -> String? in
                    nonce.withUnsafeBytes { nonceRaw -> String? in
                        guard let pPtr = ptRaw.baseAddress,
                              let kPtr = keyRaw.baseAddress,
                              let nPtr = nonceRaw.baseAddress,
                              let out = hanzi_encrypt_field(
                                pPtr, UInt32(pt.count), kPtr, nPtr)
                        else { return nil }
                        let data = Self.copyLengthPrefixed(out)
                        hanzi_reset_alloc()
                        return String(data: data, encoding: .utf8)
                    }
                }
            }
        }
    }

    /// Decrypts a base64-encoded `nonce ‖ ciphertext ‖ tag` payload.
    func decryptField(_ ciphertext: String, key: Data) -> String? {
        guard key.count == 32 else { return nil }
        return withAbi {
            let ct = Data(ciphertext.utf8)
            return ct.withUnsafeBytes { ctRaw -> String? in
                key.withUnsafeBytes { keyRaw -> String? in
                    guard let cPtr = ctRaw.baseAddress,
                          let kPtr = keyRaw.baseAddress,
                          let out = hanzi_decrypt_field(
                            cPtr, UInt32(ct.count), kPtr)
                    else { return nil }
                    let data = Self.copyLengthPrefixed(out)
                    hanzi_reset_alloc()
                    return String(data: data, encoding: .utf8)
                }
            }
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
