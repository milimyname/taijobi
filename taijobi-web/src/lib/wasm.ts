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
	hanzi_review_card: (id: number, idLen: number, rating: number) => number;
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
						(result.exports as { memory: WebAssembly.Memory }).memory.buffer,
					);
					const msg = new TextDecoder().decode(mem.slice(ptr, ptr + len));
					console.log('[taijobi]', msg);
				} catch {
					console.log('[taijobi] (log failed, ptr=%d len=%d)', ptr, len);
				}
			},
			js_time_ms: () => BigInt(Date.now()),
		},
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

	const result = await WebAssembly.instantiate(
		compiled,
		importObject as WebAssembly.Imports,
	);
	wasm = result.exports as unknown as WasmExports;

	console.log(
		'[taijobi] exports:',
		WebAssembly.Module.exports(compiled)
			.map((e) => e.name)
			.join(', '),
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

export function isReady(): boolean {
	return wasm !== null;
}

export function close(): void {
	if (!wasm) return;
	wasm.hanzi_close();
}

export { opfsSave };
