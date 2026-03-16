// Zig bindings for the SQLite C API subset we need.
// Manual declarations — proven wimg pattern for stable WASM builds.

const builtin = @import("builtin");

pub const SQLITE_OK = 0;
pub const SQLITE_ROW = 100;
pub const SQLITE_DONE = 101;
pub const SQLITE_STATIC = @as(isize, 0);
pub const SQLITE_NULL = 5;

pub const sqlite3 = opaque {};
pub const sqlite3_stmt = opaque {};

// Resolved at link time (sqlite3.c compiled as C source).
pub extern fn sqlite3_initialize() c_int;
pub extern fn sqlite3_open(filename: [*:0]const u8, ppDb: *?*sqlite3) c_int;
pub extern fn sqlite3_close(db: *sqlite3) c_int;
pub extern fn sqlite3_exec(
    db: *sqlite3,
    sql: [*:0]const u8,
    callback: ?*const anyopaque,
    arg: ?*anyopaque,
    errmsg: ?*?[*:0]u8,
) c_int;
pub extern fn sqlite3_prepare_v2(
    db: *sqlite3,
    sql: [*:0]const u8,
    nByte: c_int,
    ppStmt: *?*sqlite3_stmt,
    pzTail: ?*?[*:0]const u8,
) c_int;
pub extern fn sqlite3_finalize(stmt: *sqlite3_stmt) c_int;
pub extern fn sqlite3_step(stmt: *sqlite3_stmt) c_int;
pub extern fn sqlite3_reset(stmt: *sqlite3_stmt) c_int;

pub extern fn sqlite3_bind_int(stmt: *sqlite3_stmt, col: c_int, value: c_int) c_int;
pub extern fn sqlite3_bind_int64(stmt: *sqlite3_stmt, col: c_int, value: i64) c_int;
pub extern fn sqlite3_bind_double(stmt: *sqlite3_stmt, col: c_int, value: f64) c_int;
pub extern fn sqlite3_bind_text(
    stmt: *sqlite3_stmt,
    col: c_int,
    text: [*]const u8,
    len: c_int,
    destructor: isize,
) c_int;
pub extern fn sqlite3_bind_null(stmt: *sqlite3_stmt, col: c_int) c_int;

pub extern fn sqlite3_column_int(stmt: *sqlite3_stmt, col: c_int) c_int;
pub extern fn sqlite3_column_int64(stmt: *sqlite3_stmt, col: c_int) i64;
pub extern fn sqlite3_column_double(stmt: *sqlite3_stmt, col: c_int) f64;
pub extern fn sqlite3_column_text(stmt: *sqlite3_stmt, col: c_int) ?[*]const u8;
pub extern fn sqlite3_column_bytes(stmt: *sqlite3_stmt, col: c_int) c_int;
pub extern fn sqlite3_column_type(stmt: *sqlite3_stmt, col: c_int) c_int;

pub extern fn sqlite3_changes(db: *sqlite3) c_int;
pub extern fn sqlite3_errmsg(db: *sqlite3) ?[*:0]const u8;

// WASM VFS externs (only available in wasm32-freestanding)
pub const wasm_vfs = if (builtin.cpu.arch == .wasm32) struct {
    pub extern fn wasm_vfs_get_db_ptr(name: [*:0]const u8) ?[*]u8;
    pub extern fn wasm_vfs_get_db_size(name: [*:0]const u8) c_int;
    pub extern fn wasm_vfs_load_db(name: [*:0]const u8, data: [*]const u8, size: c_int) c_int;
} else struct {};
