import Foundation

/// Real-time sync via WebSocket to the wimg-sync `SyncRoom` Durable
/// Object. Mirrors taijobi-web/src/lib/sync-ws.svelte.ts: connect to
/// `wss://.../ws/{key}`, receive broadcasts from other devices,
/// decrypt + apply locally, suppress echoes of our own HTTP pushes.
///
/// Why a separate class from SyncService: the WS is a long-lived
/// connection that needs its own receive loop and reconnect backoff,
/// none of which fit cleanly inside the imperative `func sync()` shape
/// the rest of SyncService uses. The two cooperate via `suppressEcho()`
/// — SyncService calls it before every HTTP push so the broadcast we
/// get back in the next ~2 s gets skipped.
@MainActor
final class SyncWS: ObservableObject {
	static let shared = SyncWS()
	private init() {}

	@Published var connected = false

	private var task: URLSessionWebSocketTask?
	private var session: URLSession?
	private var reconnectDelay: TimeInterval = 1.0
	private var closed = false
	private var syncKey: String?
	private var suppressUntilMs: Int64 = 0
	private var encryptionKey: Data?
	/// Identifies the current connection so a stale receive callback
	/// (from a connection we already closed) can't bump state on a new one.
	private var connectionId = 0

	// Same wire shape SyncService.pull() decodes.
	private struct WireRow: Codable {
		let table: String
		let id: String
		let updated_at: Int64
		let data: String // base64-encoded ciphertext blob
	}

	private struct PlainRow: Codable {
		let table: String
		let id: String
		let updated_at: Int64
		let data: [String: AnyCodable]
	}

	private struct WSMessage: Codable {
		let type: String
		let rows: [WireRow]?
	}

	private struct PlainPayload: Codable {
		let rows: [PlainRow]
	}

	// MARK: - Public

	func connect(key: String) {
		closed = false
		syncKey = key
		// Reset and re-derive the encryption key — if the user just
		// pasted a new sync key we don't want to carry over the old one.
		encryptionKey = nil
		doConnect()
	}

	func disconnect() {
		closed = true
		task?.cancel(with: .goingAway, reason: nil)
		task = nil
		session?.invalidateAndCancel()
		session = nil
		connected = false
	}

	/// Force an immediate reconnect — called from `SyncService.onForeground()`
	/// and from `NetworkMonitor` when connectivity is regained. iOS drops
	/// WebSocket tasks when the app backgrounds, and without this kick the
	/// next message wouldn't arrive until the natural backoff timer (up to
	/// 30 s) fired. Cancelling the current task triggers the receive loop's
	/// `.failure` branch, which calls `scheduleReconnect()`, but we bypass
	/// the backoff by resetting `reconnectDelay` and connecting immediately.
	func reconnect() {
		guard !closed, syncKey != nil else { return }
		task?.cancel(with: .goingAway, reason: nil)
		task = nil
		session?.invalidateAndCancel()
		session = nil
		reconnectDelay = 1.0
		doConnect()
	}

	/// Called by SyncService right before every HTTP push so the broadcast
	/// we receive back for our own change gets ignored (avoids round-tripping
	/// applyChanges on data we already wrote locally).
	func suppressEcho() {
		suppressUntilMs = Int64(Date().timeIntervalSince1970 * 1000) + 2000
	}

	// MARK: - Internals

	private func doConnect() {
		guard !closed, let key = syncKey else { return }
		// Re-derive the encryption key lazily on first need.
		if encryptionKey == nil {
			encryptionKey = LibTaijobi.shared.deriveEncryptionKey(syncKey: key)
		}

		let wsBase = TaijobiConfig.syncBaseURL
			.replacingOccurrences(of: "http://", with: "ws://")
			.replacingOccurrences(of: "https://", with: "wss://")
		guard let url = URL(string: "\(wsBase)/ws/\(key)") else { return }

		let cfg = URLSessionConfiguration.default
		cfg.waitsForConnectivity = true
		let session = URLSession(configuration: cfg)
		self.session = session

		let task = session.webSocketTask(with: url)
		self.task = task
		connectionId += 1
		let myId = connectionId

		task.resume()
		// URLSessionWebSocketTask doesn't fire a discrete "open" callback —
		// it's open once `.resume()` returns and the first receive() doesn't
		// fail immediately. Flip the flag now; we'll roll back to false if
		// the receive loop errors out before a successful message.
		connected = true
		reconnectDelay = 1.0
		receiveLoop(connectionId: myId)
	}

	private func receiveLoop(connectionId myId: Int) {
		task?.receive { [weak self] result in
			Task { @MainActor [weak self] in
				guard let self else { return }
				// Stale callback from a previously-cancelled connection.
				if myId != self.connectionId { return }

				switch result {
				case .success(let message):
					self.handleMessage(message)
					self.receiveLoop(connectionId: myId)
				case .failure:
					self.connected = false
					self.scheduleReconnect()
				}
			}
		}
	}

	private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
		let json: Data?
		switch message {
		case .string(let s): json = s.data(using: .utf8)
		case .data(let d): json = d
		@unknown default: json = nil
		}
		guard let data = json,
		      let msg = try? JSONDecoder().decode(WSMessage.self, from: data)
		else { return }

		if msg.type == "ping" {
			task?.send(.string(#"{"type":"pong"}"#)) { _ in }
			return
		}

		if msg.type == "changes", let rows = msg.rows, !rows.isEmpty {
			// Echo guard — within ~2 s of our own HTTP push, skip the
			// broadcast since applyChanges would just rewrite our own
			// writes.
			if Int64(Date().timeIntervalSince1970 * 1000) < suppressUntilMs {
				return
			}
			applyEncryptedRows(rows)
		}
	}

	private func applyEncryptedRows(_ rows: [WireRow]) {
		guard let ekey = encryptionKey else { return }
		var plain: [PlainRow] = []
		plain.reserveCapacity(rows.count)
		for row in rows {
			guard let decrypted = LibTaijobi.shared.decryptField(row.data, key: ekey),
			      let data = decrypted.data(using: .utf8),
			      let dict = try? JSONDecoder().decode(
			      	[String: AnyCodable].self, from: data
			      )
			else { continue }
			plain.append(PlainRow(
				table: row.table, id: row.id,
				updated_at: row.updated_at, data: dict
			))
		}
		guard !plain.isEmpty,
		      let body = try? JSONEncoder().encode(PlainPayload(rows: plain))
		else { return }
		_ = LibTaijobi.shared.applyChanges(body)
		// Bump the sync timestamp so the next HTTP pull doesn't re-fetch
		// these rows — we already have them.
		let now = Int64(Date().timeIntervalSince1970 * 1000)
		SyncService.shared.lastSyncMs = now
		UserDefaults.standard.set(now, forKey: TaijobiConfig.udSyncLastTS)
		// Tell observing views (LexiconView etc.) that the underlying
		// SQLite has changed so they re-fetch — without this, real-time
		// WS pushes land silently in the DB and the UI only refreshes
		// the next time a view `.onAppear`s.
		SyncService.shared.dataVersion &+= 1
	}

	private func scheduleReconnect() {
		guard !closed else { return }
		let delay = reconnectDelay
		// Exponential backoff capped at 30 s, same as web.
		reconnectDelay = min(reconnectDelay * 2, 30)
		Task { @MainActor [weak self] in
			try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			self?.doConnect()
		}
	}
}
