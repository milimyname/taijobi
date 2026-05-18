import Foundation

/// HTTP push/pull sync against the wimg-sync Worker (sync.taijobi.com).
/// Mirrors taijobi-web/src/lib/sync.ts for the parts iOS actually needs;
/// WebSocket real-time is intentionally deferred until daily use proves it
/// matters.
///
/// Wire format matches the web client exactly so a phone's pushes show up
/// on laptop and vice versa:
///   POST /sync/{key}        { rows: [encrypted rows] }
///   GET  /sync/{key}?since= → { rows: [encrypted rows] }
@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()
    private init() {}

    @Published var syncing = false
    @Published var lastError: String?
    @Published var lastSyncMs: Int64 = UserDefaults.standard
        .object(forKey: TaijobiConfig.udSyncLastTS) as? Int64 ?? 0
    @Published var hasKey: Bool = KeychainService.get(KeychainService.syncKey) != nil

    private var encryptionKey: Data?

    var syncKey: String? {
        KeychainService.get(KeychainService.syncKey)
    }

    // MARK: - Key management

    func setSyncKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainService.set(KeychainService.syncKey, value: trimmed)
        encryptionKey = nil
        hasKey = true
    }

    func clearSyncKey() {
        KeychainService.delete(KeychainService.syncKey)
        UserDefaults.standard.removeObject(forKey: TaijobiConfig.udSyncLastTS)
        encryptionKey = nil
        lastSyncMs = 0
        hasKey = false
    }

    /// Generates a random 32-character base32 sync key. Same alphabet the
    /// web client uses, so it can be typed into either side interchangeably.
    static func generateKey() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var key = ""
        for _ in 0..<32 {
            key.append(alphabet.randomElement()!)
        }
        return key
    }

    // MARK: - Sync

    /// Push local changes + pull remote changes. Atomic from the user's
    /// perspective: either both succeed or `lastError` is set and nothing
    /// is partially applied (apply happens last, after pull succeeds).
    func sync() async {
        guard !syncing else { return }
        guard let key = syncKey else {
            lastError = "Kein Sync-Schlüssel gesetzt"
            return
        }
        syncing = true
        lastError = nil
        defer { syncing = false }

        do {
            try ensureEncryptionKey(for: key)
            try await push(key: key)
            try await pull(key: key)
            lastSyncMs = Int64(Date().timeIntervalSince1970 * 1000)
            UserDefaults.standard.set(lastSyncMs, forKey: TaijobiConfig.udSyncLastTS)
        } catch {
            lastError = "\(error.localizedDescription)"
        }
    }

    // MARK: - Internals

    private func ensureEncryptionKey(for key: String) throws {
        if encryptionKey != nil { return }
        guard let derived = LibTaijobi.shared.deriveEncryptionKey(syncKey: key)
        else {
            throw SyncError.derivation
        }
        encryptionKey = derived
    }

    private struct WireRow: Codable {
        let table: String
        let id: String
        let updated_at: Int64
        let data: String  // base64-encoded ciphertext blob
    }

    private struct WirePayload: Codable {
        let rows: [WireRow]
    }

    private struct PlainRow: Codable {
        let table: String
        let id: String
        let updated_at: Int64
        let data: [String: AnyCodable]
    }

    private struct PlainPayload: Codable {
        let rows: [PlainRow]
    }

    private func push(key: String) async throws {
        guard let changesData = LibTaijobi.shared.getChanges(sinceMs: lastSyncMs)
        else { throw SyncError.localRead }
        let plain = try JSONDecoder().decode(PlainPayload.self, from: changesData)
        if plain.rows.isEmpty { return }

        guard let ekey = encryptionKey else { throw SyncError.derivation }
        var encryptedRows: [WireRow] = []
        encryptedRows.reserveCapacity(plain.rows.count)
        for row in plain.rows {
            let plainJson = try JSONEncoder().encode(row.data)
            let plainString = String(data: plainJson, encoding: .utf8) ?? "{}"
            guard let cipher = LibTaijobi.shared
                .encryptField(plainString, key: ekey) else {
                throw SyncError.encryption
            }
            encryptedRows.append(
                WireRow(
                    table: row.table, id: row.id,
                    updated_at: row.updated_at, data: cipher))
        }
        let body = try JSONEncoder().encode(WirePayload(rows: encryptedRows))
        let url = URL(string: "\(TaijobiConfig.syncBaseURL)/sync/\(key)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (_, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 300 {
            throw SyncError.server(status: http.statusCode)
        }
    }

    private func pull(key: String) async throws {
        let url = URL(
            string:
                "\(TaijobiConfig.syncBaseURL)/sync/\(key)?since=\(lastSyncMs)")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 300 {
            throw SyncError.server(status: http.statusCode)
        }
        let wire = try JSONDecoder().decode(WirePayload.self, from: data)
        if wire.rows.isEmpty { return }

        guard let ekey = encryptionKey else { throw SyncError.derivation }
        var plainRows: [PlainRow] = []
        plainRows.reserveCapacity(wire.rows.count)
        for row in wire.rows {
            guard let decrypted = LibTaijobi.shared
                .decryptField(row.data, key: ekey),
                let decryptedData = decrypted.data(using: .utf8),
                let dict = try? JSONDecoder().decode(
                    [String: AnyCodable].self, from: decryptedData)
            else {
                throw SyncError.decryption
            }
            plainRows.append(
                PlainRow(
                    table: row.table, id: row.id,
                    updated_at: row.updated_at, data: dict))
        }
        let body = try JSONEncoder().encode(PlainPayload(rows: plainRows))
        if !LibTaijobi.shared.applyChanges(body) {
            throw SyncError.localWrite
        }
    }
}

enum SyncError: LocalizedError {
    case derivation
    case localRead
    case localWrite
    case encryption
    case decryption
    case server(status: Int)

    var errorDescription: String? {
        switch self {
        case .derivation: return "Konnte Verschlüsselungsschlüssel nicht ableiten"
        case .localRead: return "Konnte lokale Änderungen nicht lesen"
        case .localWrite: return "Konnte Server-Änderungen nicht anwenden"
        case .encryption: return "Verschlüsselung fehlgeschlagen"
        case .decryption: return "Entschlüsselung fehlgeschlagen"
        case .server(let s): return "Server-Fehler (HTTP \(s))"
        }
    }
}

/// Tiny `AnyCodable` so we can round-trip arbitrary JSON value types
/// inside `PlainRow.data` without writing a per-table decoder for every
/// SQLite column. Mirrors what the web client does in TypeScript via
/// untyped `Record<string, unknown>`.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = NSNull() }
        else if let v = try? c.decode(Bool.self) { value = v }
        else if let v = try? c.decode(Int64.self) { value = v }
        else if let v = try? c.decode(Double.self) { value = v }
        else if let v = try? c.decode(String.self) { value = v }
        else if let v = try? c.decode([AnyCodable].self) { value = v.map { $0.value } }
        else if let v = try? c.decode([String: AnyCodable].self) {
            value = v.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "Unknown JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull: try c.encodeNil()
        case let v as Bool: try c.encode(v)
        case let v as Int64: try c.encode(v)
        case let v as Int: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        case let v as [Any]: try c.encode(v.map { AnyCodable($0) })
        case let v as [String: Any]:
            try c.encode(v.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: c.codingPath,
                    debugDescription: "Unsupported value: \(value)"))
        }
    }
}
