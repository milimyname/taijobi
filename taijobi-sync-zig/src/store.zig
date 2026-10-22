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
        // Web Push subscriptions — the Worker's PushSubs Durable Object table.
        // Keyed by SHA-256(sync key), never the raw key.
        try self.exec(
            \\CREATE TABLE IF NOT EXISTS push_subs (
            \\  sync_key_hash    TEXT PRIMARY KEY,
            \\  endpoint         TEXT NOT NULL,
            \\  p256dh           TEXT NOT NULL,
            \\  auth             TEXT NOT NULL,
            \\  last_review_at   INTEGER NOT NULL DEFAULT 0,
            \\  last_notified_at INTEGER NOT NULL DEFAULT 0,
            \\  created_at       INTEGER NOT NULL
            \\);
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

    // --- Web Push subscriptions ---

    pub const PushSub = struct { sync_key_hash: []const u8, endpoint: []const u8, p256dh: []const u8, auth: []const u8 };

    /// Owned result of `pushDue`; strings point into `arena`.
    pub const PushDue = struct {
        arena: std.heap.ArenaAllocator,
        subs: []PushSub,

        pub fn deinit(self: *PushDue) void {
            self.arena.deinit();
        }
    };

    /// Upsert a subscription. A re-subscribe keeps the review/notify clocks.
    pub fn pushSubscribe(self: *Store, hash: []const u8, endpoint: []const u8, p256dh: []const u8, auth: []const u8, now_ms: i64) Error!void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const sql =
            \\INSERT INTO push_subs (sync_key_hash, endpoint, p256dh, auth, last_review_at, last_notified_at, created_at)
            \\VALUES (?1, ?2, ?3, ?4, ?5, 0, ?5)
            \\ON CONFLICT (sync_key_hash) DO UPDATE SET
            \\  endpoint = excluded.endpoint, p256dh = excluded.p256dh, auth = excluded.auth;
        ;
        const stmt = try self.prepare(sql);
        defer _ = c.sqlite3_finalize(stmt);
        bindText(stmt, 1, hash);
        bindText(stmt, 2, endpoint);
        bindText(stmt, 3, p256dh);
        bindText(stmt, 4, auth);
        _ = c.sqlite3_bind_int64(stmt, 5, now_ms);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.StepFailed;
    }

    pub fn pushUnsubscribe(self: *Store, hash: []const u8) Error!void {
        try self.execHash("DELETE FROM push_subs WHERE sync_key_hash = ?1;", hash, null);
    }

    /// Record the client's last review time (the heartbeat after each review).
    pub fn pushHeartbeat(self: *Store, hash: []const u8, ts_ms: i64) Error!void {
        try self.execHash("UPDATE push_subs SET last_review_at = ?2 WHERE sync_key_hash = ?1;", hash, ts_ms);
    }

    pub fn pushNotified(self: *Store, hash: []const u8, now_ms: i64) Error!void {
        try self.execHash("UPDATE push_subs SET last_notified_at = ?2 WHERE sync_key_hash = ?1;", hash, now_ms);
    }

    /// Subscriptions whose last review is 20–28 h old and that weren't notified
    /// in the last 18 h — same window as the Worker's `/due`.
    pub fn pushDue(self: *Store, gpa: std.mem.Allocator, now_ms: i64) !PushDue {
        self.mutex.lock();
        defer self.mutex.unlock();
        const hour: i64 = 3600 * 1000;
        const sql =
            \\SELECT sync_key_hash, endpoint, p256dh, auth FROM push_subs
            \\WHERE last_review_at > ?1 AND last_review_at < ?2 AND last_notified_at < ?3;
        ;
        const stmt = try self.prepare(sql);
        defer _ = c.sqlite3_finalize(stmt);
        _ = c.sqlite3_bind_int64(stmt, 1, now_ms - 28 * hour);
        _ = c.sqlite3_bind_int64(stmt, 2, now_ms - 20 * hour);
        _ = c.sqlite3_bind_int64(stmt, 3, now_ms - 18 * hour);

        var arena = std.heap.ArenaAllocator.init(gpa);
        errdefer arena.deinit();
        const a = arena.allocator();
        var subs: std.ArrayList(PushSub) = .empty;
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            try subs.append(a, .{
                .sync_key_hash = try a.dupe(u8, columnText(stmt, 0)),
                .endpoint = try a.dupe(u8, columnText(stmt, 1)),
                .p256dh = try a.dupe(u8, columnText(stmt, 2)),
                .auth = try a.dupe(u8, columnText(stmt, 3)),
            });
        }
        return .{ .arena = arena, .subs = try subs.toOwnedSlice(a) };
    }

    fn prepare(self: *Store, sql: []const u8) Error!?*c.sqlite3_stmt {
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.db, sql.ptr, @intCast(sql.len), &stmt, null) != c.SQLITE_OK or stmt == null) {
            return error.PrepareFailed;
        }
        return stmt;
    }

    /// Run a statement binding ?1 = hash and, if given, ?2 = an integer.
    fn execHash(self: *Store, sql: []const u8, hash: []const u8, int2: ?i64) Error!void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stmt = try self.prepare(sql);
        defer _ = c.sqlite3_finalize(stmt);
        bindText(stmt, 1, hash);
        if (int2) |v| _ = c.sqlite3_bind_int64(stmt, 2, v);
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.StepFailed;
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

test "push subscriptions: upsert, heartbeat window, notified, unsubscribe" {
    const gpa = std.testing.allocator;
    var store = try Store.open(":memory:");
    defer store.close();
    const hour: i64 = 3600 * 1000;
    const now: i64 = 1_000 * hour;

    try store.pushSubscribe("h1", "https://a/1", "p", "a", now - 48 * hour);
    try store.pushSubscribe("h2", "https://a/2", "p", "a", now - 48 * hour);
    try store.pushHeartbeat("h1", now - 24 * hour); // in the 20–28 h window
    try store.pushHeartbeat("h2", now - 2 * hour); // reviewed recently

    var due = try store.pushDue(gpa, now);
    try std.testing.expectEqual(@as(usize, 1), due.subs.len);
    try std.testing.expectEqualStrings("h1", due.subs[0].sync_key_hash);
    due.deinit();

    // Re-subscribing (new endpoint) keeps the heartbeat; notifying silences it.
    try store.pushSubscribe("h1", "https://a/1b", "p", "a", now);
    var due2 = try store.pushDue(gpa, now);
    try std.testing.expectEqualStrings("https://a/1b", due2.subs[0].endpoint);
    due2.deinit();
    try store.pushNotified("h1", now);
    var due3 = try store.pushDue(gpa, now);
    try std.testing.expectEqual(@as(usize, 0), due3.subs.len);
    due3.deinit();

    try store.pushUnsubscribe("h1");
    var due4 = try store.pushDue(gpa, now + 30 * hour);
    try std.testing.expectEqual(@as(usize, 0), due4.subs.len);
    due4.deinit();
}
