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
	hanzi_review_card: (id: number, idLen: number, rating: number) => number;
	hanzi_add_word: (word: number, len: number) => number;
	hanzi_remove_word: (id: number, len: number) => number;
	hanzi_update_word: (id: number, idLen: number, trans: number, transLen: number) => number;
	hanzi_lookup: (query: number, len: number) => number;
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
	hanzi_db_ptr: () => number;
	hanzi_db_size: () => number;
	hanzi_db_load: (data: number, size: number) => number;
}

let wasm: WasmExports | null = null;

const OPFS_DB_NAME = 'taijobi.db';

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
}

export function getDueCount(): number {
	if (!wasm) return 0;
	return wasm.hanzi_get_due_count();
}

export function getDueCards(limit: number = 50): Card[] {
	if (!wasm) return [];
	wasm.hanzi_reset_alloc();
	const ptr = wasm.hanzi_get_due_cards(limit);
	if (ptr === 0) return [];
	const json = readLengthPrefixedString(ptr);
	wasm.hanzi_free(ptr, 0);
	try {
		return JSON.parse(json);
	} catch {
		console.error('[taijobi] Failed to parse due cards JSON');
		return [];
	}
}

export function getDueCardsFiltered(filter: string, limit: number = 50): Card[] {
	if (!wasm) return [];
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(filter);
	const ptr = filter ? writeBytes(encoded) : 0;
	const resultPtr = wasm.hanzi_get_due_cards_filtered(ptr, encoded.length, limit);
	if (resultPtr === 0) return [];
	const json = readLengthPrefixedString(resultPtr);
	try {
		return JSON.parse(json);
	} catch {
		return [];
	}
}

export function getDueCountFiltered(filter: string): number {
	if (!wasm) return 0;
	wasm.hanzi_reset_alloc();
	const encoded = new TextEncoder().encode(filter);
	const ptr = filter ? writeBytes(encoded) : 0;
	return wasm.hanzi_get_due_count_filtered(ptr, encoded.length);
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
}

export function getDrillStats(): DrillStats {
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

export function isReady(): boolean {
	return wasm !== null;
}

export function close(): void {
	if (!wasm) return;
	wasm.hanzi_close();
}

export { opfsSave };
