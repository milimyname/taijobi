# C ABI — Public API

All functions exported with `export fn`. Web calls via WASM, iOS links `.a`.

## Phase 0 — Core

```zig
export fn hanzi_init(db_path: [*:0]const u8) i32
export fn hanzi_close() void
export fn hanzi_free(ptr: [*]u8, len: usize) void
export fn hanzi_alloc(len: usize) ?[*]u8
export fn hanzi_get_due_cards(limit: u32) ?[*]const u8
export fn hanzi_get_due_count() i32
export fn hanzi_review_card(id: [*]const u8, len: usize, rating: u8) i32
export fn hanzi_get_db_ptr() ?[*]u8
export fn hanzi_get_db_size() usize
export fn hanzi_restore_db(ptr: [*]const u8, len: usize) i32
```

## Phase 1 — Lexicon + Dictionary

```zig
export fn hanzi_add_word(word: [*]const u8, len: usize) ?[*]const u8
export fn hanzi_import_lexicon(json: [*]const u8, len: usize) i32
export fn hanzi_get_lexicon() ?[*]const u8
export fn hanzi_lookup(query: [*]const u8, len: usize) ?[*]const u8
export fn hanzi_get_drill_stats() ?[*]const u8
```

## Phase 2 — Content Packs

```zig
export fn hanzi_install_pack(json: [*]const u8, len: usize) i32
export fn hanzi_get_packs() ?[*]const u8
export fn hanzi_remove_pack(id: [*]const u8, len: usize) i32
export fn hanzi_get_lessons(pack_id: [*]const u8, len: usize) ?[*]const u8
export fn hanzi_get_vocabulary(lesson_id: [*]const u8, len: usize) ?[*]const u8
export fn hanzi_get_progress(pack_id: [*]const u8, len: usize) ?[*]const u8
```

## Phase 3 — Deep Chinese

```zig
export fn hanzi_decompose(char: [*]const u8, len: usize) ?[*]const u8
export fn hanzi_fuzzy_search(query: [*]const u8, len: usize) ?[*]const u8
export fn hanzi_get_grammar_stats(tag: [*]const u8, len: usize) ?[*]const u8
export fn hanzi_check_answer(card_id: [*]const u8, id_len: usize,
    answer: [*]const u8, ans_len: usize) ?[*]const u8
```

## Phase 3.5 — CSV Import/Export

```zig
export fn hanzi_import_csv(csv_ptr: [*]const u8, csv_len: usize,
    name_ptr: [*]const u8, name_len: usize) i32
export fn hanzi_export_csv() ?[*]const u8
```

## Phase 5.2 — Search

```zig
export fn hanzi_search_cards(query_ptr: [*]const u8, query_len: usize, limit: u32) ?[*]const u8
```

SQL LIKE across `cards.word`, `cards.translation`, `cards.pinyin` (excluding soft-deleted).
Orders exact match, then prefix, then anywhere. Returns JSON array of
`{id, word, language, pinyin, translation, source_type, pack_id}`.

## Phase 4 — Sync

```zig
export fn hanzi_get_changes(since_ts: i64) ?[*]const u8
export fn hanzi_apply_changes(data: [*]const u8, len: u32) i32
export fn hanzi_derive_key(sync_key_ptr: [*]const u8, sync_key_len: u32) ?[*]const u8
export fn hanzi_encrypt_field(pt_ptr: [*]const u8, pt_len: u32,
    key_ptr: [*]const u8, nonce_ptr: [*]const u8) ?[*]const u8
export fn hanzi_decrypt_field(ct_ptr: [*]const u8, ct_len: u32,
    key_ptr: [*]const u8) ?[*]const u8
```

## Phase 6.2 — MCP Server

No new Zig exports. The MCP Worker reuses the Phase 1 / 4 / 5.4 surface
verbatim — tool handlers in `taijobi-sync/src/mcp-tools.ts` map directly
onto `hanzi_get_due_cards`, `hanzi_add_word`, `hanzi_parse_kindle`,
`hanzi_bulk_add_lexicon`, etc.

The one Zig-side change is a **build flag**, not an ABI change:

```sh
zig build -Dmcp=true   # produces libtaijobi-mcp.wasm
```

Toggling `mcp=true` at compile time swaps `PERSIST_SIZE` (128 MB → 16 MB)
inside `root.zig` via `@import("build_options").mcp`. Both artifacts export
the same `hanzi_*` functions with identical signatures; callers don't know
which binary they loaded.
