/**
 * Real-time sync via WebSocket to SyncRoom Durable Object.
 *
 * Connects to ws://.../ws/:key, receives broadcasts from other devices,
 * applies changes locally, and notifies all pages to refresh.
 *
 * On every (re)connect, triggers an HTTP pull to catch up on missed changes.
 */

import {
	applyChanges,
	opfsSave,
	deriveEncryptionKey,
	decryptRows,
	getPacks,
	type SyncRow
} from './wasm';
import { data } from './data.svelte';
import { toastStore } from './toast.svelte';
import { SYNC_API_URL, LS_SYNC_KEY } from './config';

interface WSMessage {
	type: string;
	rows?: SyncRow[];
	merged?: number;
}

type OnReconnectFn = () => void;

class SyncWS {
	private ws: WebSocket | null = null;
	private reconnectDelay = 1000;
	private syncKey: string | null = null;
	private closed = false;
	private suppressUntil = 0;
	private onReconnect: OnReconnectFn | null = null;
	connected = $state(false);

	connect(syncKey: string): void {
		this.syncKey = syncKey;
		this.closed = false;
		this.doConnect();
	}

	setOnReconnect(cb: OnReconnectFn | null): void {
		this.onReconnect = cb;
	}

	private doConnect(): void {
		if (this.closed || !this.syncKey) return;

		const wsUrl = SYNC_API_URL.replace(/^http/, 'ws') + `/ws/${this.syncKey}`;
		this.ws = new WebSocket(wsUrl);

		this.ws.addEventListener('open', () => {
			this.connected = true;
			this.reconnectDelay = 1000;
			console.log('[taijobi-sync] WebSocket connected');
			this.onReconnect?.();
		});

		this.ws.addEventListener('message', (e) => {
			try {
				const msg = JSON.parse(e.data) as WSMessage;

				if (msg.type === 'changes' && msg.rows?.length) {
					// Ignore echo of own push (within 2s window)
					if (Date.now() < this.suppressUntil) {
						console.log(`[taijobi-sync] Ignoring echo (${msg.rows.length} rows)`);
						return;
					}
					// Decrypt incoming rows
					let rows = msg.rows;
					try {
						const syncKey = localStorage.getItem(LS_SYNC_KEY);
						if (syncKey) {
							const key = deriveEncryptionKey(syncKey);
							rows = decryptRows(rows, key);
						}
					} catch (decryptErr) {
						console.error('[taijobi-sync] WS decrypt failed:', decryptErr);
						return;
					}
					// Snapshot pack ids *before* apply so we can tell which are new.
					const packIdsBefore = new Set(getPacks().map((p) => p.id));
					const applied = applyChanges(rows);
					console.log(`[taijobi-sync] WS: applied ${applied} of ${msg.rows.length} changes`);
					opfsSave();
					if (applied > 0) {
						data.bump();
						showSyncToast(rows, packIdsBefore);
					}
				}

				if (msg.type === 'ping') {
					this.ws?.send(JSON.stringify({ type: 'pong' }));
				}
			} catch {
				// Ignore malformed messages
			}
		});

		this.ws.addEventListener('close', () => {
			this.connected = false;
			if (!this.closed) {
				console.log(`[taijobi-sync] Reconnecting in ${this.reconnectDelay}ms`);
				setTimeout(() => this.doConnect(), this.reconnectDelay);
				this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30_000);
			}
		});

		this.ws.addEventListener('error', () => {
			// onclose will fire after this — handles reconnect
		});
	}

	suppressEcho(): void {
		this.suppressUntil = Date.now() + 2000;
	}

	disconnect(): void {
		this.closed = true;
		this.onReconnect = null;
		this.ws?.close();
		this.ws = null;
		this.connected = false;
	}
}

export const syncWS = new SyncWS();

/**
 * Prefer a specific message for new-pack arrivals (from MCP `install_pack`
 * or a second device installing a pack) over a generic row count — "Neues
 * Paket: Geld, Zimmer & Bank" is a lot more actionable than "8 Änderungen
 * synchronisiert". Card-only changes (review state from another device)
 * stay generic. Suppressed entirely for review_log noise.
 */
function showSyncToast(rows: SyncRow[], packIdsBefore: Set<string>): void {
	const newPacks = rows.filter((r) => r.table === 'packs' && !packIdsBefore.has(r.id));
	if (newPacks.length > 0) {
		for (const row of newPacks) {
			const name =
				(typeof row.data === 'object' && row.data !== null
					? ((row.data as Record<string, unknown>).name as string | undefined)
					: undefined) ?? row.id;
			toastStore.show(`Neues Paket: ${name}`);
		}
		return;
	}

	// Card/lesson updates from another device — show a summary unless they're
	// all review_log (which is just review-state noise, not a content change).
	const meaningful = rows.filter((r) => r.table !== 'review_log');
	if (meaningful.length > 0) {
		toastStore.show(`${meaningful.length} Änderungen synchronisiert`);
	}
}
