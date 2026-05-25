import Foundation
import Network

/// HTTP push/pull sync against the wimg-sync Worker (sync.taijobi.com).
/// Mirrors taijobi-web/src/lib/sync.ts.
///
/// Wire format matches the web client exactly so a phone's pushes show up
/// on laptop and vice versa:
///   POST /sync/{key}        { rows: [encrypted rows] }
///   GET  /sync/{key}?since= → { rows: [encrypted rows] }
///
/// iOS divergence vs. web — neither platform gets reconnect-on-online for
/// free. The browser at least surfaces `online`/`offline` events and keeps
/// a WebSocket alive in the background tab; iOS suspends sockets the
/// moment the app backgrounds and provides no equivalent event. We bridge
/// that gap with `NWPathMonitor` + a manual `SyncWS.reconnect()` on
/// foreground transitions — ~30 lines of iOS-specific glue, no library.
@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()
    private init() {
        startNetworkMonitor()
    }

    @Published var syncing = false
    @Published var lastError: String?
    @Published var lastSyncMs: Int64 = UserDefaults.standard
        .object(forKey: TaijobiConfig.udSyncLastTS) as? Int64 ?? 0
    @Published var hasKey: Bool = KeychainService.get(KeychainService.syncKey) != nil
    /// Bumps whenever `applyChanges` lands new rows from a pull or a WS
    /// broadcast. Views observe it via `@StateObject` + `.onChange(of:)`
    /// so the UI refreshes the moment remote changes arrive — without
    /// this, a phone that's still on the Wörter tab when the laptop saves
    /// a word wouldn't show it until the user navigated away and back.
    @Published var dataVersion: UInt64 = 0

    private var encryptionKey: Data?
    private var pendingSyncTask: Task<Void, Never>?
    private var networkMonitor: NWPathMonitor?
    private var wasOnline = true

    // MARK: - Auto-sync wiring

    /// Wire the mutation callback + run an initial sync once a key is set.
    /// Called from `taijobiApp.init` and from Settings → "Sync verknüpfen".
    /// Mirrors the web client's `connectSync()`: after every local write
    /// (addWord/removeWord) we schedule a debounced push so the user never
    /// has to think about hitting the Sync button.
    func start() {
        LibTaijobi.shared.setOnMutate { [weak self] in
            // setOnMutate fires inside the abi lock — hop off-thread so we
            // don't block the write, then debounce.
            Task { @MainActor in
                self?.debouncedSync()
            }
        }
        if hasKey, let key = syncKey {
            // Connect the WebSocket so changes from other devices (web,
            // another iPhone) arrive in real time, not just on the next
            // foreground/mutation cycle. Mirrors web's connectSync().
            SyncWS.shared.connect(key: key)
            Task { @MainActor in await sync() }
        }
    }

    /// Coalesces bursts of mutations (e.g. the share extension dropping 20
    /// words at once) into a single sync round-trip ~1.5 s after the last
    /// write. Cancels any previously-scheduled sync so they don't pile up.
    func debouncedSync() {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
            await self?.sync()
        }
    }

    /// Called whenever the app becomes active. Two things matter here:
    ///   1. Kick the WebSocket — iOS killed it the moment we backgrounded,
    ///      and the receive-loop's scheduled reconnect may have backed off
    ///      up to 30 s. Forcing reconnect now means real-time broadcasts
    ///      resume immediately instead of after the next backoff tick.
    ///   2. Run a full HTTP sync so any rows we missed while the WS was
    ///      down (or while the app was offline entirely) land before the
    ///      user reads them.
    func onForeground() {
        guard hasKey else { return }
        SyncWS.shared.reconnect()
        Task { @MainActor in await sync() }
    }

    // MARK: - Network reachability

    /// `NWPathMonitor` is iOS's closest analogue to the browser's
    /// `online`/`offline` events. Without it, regaining Wi-Fi after a
    /// flight or stepping back inside from cellular dead zone leaves the
    /// WebSocket dead and `lastSyncMs` stale until the user manually
    /// taps "Jetzt synchronisieren".
    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let online = path.status == .satisfied
                let regained = online && !self.wasOnline
                self.wasOnline = online
                guard regained, self.hasKey else { return }
                SyncWS.shared.reconnect()
                await self.sync()
            }
        }
        monitor.start(queue: DispatchQueue(label: "taijobi.network"))
    }

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
        // Fresh key — pull existing rows from the other devices immediately
        // so the user doesn't see an empty lexicon while waiting for a
        // mutation to trigger the auto-sync. Reconnect the WebSocket so
        // subsequent broadcasts on this key land in real time.
        SyncWS.shared.disconnect()
        SyncWS.shared.connect(key: trimmed)
        Task { @MainActor in await sync() }
    }

    func clearSyncKey() {
        SyncWS.shared.disconnect()
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
            let appliedRows = try await pull(key: key)
            lastSyncMs = Int64(Date().timeIntervalSince1970 * 1000)
            UserDefaults.standard.set(lastSyncMs, forKey: TaijobiConfig.udSyncLastTS)
            // Bump dataVersion only when pull actually applied rows —
            // otherwise every onForeground tick (which fires `sync()` for
            // the empty-rows case) would re-render every observing view
            // for nothing.
            if appliedRows {
                dataVersion &+= 1
            }
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
        // The server broadcasts every push to all WS subscribers, including
        // the sender. Mark a 2 s window so SyncWS skips re-applying our
        // own writes when the echo lands.
        SyncWS.shared.suppressEcho()

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

    /// Returns true when at least one row was applied locally — caller
    /// uses that to decide whether to bump `dataVersion`.
    private func pull(key: String) async throws -> Bool {
        let url = URL(
            string:
                "\(TaijobiConfig.syncBaseURL)/sync/\(key)?since=\(lastSyncMs)")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 300 {
            throw SyncError.server(status: http.statusCode)
        }
        let wire = try JSONDecoder().decode(WirePayload.self, from: data)
        if wire.rows.isEmpty { return false }

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
        return true
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
