const std = @import("std");
const builtin = @import("builtin");
const sqlite = @import("sqlite_c.zig");
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

// --- Fixed buffer allocator (64MB) ---
const FBA_SIZE = 64 * 1024 * 1024;
var fba_backing: [FBA_SIZE]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&fba_backing);

// --- Global state ---
var global_db: ?Db = null;
var error_buf: [512]u8 = undefined;
var error_len: usize = 0;
var json_buf: [64 * 1024]u8 = undefined; // 64KB for JSON responses

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

export fn hanzi_init(path: [*:0]const u8) i32 {
    log("hanzi_init called");
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

export fn hanzi_remove_word(id_ptr: [*]const u8, id_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const card_id = id_ptr[0..id_len];
    lexicon.removeWord(db.handle, card_id) catch |err| {
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

export fn hanzi_remove_pack(id_ptr: [*]const u8, id_len: usize) i32 {
    const db = &(global_db orelse return -1);
    const pack_id = id_ptr[0..id_len];
    curriculum.removePack(db.handle, pack_id) catch |err| {
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

export fn hanzi_get_vocabulary(lesson_id_ptr: [*]const u8, lesson_id_len: usize) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const lesson_id = lesson_id_ptr[0..lesson_id_len];
    const json = curriculum.getVocabulary(db.handle, lesson_id, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_get_progress(pack_id_ptr: [*]const u8, pack_id_len: usize) ?[*]const u8 {
    const db = &(global_db orelse return null);
    const pack_id = pack_id_ptr[0..pack_id_len];
    const json = curriculum.getProgress(db.handle, pack_id, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

// === Phase 3 — Deep Chinese ===

export fn hanzi_decompose(char_ptr: [*]const u8, char_len: usize) ?[*]const u8 {
    const query = char_ptr[0..char_len];
    const json = decompose.decomposeToJson(query, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
}

export fn hanzi_get_strokes(char_ptr: [*]const u8, char_len: usize) ?[*]const u8 {
    const query = char_ptr[0..char_len];
    const json = strokes_mod.strokesAsJson(query, &json_buf) orelse return null;
    return makeLengthPrefixed(json);
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
}
