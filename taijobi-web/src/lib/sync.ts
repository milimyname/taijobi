/**
 * Sync service — orchestrates push/pull with the Cloudflare Worker API.
 * Manages real-time WebSocket connection for live sync.
 *
 * Dev:  http://localhost:8787 (wrangler dev)
 * Prod: https://sync.taijobi.com
 */

import {
	getChanges,
	applyChanges,
	opfsSave,
	setOnMutate,
	deriveEncryptionKey,
	encryptField,
	decryptRows,
	type SyncRow
} from './wasm';
import { syncWS } from './sync-ws.svelte';
import { data } from './data.svelte';
import { SYNC_API_URL, LS_SYNC_KEY, LS_SYNC_LAST_TS } from './config';

// Cached encryption key — derived once from sync key
let encryptionKey: Uint8Array | null = null;

function getEncryptionKey(syncKey: string): Uint8Array {
	if (!encryptionKey) {
		encryptionKey = deriveEncryptionKey(syncKey);
	}
	return encryptionKey;
}

function encryptRows(rows: SyncRow[], key: Uint8Array): SyncRow[] {
	return rows.map((row) => ({
		...row,
		data: encryptField(JSON.stringify(row.data), key) as unknown as Record<string, unknown>
	}));
}

export function getSyncKey(): string | null {
	return localStorage.getItem(LS_SYNC_KEY);
}

export function setSyncKey(key: string): void {
	localStorage.setItem(LS_SYNC_KEY, key);
	// Clear stale timestamp so next pull fetches ALL data (since=0)
	localStorage.removeItem(LS_SYNC_LAST_TS);
	encryptionKey = null;
}

export function clearSyncKey(): void {
	localStorage.removeItem(LS_SYNC_KEY);
	localStorage.removeItem(LS_SYNC_LAST_TS);
	encryptionKey = null;
	disconnectSync();
}

export function getLastSyncTimestamp(): number {
	return Number(localStorage.getItem(LS_SYNC_LAST_TS) || '0');
}

function setLastSyncTimestamp(ts: number): void {
	localStorage.setItem(LS_SYNC_LAST_TS, String(ts));
}

export function isSyncEnabled(): boolean {
	return !!getSyncKey();
}

export async function syncPush(syncKey: string): Promise<number> {
	const lastSync = getLastSyncTimestamp();
	const changes: SyncRow[] = getChanges(lastSync);
	console.log(`[taijobi-sync] Push: ${changes.length} changes since ${lastSync}`);
	if (changes.length === 0) return 0;

	// Encrypt data fields before pushing
	const key = getEncryptionKey(syncKey);
	const encrypted = encryptRows(changes, key);

	// Suppress echo: the DO will broadcast our push back to us via WS
	syncWS.suppressEcho();

	const res = await fetch(`${SYNC_API_URL}/sync/${syncKey}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ rows: encrypted })
	});

	if (!res.ok) {
		const body = await res.text();
		throw new Error(`Sync push failed: ${res.status} ${body}`);
	}

	const result = (await res.json()) as { merged: number };
	console.log(`[taijobi-sync] Push result: ${result.merged} merged`);

	setLastSyncTimestamp(Date.now());
	return result.merged;
}

export async function syncPull(syncKey: string): Promise<number> {
	const lastSync = getLastSyncTimestamp();
	console.log(`[taijobi-sync] Pull: since=${lastSync}`);

	const res = await fetch(`${SYNC_API_URL}/sync/${syncKey}?since=${lastSync}`);
	if (!res.ok) {
		const body = await res.text();
		throw new Error(`Sync pull failed: ${res.status} ${body}`);
	}

	const { rows } = (await res.json()) as { rows: SyncRow[] };
	console.log(`[taijobi-sync] Pull: received ${rows.length} rows from server`);
	if (!rows.length) return 0;

	// Decrypt data fields
	const key = getEncryptionKey(syncKey);
	const decrypted = decryptRows(rows, key);

	const applied = applyChanges(decrypted);
	console.log(`[taijobi-sync] Pull: applied ${applied} of ${rows.length} rows`);
	await opfsSave();
	setLastSyncTimestamp(Date.now());
	if (applied > 0) data.bump();

	return applied;
}

export async function syncFull(syncKey: string): Promise<{ pushed: number; pulled: number }> {
	const pulled = await syncPull(syncKey);
	const pushed = await syncPush(syncKey);
	setLastSyncTimestamp(Date.now());
	return { pushed, pulled };
}

/** Connect WebSocket for real-time sync + register onMutate callback */
export function connectSync(): void {
	const key = getSyncKey();
	if (!key) return;

	syncWS.connect(key);

	// Catch-up sync on every (re)connect
	syncWS.setOnReconnect(() => {
		const syncKey = getSyncKey();
		if (syncKey) {
			syncPull(syncKey)
				.then(() => syncPush(syncKey))
				.catch((err) => {
					console.error('[taijobi-sync] Catch-up sync failed:', err);
				});
		}
	});

	// Auto-push on every local mutation
	setOnMutate(() => {
		const syncKey = getSyncKey();
		if (syncKey) {
			syncPush(syncKey).catch((err) => {
				console.error('[taijobi-sync] Auto-push failed:', err);
			});
		}
	});
}

/** Disconnect WebSocket and remove onMutate callback */
export function disconnectSync(): void {
	syncWS.disconnect();
	setOnMutate(null);
}
