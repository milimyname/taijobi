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
	isChineseDataLoaded
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

/** Load data from OPFS cache into WASM (no network). Called at startup. */
export async function loadCachedData(): Promise<void> {
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
		console.warn('[taijobi] Chinese data: OPFS cache load failed:', e);
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

async function downloadSpecificFiles(
	files: DataFile[],
	onProgress?: (loaded: number, total: number) => void
): Promise<void> {
	const root = await navigator.storage.getDirectory();
	const dir = await root.getDirectoryHandle(OPFS_DIR, { create: true });

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

	onProgress?.(0, totalBytes);

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
				onProgress?.(loadedBytes, totalBytes);
			}
		} else {
			// Fallback for environments without streaming body
			const ab = await resp.arrayBuffer();
			chunks.push(new Uint8Array(ab));
			received = ab.byteLength;
			loadedBytes += ab.byteLength;
			onProgress?.(loadedBytes, totalBytes);
		}

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

		// Write to WASM
		writeToWasm(file.key, buf);

		// Cache in OPFS
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
			console.warn(`[taijobi] Chinese data: OPFS cache write failed for ${file.key}:`, e);
			throw e;
		}

		console.log(`[taijobi] Chinese data: downloaded ${file.key} (${buf.length} bytes)`);
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
	try {
		const root = await navigator.storage.getDirectory();
		await root.removeEntry(OPFS_DIR, { recursive: true });
		console.log('[taijobi] Chinese data: OPFS cache cleared');
	} catch {
		// Doesn't exist
	}
}
