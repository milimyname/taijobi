const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const sqlite = @import("sqlite_c.zig");

/// Set true for the Cloudflare Worker build (libtaijobi-mcp.wasm). Used to
/// drop the big dictionary-holding persistent allocator down to something
/// that fits in the 128MB Worker memory cap.
const MCP_BUILD = build_options.mcp;
const types = @import("types.zig");
const db_mod = @import("db.zig");
const fsrs_mod = @import("fsrs.zig");

const Db = db_mod.Db;
const lexicon = @import("lexicon.zig");
const lang_mod = @import("lang.zig");
const cedict = @import("cedict.zig");
const curriculum = @import("curriculum.zig");
const decompose = @import("decompose.zig");
const strokes_mod = @import("strokes.zig");
const csv_mod = @import("csv.zig");
const apkg_mod = @import("apkg.zig");
const kindle = @import("kindle.zig");
const wiktdict = @import("wiktdict.zig");

// --- Fixed buffer allocator ---
// Web build: 64MB covers dictionary compilation + pack-install JSON bodies
// (HSK 6 with ~15k cards + sentences runs to a few MB).
// MCP build: 16MB is the floor — `hanzi_get_changes` asks for an 8MB+4
// scratch buffer to serialize the sync push, and 8MB FBA couldn't satisfy
// it, so every write tool's background `pushToSync` was silently failing
// (MCP response succeeded but SyncRoom never received the rows).
const FBA_SIZE = if (MCP_BUILD) 16 * 1024 * 1024 else 64 * 1024 * 1024;
var fba_backing: [FBA_SIZE]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&fba_backing);

// --- Persistent allocator — never reset, holds all dictionary .bin data ---
//
// Web build sizing budget (prod as of 2026-04):
//   cedict ~9MB, decomp ~1MB, strokes ~9MB, endict ~60MB, dedict ~5MB
//   → ~84MB total; 128MB leaves headroom for JMdict/KDICT later.
//
// MCP build: MCP tools never touch dictionaries (Claude already knows
// definitions for the languages we support), so we skip the 128MB reservation
// entirely. 16MB fits well inside the 128MB Cloudflare Worker memory cap and
// is plenty for CEDICT if we re-enable `lookup_word` in v2.
const PERSIST_SIZE: usize = if (MCP_BUILD) 16 * 1024 * 1024 else 128 * 1024 * 1024;
var persist_backing: [PERSIST_SIZE]u8 = undefined;
var persist_fba = std.heap.FixedBufferAllocator.init(&persist_backing);

// --- Global state ---
var global_db: ?Db = null;
var error_buf: [512]u8 = undefined;
var error_len: usize = 0;
var json_buf: [512 * 1024]u8 = undefined; // 512KB for JSON responses

// --- JS imports ---
const is_wasm = builtin.cpu.arch == .wasm32;

extern fn js_console_log(ptr: [*]const u8, len: usize) void;
extern fn js_time_ms() i64;

fn log(msg: []const u8) void {
    if (is_wasm) {
        js_console_log(msg.ptr, msg.len);
    }
}

fn setError(msg: []const u8) void {
    const copy_len = @min(msg.len, error_buf.len);
    @memcpy(error_buf[0..copy_len], msg[0..copy_len]);
    error_len = copy_len;
}

fn now() i64 {
    if (is_wasm) {
        return js_time_ms();
    }
    return std.time.milliTimestamp();
}

/// Returns length-prefixed data: 4-byte LE u32 length + data bytes
fn makeLengthPrefixed(data: []const u8) ?[*]const u8 {
    const total = 4 + data.len;
    const mem = fba.allocator().alloc(u8, total) catch return null;
    std.mem.writeInt(u32, mem[0..4], @intCast(data.len), .little);
    @memcpy(mem[4..][0..data.len], data);
    return mem.ptr;
}

// === C ABI Exports ===

export fn hanzi_build_id() ?[*]const u8 {
    const id = "build-2026-03-19b";
    return makeLengthPrefixed(id);
}

export fn hanzi_init(path: [*:0]const u8) i32 {
    log("hanzi_init called (build-2026-03-19b)");
    global_db = Db.init(path) catch |err| {
        const msg = switch (err) {
            error.OpenFailed => "failed to open database",
            error.ExecFailed => "schema exec failed",
            error.PrepareFailed => "prepare failed",
            error.StepFailed => "step failed",
            else => "init failed",
        };
        setError(msg);
        return -1;
    };
    log("hanzi_init success");
    return 0;
}

export fn hanzi_close() void {
    if (global_db) |*db| {
        db.close();
        global_db = null;
    }
}

export fn hanzi_alloc(len: usize) ?[*]u8 {
    const mem = fba.allocator().alloc(u8, len) catch return null;
    return mem.ptr;
}

export fn hanzi_free(ptr: [*]u8, len: usize) void {
    _ = .{ ptr, len };
    // FBA does not support individual frees — reset via hanzi_reset_alloc
}

export fn hanzi_get_error() ?[*]const u8 {
    if (error_len == 0) return null;
    return makeLengthPrefixed(error_buf[0..error_len]);
}

export fn hanzi_get_due_cards(limit: u32) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const json = db.getDueCards(limit, now(), &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_get_due_count() i32 {
    const db = &(global_db orelse return -1);
    return db.getDueCount(now());
}

export fn hanzi_review_card(id_ptr: [*]const u8, id_len: usize, rating: u8) i32 {
    const db = &(global_db orelse return -1);
    const card_id = id_ptr[0..id_len];
    db.reviewCard(card_id, rating, now()) catch |err| {
        const msg = switch (err) {
            error.InvalidRating => "invalid rating (must be 1-4)",
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
            else => "review failed",
        };
        setError(msg);
        return -1;
    };
    return 0;
}

export fn hanzi_reset_alloc() void {
    fba.reset();
}

export fn hanzi_get_due_cards_filtered(filter_ptr: [*]const u8, filter_len: usize, limit: u32) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const filter = if (filter_len == 0) null else filter_ptr[0..filter_len];
    const json = db.getDueCardsFiltered(limit, now(), filter, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_get_due_count_filtered(filter_ptr: [*]const u8, filter_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const filter = if (filter_len == 0) null else filter_ptr[0..filter_len];
    return db.getDueCountFiltered(now(), filter);
}

export fn hanzi_get_upcoming_cards(filter_ptr: [*]const u8, filter_len: usize, limit: u32, ahead_hours: u32) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const filter = if (filter_len == 0) null else filter_ptr[0..filter_len];
    const ahead_ms: i64 = @as(i64, ahead_hours) * 3600000;
    const json = db.getUpcomingCards(limit, now(), ahead_ms, filter, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

// === Phase 1 — Lexicon + Dictionary ===

export fn hanzi_add_word(word_ptr: [*]const u8, word_len: usize) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const word = word_ptr[0..word_len];
    const lang_code = lexicon.addWord(db.handle, word, null, now()) catch |err| {
        const msg = switch (err) {
            error.WordEmpty => "word is empty",
            error.AlreadyExists => "word already exists",
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
            error.NotFound => "not found",
        };
        setError(msg);
        return null;
    };

    // Return JSON with the added word info + enrichment
    var w = types.JsonWriter.init(&json_buf);
    w.writeByte('{');
    w.writeKey("word");
    w.writeJsonString(word);
    w.writeByte(',');
    w.writeKey("language");
    w.writeJsonString(lang_code);
    w.writeByte(',');
    w.writeKey("status");
    w.writeJsonString("added");
    // Include CEDICT enrichment if Chinese
    if (std.mem.eql(u8, lang_code, "zh")) {
        if (cedict.lookup(word)) |entry| {
            w.writeByte(',');
            w.writeKey("pinyin");
            w.writeJsonString(entry.pinyin);
            w.writeByte(',');
            w.writeKey("translation");
            w.writeJsonString(entry.english);
        }
    }
    w.writeByte('}');
    return makeLengthPrefixed(w.written());
}

/// Parse a Kindle `My Clippings.txt` file and return a JSON array of entries.
/// Each entry: `{book, author, type, text}`. Bookmarks are skipped.
///
/// FBA leaks (input.len + 512KB) per call until the next `hanzi_reset_alloc`
/// — acceptable for an import flow the user triggers once.
export fn hanzi_parse_kindle(data_ptr: [*]const u8, data_len: u32) ?[*]const u8 {
    const input = data_ptr[0..data_len];

    const scratch = fba.allocator().alloc(u8, input.len) catch {
        setError("hanzi_parse_kindle: scratch alloc failed");
        return null;
    };
    const out_size: usize = 512 * 1024;
    const out = fba.allocator().alloc(u8, out_size) catch {
        setError("hanzi_parse_kindle: output alloc failed");
        return null;
    };

    const json = kindle.parseClippings(input, scratch, out) orelse {
        setError("hanzi_parse_kindle: output buffer overflow (too many clippings)");
        return null;
    };
    return makeLengthPrefixed(json);
}

/// Bulk-add lexicon words inside a single transaction.
///
/// Wire format for `data`:
///   [u32 LE: count]
///   N × ( [u32 LE: word_len] [word_bytes] )
///
/// Length-prefixed (not UTF-8 / not null-terminated) so word content is
/// unrestricted — Kindle highlights can contain newlines, tabs, null bytes
/// (rare but legal in text). Returns length-prefixed JSON
/// `{added, skipped, failed}` or null on fatal SQL error.
export fn hanzi_bulk_add_lexicon(data_ptr: [*]const u8, data_len: u32) ?[*]const u8 {
    const db = &(global_db orelse {
        setError("hanzi_bulk_add_lexicon: database not initialized");
        return null;
    });

    const data = data_ptr[0..data_len];
    if (data.len < 4) {
        setError("hanzi_bulk_add_lexicon: input too small for count header");
        return null;
    }
    const count = std.mem.readInt(u32, data[0..4], .little);
    if (count == 0) {
        // Nothing to do — return zero summary.
        var w = types.JsonWriter.init(&json_buf);
        w.writeStr("{\"added\":0,\"skipped\":0,\"failed\":0}");
        return makeLengthPrefixed(w.written());
    }

    // Cap at a sane ceiling; anything bigger is almost certainly a bug.
    const MAX_WORDS: u32 = 10_000;
    const n = @min(count, MAX_WORDS);

    // Allocate a slice of slices from FBA. One fixed allocation, no resize.
    const words = fba.allocator().alloc([]const u8, n) catch {
        setError("hanzi_bulk_add_lexicon: FBA alloc failed");
        return null;
    };

    var offset: usize = 4;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        if (offset + 4 > data.len) {
            setError("hanzi_bulk_add_lexicon: truncated — missing length prefix");
            return null;
        }
        const word_len = std.mem.readInt(u32, data[offset..][0..4], .little);
        offset += 4;
        if (offset + word_len > data.len) {
            setError("hanzi_bulk_add_lexicon: truncated — word bytes past end");
            return null;
        }
        words[i] = data[offset..][0..word_len];
        offset += word_len;
    }

    var added: u32 = 0;
    var skipped: u32 = 0;
    var failed: u32 = 0;
    lexicon.bulkAddWords(db.handle, words, now(), &added, &skipped, &failed) catch |err| {
        const msg = switch (err) {
            error.PrepareFailed => "bulk_add_lexicon: SQL prepare failed",
            error.StepFailed => "bulk_add_lexicon: SQL step failed",
            else => "bulk_add_lexicon: unknown error",
        };
        setError(msg);
        return null;
    };

    var w = types.JsonWriter.init(&json_buf);
    w.writeByte('{');
    w.writeKey("added");
    w.writeInt(@intCast(added));
    w.writeByte(',');
    w.writeKey("skipped");
    w.writeInt(@intCast(skipped));
    w.writeByte(',');
    w.writeKey("failed");
    w.writeInt(@intCast(failed));
    w.writeByte('}');
    return makeLengthPrefixed(w.written());
}

export fn hanzi_remove_word(id_ptr: [*]const u8, id_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const card_id = id_ptr[0..id_len];
    lexicon.removeWord(db.handle, card_id, now()) catch |err| {
        const msg = switch (err) {
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
            error.NotFound => "word not found",
            error.WordEmpty => "word is empty",
            error.AlreadyExists => "already exists",
        };
        setError(msg);
        return -1;
    };
    return 0;
}

export fn hanzi_restore_word(id_ptr: [*]const u8, id_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const card_id = id_ptr[0..id_len];
    lexicon.restoreWord(db.handle, card_id, now()) catch |err| {
        const msg = switch (err) {
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
            error.NotFound => "word not found",
            error.WordEmpty => "word is empty",
            error.AlreadyExists => "already exists",
        };
        setError(msg);
        return -1;
    };
    return 0;
}

export fn hanzi_update_word(id_ptr: [*]const u8, id_len: usize, trans_ptr: [*]const u8, trans_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const card_id = id_ptr[0..id_len];
    const translation = trans_ptr[0..trans_len];
    lexicon.updateWord(db.handle, card_id, translation, now()) catch |err| {
        const msg = switch (err) {
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
            error.NotFound => "word not found",
            error.WordEmpty => "word is empty",
            error.AlreadyExists => "already exists",
        };
        setError(msg);
        return -1;
    };
    return 0;
}

export fn hanzi_lookup(query_ptr: [*]const u8, query_len: usize) ?[*]const u8 {
    const query = query_ptr[0..query_len];
    const json = cedict.search(query, 20, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

// === Phase 5.2 — Search ===

export fn hanzi_search_cards(query_ptr: [*]const u8, query_len: usize, limit: u32) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const query = query_ptr[0..query_len];
    const json = db.searchCards(query, limit, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

/// Most-recently-reviewed card. Used by the Cmd+K empty state to offer
/// a "Zuletzt geübt" shortcut. Returns a 1-element JSON array matching
/// the CardSearchResult shape (or [] if no reviews exist).
export fn hanzi_get_last_reviewed_card() ?[*]const u8 {
    const db = &(global_db orelse return null);
    const json = db.getLastReviewedCard(&json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

/// Look up a single card by id. Returns a 1-element JSON array in the
/// CardSearchResult shape, or `[]` if not found. Used for deep-linking
/// into lesson pages where the target card may be past the 200-row
/// vocabulary LIMIT and so absent from the rendered list.
export fn hanzi_get_card_by_id(id_ptr: [*]const u8, id_len: usize) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const card_id = id_ptr[0..id_len];
    const json = db.getCardById(card_id, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

/// DevTools SQL panel — run arbitrary SQL and return JSON results.
/// Returns length-prefixed JSON `{columns, rows, count, truncated}`.
/// FBA caveat: burns ~2MB per call (scratch + length-prefix copy) until the
/// next hanzi_reset_alloc(). Acceptable for dev-only use within the 64MB budget.
export fn hanzi_query(sql_ptr: [*]const u8, sql_len: u32) ?[*]const u8 {
    const db = &(global_db orelse {
        setError("hanzi_query: database not initialized");
        return null;
    });

    // Copy SQL into a null-terminated FBA buffer for sqlite3_prepare_v2.
    const sql_buf = fba.allocator().alloc(u8, sql_len + 1) catch {
        setError("hanzi_query: alloc failed for SQL");
        return null;
    };
    @memcpy(sql_buf[0..sql_len], sql_ptr[0..sql_len]);
    sql_buf[sql_len] = 0;

    // 2MB scratch — bounded by the 500-row cap inside rawQuery.
    const buf_size: usize = 2 * 1024 * 1024;
    const scratch = fba.allocator().alloc(u8, buf_size) catch {
        setError("hanzi_query: alloc failed for result buffer");
        return null;
    };

    const json_len = db.rawQuery(@ptrCast(sql_buf.ptr), scratch.ptr, buf_size) catch {
        if (db.lastError()) |msg_ptr| {
            const msg = std.mem.span(msg_ptr);
            var combined: [512]u8 = undefined;
            const prefix = "hanzi_query: ";
            const plen = @min(prefix.len, combined.len);
            @memcpy(combined[0..plen], prefix[0..plen]);
            const mlen = @min(msg.len, combined.len - plen);
            @memcpy(combined[plen..][0..mlen], msg[0..mlen]);
            setError(combined[0 .. plen + mlen]);
        } else {
            setError("hanzi_query: prepare failed");
        }
        return null;
    } orelse {
        setError("hanzi_query: result too large for 2MB buffer");
        return null;
    };

    return makeLengthPrefixed(scratch[0..json_len]);
}

export fn hanzi_get_lexicon() ?[*]const u8 {
    const db = &(global_db orelse return null);
    const json = lexicon.getLexicon(db.handle, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_get_drill_stats() ?[*]const u8 {
    const db = &(global_db orelse return null);
    const json = lexicon.getDrillStats(db.handle, now(), &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

// === Phase 5.1 — Stats ===

export fn hanzi_get_stats(days: u32) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const json = lexicon.getStats(db.handle, now(), days, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

// === Phase 2 — Content Packs ===

export fn hanzi_install_pack(json_ptr: [*]const u8, json_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const json = json_ptr[0..json_len];
    curriculum.installPack(db.handle, json, now()) catch |err| {
        const msg = switch (err) {
            error.InvalidJson => "invalid pack JSON",
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
            error.PackNotFound => "pack not found",
        };
        setError(msg);
        return -1;
    };
    return 0;
}

export fn hanzi_get_packs() ?[*]const u8 {
    const db = &(global_db orelse return null);
    const json = curriculum.getPacks(db.handle, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_add_lesson_to_pack(
    pack_id_ptr: [*]const u8,
    pack_id_len: usize,
    lesson_json_ptr: [*]const u8,
    lesson_json_len: usize,
) i32 {
    const db = &(global_db orelse return -1);
    const pack_id = pack_id_ptr[0..pack_id_len];
    const lesson_json = lesson_json_ptr[0..lesson_json_len];
    curriculum.addLessonToPack(db.handle, pack_id, lesson_json, now()) catch |err| {
        const msg = switch (err) {
            error.InvalidJson => "invalid lesson JSON",
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
            error.PackNotFound => "pack not found",
        };
        setError(msg);
        return -1;
    };
    return 0;
}

export fn hanzi_remove_pack(id_ptr: [*]const u8, id_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const pack_id = id_ptr[0..id_len];
    curriculum.removePack(db.handle, pack_id, now()) catch |err| {
        const msg = switch (err) {
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
            error.PackNotFound => "pack not found",
            error.InvalidJson => "invalid JSON",
        };
        setError(msg);
        return -1;
    };
    return 0;
}

export fn hanzi_get_lessons(pack_id_ptr: [*]const u8, pack_id_len: usize) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const pack_id = pack_id_ptr[0..pack_id_len];
    const json = curriculum.getLessons(db.handle, pack_id, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_get_vocabulary(lesson_id_ptr: [*]const u8, lesson_id_len: usize, offset: u32, limit: u32) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const lesson_id = lesson_id_ptr[0..lesson_id_len];
    const effective_limit: u32 = if (limit == 0 or limit > 500) 200 else limit;
    const json = curriculum.getVocabulary(db.handle, lesson_id, offset, effective_limit, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_get_progress(pack_id_ptr: [*]const u8, pack_id_len: usize) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const pack_id = pack_id_ptr[0..pack_id_len];
    const json = curriculum.getProgress(db.handle, pack_id, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_restore_pack(id_ptr: [*]const u8, id_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const pack_id = id_ptr[0..id_len];
    curriculum.restorePack(db.handle, pack_id, now()) catch |err| {
        const msg = switch (err) {
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
            error.PackNotFound => "pack not found",
            error.InvalidJson => "invalid JSON",
        };
        setError(msg);
        return -1;
    };
    return 0;
}

// === Reading Mode ===

export fn hanzi_mark_read(id_ptr: [*]const u8, id_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const card_id = id_ptr[0..id_len];
    db.markCardRead(card_id, now()) catch |err| {
        const msg = switch (err) {
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
            else => "mark read failed",
        };
        setError(msg);
        return -1;
    };
    return 0;
}

export fn hanzi_get_unread_cards(filter_ptr: [*]const u8, filter_len: usize, limit: u32) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const filter = if (filter_len == 0) null else filter_ptr[0..filter_len];
    const json = db.getUnreadCards(limit, filter, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_get_unread_count(filter_ptr: [*]const u8, filter_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const filter = if (filter_len == 0) null else filter_ptr[0..filter_len];
    return db.getUnreadCount(filter);
}

// === Phase 3 — Deep Chinese ===

export fn hanzi_decompose(char_ptr: [*]const u8, char_len: usize) ?[*]const u8 {
    const query = char_ptr[0..char_len];
    const json = decompose.decomposeToJson(query, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

/// List every character in the loaded decomp.bin as compact JSON
/// `[{c, p}]`. ~9500 entries, ~300KB payload. Fuels the /characters
/// "Alle Zeichen" browse grid when the Chinese dict is installed.
export fn hanzi_list_decomp_chars() ?[*]const u8 {
    const json = decompose.listChars(&json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_get_strokes(char_ptr: [*]const u8, char_len: usize) ?[*]const u8 {
    const query = char_ptr[0..char_len];
    const json = strokes_mod.strokesAsJson(query, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

// === Phase 3.5 — CSV Import/Export ===

export fn hanzi_import_csv(csv_ptr: [*]const u8, csv_len: usize, name_ptr: [*]const u8, name_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const csv_data = csv_ptr[0..csv_len];
    const pack_name = name_ptr[0..name_len];
    const count = csv_mod.importCsv(db.handle, csv_data, pack_name, now()) catch |err| {
        const msg = switch (err) {
            error.EmptyInput => "CSV is empty",
            error.NoWordsFound => "no words found in CSV",
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
        };
        setError(msg);
        return -1;
    };
    return @intCast(count);
}

export fn hanzi_export_csv() ?[*]const u8 {
    const db = &(global_db orelse return null);
    // Use a larger buffer for CSV export (allocated from FBA)
    const export_buf = fba.allocator().alloc(u8, 256 * 1024) catch return null;
    const csv_text = csv_mod.exportCsv(db.handle, export_buf) orelse return null;
    return makeLengthPrefixed(csv_text);
}

export fn hanzi_import_apkg(apkg_ptr: [*]const u8, apkg_len: usize, name_ptr: [*]const u8, name_len: usize) i32 {
    log("hanzi_import_apkg called");
    const db = &(global_db orelse {
        log("apkg: no db");
        return -1;
    });
    const apkg_data = apkg_ptr[0..apkg_len];
    const pack_name = name_ptr[0..name_len];

    // Log input sizes
    var size_buf: [64]u8 = undefined;
    const size_msg = std.fmt.bufPrint(&size_buf, "apkg: data={d} name={d}", .{ apkg_len, name_len }) catch "apkg: fmt err";
    log(size_msg);

    // Allocate scratch buffer for decompressed SQLite (up to 32MB)
    const scratch = fba.allocator().alloc(u8, 32 * 1024 * 1024) catch {
        log("apkg: scratch alloc failed");
        return -1;
    };
    const count = apkg_mod.importApkg(db.handle, apkg_data, pack_name, now(), scratch) catch |err| {
        const msg = switch (err) {
            error.InvalidZip => "invalid or corrupt .apkg file",
            error.DatabaseNotFound => "no Anki database found in .apkg",
            error.DecompressFailed => "failed to decompress .apkg",
            error.NoNotesFound => "no notes found in Anki database",
            error.TempDbFailed => "failed to open Anki database",
            error.PrepareFailed => "SQL prepare failed",
            error.StepFailed => "SQL step failed",
        };
        setError(msg);
        log(msg);
        return -1;
    };

    var count_buf: [48]u8 = undefined;
    const count_msg = std.fmt.bufPrint(&count_buf, "apkg: imported {d} cards", .{count}) catch "apkg: done";
    log(count_msg);

    // Log due count right after import for debugging
    const due = db.getDueCount(now());
    var due_buf: [48]u8 = undefined;
    const due_msg = std.fmt.bufPrint(&due_buf, "apkg: due count now = {d}", .{due}) catch "apkg: due ?";
    log(due_msg);

    return @intCast(count);
}

// === Phase 4 — Sync ===

const crypto = @import("crypto.zig");

export fn hanzi_get_changes(since_ts: i64) ?[*]const u8 {
    var db = global_db orelse {
        setError("hanzi_get_changes: database not initialized");
        return null;
    };

    const buf_size: usize = 8 * 1024 * 1024; // 8 MB
    const buf = fba.allocator().alloc(u8, buf_size + 4) catch {
        setError("hanzi_get_changes: failed to allocate buffer");
        return null;
    };

    const json_len = db.getChangesJson(since_ts, buf.ptr + 4, buf_size) catch {
        setError("hanzi_get_changes: query failed");
        fba.allocator().free(buf);
        return null;
    } orelse {
        setError("hanzi_get_changes: buffer too small");
        fba.allocator().free(buf);
        return null;
    };

    std.mem.writeInt(u32, buf[0..4], @intCast(json_len), .little);
    return buf.ptr;
}

export fn hanzi_apply_changes(data: [*]const u8, len: u32) i32 {
    var db = global_db orelse {
        setError("hanzi_apply_changes: database not initialized");
        return -1;
    };

    const result = db.applyChanges(data[0..len]) catch {
        setError("hanzi_apply_changes: failed");
        return -1;
    };

    return result;
}

export fn hanzi_derive_key(sync_key_ptr: [*]const u8, sync_key_len: u32) ?[*]const u8 {
    const sync_key = sync_key_ptr[0..sync_key_len];
    const key = crypto.deriveKey(sync_key);
    return makeLengthPrefixed(&key);
}

export fn hanzi_encrypt_field(
    pt_ptr: [*]const u8,
    pt_len: u32,
    key_ptr: [*]const u8,
    nonce_ptr: [*]const u8,
) ?[*]const u8 {
    const plaintext = pt_ptr[0..pt_len];
    const key: [32]u8 = key_ptr[0..32].*;
    const nonce: [24]u8 = nonce_ptr[0..24].*;

    const enc_size = 24 + pt_len + 16;
    const enc_buf = fba.allocator().alloc(u8, enc_size) catch {
        setError("hanzi_encrypt_field: alloc failed");
        return null;
    };

    const enc_len = crypto.encryptField(plaintext, key, nonce, enc_buf) catch {
        setError("hanzi_encrypt_field: encryption failed");
        return null;
    };

    // Base64 encode
    const b64_len = std.base64.standard.Encoder.calcSize(enc_len);
    const b64_buf = fba.allocator().alloc(u8, b64_len) catch {
        setError("hanzi_encrypt_field: b64 alloc failed");
        return null;
    };
    const encoded = std.base64.standard.Encoder.encode(b64_buf, enc_buf[0..enc_len]);

    return makeLengthPrefixed(encoded);
}

export fn hanzi_decrypt_field(
    ct_ptr: [*]const u8,
    ct_len: u32,
    key_ptr: [*]const u8,
) ?[*]const u8 {
    const b64_input = ct_ptr[0..ct_len];
    const key: [32]u8 = key_ptr[0..32].*;

    const decoded_size = std.base64.standard.Decoder.calcSizeForSlice(b64_input) catch {
        setError("hanzi_decrypt_field: invalid base64");
        return null;
    };
    const decoded_buf = fba.allocator().alloc(u8, decoded_size) catch {
        setError("hanzi_decrypt_field: alloc failed");
        return null;
    };
    std.base64.standard.Decoder.decode(decoded_buf, b64_input) catch {
        setError("hanzi_decrypt_field: base64 decode failed");
        return null;
    };

    const pt_len_max = if (decoded_size > 40) decoded_size - 40 else 0;
    const pt_buf = fba.allocator().alloc(u8, pt_len_max) catch {
        setError("hanzi_decrypt_field: pt alloc failed");
        return null;
    };

    const pt_len2 = crypto.decryptField(decoded_buf[0..decoded_size], key, pt_buf) catch {
        setError("hanzi_decrypt_field: decryption failed");
        return null;
    };

    return makeLengthPrefixed(pt_buf[0..pt_len2]);
}

export fn hanzi_vacuum_deleted() i32 {
    var db = global_db orelse return -1;
    const retention_ms: i64 = 30 * 24 * 60 * 60 * 1000; // 30 days
    const removed = db.vacuumDeleted(now(), retention_ms) catch return -1;
    return removed;
}

// === Chinese data loading (on-demand for WASM) ===

export fn hanzi_persist_alloc(len: usize) ?[*]u8 {
    const mem = persist_fba.allocator().alloc(u8, len) catch return null;
    return mem.ptr;
}

export fn hanzi_load_cedict(ptr: [*]const u8, len: usize) i32 {
    cedict.load(ptr, len);
    log("cedict data loaded");
    return 0;
}

export fn hanzi_load_decomp(ptr: [*]const u8, len: usize) i32 {
    decompose.load(ptr, len);
    log("decomp data loaded");
    return 0;
}

export fn hanzi_load_strokes(ptr: [*]const u8, len: usize) i32 {
    strokes_mod.load(ptr, len);
    log("strokes data loaded");
    return 0;
}

export fn hanzi_chinese_data_loaded() i32 {
    if (cedict.isLoaded() and decompose.isLoaded() and strokes_mod.isLoaded()) return 1;
    return 0;
}

// Unload the Chinese data bundle. Clears the data slice references so
// `*_loaded()` returns false and the UI reflects removal. Persistent
// allocator blocks are NOT freed (FBA arena, no individual free) — the
// bytes stay reserved until the next page reload, which also zeros out
// the FBA. Callers should pair this with deleting the OPFS cache files
// and nudge the user to reload for a clean slate.
export fn hanzi_unload_chinese() i32 {
    cedict.unload();
    decompose.unload();
    strokes_mod.unload();
    log("chinese data unloaded");
    return 0;
}

// === Wiktionary EN/DE dictionaries ===

export fn hanzi_load_endict(ptr: [*]const u8, len: usize) i32 {
    wiktdict.loadEn(ptr, len);
    log("endict data loaded");
    return 0;
}

export fn hanzi_load_dedict(ptr: [*]const u8, len: usize) i32 {
    wiktdict.loadDe(ptr, len);
    log("dedict data loaded");
    return 0;
}

export fn hanzi_unload_endict() i32 {
    wiktdict.unloadEn();
    log("endict data unloaded");
    return 0;
}

export fn hanzi_unload_dedict() i32 {
    wiktdict.unloadDe();
    log("dedict data unloaded");
    return 0;
}

/// Wipe all dictionary slice references AND reset the persistent FBA.
///
/// `hanzi_unload_*` only clears the data slice — the bytes stay reserved
/// in the persist arena because FBA is an arena (no per-block free), so a
/// follow-up install would hit "persistent alloc failed" until a page
/// reload re-instantiated the WASM. This export is the in-place
/// alternative: after calling it the persist arena is empty and the
/// caller must re-feed any dictionaries it wants kept (read .bin from
/// OPFS → persist_alloc → load_*).
export fn hanzi_persist_reset() void {
    cedict.unload();
    decompose.unload();
    strokes_mod.unload();
    wiktdict.unloadEn();
    wiktdict.unloadDe();
    persist_fba.reset();
    log("persist arena reset");
}

export fn hanzi_endict_loaded() i32 {
    return if (wiktdict.isEnLoaded()) @as(i32, 1) else 0;
}

export fn hanzi_dedict_loaded() i32 {
    return if (wiktdict.isDeLoaded()) @as(i32, 1) else 0;
}

export fn hanzi_lookup_word(query_ptr: [*]const u8, query_len: usize) ?[*]const u8 {
    const query = query_ptr[0..query_len];
    // Auto-detect language and search appropriate dictionary. The primary
    // dict may return "[]" (empty JSON array) rather than null when the
    // query has zero prefix matches — non-null, so a plain `orelse` never
    // falls through. Treat empty as "try the other dict" so German words
    // without umlauts (e.g. "hinken", misdetected as English) still resolve.
    const detected = lang_mod.detect(query);
    const primary = switch (detected) {
        .de => wiktdict.searchDe(query, 20, &json_buf),
        else => wiktdict.searchEn(query, 20, &json_buf),
    };
    const fallback_is_de = detected != .de;
    const result = if (primary != null and !isEmptyJsonArray(primary.?))
        primary.?
    else switch (fallback_is_de) {
        true => wiktdict.searchDe(query, 20, &json_buf) orelse return null,
        false => wiktdict.searchEn(query, 20, &json_buf) orelse return null,
    };
    return makeLengthPrefixed(result);
}

fn isEmptyJsonArray(s: []const u8) bool {
    return s.len == 2 and s[0] == '[' and s[1] == ']';
}

// === WASM-only exports ===

comptime {
    if (is_wasm) {
        @export(&wasmDbPtr, .{ .name = "hanzi_db_ptr" });
        @export(&wasmDbSize, .{ .name = "hanzi_db_size" });
        @export(&wasmDbLoad, .{ .name = "hanzi_db_load" });
    }
}

fn wasmDbPtr() callconv(.c) ?[*]u8 {
    return sqlite.wasm_vfs.wasm_vfs_get_db_ptr("taijobi.db");
}

fn wasmDbSize() callconv(.c) c_int {
    return sqlite.wasm_vfs.wasm_vfs_get_db_size("taijobi.db");
}

fn wasmDbLoad(ptr: [*]const u8, len: c_int) callconv(.c) c_int {
    return sqlite.wasm_vfs.wasm_vfs_load_db("taijobi.db", ptr, len);
}

// Pull in tests from other modules
test {
    _ = @import("types.zig");
    _ = @import("fsrs.zig");
    _ = @import("db.zig");
    _ = @import("lang.zig");
    _ = @import("lexicon.zig");
    _ = @import("cedict.zig");
    _ = @import("curriculum.zig");
    _ = @import("decompose.zig");
    _ = @import("strokes.zig");
    _ = @import("pinyin.zig");
    _ = @import("csv.zig");
    _ = @import("apkg.zig");
    _ = @import("crypto.zig");
}
