/**
 * libtaijobi WASM loader for Cloudflare Workers (MCP server).
 *
 * Uses the compact build (libtaijobi-mcp.wasm, 16MB persist allocator) so the
 * full instance fits inside the Worker's 128MB memory cap. Shape mirrors the
 * web client's wasm.ts for the subset of exports the MCP tool surface uses.
 *
 * Every method here is a thin wrapper around a Zig export — JSON in, JSON out
 * via length-prefixed `Uint8Array`. See `libtaijobi/src/root.zig` for the
 * canonical signatures.
 */

// Cloudflare bundles .wasm files as WebAssembly.Module via wrangler's
// [[rules]] (see wrangler.toml).
import wasmModule from "../libtaijobi-mcp.wasm";

// --- Domain types (match the JSON returned by hanzi_* exports) ---

export interface Card {
  id: string;
  word: string;
  language: string;
  pinyin?: string;
  translation?: string;
  source_type: string;
  pack_id?: string;
  reps?: number;
  intervals?: { again: number; hard: number; good: number; easy: number };
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

export interface StatsData {
  days: { d: number; c: number; r: number }[];
  ratings: number[];
  streak: number;
  longest_streak: number;
}

export interface BulkAddResult {
  added: number;
  skipped: number;
  failed: number;
}

export interface KindleClipping {
  book: string;
  author: string;
  type: "highlight" | "note" | "bookmark";
  text: string;
}

export interface SyncRow {
  table: string;
  id: string;
  data: Record<string, unknown> | string;
  updated_at: number;
}

// --- WASM export surface (MCP tool subset) ---

interface WasmExports {
  memory: WebAssembly.Memory;
  hanzi_init: (path: number) => number;
  hanzi_close: () => void;
  hanzi_alloc: (size: number) => number;
  hanzi_free: (ptr: number, len: number) => void;
  hanzi_reset_alloc: () => void;
  hanzi_get_error: () => number;

  // Read
  hanzi_get_due_count: () => number;
  hanzi_get_due_count_filtered: (filter: number, filterLen: number) => number;
  hanzi_get_due_cards: (limit: number) => number;
  hanzi_get_due_cards_filtered: (filter: number, filterLen: number, limit: number) => number;
  hanzi_search_cards: (query: number, len: number, limit: number) => number;
  hanzi_get_lexicon: () => number;
  hanzi_get_stats: (days: number) => number;

  // Write
  hanzi_add_word: (word: number, len: number) => number;
  hanzi_review_card: (id: number, idLen: number, rating: number) => number;
  hanzi_parse_kindle: (data: number, len: number) => number;
  hanzi_bulk_add_lexicon: (data: number, len: number) => number;
  hanzi_install_pack: (json: number, len: number) => number;

  // Sync
  hanzi_get_changes: (sinceTs: bigint) => number;
  hanzi_apply_changes: (data: number, len: number) => number;

  // Encryption
  hanzi_derive_key: (ptr: number, len: number) => number;
  hanzi_encrypt_field: (pt: number, ptLen: number, key: number, nonce: number) => number;
  hanzi_decrypt_field: (ct: number, ctLen: number, key: number) => number;
}

// --- WasmInstance: one instance per McpSession ---

export class WasmInstance {
  private wasm: WasmExports;

  private constructor(wasm: WasmExports) {
    this.wasm = wasm;
  }

  static async create(): Promise<WasmInstance> {
    // eslint-disable-next-line prefer-const
    let resultExports: WasmExports;

    const importObject: Record<string, Record<string, unknown>> = {
      env: {
        js_console_log: (ptr: number, len: number) => {
          try {
            const mem = new Uint8Array(resultExports.memory.buffer);
            const msg = new TextDecoder().decode(mem.slice(ptr, ptr + len));
            console.log("[taijobi-wasm]", msg);
          } catch {
            // ignore
          }
        },
        js_time_ms: () => BigInt(Date.now()),
      },
    };

    // Fill any other imports the compact build might expect with noop stubs.
    const neededImports = WebAssembly.Module.imports(wasmModule);
    for (const imp of neededImports) {
      if (!importObject[imp.module]) importObject[imp.module] = {};
      if (!(imp.name in importObject[imp.module])) {
        if (imp.kind === "function") {
          importObject[imp.module][imp.name] = () => 0;
        }
      }
    }

    const instance = await WebAssembly.instantiate(
      wasmModule,
      importObject as WebAssembly.Imports,
    );
    resultExports = instance.exports as unknown as WasmExports;

    const w = new WasmInstance(resultExports);

    // Initialize the in-memory SQLite DB. The path string only matters to the
    // WASM VFS — it's never a real file.
    const pathPtr = w.writeString("/mcp.db");
    const rc = resultExports.hanzi_init(pathPtr);
    if (rc !== 0) {
      throw new Error(w.getLastError("Failed to initialize taijobi database"));
    }
    return w;
  }

  // --- Internal helpers ---

  private readLengthPrefixedString(ptr: number): string {
    const mem = new Uint8Array(this.wasm.memory.buffer);
    const len =
      mem[ptr] | (mem[ptr + 1] << 8) | (mem[ptr + 2] << 16) | (mem[ptr + 3] << 24);
    return new TextDecoder().decode(mem.slice(ptr + 4, ptr + 4 + len));
  }

  private readLengthPrefixedBytes(ptr: number): Uint8Array {
    const mem = new Uint8Array(this.wasm.memory.buffer);
    const len =
      mem[ptr] | (mem[ptr + 1] << 8) | (mem[ptr + 2] << 16) | (mem[ptr + 3] << 24);
    const out = new Uint8Array(len);
    out.set(mem.slice(ptr + 4, ptr + 4 + len));
    return out;
  }

  private getLastError(fallback: string): string {
    try {
      const ptr = this.wasm.hanzi_get_error();
      if (ptr !== 0) return this.readLengthPrefixedString(ptr);
    } catch {
      // ignore
    }
    return fallback;
  }

  private writeString(s: string): number {
    const encoded = new TextEncoder().encode(s + "\0");
    const ptr = this.wasm.hanzi_alloc(encoded.length);
    if (ptr === 0) throw new Error("WASM allocation failed");
    const mem = new Uint8Array(this.wasm.memory.buffer);
    mem.set(encoded, ptr);
    return ptr;
  }

  private writeBytes(data: Uint8Array): number {
    const ptr = this.wasm.hanzi_alloc(data.length);
    if (ptr === 0) throw new Error("WASM allocation failed");
    const mem = new Uint8Array(this.wasm.memory.buffer);
    mem.set(data, ptr);
    return ptr;
  }

  // --- Read API ---

  getDueCount(filter?: string | null): number {
    if (!filter) return this.wasm.hanzi_get_due_count();
    const encoded = new TextEncoder().encode(filter);
    const ptr = this.writeBytes(encoded);
    return this.wasm.hanzi_get_due_count_filtered(ptr, encoded.length);
  }

  getDueCards(limit: number, filter?: string | null): Card[] {
    this.wasm.hanzi_reset_alloc();
    let ptr: number;
    if (filter) {
      const encoded = new TextEncoder().encode(filter);
      const filterPtr = this.writeBytes(encoded);
      ptr = this.wasm.hanzi_get_due_cards_filtered(filterPtr, encoded.length, limit);
    } else {
      ptr = this.wasm.hanzi_get_due_cards(limit);
    }
    if (ptr === 0) return [];
    const json = this.readLengthPrefixedString(ptr);
    return JSON.parse(json) as Card[];
  }

  searchCards(query: string, limit = 20): Card[] {
    this.wasm.hanzi_reset_alloc();
    const encoded = new TextEncoder().encode(query);
    const ptr = this.writeBytes(encoded);
    const resultPtr = this.wasm.hanzi_search_cards(ptr, encoded.length, limit);
    if (resultPtr === 0) return [];
    const json = this.readLengthPrefixedString(resultPtr);
    return JSON.parse(json) as Card[];
  }

  getLexicon(): LexiconEntry[] {
    this.wasm.hanzi_reset_alloc();
    const ptr = this.wasm.hanzi_get_lexicon();
    if (ptr === 0) return [];
    const json = this.readLengthPrefixedString(ptr);
    return JSON.parse(json) as LexiconEntry[];
  }

  getStats(days = 30): StatsData {
    this.wasm.hanzi_reset_alloc();
    const ptr = this.wasm.hanzi_get_stats(days);
    if (ptr === 0) {
      return { days: [], ratings: [0, 0, 0, 0], streak: 0, longest_streak: 0 };
    }
    const json = this.readLengthPrefixedString(ptr);
    return JSON.parse(json) as StatsData;
  }

  // --- Write API ---

  addWord(word: string): { word: string; language: string; status: string } {
    this.wasm.hanzi_reset_alloc();
    const encoded = new TextEncoder().encode(word);
    const ptr = this.writeBytes(encoded);
    const resultPtr = this.wasm.hanzi_add_word(ptr, encoded.length);
    if (resultPtr === 0) throw new Error(this.getLastError("addWord failed"));
    const json = this.readLengthPrefixedString(resultPtr);
    return JSON.parse(json);
  }

  reviewCard(id: string, rating: number): void {
    this.wasm.hanzi_reset_alloc();
    const encoded = new TextEncoder().encode(id);
    const ptr = this.writeBytes(encoded);
    const rc = this.wasm.hanzi_review_card(ptr, encoded.length, rating);
    if (rc !== 0) throw new Error(this.getLastError("reviewCard failed"));
  }

  /**
   * Install a content pack from its JSON body. Inserts pack + lessons +
   * cards in a single SQLite transaction. Per-card language is detected
   * from the word's script (post Phase 5.0 fix), so Chinese / Arabic /
   * German packs all tag their cards correctly. Returns rc — 0 on
   * success, non-zero on parse error.
   */
  installPack(packJson: string): void {
    this.wasm.hanzi_reset_alloc();
    const encoded = new TextEncoder().encode(packJson);
    const ptr = this.writeBytes(encoded);
    const rc = this.wasm.hanzi_install_pack(ptr, encoded.length);
    if (rc !== 0) throw new Error(this.getLastError("installPack failed"));
  }

  parseKindle(raw: string): KindleClipping[] {
    this.wasm.hanzi_reset_alloc();
    const encoded = new TextEncoder().encode(raw);
    const ptr = this.writeBytes(encoded);
    const resultPtr = this.wasm.hanzi_parse_kindle(ptr, encoded.length);
    if (resultPtr === 0) throw new Error(this.getLastError("parseKindle failed"));
    const json = this.readLengthPrefixedString(resultPtr);
    return JSON.parse(json) as KindleClipping[];
  }

  /**
   * Bulk-add words inside one SQLite transaction. Wire format: [u32 count]
   * [u32 len][bytes]… — identical to the web client's bulkAddLexicon wrapper.
   */
  bulkAddLexicon(words: string[]): BulkAddResult {
    if (words.length === 0) return { added: 0, skipped: 0, failed: 0 };
    this.wasm.hanzi_reset_alloc();

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

    const ptr = this.writeBytes(buf);
    const resultPtr = this.wasm.hanzi_bulk_add_lexicon(ptr, buf.length);
    if (resultPtr === 0) throw new Error(this.getLastError("bulkAddLexicon failed"));
    const json = this.readLengthPrefixedString(resultPtr);
    return JSON.parse(json) as BulkAddResult;
  }

  // --- Sync API ---

  getChanges(sinceTs: number): SyncRow[] {
    this.wasm.hanzi_reset_alloc();
    const ptr = this.wasm.hanzi_get_changes(BigInt(sinceTs));
    // ptr === 0 is always an error (0-row pushes still return a pointer to
    // `{"rows":[]}`). Swallowing it as `[]` turned every write tool's
    // background sync-push into a silent no-op when FBA alloc failed.
    if (ptr === 0) throw new Error(this.getLastError("hanzi_get_changes failed"));
    const json = this.readLengthPrefixedString(ptr);
    const result = JSON.parse(json) as { rows: SyncRow[] };
    return result.rows;
  }

  applyChanges(rows: SyncRow[]): number {
    this.wasm.hanzi_reset_alloc();
    const json = JSON.stringify({ rows });
    const encoded = new TextEncoder().encode(json);
    const ptr = this.writeBytes(encoded);
    const rc = this.wasm.hanzi_apply_changes(ptr, encoded.length);
    if (rc < 0) throw new Error(this.getLastError("applyChanges failed"));
    return rc;
  }

  // --- Encryption API ---

  deriveEncryptionKey(syncKey: string): Uint8Array {
    this.wasm.hanzi_reset_alloc();
    const encoded = new TextEncoder().encode(syncKey);
    const ptr = this.writeBytes(encoded);
    const resultPtr = this.wasm.hanzi_derive_key(ptr, encoded.length);
    if (resultPtr === 0) throw new Error(this.getLastError("deriveEncryptionKey failed"));
    return this.readLengthPrefixedBytes(resultPtr);
  }

  encryptField(plaintext: string, key: Uint8Array): string {
    this.wasm.hanzi_reset_alloc();
    const ptEncoded = new TextEncoder().encode(plaintext);
    const ptPtr = this.writeBytes(ptEncoded);
    const keyPtr = this.writeBytes(key);
    const nonce = crypto.getRandomValues(new Uint8Array(24));
    const noncePtr = this.writeBytes(nonce);
    const resultPtr = this.wasm.hanzi_encrypt_field(ptPtr, ptEncoded.length, keyPtr, noncePtr);
    if (resultPtr === 0) throw new Error(this.getLastError("encryptField failed"));
    return this.readLengthPrefixedString(resultPtr);
  }

  decryptField(ciphertext: string, key: Uint8Array): string {
    this.wasm.hanzi_reset_alloc();
    const ctEncoded = new TextEncoder().encode(ciphertext);
    const ctPtr = this.writeBytes(ctEncoded);
    const keyPtr = this.writeBytes(key);
    const resultPtr = this.wasm.hanzi_decrypt_field(ctPtr, ctEncoded.length, keyPtr);
    if (resultPtr === 0) throw new Error(this.getLastError("decryptField failed"));
    return this.readLengthPrefixedString(resultPtr);
  }

  decryptRows(rows: SyncRow[], key: Uint8Array): SyncRow[] {
    return rows.map((row) => {
      if (typeof row.data === "string") {
        const plaintext = this.decryptField(row.data, key);
        return { ...row, data: JSON.parse(plaintext) as Record<string, unknown> };
      }
      return row;
    });
  }

  close(): void {
    this.wasm.hanzi_close();
  }
}
