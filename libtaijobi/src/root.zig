const std = @import("std");
const builtin = @import("builtin");
const sqlite = @import("sqlite_c.zig");
const types = @import("types.zig");
const db_mod = @import("db.zig");
const fsrs_mod = @import("fsrs.zig");

const Db = db_mod.Db;

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
}
