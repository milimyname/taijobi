/**
 * Dictionary data on-demand download, OPFS cache, and WASM loading.
 *
 * Five .bin files served as static assets and loaded into WASM at runtime:
 *   Chinese: cedict, decomp, strokes
 *   EN/DE:   endict, dedict (Wiktextract)
 */

import {
	persistAlloc,
	loadCedict,
	loadDecomp,
	loadStrokes,
	loadEndict,
	loadDedict,
	isChineseDataLoaded,
	unloadChinese,
	unloadEndict,
	unloadDedict
} from './wasm';

type DataKey = 'cedict' | 'decomp' | 'strokes' | 'endict' | 'dedict';

interface DataFile {
	key: DataKey;
	path: string;
}

const CHINESE_FILES: DataFile[] = [
	{ key: 'cedict', path: '/data/cedict.bin' },
	{ key: 'decomp', path: '/data/decomp.bin' },
	{ key: 'strokes', path: '/data/strokes.bin' }
];

const ALL_FILES: DataFile[] = [
	...CHINESE_FILES,
	{ key: 'endict', path: '/data/endict.bin' },
	{ key: 'dedict', path: '/data/dedict.bin' }
];

const OPFS_DIR = 'dictionary-data';

/** OPFS requires a secure context (HTTPS or localhost). Safari on LAN IPs over
 *  plain HTTP does not expose it, and some older/embedded browsers lack it too.
 *  When unavailable we still download + load into WASM for the session, just
 *  without durable persistence. */
function opfsAvailable(): boolean {
	return (
		typeof navigator !== 'undefined' &&
		!!navigator.storage &&
		typeof navigator.storage.getDirectory === 'function'
	);
}

/** Load data from OPFS cache into WASM (no network). Called at startup. */
export async function loadCachedData(): Promise<void> {
	if (!opfsAvailable()) {
		console.info('[taijobi] data: OPFS unavailable — skipping cache load');
		return;
	}
	try {
		const root = await navigator.storage.getDirectory();
		let dir: FileSystemDirectoryHandle;
		try {
			dir = await root.getDirectoryHandle(OPFS_DIR);
		} catch {
			// Directory doesn't exist yet — no cached data
			return;
		}

		for (const file of ALL_FILES) {
			try {
				const fh = await dir.getFileHandle(`${file.key}.bin`);
				const f = await fh.getFile();
				if (f.size === 0) continue;
				const buf = new Uint8Array(await f.arrayBuffer());
				writeToWasm(file.key, buf);
				console.log(`[taijobi] data: loaded ${file.key} from OPFS (${buf.length} bytes)`);
			} catch {
				// File doesn't exist in cache
			}
		}
	} catch (e) {
		console.warn('[taijobi] data: OPFS cache load failed:', e);
	}
}

/** Download Chinese data files (cedict, decomp, strokes). */
export async function downloadAndLoad(
	onProgress?: (loaded: number, total: number) => void
): Promise<void> {
	return downloadSpecificFiles(CHINESE_FILES, onProgress);
}

/** Download specific dictionary files by key. */
export async function downloadByKeys(
	keys: DataKey[],
	onProgress?: (loaded: number, total: number) => void
): Promise<void> {
	const files = ALL_FILES.filter((f) => keys.includes(f.key));
	return downloadSpecificFiles(files, onProgress);
}

/** Yield to the event loop so the browser can paint and run other tasks. */
function yieldToMain(): Promise<void> {
	// Use scheduler.yield() if available (Chrome 129+), otherwise fall back to
	// MessageChannel-based microtask, otherwise setTimeout.
	const sched = (globalThis as { scheduler?: { yield?: () => Promise<void> } }).scheduler;
	if (sched && typeof sched.yield === 'function') {
		return sched.yield();
	}
	return new Promise((resolve) => setTimeout(resolve, 0));
}

async function downloadSpecificFiles(
	files: DataFile[],
	onProgress?: (loaded: number, total: number) => void
): Promise<void> {
	// OPFS is best-effort. If unavailable (Safari on LAN IP over HTTP, private
	// browsing in some browsers, etc.) we still download + load into WASM; the
	// user just loses the cache on reload.
	let dir: FileSystemDirectoryHandle | null = null;
	if (opfsAvailable()) {
		try {
			const root = await navigator.storage.getDirectory();
			dir = await root.getDirectoryHandle(OPFS_DIR, { create: true });
		} catch (e) {
			console.warn('[taijobi] data: OPFS unavailable, download will not persist:', e);
		}
	}

	// Parallel HEAD requests to get total size up front
	const sizes = await Promise.all(
		files.map(async (file) => {
			try {
				const resp = await fetch(file.path, { method: 'HEAD' });
				const cl = resp.headers.get('content-length');
				return cl ? parseInt(cl, 10) : 5_000_000;
			} catch {
				return 5_000_000;
			}
		})
	);
	const totalBytes = sizes.reduce((a, b) => a + b, 0);
	let loadedBytes = 0;

	// Throttle progress callbacks to ~30Hz so reactive UI doesn't re-render on
	// every 16KB chunk. Without this, a 19MB file fires ~1200 progress events
	// and the browser drops frames trying to keep up.
	let lastProgressAt = 0;
	const PROGRESS_INTERVAL_MS = 33;
	function emitProgress(loaded: number, total: number, force = false): void {
		const now = performance.now();
		if (force || now - lastProgressAt >= PROGRESS_INTERVAL_MS) {
			lastProgressAt = now;
			onProgress?.(loaded, total);
		}
	}

	emitProgress(0, totalBytes, true);

	for (const file of files) {
		const resp = await fetch(file.path);
		if (!resp.ok) throw new Error(`Failed to download ${file.path}: ${resp.status}`);

		// Stream chunks so progress updates during the download, not after
		const contentLength = parseInt(resp.headers.get('content-length') ?? '0', 10);
		const chunks: Uint8Array[] = [];
		let received = 0;

		if (resp.body) {
			const reader = resp.body.getReader();
			while (true) {
				const { done, value } = await reader.read();
				if (done) break;
				chunks.push(value);
				received += value.length;
				loadedBytes += value.length;
				emitProgress(loadedBytes, totalBytes);
			}
		} else {
			// Fallback for environments without streaming body
			const ab = await resp.arrayBuffer();
			chunks.push(new Uint8Array(ab));
			received = ab.byteLength;
			loadedBytes += ab.byteLength;
			emitProgress(loadedBytes, totalBytes);
		}

		// Force-emit at 100% so the bar lands on the final position before we
		// hand off to the OPFS write + WASM parse stages.
		emitProgress(loadedBytes, totalBytes, true);

		// Yield to the event loop so the browser can paint the 100% bar before
		// we start the synchronous chunk concat.
		await yieldToMain();

		// Concatenate chunks into a single buffer
		const buf = new Uint8Array(received);
		let offset = 0;
		for (const c of chunks) {
			buf.set(c, offset);
			offset += c.length;
		}

		// Sanity check against advertised size
		if (contentLength > 0 && buf.length !== contentLength) {
			throw new Error(`Incomplete download for ${file.path}: ${buf.length}/${contentLength} bytes`);
		}

		// Write to OPFS FIRST so the file is durably cached even if the WASM
		// parse below fails or the user closes the tab. Subsequent runs will
		// load from OPFS via loadCachedData(). If OPFS is unavailable we skip
		// persistence and still load into WASM below.
		if (dir) {
			try {
				const fh = await dir.getFileHandle(`${file.key}.bin`, { create: true });
				if (typeof fh.createWritable === 'function') {
					const w = await fh.createWritable();
					await w.write(buf);
					await w.close();
				} else {
					// Fallback: write via Worker + createSyncAccessHandle for older Safari
					await opfsWriteViaWorker(OPFS_DIR + '/' + file.key + '.bin', buf);
				}
			} catch (e) {
				// Cache write failed — log but continue, don't fail the whole download.
				console.warn(`[taijobi] data: OPFS cache write failed for ${file.key}:`, e);
			}
		}

		// Yield again before the synchronous WASM parse — this is the longest
		// blocking step (loadEndict on 19MB takes hundreds of ms). Yielding
		// here lets the browser repaint the bar and any "Wird geladen..." UI.
		await yieldToMain();

		// Write to WASM (synchronous, blocks main thread for the parse)
		writeToWasm(file.key, buf);

		// Yield once more so subsequent reactive updates (e.g. data.bump from
		// the caller) can repaint without piling up.
		await yieldToMain();

		console.log(`[taijobi] data: downloaded ${file.key} (${buf.length} bytes)`);
	}
}

/** Write to OPFS via Worker + createSyncAccessHandle (Safari fallback). */
async function opfsWriteViaWorker(path: string, data: Uint8Array): Promise<void> {
	const workerCode = `
		onmessage = async (e) => {
			try {
				const root = await navigator.storage.getDirectory();
				let dir = root;
				const parts = e.data.path.split('/');
				const fileName = parts.pop();
				for (const part of parts) {
					dir = await dir.getDirectoryHandle(part, { create: true });
				}
				const fh = await dir.getFileHandle(fileName, { create: true });
				const ah = await fh.createSyncAccessHandle();
				ah.truncate(0);
				ah.write(e.data.bytes);
				ah.flush();
				ah.close();
				postMessage("done");
			} catch (err) {
				postMessage({ error: err.message });
			}
		};
	`;
	const workerBlob = new Blob([workerCode], { type: 'text/javascript' });
	const worker = new Worker(URL.createObjectURL(workerBlob));
	await new Promise<void>((resolve, reject) => {
		worker.addEventListener('message', (e) => {
			worker.terminate();
			if (e.data?.error) reject(new Error(e.data.error));
			else resolve();
		});
		worker.addEventListener('error', (err) => {
			worker.terminate();
			reject(err);
		});
		// oxlint-disable-next-line require-post-message-target-origin -- Worker.postMessage's 2nd arg is `transfer`, not a target origin (that's Window.postMessage).
		worker.postMessage({ path, bytes: data });
	});
}

function writeToWasm(key: DataKey, buf: Uint8Array): void {
	const ptr = persistAlloc(buf.length);
	if (ptr === 0) {
		console.error(`[taijobi] Chinese data: persistent alloc failed for ${key}`);
		return;
	}

	switch (key) {
		case 'cedict':
			loadCedict(ptr, buf);
			break;
		case 'decomp':
			loadDecomp(ptr, buf);
			break;
		case 'strokes':
			loadStrokes(ptr, buf);
			break;
		case 'endict':
			loadEndict(ptr, buf);
			break;
		case 'dedict':
			loadDedict(ptr, buf);
			break;
	}
}

/** Check if all three data files are loaded in WASM. */
export function isLoaded(): boolean {
	return isChineseDataLoaded();
}

/** Clear cached data from OPFS. */
export async function clearCache(): Promise<void> {
	if (!opfsAvailable()) return;
	try {
		const root = await navigator.storage.getDirectory();
		await root.removeEntry(OPFS_DIR, { recursive: true });
		console.log('[taijobi] data: OPFS cache cleared');
	} catch {
		// Doesn't exist
	}
}

/**
 * Uninstall a dictionary bundle. Clears the WASM data slice reference so
 * `*_loaded()` returns false and the UI reflects removal, then deletes the
 * underlying .bin file(s) from OPFS so the next session starts clean.
 *
 * The bytes in the WASM persistent allocator stay reserved until the next
 * page reload — the FBA is an arena without per-block free. Callers should
 * hint the user to reload if they want the memory back.
 */
export async function uninstallDictionary(kind: 'zh' | 'en' | 'de'): Promise<void> {
	if (kind === 'zh') unloadChinese();
	else if (kind === 'en') unloadEndict();
	else unloadDedict();

	if (!opfsAvailable()) return;
	const files = kind === 'zh' ? CHINESE_FILES.map((f) => f.key) : [kind === 'en' ? 'endict' : 'dedict'];
	try {
		const root = await navigator.storage.getDirectory();
		const dir = await root.getDirectoryHandle(OPFS_DIR);
		for (const key of files) {
			try {
				await dir.removeEntry(`${key}.bin`);
			} catch {
				// File didn't exist
			}
		}
	} catch {
		// OPFS dir missing — nothing to clean
	}
}
