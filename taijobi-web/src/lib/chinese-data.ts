/**
 * Chinese data on-demand download, OPFS cache, and WASM loading.
 *
 * Three .bin files (cedict, decomp, strokes) are served as static assets
 * and loaded into WASM memory at runtime instead of being embedded.
 */

import { persistAlloc, loadCedict, loadDecomp, loadStrokes, isChineseDataLoaded } from "./wasm";

type DataKey = "cedict" | "decomp" | "strokes";

const FILES: { key: DataKey; path: string }[] = [
  { key: "cedict", path: "/data/cedict.bin" },
  { key: "decomp", path: "/data/decomp.bin" },
  { key: "strokes", path: "/data/strokes.bin" },
];

const OPFS_DIR = "chinese-data";

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

    for (const file of FILES) {
      try {
        const fh = await dir.getFileHandle(`${file.key}.bin`);
        const f = await fh.getFile();
        if (f.size === 0) continue;
        const buf = new Uint8Array(await f.arrayBuffer());
        writeToWasm(file.key, buf);
        console.log(`[taijobi] Chinese data: loaded ${file.key} from OPFS (${buf.length} bytes)`);
      } catch {
        // File doesn't exist in cache
      }
    }
  } catch (e) {
    console.warn("[taijobi] Chinese data: OPFS cache load failed:", e);
  }
}

/** Download all Chinese data files from origin, write to OPFS + WASM. */
export async function downloadAndLoad(
  onProgress?: (loaded: number, total: number) => void,
): Promise<void> {
  const root = await navigator.storage.getDirectory();
  const dir = await root.getDirectoryHandle(OPFS_DIR, { create: true });

  let totalBytes = 0;
  let loadedBytes = 0;

  // First pass: HEAD requests to get total size
  for (const file of FILES) {
    try {
      const resp = await fetch(file.path, { method: "HEAD" });
      const cl = resp.headers.get("content-length");
      if (cl) totalBytes += parseInt(cl, 10);
    } catch {
      // Estimate if HEAD fails
      totalBytes += 5_000_000;
    }
  }

  onProgress?.(0, totalBytes);

  for (const file of FILES) {
    const resp = await fetch(file.path);
    if (!resp.ok) throw new Error(`Failed to download ${file.path}: ${resp.status}`);

    const buf = new Uint8Array(await resp.arrayBuffer());
    loadedBytes += buf.length;

    // Write to WASM
    writeToWasm(file.key, buf);

    // Cache in OPFS
    try {
      const fh = await dir.getFileHandle(`${file.key}.bin`, { create: true });
      if (typeof fh.createWritable === "function") {
        const w = await fh.createWritable();
        await w.write(buf);
        await w.close();
      } else {
        // Fallback: write via Worker + createSyncAccessHandle for older Safari
        await opfsWriteViaWorker(OPFS_DIR + "/" + file.key + ".bin", buf);
      }
    } catch (e) {
      console.warn(`[taijobi] Chinese data: OPFS cache write failed for ${file.key}:`, e);
    }

    onProgress?.(loadedBytes, totalBytes);
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
  const workerBlob = new Blob([workerCode], { type: "text/javascript" });
  const worker = new Worker(URL.createObjectURL(workerBlob));
  await new Promise<void>((resolve, reject) => {
    worker.addEventListener("message", (e) => {
      worker.terminate();
      if (e.data?.error) reject(new Error(e.data.error));
      else resolve();
    });
    worker.addEventListener("error", (err) => {
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
    case "cedict":
      loadCedict(ptr, buf);
      break;
    case "decomp":
      loadDecomp(ptr, buf);
      break;
    case "strokes":
      loadStrokes(ptr, buf);
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
    console.log("[taijobi] Chinese data: OPFS cache cleared");
  } catch {
    // Doesn't exist
  }
}
