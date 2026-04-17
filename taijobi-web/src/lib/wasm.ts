/**
 * libtaijobi WASM loader and typed TypeScript wrappers.
 * Adapted from wimg's proven WASM integration pattern.
 */

export interface Card {
	id: string;
	word: string;
	language: string;
	pinyin: string | null;
	translation: string | null;
	source_type: string;
	reps: number;
	intervals: {
		again: number;
		hard: number;
		good: number;
		easy: number;
	};
}

export interface LexiconEntry {
	id: string;
	word: string;
	language: string;
	pinyin: string | null;
	translation: string | null;
	context: string | null;
	reps: number;
	stability: number;
}

export interface DrillStats {
	reviewed_today: number;
	correct_today: number;
	total_cards: number;
	lexicon_count: number;
}

export interface StatsData {
	days: Array<{ d: number; c: number; r: number }>;
	ratings: [number, number, number, number];
	streak: number;
	longest_streak: number;
}

export interface AddWordResult {
	word: string;
	language: string;
	status: string;
	pinyin?: string;
	translation?: string;
}

export interface CedictResult {
	simplified: string;
	pinyin: string;
	english: string;
}

interface WasmExports {
	memory: WebAssembly.Memory;
	hanzi_init: (path: number) => number;
	hanzi_close: () => void;
	hanzi_alloc: (size: number) => number;
	hanzi_free: (ptr: number, len: number) => void;
	hanzi_reset_alloc: () => void;
	hanzi_get_error: () => number;
	hanzi_get_due_cards: (limit: number) => number;
	hanzi_get_due_count: () => number;
	hanzi_get_due_cards_filtered: (filter: number, filterLen: number, limit: number) => number;
	hanzi_get_due_count_filtered: (filter: number, filterLen: number) => number;
	hanzi_get_upcoming_cards: (
		filter: number,
		filterLen: number,
		limit: number,
		aheadHours: number
	) => number;
	hanzi_review_card: (id: number, idLen: number, rating: number) => number;
	hanzi_add_word: (word: number, len: number) => number;
	hanzi_remove_word: (id: number, len: number) => number;
	hanzi_update_word: (id: number, idLen: number, trans: number, transLen: number) => number;
	hanzi_lookup: (query: number, len: number) => number;
	hanzi_search_cards: (query: number, len: number, limit: number) => number;
	hanzi_get_last_reviewed_card: () => number;
	hanzi_query: (sql: number, len: number) => number;
	hanzi_parse_kindle: (data: number, len: number) => number;
	hanzi_bulk_add_lexicon: (data: number, len: number) => number;
	hanzi_get_lexicon: () => number;
	hanzi_get_drill_stats: () => number;
	hanzi_install_pack: (json: number, len: number) => number;
	hanzi_get_packs: () => number;
	hanzi_remove_pack: (id: number, len: number) => number;
	hanzi_get_lessons: (packId: number, len: number) => number;
	hanzi_get_vocabulary: (lessonId: number, len: number) => number;
	hanzi_get_progress: (packId: number, len: number) => number;
	hanzi_decompose: (ch: number, len: number) => number;
	hanzi_get_strokes: (ch: number, len: number) => number;
	hanzi_restore_pack: (id: number, len: number) => number;
	hanzi_mark_read: (id: number, len: number) => number;
	hanzi_get_unread_cards: (filter: number, filterLen: number, limit: number) => number;
	hanzi_get_unread_count: (filter: number, filterLen: number) => number;
	hanzi_import_csv: (csv: number, csvLen: number, name: number, nameLen: number) => number;
	hanzi_export_csv: () => number;
	hanzi_import_apkg: (apkg: number, apkgLen: number, name: number, nameLen: number) => number;
	hanzi_get_stats: (days: number) => number;
	hanzi_build_id: () => number;
	hanzi_db_ptr: () => number;
	hanzi_db_size: () => number;
	hanzi_db_load: (data: number, size: number) => number;
	// Chinese data — on-demand loading
	hanzi_persist_alloc: (len: number) => number;
	hanzi_load_cedict: (ptr: number, len: number) => number;
	hanzi_load_decomp: (ptr: number, len: number) => number;
	hanzi_load_strokes: (ptr: number, len: number) => number;
	hanzi_chinese_data_loaded: () => number;
	hanzi_unload_chinese: () => number;
	// Wiktionary EN/DE dictionaries
	hanzi_load_endict: (ptr: number, len: number) => number;
	hanzi_load_dedict: (ptr: number, len: number) => number;
	hanzi_endict_loaded: () => number;
	hanzi_dedict_loaded: () => number;
	hanzi_unload_endict: () => number;
	hanzi_unload_dedict: () => number;
	hanzi_lookup_word: (query: number, len: number) => number;
	// Phase 4 — Sync
	hanzi_get_changes: (sinceTs: bigint) => number;
	hanzi_apply_changes: (data: number, len: number) => number;
	hanzi_derive_key: (ptr: number, len: number) => number;
	hanzi_encrypt_field: (pt: number, ptLen: number, key: number, nonce: number) => number;
	hanzi_decrypt_field: (ct: number, ctLen: number, key: number) => number;
}

export interface SyncRow {
	table: string;
	id: string;
	data: Record<string, unknown> | string;
	updated_at: number;
}

let onMutateCb: (() => void) | null = null;
let onDataChangedCb: (() => void) | null = null;

export function setOnMutate(cb: (() => void) | null): void {
	onMutateCb = cb;
}

export function setOnDataChanged(cb: (() => void) | null): void {
	onDataChangedCb = cb;
}

let wasm: WasmExports | null = null;

const OPFS_DB_NAME = 'taijobi.db';

// --- Instrumentation ---

import { devtoolsStore } from './devtools-store.svelte';

/** Wrap a synchronous WASM call with timing. Records name + duration
 *  into the devtools store so the DevTools WASM tab can show a live
 *  call log with avg/slowest stats. Recording is deferred via
 *  queueMicrotask so it doesn't mutate $state inside a $derived chain
 *  (e.g. when a derived reads data.stats() → getStats() → timed()). */
function timed<T>(name: string, fn: () => T): T {
	const start = performance.now();
	const result = fn();
	const duration = performance.now() - start;
	queueMicrotask(() => devtoolsStore.record(name, duration));
	return result;
}

// --- Internal helpers ---

function readLengthPrefixedString(ptr: number): string {
	const mem = new Uint8Array(wasm!.memory.buffer);
	const len = mem[ptr] | (mem[ptr + 1] << 8) | (mem[ptr + 2] << 16) | (mem[ptr + 3] << 24);
	return new TextDecoder().decode(mem.slice(ptr + 4, ptr + 4 + len));
}

function getLastError(fallback: string): string {
	let msg = fallback;
	try {
		const ptr = wasm!.hanzi_get_error();
		if (ptr !== 0) {
			msg = readLengthPrefixedString(ptr);
		}
	} catch {
		// ignore
	}
	console.error('[taijobi]', msg);
	return msg;
}

function writeString(s: string): number {
	const encoded = new TextEncoder().encode(s + '\0');
	const ptr = wasm!.hanzi_alloc(encoded.length);
	if (ptr === 0) throw new Error('WASM allocation failed');
	const mem = new Uint8Array(wasm!.memory.buffer);
	mem.set(encoded, ptr);
	return ptr;
}

function writeBytes(data: Uint8Array): number {
	const ptr = wasm!.hanzi_alloc(data.length);
	if (ptr === 0) throw new Error('WASM allocation failed');
	const mem = new Uint8Array(wasm!.memory.buffer);
	mem.set(data, ptr);
	return ptr;
}

// --- OPFS persistence ---

async function opfsLoad(): Promise<Uint8Array | null> {
	try {
		const root = await navigator.storage.getDirectory();
		const fileHandle = await root.getFileHandle(OPFS_DB_NAME);
		const file = await fileHandle.getFile();
		const buffer = await file.arrayBuffer();
		if (buffer.byteLength === 0) return null;
		console.log(`[taijobi] OPFS: loaded ${buffer.byteLength} bytes`);
		return new Uint8Array(buffer);
	} catch {
		console.log('[taijobi] OPFS: no existing database');
		return null;
	}
}

async function opfsSave(): Promise<void> {
	if (!wasm) return;

	const ptr = wasm.hanzi_db_ptr();
	const size = wasm.hanzi_db_size();
	if (ptr === 0 || size === 0) return;

	const mem = new Uint8Array(wasm.memory.buffer);
	const dbBytes = mem.slice(ptr, ptr + size);

	try {
		const root = await navigator.storage.getDirectory();
		const fileHandle = await root.getFileHandle(OPFS_DB_NAME, { create: true });

		// Safari < 17.2 doesn't support createWritable on main thread
		if (typeof fileHandle.createWritable === 'function') {
			const writable = await fileHandle.createWritable();
			await writable.write(dbBytes);
			await writable.close();
		} else {
			// Fallback: write via Worker + createSyncAccessHandle for older Safari
			const workerCode = `
				onmessage = async (e) => {
					const root = await navigator.storage.getDirectory();
					const fh = await root.getFileHandle(e.data.name, { create: true });
					const ah = await fh.createSyncAccessHandle();
					ah.truncate(0);
					ah.write(e.data.bytes);
					ah.flush();
					ah.close();
					postMessage("done");
				};
			`;
			const workerBlob = new Blob([workerCode], { type: 'text/javascript' });
			const worker = new Worker(URL.createObjectURL(workerBlob));
			await new Promise<void>((resolve, reject) => {
				worker.addEventListener('message', () => {
					worker.terminate();
					resolve();
				});
				worker.addEventListener('error', (err) => {
					worker.terminate();
					reject(err);
				});
				worker.postMessage({ name: OPFS_DB_NAME, bytes: dbBytes }, [dbBytes.buffer]);
			});
		}
		console.log(`[taijobi] OPFS: saved ${size} bytes`);
	} catch (e) {
		console.error('[taijobi] OPFS save failed:', e);
	}
}

// --- Public API ---

export async function init(): Promise<void> {
	if (wasm) return;

	const response = await fetch('/libtaijobi.wasm');
	const bytes = await response.arrayBuffer();
	const compiled = await WebAssembly.compile(bytes);

	const neededImports = WebAssembly.Module.imports(compiled);
	if (neededImports.length > 0) {
		console.log('[taijobi] WASM imports required:', neededImports);
	}

	const importObject: Record<string, Record<string, unknown>> = {
		env: {
			js_console_log: (ptr: number, len: number) => {
				try {
					const mem = new Uint8Array(
						(result.exports as { memory: WebAssembly.Memory }).memory.buffer
					);
					const msg = new TextDecoder().decode(mem.slice(ptr, ptr + len));
					console.log('[taijobi]', msg);
				} catch {
					console.log('[taijobi] (log failed, ptr=%d len=%d)', ptr, len);
				}
			},
			js_time_ms: () => BigInt(Date.now())
		}
	};

	// Stub any unexpected imports to prevent instantiation failure
	for (const imp of neededImports) {
		if (!importObject[imp.module]) importObject[imp.module] = {};
		if (!(imp.name in importObject[imp.module])) {
			if (imp.kind === 'function') {
				importObject[imp.module][imp.name] = (...args: unknown[]) => {
					console.warn(`[taijobi] unimplemented import: ${imp.module}.${imp.name}`, args);
					return 0;
				};
			}
		}
	}

	const result = await WebAssembly.instantiate(compiled, importObject as WebAssembly.Imports);
	wasm = result.exports as unknown as WasmExports;

	console.log(
		'[taijobi] exports:',
		WebAssembly.Module.exports(compiled)
			.map((e) => e.name)
			.join(', ')
	);

	// Restore from OPFS
	const saved = await opfsLoad();
	if (saved) {
		const loadPtr = wasm.hanzi_alloc(saved.length);
		if (loadPtr !== 0) {
			const mem = new Uint8Array(wasm.memory.buffer);
			mem.set(saved, loadPtr);
			const rc = wasm.hanzi_db_load(loadPtr, saved.length);
			if (rc !== 0) {
				console.warn('[taijobi] failed to restore DB from OPFS');
			}
		}
	}

	// Initialize
	const pathPtr = writeString(OPFS_DB_NAME);
	const rc = wasm.hanzi_init(pathPtr);
	if (rc !== 0) {
		throw new Error(getLastError('Failed to initialize taijobi database'));
	}

	// Load cached Chinese data from OPFS (no network)
	const { loadCachedData } = await import('./dictionary-data');
	await loadCachedData();
}

// --- Chinese data helpers ---

export function persistAlloc(len: number): number {
	if (!wasm || typeof wasm.hanzi_persist_alloc !== 'function') return 0;
	return wasm.hanzi_persist_alloc(len);
}

export function loadCedict(ptr: number, data: Uint8Array): void {
	if (!wasm || typeof wasm.hanzi_load_cedict !== 'function') return;
	const mem = new Uint8Array(wasm.memory.buffer);
	mem.set(data, ptr);
	wasm.hanzi_load_cedict(ptr, data.length);
}

export function loadDecomp(ptr: number, data: Uint8Array): void {
	if (!wasm || typeof wasm.hanzi_load_decomp !== 'function') return;
	const mem = new Uint8Array(wasm.memory.buffer);
	mem.set(data, ptr);
	wasm.hanzi_load_decomp(ptr, data.length);
}

export function loadStrokes(ptr: number, data: Uint8Array): void {
	if (!wasm || typeof wasm.hanzi_load_strokes !== 'function') return;
	const mem = new Uint8Array(wasm.memory.buffer);
	mem.set(data, ptr);
	wasm.hanzi_load_strokes(ptr, data.length);
}

export function isChineseDataLoaded(): boolean {
	if (!wasm || typeof wasm.hanzi_chinese_data_loaded !== 'function') return false;
	return wasm.hanzi_chinese_data_loaded() === 1;
}

export function unloadChinese(): void {
	if (!wasm || typeof wasm.hanzi_unload_chinese !== 'function') return;
	wasm.hanzi_unload_chinese();
}

export function loadEndict(ptr: number, data: Uint8Array): void {
	if (!wasm || typeof wasm.hanzi_load_endict !== 'function') return;
	const mem = new Uint8Array(wasm.memory.buffer);
	mem.set(data, ptr);
	wasm.hanzi_load_endict(ptr, data.length);
}

export function loadDedict(ptr: number, data: Uint8Array): void {
	if (!wasm || typeof wasm.hanzi_load_dedict !== 'function') return;
	const mem = new Uint8Array(wasm.memory.buffer);
	mem.set(data, ptr);
	wasm.hanzi_load_dedict(ptr, data.length);
}

export function getDueCount(): number {
	if (!wasm) return 0;
	return timed('getDueCount', () => wasm!.hanzi_get_due_count());
}

export function getDueCards(limit: number = 50): Card[] {
	if (!wasm) return [];
	wasm.hanzi_reset_alloc();
	const ptr = wasm.hanzi_get_due_cards(limit);
	if (ptr === 0) {
		console.warn('[taijobi] getDueCards: ptr=0 (no cards or error)');
		return [];
	}
	const json = readLengthPrefixedString(ptr);
	console.log(
		`[taijobi] getDueCards: json length=${json.length}, first 200 chars:`,
		json.slice(0, 200)
	);
	wasm.hanzi_free(ptr, 0);
	try {
		return JSON.parse(json);
	} catch (e) {
		console.error('[taijobi] Failed to parse due cards JSON:', e);
		console.error('[taijobi] last 200 chars:', json.slice(-200));
		return [];
	}
}

export function getDueCardsFiltered(filter: string, limit: number = 50): Card[] {
	return timed('getDueCardsFiltered', () => {
		if (!wasm) return [];
		wasm.hanzi_reset_alloc();
		const encoded = new TextEncoder().encode(filter);
		const ptr = filter ? writeBytes(encoded) : 0;
		const resultPtr = wasm.hanzi_get_due_cards_filtered(ptr, encoded.length, limit);
		if (resultPtr === 0) return [];
		const json = readLengthPrefixedString(resultPtr);
		try {
			return JSON.parse(json);
		} catch (e) {
			console.error('[taijobi] Failed to parse filtered due cards JSON:', e);
			console.error('[taijobi] json length:', json.length, 'first 200:', json.slice(0, 200));
			return [];
		}
	});
}

export function getDueCountFiltered(filter: string): number {
	return timed('getDueCountFiltered', () => {
		if (!wasm) return 0;
		wasm.hanzi_reset_alloc();
		const encoded = new TextEncoder().encode(filter);
		const ptr = filter ? writeBytes(encoded) : 0;
		return wasm.hanzi_get_due_count_filtered(ptr, encoded.length);
	});
}

export function getUpcomingCards(
	filter: string,
	limit: number = 50,
	aheadHours: number = 24
): Card[] {
	if (!wasm || typeof wasm.hanzi_get_upcoming_cards !== 'function') return [];
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(filter);
	const ptr = filter ? writeBytes(encoded) : 0;
	const resultPtr = wasm.hanzi_get_upcoming_cards(ptr, encoded.length, limit, aheadHours);
	if (resultPtr === 0) return [];
	const json = readLengthPrefixedString(resultPtr);
	try {
		return JSON.parse(json);
	} catch (e) {
		console.error('[taijobi] Failed to parse upcoming cards JSON:', e);
		return [];
	}
}

// --- Reading mode ---

export interface ReadCard {
	id: string;
	word: string;
	language: string;
	pinyin: string | null;
	translation: string | null;
	source_type: string;
}

export async function markRead(cardId: string): Promise<void> {
	if (!wasm) return;
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(cardId);
	const ptr = writeBytes(encoded);
	const rc = wasm.hanzi_mark_read(ptr, encoded.length);
	if (rc !== 0) {
		console.error('[taijobi] markRead failed:', getLastError('markRead failed'));
	}
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();
}

export function getUnreadCards(filter: string, limit: number = 50): ReadCard[] {
	if (!wasm) return [];
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(filter);
	const ptr = filter ? writeBytes(encoded) : 0;
	const resultPtr = wasm.hanzi_get_unread_cards(ptr, encoded.length, limit);
	if (resultPtr === 0) return [];
	const json = readLengthPrefixedString(resultPtr);
	try {
		return JSON.parse(json);
	} catch (e) {
		console.error('[taijobi] Failed to parse unread cards JSON:', e);
		return [];
	}
}

export function getUnreadCount(filter: string): number {
	if (!wasm) return 0;
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(filter);
	const ptr = filter ? writeBytes(encoded) : 0;
	return wasm.hanzi_get_unread_count(ptr, encoded.length);
}

export async function reviewCard(id: string, rating: number): Promise<number> {
	if (!wasm) return -1;
	wasm.hanzi_reset_alloc();
	const idPtr = writeString(id);
	const rc = wasm.hanzi_review_card(idPtr, id.length, rating);
	if (rc !== 0) {
		getLastError('reviewCard failed');
	}
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();
	return rc;
}

export async function addWord(word: string): Promise<AddWordResult> {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(word);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_add_word(ptr, encoded.length);
	if (resultPtr === 0) {
		throw new Error(getLastError('addWord failed'));
	}
	const json = readLengthPrefixedString(resultPtr);
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();
	return JSON.parse(json);
}

export async function removeWord(id: string): Promise<void> {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(id);
	const ptr = writeBytes(encoded);
	const rc = wasm.hanzi_remove_word(ptr, encoded.length);
	if (rc !== 0) {
		throw new Error(getLastError('removeWord failed'));
	}
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();
}

export async function updateWord(id: string, translation: string): Promise<void> {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const idEncoded = new TextEncoder().encode(id);
	const idPtr = writeBytes(idEncoded);
	const transEncoded = new TextEncoder().encode(translation);
	const transPtr = writeBytes(transEncoded);
	const rc = wasm.hanzi_update_word(idPtr, idEncoded.length, transPtr, transEncoded.length);
	if (rc !== 0) {
		throw new Error(getLastError('updateWord failed'));
	}
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();
}

export interface DictResult {
	word: string;
	pos: string;
	definition: string;
}

export function lookupWord(query: string): DictResult[] {
	if (!wasm || typeof wasm.hanzi_lookup_word !== 'function') return [];
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(query);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_lookup_word(ptr, encoded.length);
	if (resultPtr === 0) return [];
	const json = readLengthPrefixedString(resultPtr);
	try {
		return JSON.parse(json);
	} catch {
		return [];
	}
}

export function isEndictLoaded(): boolean {
	if (!wasm || typeof wasm.hanzi_endict_loaded !== 'function') return false;
	return wasm.hanzi_endict_loaded() === 1;
}

export function isDedictLoaded(): boolean {
	if (!wasm || typeof wasm.hanzi_dedict_loaded !== 'function') return false;
	return wasm.hanzi_dedict_loaded() === 1;
}

export function unloadEndict(): void {
	if (!wasm || typeof wasm.hanzi_unload_endict !== 'function') return;
	wasm.hanzi_unload_endict();
}

export function unloadDedict(): void {
	if (!wasm || typeof wasm.hanzi_unload_dedict !== 'function') return;
	wasm.hanzi_unload_dedict();
}

export interface CardSearchResult {
	id: string;
	word: string;
	language: string;
	pinyin: string | null;
	translation: string | null;
	source_type: string;
	pack_id: string | null;
	context: string | null;
}

export function searchCards(query: string, limit = 20): CardSearchResult[] {
	return timed('searchCards', () => {
		if (!wasm || typeof wasm.hanzi_search_cards !== 'function') return [];
		if (!query) return [];
		wasm.hanzi_reset_alloc();
		const encoded = new TextEncoder().encode(query);
		const ptr = writeBytes(encoded);
		const resultPtr = wasm.hanzi_search_cards(ptr, encoded.length, limit);
		if (resultPtr === 0) return [];
		const json = readLengthPrefixedString(resultPtr);
		try {
			return JSON.parse(json);
		} catch (e) {
			console.error('[taijobi] Failed to parse searchCards JSON', e, json.slice(0, 200));
			return [];
		}
	});
}

/** Most recently reviewed card, or null if there are no reviews yet. */
export function getLastReviewedCard(): CardSearchResult | null {
	return timed('getLastReviewedCard', () => {
		if (!wasm || typeof wasm.hanzi_get_last_reviewed_card !== 'function') return null;
		const resultPtr = wasm.hanzi_get_last_reviewed_card();
		if (resultPtr === 0) return null;
		const json = readLengthPrefixedString(resultPtr);
		try {
			const arr = JSON.parse(json) as CardSearchResult[];
			return arr[0] ?? null;
		} catch (e) {
			console.error('[taijobi] Failed to parse getLastReviewedCard JSON', e, json.slice(0, 200));
			return null;
		}
	});
}

// === DevTools: raw SQL execution ===

export interface QueryResult {
	columns: string[];
	rows: (string | number | null)[][];
	count: number;
	truncated: boolean;
}

/**
 * Run arbitrary SQL and return a JSON result.
 * DevTools-only — not safe to expose to untrusted input. Row cap is 500,
 * result buffer is 2MB. Throws with the SQLite error message on failure.
 */
export function queryRaw(sql: string): QueryResult {
	if (!wasm) {
		throw new Error('WASM not initialized — reload the page');
	}
	if (typeof wasm.hanzi_query !== 'function') {
		throw new Error(
			'hanzi_query export missing — stale WASM. Hard-reload (Cmd+Shift+R) or unregister the service worker in DevTools → Application.'
		);
	}
	// Reset FBA so the 2MB scratch + length-prefixed copy don't accumulate
	// across queries. Safe here because DevTools doesn't interleave with
	// other WASM calls mid-flight.
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(sql);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_query(ptr, encoded.length);
	if (resultPtr === 0) {
		throw new Error(getLastError('SQL query failed'));
	}
	const json = readLengthPrefixedString(resultPtr);
	return JSON.parse(json) as QueryResult;
}

// === Bulk lexicon import (Kindle, future Anki, etc.) ===

export interface BulkAddResult {
	added: number;
	skipped: number;
	failed: number;
}

/**
 * Add many lexicon words in one SQLite transaction + one OPFS save.
 * Per-word `addWord()` would do N OPFS writes; this collapses to 1.
 *
 * Wire format (length-prefixed, little-endian u32):
 *   [count][len1][bytes1][len2][bytes2]...
 */
/** Kindle `My Clippings.txt` entry shape returned by the Zig parser. */
export interface KindleClipping {
	book: string;
	author: string;
	type: 'highlight' | 'note' | 'bookmark';
	text: string;
}

/**
 * Parse a raw My Clippings.txt file via the Zig parser. Bookmarks are
 * skipped server-side (they have no body). Throws on fatal parse errors.
 */
export function parseKindleClippings(raw: string): KindleClipping[] {
	if (!wasm) throw new Error('WASM not initialized — reload the page');
	if (typeof wasm.hanzi_parse_kindle !== 'function') {
		throw new Error(
			'hanzi_parse_kindle export missing — stale WASM. Hard-reload (Cmd+Shift+R) or unregister the service worker in DevTools → Application.'
		);
	}
	if (!raw) return [];

	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(raw);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_parse_kindle(ptr, encoded.length);
	if (resultPtr === 0) {
		throw new Error(getLastError('parseKindleClippings failed'));
	}
	const json = readLengthPrefixedString(resultPtr);
	return JSON.parse(json) as KindleClipping[];
}

export async function bulkAddLexicon(words: string[]): Promise<BulkAddResult> {
	if (!wasm) throw new Error('WASM not initialized — reload the page');
	if (typeof wasm.hanzi_bulk_add_lexicon !== 'function') {
		throw new Error(
			'hanzi_bulk_add_lexicon export missing — stale WASM. Hard-reload (Cmd+Shift+R) or unregister the service worker in DevTools → Application.'
		);
	}
	if (words.length === 0) return { added: 0, skipped: 0, failed: 0 };

	wasm.hanzi_reset_alloc();

	const enc = new TextEncoder();
	const encoded = words.map((w) => enc.encode(w));
	const total = 4 + encoded.reduce((sum, e) => sum + 4 + e.length, 0);
	const buf = new Uint8Array(total);
	const view = new DataView(buf.buffer);
	view.setUint32(0, words.length, true);
	let off = 4;
	for (const e of encoded) {
		view.setUint32(off, e.length, true);
		off += 4;
		buf.set(e, off);
		off += e.length;
	}

	const ptr = writeBytes(buf);
	const resultPtr = wasm.hanzi_bulk_add_lexicon(ptr, buf.length);
	if (resultPtr === 0) {
		throw new Error(getLastError('bulkAddLexicon failed'));
	}
	const json = readLengthPrefixedString(resultPtr);
	const result = JSON.parse(json) as BulkAddResult;

	// One OPFS save for the whole batch — the whole point of this path.
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();

	return result;
}

export function lookupCedict(query: string): CedictResult[] {
	if (!wasm) return [];
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(query);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_lookup(ptr, encoded.length);
	if (resultPtr === 0) return [];
	const json = readLengthPrefixedString(resultPtr);
	try {
		return JSON.parse(json);
	} catch {
		return [];
	}
}

export function getLexicon(): LexiconEntry[] {
	return timed('getLexicon', () => {
		if (!wasm) return [];
		wasm.hanzi_reset_alloc();
		const ptr = wasm.hanzi_get_lexicon();
		if (ptr === 0) return [];
		const json = readLengthPrefixedString(ptr);
		try {
			return JSON.parse(json);
		} catch {
			console.error('[taijobi] Failed to parse lexicon JSON');
			return [];
		}
	});
}

export function getDrillStats(): DrillStats {
	return timed('getDrillStats', () => {
		if (!wasm) return { reviewed_today: 0, correct_today: 0, total_cards: 0, lexicon_count: 0 };
		wasm.hanzi_reset_alloc();
		const ptr = wasm.hanzi_get_drill_stats();
		if (ptr === 0) return { reviewed_today: 0, correct_today: 0, total_cards: 0, lexicon_count: 0 };
		const json = readLengthPrefixedString(ptr);
		try {
			return JSON.parse(json);
		} catch {
			console.error('[taijobi] Failed to parse drill stats JSON');
			return { reviewed_today: 0, correct_today: 0, total_cards: 0, lexicon_count: 0 };
		}
	});
}

export function getStats(days: number = 30): StatsData {
	return timed('getStats', () => {
		const empty: StatsData = { days: [], ratings: [0, 0, 0, 0], streak: 0, longest_streak: 0 };
		if (!wasm || typeof wasm.hanzi_get_stats !== 'function') return empty;
		wasm.hanzi_reset_alloc();
		const ptr = wasm.hanzi_get_stats(days);
		if (ptr === 0) return empty;
		const json = readLengthPrefixedString(ptr);
		try {
			return JSON.parse(json);
		} catch {
			console.error('[taijobi] Failed to parse stats JSON');
			return empty;
		}
	});
}

// --- Phase 2: Content Packs ---

export interface Pack {
	id: string;
	name: string;
	version: number;
	language_pair: string;
	word_count: number;
}

export interface Lesson {
	id: string;
	title: string | null;
	sort_order: number;
	total: number;
	mastered: number;
}

export interface VocabEntry {
	id: string;
	word: string;
	pinyin: string | null;
	translation: string | null;
	reps: number;
	stability: number;
}

export interface PackProgress {
	total: number;
	reviewed: number;
	mastered: number;
}

export async function installPack(json: string): Promise<void> {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(json);
	const ptr = writeBytes(encoded);
	const rc = wasm.hanzi_install_pack(ptr, encoded.length);
	if (rc !== 0) {
		throw new Error(getLastError('installPack failed'));
	}
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();
}

export function getPacks(): Pack[] {
	if (!wasm) return [];
	wasm.hanzi_reset_alloc();
	const ptr = wasm.hanzi_get_packs();
	if (ptr === 0) return [];
	const json = readLengthPrefixedString(ptr);
	try {
		return JSON.parse(json);
	} catch {
		return [];
	}
}

export async function removePack(id: string): Promise<void> {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(id);
	const ptr = writeBytes(encoded);
	const rc = wasm.hanzi_remove_pack(ptr, encoded.length);
	if (rc !== 0) {
		throw new Error(getLastError('removePack failed'));
	}
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();
}

export async function restorePack(id: string): Promise<void> {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(id);
	const ptr = writeBytes(encoded);
	const rc = wasm.hanzi_restore_pack(ptr, encoded.length);
	if (rc !== 0) {
		throw new Error(getLastError('restorePack failed'));
	}
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();
}

export function getLessons(packId: string): Lesson[] {
	if (!wasm) return [];
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(packId);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_get_lessons(ptr, encoded.length);
	if (resultPtr === 0) return [];
	const json = readLengthPrefixedString(resultPtr);
	try {
		return JSON.parse(json);
	} catch {
		return [];
	}
}

export function getVocabulary(lessonId: string): VocabEntry[] {
	if (!wasm) return [];
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(lessonId);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_get_vocabulary(ptr, encoded.length);
	if (resultPtr === 0) return [];
	const json = readLengthPrefixedString(resultPtr);
	try {
		return JSON.parse(json);
	} catch {
		return [];
	}
}

export function getPackProgress(packId: string): PackProgress {
	if (!wasm) return { total: 0, reviewed: 0, mastered: 0 };
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(packId);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_get_progress(ptr, encoded.length);
	if (resultPtr === 0) return { total: 0, reviewed: 0, mastered: 0 };
	const json = readLengthPrefixedString(resultPtr);
	try {
		return JSON.parse(json);
	} catch {
		return { total: 0, reviewed: 0, mastered: 0 };
	}
}

// --- Phase 3: Deep Chinese ---

export interface DecompComponent {
	char: string;
	definition: string;
	type: 'radical' | 'component';
}

export interface DecompResult {
	character: string;
	radical: string;
	decomposition: string;
	pinyin: string;
	definition: string;
	etymology_type: string;
	etymology_hint: string;
	components: DecompComponent[];
}

export interface StrokeData {
	character: string;
	stroke_count: number;
	strokes: string[];
	medians: number[][][];
}

export function decompose(char: string): DecompResult | null {
	if (!wasm) return null;
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(char);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_decompose(ptr, encoded.length);
	if (resultPtr === 0) return null;
	const json = readLengthPrefixedString(resultPtr);
	try {
		return JSON.parse(json);
	} catch {
		return null;
	}
}

export function getStrokes(char: string): StrokeData | null {
	if (!wasm) return null;
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(char);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_get_strokes(ptr, encoded.length);
	if (resultPtr === 0) return null;
	const json = readLengthPrefixedString(resultPtr);
	try {
		return JSON.parse(json);
	} catch {
		return null;
	}
}

export interface AnswerResult {
	correct: boolean;
	expected: string;
	actual: string;
}

/**
 * Check if a user's answer matches the expected answer.
 * Generous matching: case-insensitive, strip German articles, normalize pinyin.
 */
export function checkAnswer(answer: string, expected: string, lang: string): AnswerResult {
	const actual = answer.trim();
	const exp = expected.trim();

	if (!actual || !exp) {
		return { correct: false, expected: exp, actual };
	}

	const normActual = normalizeAnswer(actual, lang);
	const normExpected = normalizeAnswer(exp, lang);

	return {
		correct: normActual === normExpected,
		expected: exp,
		actual
	};
}

function normalizeAnswer(s: string, lang: string): string {
	let result = s.toLowerCase().trim();

	if (lang === 'de') {
		// Strip German articles
		result = result.replace(/^(der|die|das|ein|eine|einen|einem|einer)\s+/i, '');
	}

	if (lang === 'zh' || lang === 'pinyin') {
		result = normalizePinyin(result);
	}

	return result;
}

/**
 * Normalize pinyin: strip tone numbers, convert diacritics to base vowels,
 * remove spaces, lowercase.
 */
function normalizePinyin(s: string): string {
	const diacriticMap: Record<string, string> = {
		ā: 'a',
		á: 'a',
		ǎ: 'a',
		à: 'a',
		ē: 'e',
		é: 'e',
		ě: 'e',
		è: 'e',
		ī: 'i',
		í: 'i',
		ǐ: 'i',
		ì: 'i',
		ō: 'o',
		ó: 'o',
		ǒ: 'o',
		ò: 'o',
		ū: 'u',
		ú: 'u',
		ǔ: 'u',
		ù: 'u',
		ǖ: 'v',
		ǘ: 'v',
		ǚ: 'v',
		ǜ: 'v',
		ü: 'v'
	};

	let result = '';
	for (const ch of s) {
		if (ch >= '1' && ch <= '5') continue;
		if (ch === ' ') continue;
		result += diacriticMap[ch] ?? ch;
	}
	return result.toLowerCase();
}

// --- Phase 3.5: CSV Import/Export ---

export async function importCsv(text: string, name: string): Promise<number> {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const csvEncoded = new TextEncoder().encode(text);
	const csvPtr = writeBytes(csvEncoded);
	const nameEncoded = new TextEncoder().encode(name);
	const namePtr = writeBytes(nameEncoded);
	const rc = wasm.hanzi_import_csv(csvPtr, csvEncoded.length, namePtr, nameEncoded.length);
	if (rc < 0) {
		throw new Error(getLastError('CSV import failed'));
	}
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();
	return rc;
}

export async function importApkg(data: ArrayBuffer, name: string): Promise<number> {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const bytes = new Uint8Array(data);
	console.log(`[taijobi] importApkg: ${bytes.length} bytes, name="${name}"`);
	console.log(
		`[taijobi] importApkg: first 4 bytes: ${Array.from(bytes.slice(0, 4))
			.map((b) => b.toString(16).padStart(2, '0'))
			.join(' ')}`
	);
	const dataPtr = writeBytes(bytes);
	const nameEncoded = new TextEncoder().encode(name);
	const namePtr = writeBytes(nameEncoded);
	console.log(`[taijobi] importApkg: calling WASM (dataPtr=${dataPtr}, namePtr=${namePtr})`);
	const rc = wasm.hanzi_import_apkg(dataPtr, bytes.length, namePtr, nameEncoded.length);
	console.log(`[taijobi] importApkg: rc=${rc}`);
	if (rc < 0) {
		throw new Error(getLastError('.apkg import failed'));
	}
	await opfsSave();
	onMutateCb?.();
	onDataChangedCb?.();
	return rc;
}

export function exportCsv(): string {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const ptr = wasm.hanzi_export_csv();
	if (ptr === 0) {
		throw new Error(getLastError('CSV export failed'));
	}
	return readLengthPrefixedString(ptr);
}

// --- DevTools helpers ---

export function getWasmMemoryBytes(): number {
	if (!wasm) return 0;
	return wasm.memory.buffer.byteLength;
}

export function getWasmDbSize(): number {
	if (!wasm) return 0;
	return wasm.hanzi_db_size();
}

export function getBuildId(): string {
	if (!wasm) return 'unknown';
	wasm.hanzi_reset_alloc();
	const ptr = (wasm as unknown as { hanzi_build_id: () => number }).hanzi_build_id();
	if (ptr === 0) return 'unknown';
	return readLengthPrefixedString(ptr);
}

export function isReady(): boolean {
	return wasm !== null;
}

export function close(): void {
	if (!wasm) return;
	wasm.hanzi_close();
}

// --- Phase 4: Sync helpers ---

export function getChanges(sinceTs: number): SyncRow[] {
	if (!wasm) return [];
	wasm.hanzi_reset_alloc();
	const ptr = wasm.hanzi_get_changes(BigInt(sinceTs));
	if (ptr === 0) return [];
	const json = readLengthPrefixedString(ptr);
	try {
		const result = JSON.parse(json) as { rows: SyncRow[] };
		return result.rows ?? [];
	} catch (e) {
		console.error('[taijobi] Failed to parse changes JSON:', e);
		return [];
	}
}

export function applyChanges(rows: SyncRow[]): number {
	if (!wasm) return 0;
	wasm.hanzi_reset_alloc();
	const json = JSON.stringify({ rows });
	const encoded = new TextEncoder().encode(json);
	const ptr = writeBytes(encoded);
	return wasm.hanzi_apply_changes(ptr, encoded.length);
}

export function deriveEncryptionKey(syncKey: string): Uint8Array {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(syncKey);
	const ptr = writeBytes(encoded);
	const resultPtr = wasm.hanzi_derive_key(ptr, encoded.length);
	if (resultPtr === 0) throw new Error('Failed to derive key');
	const mem = new Uint8Array(wasm.memory.buffer);
	const len =
		mem[resultPtr] |
		(mem[resultPtr + 1] << 8) |
		(mem[resultPtr + 2] << 16) |
		(mem[resultPtr + 3] << 24);
	return new Uint8Array(mem.slice(resultPtr + 4, resultPtr + 4 + len));
}

export function encryptField(plaintext: string, key: Uint8Array): string {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const ptEncoded = new TextEncoder().encode(plaintext);
	const ptPtr = writeBytes(ptEncoded);
	const keyPtr = writeBytes(key);
	// Generate 24-byte nonce from crypto.getRandomValues
	const nonce = new Uint8Array(24);
	crypto.getRandomValues(nonce);
	const noncePtr = writeBytes(nonce);
	const resultPtr = wasm.hanzi_encrypt_field(ptPtr, ptEncoded.length, keyPtr, noncePtr);
	if (resultPtr === 0) throw new Error('Encryption failed');
	return readLengthPrefixedString(resultPtr);
}

export function decryptField(ciphertext: string, key: Uint8Array): string {
	if (!wasm) throw new Error('WASM not initialized');
	wasm.hanzi_reset_alloc();
	const ctEncoded = new TextEncoder().encode(ciphertext);
	const ctPtr = writeBytes(ctEncoded);
	const keyPtr = writeBytes(key);
	const resultPtr = wasm.hanzi_decrypt_field(ctPtr, ctEncoded.length, keyPtr);
	if (resultPtr === 0) throw new Error('Decryption failed');
	return readLengthPrefixedString(resultPtr);
}

export function decryptRows(rows: SyncRow[], key: Uint8Array): SyncRow[] {
	return rows.map((row) => {
		if (typeof row.data === 'string') {
			try {
				const decrypted = decryptField(row.data, key);
				return { ...row, data: JSON.parse(decrypted) as Record<string, unknown> };
			} catch {
				console.warn('[taijobi] Failed to decrypt row:', row.table, row.id);
				return row;
			}
		}
		return row;
	});
}

export { opfsSave };
