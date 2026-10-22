//! SQLite-backed sync storage — the native equivalent of the Cloudflare
//! SyncRoom Durable Object's `sync_rows` table.
//!
//! The CF Worker gives each sync key its own DO (and its own SQLite). A single
//! VPS process serves every key, so rows are partitioned by `sync_key` instead.
//! The merge is last-write-wins on `updated_at`, byte-for-byte the same SQL as
//! `taijobi-sync/src/sync-room.ts`.
//!
//! `data` is an opaque, client-side-encrypted JSON value. The server never
//! decrypts it for sync — it stores the raw JSON text and echoes it back
//! verbatim on pull.

const std = @import("std");
const c = @import("sqlite.zig");

pub const Row = struct {
    table: []const u8,
    id: []const u8,
    /// Raw JSON text of the row's `data` value (object), stored verbatim.
    data: []const u8,
    updated_at: i64,
};

/// Tiny spinlock. SQLite is compiled THREADSAFE=0, so every DB call is
/// serialized through this. Contention is near-zero (one user, a few devices),
/// so a spinlock beats pulling in the `std.Io` async mutex machinery.
const SpinLock = struct {
    locked: std.atomic.Value(bool) = .init(false),

    fn lock(self: *SpinLock) void {
        while (self.locked.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }
    fn unlock(self: *SpinLock) void {
        self.locked.store(false, .release);
    }
};

pub const Store = struct {
    db: ?*c.sqlite3,
    mutex: SpinLock = .{},

    pub const Error = error{ OpenFailed, ExecFailed, PrepareFailed, StepFailed };

    pub fn open(path: [*:0]const u8) Error!Store {
        var db: ?*c.sqlite3 = null;
        if (c.sqlite3_open(path, &db) != c.SQLITE_OK or db == null) {
            if (db) |h| _ = c.sqlite3_close(h);
            return error.OpenFailed;
        }
        var self = Store{ .db = db };
        // WAL keeps reads (pull) from blocking the writer (push) under load.
        try self.exec("PRAGMA journal_mode=WAL;");
        try self.exec("PRAGMA synchronous=NORMAL;");
        try self.exec(
            \\CREATE TABLE IF NOT EXISTS sync_rows (
            \\  sync_key   TEXT NOT NULL,
            \\  tbl        TEXT NOT NULL,
            \\  row_id     TEXT NOT NULL,
            \\  data       TEXT NOT NULL,
            \\  updated_at INTEGER NOT NULL,
            \\  PRIMARY KEY (sync_key, tbl, row_id)
            \\);
        );
        try self.exec(
            \\CREATE INDEX IF NOT EXISTS idx_sync_rows_pull
            \\  ON sync_rows (sync_key, updated_at);
        );
        return self;
    }

    pub fn close(self: *Store) void {
        if (self.db) |h| _ = c.sqlite3_close(h);
        self.db = null;
    }

    fn exec(self: *Store, sql: [*:0]const u8) Error!void {
        if (c.sqlite3_exec(self.db, sql, null, null, null) != c.SQLITE_OK) return error.ExecFailed;
    }

    /// Apply LWW upserts for `key`. Returns the total row count for that key
    /// (matching the Worker's `merged` reply field).
    pub fn merge(self: *Store, key: []const u8, rows: []const Row) Error!i64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const sql =
            \\INSERT INTO sync_rows (sync_key, tbl, row_id, data, updated_at)
            \\VALUES (?1, ?2, ?3, ?4, ?5)
            \\ON CONFLICT (sync_key, tbl, row_id) DO UPDATE
            \\SET data = excluded.data, updated_at = excluded.updated_at
            \\WHERE excluded.updated_at > sync_rows.updated_at;
        ;
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.db, sql, @intCast(sql.len), &stmt, null) != c.SQLITE_OK or stmt == null) {
            return error.PrepareFailed;
        }
        defer _ = c.sqlite3_finalize(stmt);

        for (rows) |row| {
            _ = c.sqlite3_reset(stmt);
            bindText(stmt, 1, key);
            bindText(stmt, 2, row.table);
            bindText(stmt, 3, row.id);
            bindText(stmt, 4, row.data);
            _ = c.sqlite3_bind_int64(stmt, 5, row.updated_at);
            const rc = c.sqlite3_step(stmt);
            if (rc != c.SQLITE_DONE) return error.StepFailed;
        }

        return self.countLocked(key);
    }

    fn countLocked(self: *Store, key: []const u8) i64 {
        const sql = "SELECT COUNT(*) FROM sync_rows WHERE sync_key = ?1;";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.db, sql, sql.len, &stmt, null) != c.SQLITE_OK) return 0;
        defer _ = c.sqlite3_finalize(stmt);
        bindText(stmt, 1, key);
        if (c.sqlite3_step(stmt) != c.SQLITE_ROW) return 0;
        return c.sqlite3_column_int64(stmt, 0);
    }

    /// Append `{"rows":[...]}` for every row of `key` with `updated_at > since`
    /// to `out`. `data` is emitted verbatim (already valid JSON).
    pub fn rowsSinceJson(self: *Store, gpa: std.mem.Allocator, key: []const u8, since: i64, out: *std.ArrayList(u8)) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try out.appendSlice(gpa, "{\"rows\":[");

        const sql =
            \\SELECT tbl, row_id, data, updated_at FROM sync_rows
            \\WHERE sync_key = ?1 AND updated_at > ?2;
        ;
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.db, sql, @intCast(sql.len), &stmt, null) != c.SQLITE_OK or stmt == null) {
            return error.PrepareFailed;
        }
        defer _ = c.sqlite3_finalize(stmt);
        bindText(stmt, 1, key);
        _ = c.sqlite3_bind_int64(stmt, 2, since);

        var first = true;
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            if (!first) try out.append(gpa, ',');
            first = false;
            try out.appendSlice(gpa, "{\"table\":");
            try appendJsonString(gpa, out, columnText(stmt, 0));
            try out.appendSlice(gpa, ",\"id\":");
            try appendJsonString(gpa, out, columnText(stmt, 1));
            try out.appendSlice(gpa, ",\"data\":");
            try out.appendSlice(gpa, columnText(stmt, 2)); // verbatim JSON
            try out.appendSlice(gpa, ",\"updated_at\":");
            var num_buf: [24]u8 = undefined;
            const num = std.fmt.bufPrint(&num_buf, "{d}", .{c.sqlite3_column_int64(stmt, 3)}) catch unreachable;
            try out.appendSlice(gpa, num);
            try out.append(gpa, '}');
        }

        try out.appendSlice(gpa, "]}");
    }
};

/// Serialize in-memory rows to a JSON array `[{...},...]` — used to build the
/// `changes` payload broadcast over WebSocket. `data` is emitted verbatim.
pub fn appendRowsArrayJson(gpa: std.mem.Allocator, out: *std.ArrayList(u8), rows: []const Row) !void {
    try out.append(gpa, '[');
    for (rows, 0..) |row, i| {
        if (i != 0) try out.append(gpa, ',');
        try out.appendSlice(gpa, "{\"table\":");
        try appendJsonString(gpa, out, row.table);
        try out.appendSlice(gpa, ",\"id\":");
        try appendJsonString(gpa, out, row.id);
        try out.appendSlice(gpa, ",\"data\":");
        try out.appendSlice(gpa, row.data);
        try out.appendSlice(gpa, ",\"updated_at\":");
        var num_buf: [24]u8 = undefined;
        const num = std.fmt.bufPrint(&num_buf, "{d}", .{row.updated_at}) catch unreachable;
        try out.appendSlice(gpa, num);
        try out.append(gpa, '}');
    }
    try out.append(gpa, ']');
}

fn bindText(stmt: ?*c.sqlite3_stmt, idx: c_int, text: []const u8) void {
    _ = c.sqlite3_bind_text(stmt, idx, text.ptr, @intCast(text.len), c.SQLITE_TRANSIENT);
}

fn columnText(stmt: ?*c.sqlite3_stmt, col: c_int) []const u8 {
    const ptr = c.sqlite3_column_text(stmt, col) orelse return "";
    const len: usize = @intCast(c.sqlite3_column_bytes(stmt, col));
    return ptr[0..len];
}

fn appendJsonString(gpa: std.mem.Allocator, out: *std.ArrayList(u8), s: []const u8) !void {
    try out.append(gpa, '"');
    for (s) |ch| {
        switch (ch) {
            '"' => try out.appendSlice(gpa, "\\\""),
            '\\' => try out.appendSlice(gpa, "\\\\"),
            '\n' => try out.appendSlice(gpa, "\\n"),
            '\r' => try out.appendSlice(gpa, "\\r"),
            '\t' => try out.appendSlice(gpa, "\\t"),
            0...8, 11, 12, 14...31 => {
                var esc: [6]u8 = undefined;
                const e = std.fmt.bufPrint(&esc, "\\u{x:0>4}", .{ch}) catch unreachable;
                try out.appendSlice(gpa, e);
            },
            else => try out.append(gpa, ch),
        }
    }
    try out.append(gpa, '"');
}

test "merge applies last-write-wins and pull returns rows since" {
    const gpa = std.testing.allocator;
    var store = try Store.open(":memory:");
    defer store.close();

    const rows1 = [_]Row{
        .{ .table = "cards", .id = "a", .data = "{\"ct\":\"x\"}", .updated_at = 100 },
        .{ .table = "packs", .id = "main", .data = "{\"ct\":\"y\"}", .updated_at = 100 },
    };
    const count1 = try store.merge("key1", &rows1);
    try std.testing.expectEqual(@as(i64, 2), count1);

    // Older update must NOT overwrite.
    const stale = [_]Row{.{ .table = "cards", .id = "a", .data = "{\"ct\":\"OLD\"}", .updated_at = 50 }};
    _ = try store.merge("key1", &stale);

    // Newer update wins.
    const fresh = [_]Row{.{ .table = "cards", .id = "a", .data = "{\"ct\":\"NEW\"}", .updated_at = 200 }};
    _ = try store.merge("key1", &fresh);

    // Pull everything since 0.
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    try store.rowsSinceJson(gpa, "key1", 0, &out);
    try std.testing.expect(std.mem.indexOf(u8, out.items, "\"ct\":\"NEW\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.items, "OLD") == null);

    // Pull since 150 returns only the freshly-updated row.
    var out2: std.ArrayList(u8) = .empty;
    defer out2.deinit(gpa);
    try store.rowsSinceJson(gpa, "key1", 150, &out2);
    try std.testing.expect(std.mem.indexOf(u8, out2.items, "cards") != null);
    try std.testing.expect(std.mem.indexOf(u8, out2.items, "packs") == null);
}

test "rows are partitioned by sync key" {
    const gpa = std.testing.allocator;
    var store = try Store.open(":memory:");
    defer store.close();

    _ = try store.merge("alice", &[_]Row{.{ .table = "t", .id = "1", .data = "{}", .updated_at = 10 }});
    const bob_count = try store.merge("bob", &[_]Row{.{ .table = "t", .id = "1", .data = "{}", .updated_at = 10 }});
    try std.testing.expectEqual(@as(i64, 1), bob_count); // bob sees only his own row

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    try store.rowsSinceJson(gpa, "alice", 0, &out);
    try std.testing.expectEqualStrings("{\"rows\":[{\"table\":\"t\",\"id\":\"1\",\"data\":{},\"updated_at\":10}]}", out.items);
}
