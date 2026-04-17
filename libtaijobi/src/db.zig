const std = @import("std");
const builtin = @import("builtin");
const sqlite = @import("sqlite_c.zig");
const types = @import("types.zig");
const fsrs = @import("fsrs.zig");

const JsonWriter = types.JsonWriter;
const Rating = types.Rating;

const DbError = error{
    OpenFailed,
    ExecFailed,
    PrepareFailed,
    StepFailed,
    InvalidRating,
    CardNotFound,
    MigrationFailed,
};

pub const Db = struct {
    handle: *sqlite.sqlite3,

    pub fn init(path: [*:0]const u8) DbError!Db {
        if (sqlite.sqlite3_initialize() != sqlite.SQLITE_OK) {
            return error.OpenFailed;
        }
        var db_handle: ?*sqlite.sqlite3 = null;
        if (sqlite.sqlite3_open(path, &db_handle) != sqlite.SQLITE_OK) {
            return error.OpenFailed;
        }
        var self = Db{ .handle = db_handle.? };
        try self.exec("PRAGMA journal_mode=MEMORY");
        try self.exec("PRAGMA synchronous=OFF");
        try self.migrate();
        return self;
    }

    pub fn close(self: *Db) void {
        _ = sqlite.sqlite3_close(self.handle);
    }

    pub fn exec(self: *Db, sql: [*:0]const u8) DbError!void {
        if (sqlite.sqlite3_exec(self.handle, sql, null, null, null) != sqlite.SQLITE_OK) {
            return error.ExecFailed;
        }
    }

    /// Last SQLite error message (C string). Safe to call after any failed op.
    pub fn lastError(self: *Db) ?[*:0]const u8 {
        return sqlite.sqlite3_errmsg(self.handle);
    }

    /// Run arbitrary SQL, write JSON result `{columns, rows, count, truncated}`
    /// into `buf`, return bytes written. Used by the DevTools SQL panel only.
    /// Returns `null` if the serialized JSON would overflow the buffer; caller
    /// should treat that as "result too large". Returns `DbError.PrepareFailed`
    /// on prepare failure (syntax error etc.) — caller reads `lastError()` for
    /// the SQLite-level message.
    pub fn rawQuery(self: *Db, sql: [*:0]const u8, buf: [*]u8, buf_size: usize) DbError!?usize {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const rc = sqlite.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null);
        if (rc != sqlite.SQLITE_OK or stmt == null) return DbError.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);

        const s = stmt.?;
        const col_count: usize = @intCast(sqlite.sqlite3_column_count(s));

        // Collect column names (cap at 64 columns for the debug table)
        var col_names: [64][*:0]const u8 = undefined;
        const cols = @min(col_count, 64);
        for (0..cols) |i| {
            col_names[i] = sqlite.sqlite3_column_name(s, @intCast(i)) orelse "?";
        }

        var stream = std.io.fixedBufferStream(buf[0..buf_size]);
        const w = stream.writer();

        w.writeAll("{\"columns\":[") catch return null;
        for (0..cols) |i| {
            if (i > 0) w.writeByte(',') catch return null;
            w.writeByte('"') catch return null;
            w.writeAll(std.mem.span(col_names[i])) catch return null;
            w.writeByte('"') catch return null;
        }
        w.writeAll("],\"rows\":[") catch return null;

        var row_idx: usize = 0;
        const max_rows: usize = 500;
        while (sqlite.sqlite3_step(s) == sqlite.SQLITE_ROW) {
            if (row_idx >= max_rows) break;
            if (row_idx > 0) w.writeByte(',') catch return null;
            w.writeByte('[') catch return null;
            for (0..cols) |i| {
                if (i > 0) w.writeByte(',') catch return null;
                const col_type = sqlite.sqlite3_column_type(s, @intCast(i));
                if (col_type == sqlite.SQLITE_NULL) {
                    w.writeAll("null") catch return null;
                } else if (col_type == sqlite.SQLITE_INTEGER) {
                    const v = sqlite.sqlite3_column_int64(s, @intCast(i));
                    std.fmt.format(w, "{d}", .{v}) catch return null;
                } else if (col_type == sqlite.SQLITE_FLOAT) {
                    const v = sqlite.sqlite3_column_double(s, @intCast(i));
                    std.fmt.format(w, "{d}", .{v}) catch return null;
                } else if (col_type == sqlite.SQLITE_BLOB) {
                    const len: usize = @intCast(sqlite.sqlite3_column_bytes(s, @intCast(i)));
                    std.fmt.format(w, "\"<BLOB {d} bytes>\"", .{len}) catch return null;
                } else { // TEXT
                    const ptr = sqlite.sqlite3_column_text(s, @intCast(i));
                    const len: usize = @intCast(sqlite.sqlite3_column_bytes(s, @intCast(i)));
                    w.writeByte('"') catch return null;
                    if (ptr) |p| {
                        for (p[0..len]) |ch| {
                            switch (ch) {
                                '"' => w.writeAll("\\\"") catch return null,
                                '\\' => w.writeAll("\\\\") catch return null,
                                '\n' => w.writeAll("\\n") catch return null,
                                '\r' => w.writeAll("\\r") catch return null,
                                '\t' => w.writeAll("\\t") catch return null,
                                else => {
                                    if (ch < 0x20) {
                                        std.fmt.format(w, "\\u{x:0>4}", .{@as(u16, ch)}) catch return null;
                                    } else {
                                        w.writeByte(ch) catch return null;
                                    }
                                },
                            }
                        }
                    }
                    w.writeByte('"') catch return null;
                }
            }
            w.writeByte(']') catch return null;
            row_idx += 1;
        }

        w.writeAll("]") catch return null;
        std.fmt.format(w, ",\"count\":{d},\"truncated\":{s}}}", .{ row_idx, if (row_idx >= max_rows) "true" else "false" }) catch return null;

        return stream.pos;
    }

    fn migrate(self: *Db) DbError!void {
        // Create meta table first (may already exist)
        try self.exec(
            \\CREATE TABLE IF NOT EXISTS meta (
            \\  key TEXT PRIMARY KEY,
            \\  value TEXT NOT NULL
            \\)
        );

        const version = self.getMetaInt("schema_version");
        if (version < 1) {
            try self.exec(schema_v1);
            try self.setMeta("schema_version", "3");
            try self.seed();
        }
        if (version >= 1 and version < 2) {
            try self.exec("ALTER TABLE cards ADD COLUMN first_seen_at INTEGER");
            try self.setMeta("schema_version", "2");
        }
        const v2 = self.getMetaInt("schema_version");
        if (v2 >= 2 and v2 < 3) {
            try self.exec("ALTER TABLE cards ADD COLUMN deleted INTEGER DEFAULT 0");
            try self.exec("ALTER TABLE packs ADD COLUMN deleted INTEGER DEFAULT 0");
            try self.setMeta("schema_version", "3");
        }
    }

    fn getMetaInt(self: *Db, key: []const u8) i32 {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "SELECT value FROM meta WHERE key=?";
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) {
            return 0;
        }
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, key.ptr, @intCast(key.len), sqlite.SQLITE_STATIC);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_ROW) return 0;
        const text = sqlite.sqlite3_column_text(stmt.?, 0) orelse return 0;
        const len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 0));
        return std.fmt.parseInt(i32, text[0..len], 10) catch 0;
    }

    fn setMeta(self: *Db, key: []const u8, value: []const u8) DbError!void {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "INSERT OR REPLACE INTO meta(key,value) VALUES(?,?)";
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) {
            return error.PrepareFailed;
        }
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, key.ptr, @intCast(key.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 2, value.ptr, @intCast(value.len), sqlite.SQLITE_STATIC);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    pub fn getDueCount(self: *Db, now_ms: i64) i32 {
        return self.getDueCountFiltered(now_ms, null);
    }

    /// Get due count, optionally filtered by source.
    /// filter: null = all, "lexicon" = personal words, anything else = pack_id
    pub fn getDueCountFiltered(self: *Db, now_ms: i64, filter: ?[]const u8) i32 {
        var stmt: ?*sqlite.sqlite3_stmt = null;

        const sql_all =
            \\SELECT COUNT(*) FROM cards c
            \\LEFT JOIN fsrs_state f ON c.id = f.card_id
            \\WHERE (f.card_id IS NULL OR f.reps = 0 OR f.next_review IS NULL OR CAST(f.next_review AS INTEGER) <= ?)
            \\  AND COALESCE(c.deleted, 0) = 0
        ;
        const sql_lexicon =
            \\SELECT COUNT(*) FROM cards c
            \\LEFT JOIN fsrs_state f ON c.id = f.card_id
            \\WHERE (f.card_id IS NULL OR f.reps = 0 OR f.next_review IS NULL OR CAST(f.next_review AS INTEGER) <= ?)
            \\  AND c.source_type = 'lexicon' AND COALESCE(c.deleted, 0) = 0
        ;
        const sql_pack =
            \\SELECT COUNT(*) FROM cards c
            \\LEFT JOIN fsrs_state f ON c.id = f.card_id
            \\WHERE (f.card_id IS NULL OR f.reps = 0 OR f.next_review IS NULL OR CAST(f.next_review AS INTEGER) <= ?)
            \\  AND c.pack_id = ? AND COALESCE(c.deleted, 0) = 0
        ;

        if (filter) |f| {
            if (std.mem.eql(u8, f, "lexicon")) {
                if (sqlite.sqlite3_prepare_v2(self.handle, sql_lexicon, @intCast(sql_lexicon.len), &stmt, null) != sqlite.SQLITE_OK) return 0;
                defer _ = sqlite.sqlite3_finalize(stmt.?);
                _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
                if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_ROW) return 0;
                return sqlite.sqlite3_column_int(stmt.?, 0);
            } else {
                if (sqlite.sqlite3_prepare_v2(self.handle, sql_pack, @intCast(sql_pack.len), &stmt, null) != sqlite.SQLITE_OK) return 0;
                defer _ = sqlite.sqlite3_finalize(stmt.?);
                _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
                _ = sqlite.sqlite3_bind_text(stmt.?, 2, f.ptr, @intCast(f.len), sqlite.SQLITE_STATIC);
                if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_ROW) return 0;
                return sqlite.sqlite3_column_int(stmt.?, 0);
            }
        } else {
            if (sqlite.sqlite3_prepare_v2(self.handle, sql_all, @intCast(sql_all.len), &stmt, null) != sqlite.SQLITE_OK) return 0;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
            if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_ROW) return 0;
            return sqlite.sqlite3_column_int(stmt.?, 0);
        }
    }

    pub fn getDueCards(self: *Db, limit: u32, now_ms: i64, buf: []u8) ?[]const u8 {
        return self.getDueCardsFiltered(limit, now_ms, null, buf);
    }

    pub fn getDueCardsFiltered(self: *Db, limit: u32, now_ms: i64, filter: ?[]const u8, buf: []u8) ?[]const u8 {
        var stmt: ?*sqlite.sqlite3_stmt = null;

        const select_cols =
            \\SELECT c.id, c.word, c.language, c.pinyin, c.translation, c.source_type,
            \\       COALESCE(f.difficulty, 5.0), COALESCE(f.stability, 0.0),
            \\       COALESCE(f.reps, 0), COALESCE(f.lapses, 0),
            \\       f.next_review
            \\FROM cards c
            \\LEFT JOIN fsrs_state f ON c.id = f.card_id
        ;
        const where_due =
            \\ WHERE (f.card_id IS NULL OR f.reps = 0 OR f.next_review IS NULL OR CAST(f.next_review AS INTEGER) <= ?) AND COALESCE(c.deleted, 0) = 0
        ;
        const order_limit =
            \\ ORDER BY COALESCE(f.reps, 0) ASC, COALESCE(f.next_review, '0') ASC LIMIT ?
        ;

        const sql_all = select_cols ++ where_due ++ order_limit;
        const sql_lexicon = select_cols ++ where_due ++ " AND c.source_type = 'lexicon'" ++ order_limit;
        const sql_pack = select_cols ++ where_due ++ " AND c.pack_id = ?" ++ order_limit;

        if (filter) |f| {
            if (std.mem.eql(u8, f, "lexicon")) {
                if (sqlite.sqlite3_prepare_v2(self.handle, sql_lexicon, @intCast(sql_lexicon.len), &stmt, null) != sqlite.SQLITE_OK) return null;
                _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
                _ = sqlite.sqlite3_bind_int(stmt.?, 2, @intCast(limit));
            } else {
                if (sqlite.sqlite3_prepare_v2(self.handle, sql_pack, @intCast(sql_pack.len), &stmt, null) != sqlite.SQLITE_OK) return null;
                _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
                _ = sqlite.sqlite3_bind_text(stmt.?, 2, f.ptr, @intCast(f.len), sqlite.SQLITE_STATIC);
                _ = sqlite.sqlite3_bind_int(stmt.?, 3, @intCast(limit));
            }
        } else {
            if (sqlite.sqlite3_prepare_v2(self.handle, sql_all, @intCast(sql_all.len), &stmt, null) != sqlite.SQLITE_OK) return null;
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
            _ = sqlite.sqlite3_bind_int(stmt.?, 2, @intCast(limit));
        }
        defer _ = sqlite.sqlite3_finalize(stmt.?);

        var w = JsonWriter.init(buf);
        w.writeByte('[');
        var count: u32 = 0;

        while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
            if (count > 0) w.writeByte(',');
            count += 1;

            const id = colText(stmt.?, 0);
            const word = colText(stmt.?, 1);
            const lang = colText(stmt.?, 2);
            const pinyin_ptr = sqlite.sqlite3_column_text(stmt.?, 3);
            const trans_ptr = sqlite.sqlite3_column_text(stmt.?, 4);
            const source = colText(stmt.?, 5);
            const difficulty = sqlite.sqlite3_column_double(stmt.?, 6);
            const stability = sqlite.sqlite3_column_double(stmt.?, 7);
            const reps = sqlite.sqlite3_column_int(stmt.?, 8);
            const lapses = sqlite.sqlite3_column_int(stmt.?, 9);

            // Compute schedule for this card
            const state = types.FSRSState{
                .difficulty = difficulty,
                .stability = stability,
                .reps = @intCast(reps),
                .lapses = @intCast(lapses),
            };
            const elapsed: f64 = if (reps == 0) 0.0 else blk: {
                const nr_ptr = sqlite.sqlite3_column_text(stmt.?, 10);
                if (nr_ptr) |nr| {
                    const nr_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 10));
                    const nr_ms = std.fmt.parseInt(i64, nr[0..nr_len], 10) catch 0;
                    break :blk @as(f64, @floatFromInt(now_ms - nr_ms)) / 86400000.0;
                }
                break :blk 0.0;
            };
            const sched = fsrs.schedule(state, elapsed);

            w.writeByte('{');
            w.writeKey("id");
            w.writeJsonString(id);
            w.writeByte(',');
            w.writeKey("word");
            w.writeJsonString(word);
            w.writeByte(',');
            w.writeKey("language");
            w.writeJsonString(lang);
            w.writeByte(',');
            w.writeKey("pinyin");
            if (pinyin_ptr) |p| {
                const plen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 3));
                w.writeJsonString(p[0..plen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("translation");
            if (trans_ptr) |t| {
                const tlen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 4));
                w.writeJsonString(t[0..tlen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("source_type");
            w.writeJsonString(source);
            w.writeByte(',');
            w.writeKey("reps");
            w.writeInt(reps);
            w.writeByte(',');

            // Intervals for rating buttons
            w.writeKey("intervals");
            w.writeByte('{');
            w.writeKey("again");
            w.writeFloat(sched.again.interval_days);
            w.writeByte(',');
            w.writeKey("hard");
            w.writeFloat(sched.hard.interval_days);
            w.writeByte(',');
            w.writeKey("good");
            w.writeFloat(sched.good.interval_days);
            w.writeByte(',');
            w.writeKey("easy");
            w.writeFloat(sched.easy.interval_days);
            w.writeByte('}');

            w.writeByte('}');
        }
        w.writeByte(']');
        return w.written();
    }

    /// SQL LIKE search across cards.word / translation / pinyin.
    /// Returns JSON array. Limits query length to 128 bytes.
    pub fn searchCards(self: *Db, query: []const u8, limit: u32, buf: []u8) ?[]const u8 {
        if (query.len == 0 or query.len > 128) {
            var w0 = JsonWriter.init(buf);
            w0.writeByte('[');
            w0.writeByte(']');
            return w0.written();
        }

        var like_buf: [256]u8 = undefined;
        var prefix_buf: [256]u8 = undefined;
        if (query.len + 2 > like_buf.len) return null;
        like_buf[0] = '%';
        @memcpy(like_buf[1 .. 1 + query.len], query);
        like_buf[1 + query.len] = '%';
        const like_pat = like_buf[0 .. query.len + 2];

        @memcpy(prefix_buf[0..query.len], query);
        prefix_buf[query.len] = '%';
        const prefix_pat = prefix_buf[0 .. query.len + 1];

        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql =
            \\SELECT c.id, c.word, c.language, c.pinyin, c.translation, c.source_type, c.pack_id, c.context
            \\FROM cards c
            \\WHERE COALESCE(c.deleted, 0) = 0
            \\  AND (c.word LIKE ?1 OR c.translation LIKE ?1 OR c.pinyin LIKE ?1 OR c.context LIKE ?1)
            \\ORDER BY
            \\  CASE WHEN c.word = ?2 THEN 0
            \\       WHEN c.word LIKE ?3 THEN 1
            \\       ELSE 2 END,
            \\  c.word
            \\LIMIT ?4
        ;
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return null;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, like_pat.ptr, @intCast(like_pat.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 2, query.ptr, @intCast(query.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 3, prefix_pat.ptr, @intCast(prefix_pat.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_int(stmt.?, 4, @intCast(limit));

        var w = JsonWriter.init(buf);
        w.writeByte('[');
        var count: u32 = 0;
        while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
            if (count > 0) w.writeByte(',');
            count += 1;

            const id = colText(stmt.?, 0);
            const word = colText(stmt.?, 1);
            const language = colText(stmt.?, 2);
            const source = colText(stmt.?, 5);

            w.writeByte('{');
            w.writeKey("id");
            w.writeJsonString(id);
            w.writeByte(',');
            w.writeKey("word");
            w.writeJsonString(word);
            w.writeByte(',');
            w.writeKey("language");
            w.writeJsonString(language);
            w.writeByte(',');
            w.writeKey("pinyin");
            if (sqlite.sqlite3_column_text(stmt.?, 3)) |p| {
                const plen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 3));
                w.writeJsonString(p[0..plen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("translation");
            if (sqlite.sqlite3_column_text(stmt.?, 4)) |t| {
                const tlen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 4));
                w.writeJsonString(t[0..tlen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("source_type");
            w.writeJsonString(source);
            w.writeByte(',');
            w.writeKey("pack_id");
            if (sqlite.sqlite3_column_text(stmt.?, 6)) |pk| {
                const pklen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 6));
                w.writeJsonString(pk[0..pklen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("context");
            if (sqlite.sqlite3_column_text(stmt.?, 7)) |ctx| {
                const ctxlen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 7));
                w.writeJsonString(ctx[0..ctxlen]);
            } else {
                w.writeNull();
            }
            w.writeByte('}');
        }
        w.writeByte(']');
        return w.written();
    }

    /// Return the most recently reviewed card as a single JSON object,
    /// or an empty array `[]` if no reviews exist. Returning an array
    /// keeps the result shape uniform with searchCards — callers treat
    /// it like "the 1-item result of a search". Null-safe pinyin /
    /// translation / pack_id / context fields to match CardSearchResult.
    pub fn getLastReviewedCard(self: *Db, buf: []u8) ?[]const u8 {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql =
            \\SELECT c.id, c.word, c.language, c.pinyin, c.translation, c.source_type, c.pack_id, c.context
            \\FROM cards c
            \\JOIN review_log rl ON rl.card_id = c.id
            \\WHERE COALESCE(c.deleted, 0) = 0
            \\ORDER BY rl.review_date DESC
            \\LIMIT 1
        ;
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return null;
        defer _ = sqlite.sqlite3_finalize(stmt.?);

        var w = JsonWriter.init(buf);
        w.writeByte('[');
        if (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
            const id = colText(stmt.?, 0);
            const word = colText(stmt.?, 1);
            const language = colText(stmt.?, 2);
            const source = colText(stmt.?, 5);

            w.writeByte('{');
            w.writeKey("id");
            w.writeJsonString(id);
            w.writeByte(',');
            w.writeKey("word");
            w.writeJsonString(word);
            w.writeByte(',');
            w.writeKey("language");
            w.writeJsonString(language);
            w.writeByte(',');
            w.writeKey("pinyin");
            if (sqlite.sqlite3_column_text(stmt.?, 3)) |p| {
                const plen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 3));
                w.writeJsonString(p[0..plen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("translation");
            if (sqlite.sqlite3_column_text(stmt.?, 4)) |t| {
                const tlen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 4));
                w.writeJsonString(t[0..tlen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("source_type");
            w.writeJsonString(source);
            w.writeByte(',');
            w.writeKey("pack_id");
            if (sqlite.sqlite3_column_text(stmt.?, 6)) |pk| {
                const pklen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 6));
                w.writeJsonString(pk[0..pklen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("context");
            if (sqlite.sqlite3_column_text(stmt.?, 7)) |ctx| {
                const ctxlen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 7));
                w.writeJsonString(ctx[0..ctxlen]);
            } else {
                w.writeNull();
            }
            w.writeByte('}');
        }
        w.writeByte(']');
        return w.written();
    }

    /// Get cards scheduled in the next `ahead_ms` milliseconds (not yet due).
    /// Returns same JSON format as getDueCardsFiltered for use with review.
    pub fn getUpcomingCards(self: *Db, limit: u32, now_ms: i64, ahead_ms: i64, filter: ?[]const u8, buf: []u8) ?[]const u8 {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const future_ms = now_ms + ahead_ms;

        const select_cols =
            \\SELECT c.id, c.word, c.language, c.pinyin, c.translation, c.source_type,
            \\       COALESCE(f.difficulty, 5.0), COALESCE(f.stability, 0.0),
            \\       COALESCE(f.reps, 0), COALESCE(f.lapses, 0),
            \\       f.next_review
            \\FROM cards c
            \\LEFT JOIN fsrs_state f ON c.id = f.card_id
        ;
        const where_upcoming =
            \\ WHERE f.reps > 0 AND f.next_review IS NOT NULL
            \\   AND CAST(f.next_review AS INTEGER) > ?
            \\   AND CAST(f.next_review AS INTEGER) <= ?
            \\   AND COALESCE(c.deleted, 0) = 0
        ;
        const order_limit =
            \\ ORDER BY CAST(f.next_review AS INTEGER) ASC LIMIT ?
        ;

        const sql_all = select_cols ++ where_upcoming ++ order_limit;
        const sql_lexicon = select_cols ++ where_upcoming ++ " AND c.source_type = 'lexicon'" ++ order_limit;
        const sql_pack = select_cols ++ where_upcoming ++ " AND c.pack_id = ?" ++ order_limit;

        if (filter) |f| {
            if (std.mem.eql(u8, f, "lexicon")) {
                if (sqlite.sqlite3_prepare_v2(self.handle, sql_lexicon, @intCast(sql_lexicon.len), &stmt, null) != sqlite.SQLITE_OK) return null;
                _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
                _ = sqlite.sqlite3_bind_int64(stmt.?, 2, future_ms);
                _ = sqlite.sqlite3_bind_int(stmt.?, 3, @intCast(limit));
            } else {
                if (sqlite.sqlite3_prepare_v2(self.handle, sql_pack, @intCast(sql_pack.len), &stmt, null) != sqlite.SQLITE_OK) return null;
                _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
                _ = sqlite.sqlite3_bind_int64(stmt.?, 2, future_ms);
                _ = sqlite.sqlite3_bind_text(stmt.?, 3, f.ptr, @intCast(f.len), sqlite.SQLITE_STATIC);
                _ = sqlite.sqlite3_bind_int(stmt.?, 4, @intCast(limit));
            }
        } else {
            if (sqlite.sqlite3_prepare_v2(self.handle, sql_all, @intCast(sql_all.len), &stmt, null) != sqlite.SQLITE_OK) return null;
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 2, future_ms);
            _ = sqlite.sqlite3_bind_int(stmt.?, 3, @intCast(limit));
        }
        defer _ = sqlite.sqlite3_finalize(stmt.?);

        // Reuse the same JSON serialization as getDueCardsFiltered
        var w = JsonWriter.init(buf);
        w.writeByte('[');
        var count: u32 = 0;

        while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
            if (count > 0) w.writeByte(',');
            count += 1;

            const id = colText(stmt.?, 0);
            const word = colText(stmt.?, 1);
            const lang = colText(stmt.?, 2);
            const pinyin_ptr = sqlite.sqlite3_column_text(stmt.?, 3);
            const trans_ptr = sqlite.sqlite3_column_text(stmt.?, 4);
            const source = colText(stmt.?, 5);
            const difficulty = sqlite.sqlite3_column_double(stmt.?, 6);
            const stability = sqlite.sqlite3_column_double(stmt.?, 7);
            const reps = sqlite.sqlite3_column_int(stmt.?, 8);
            const lapses = sqlite.sqlite3_column_int(stmt.?, 9);

            const state = types.FSRSState{
                .difficulty = difficulty,
                .stability = stability,
                .reps = @intCast(reps),
                .lapses = @intCast(lapses),
            };
            const elapsed: f64 = blk: {
                const nr_ptr = sqlite.sqlite3_column_text(stmt.?, 10);
                if (nr_ptr) |nr| {
                    const nr_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 10));
                    const nr_ms = std.fmt.parseInt(i64, nr[0..nr_len], 10) catch 0;
                    break :blk @as(f64, @floatFromInt(now_ms - nr_ms)) / 86400000.0;
                }
                break :blk 0.0;
            };
            const sched = fsrs.schedule(state, elapsed);

            w.writeByte('{');
            w.writeKey("id");
            w.writeJsonString(id);
            w.writeByte(',');
            w.writeKey("word");
            w.writeJsonString(word);
            w.writeByte(',');
            w.writeKey("language");
            w.writeJsonString(lang);
            w.writeByte(',');
            w.writeKey("pinyin");
            if (pinyin_ptr) |p| {
                const plen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 3));
                w.writeJsonString(p[0..plen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("translation");
            if (trans_ptr) |t| {
                const tlen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 4));
                w.writeJsonString(t[0..tlen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("source_type");
            w.writeJsonString(source);
            w.writeByte(',');
            w.writeKey("reps");
            w.writeInt(reps);
            w.writeByte(',');

            w.writeKey("intervals");
            w.writeByte('{');
            w.writeKey("again");
            w.writeFloat(sched.again.interval_days);
            w.writeByte(',');
            w.writeKey("hard");
            w.writeFloat(sched.hard.interval_days);
            w.writeByte(',');
            w.writeKey("good");
            w.writeFloat(sched.good.interval_days);
            w.writeByte(',');
            w.writeKey("easy");
            w.writeFloat(sched.easy.interval_days);
            w.writeByte('}');

            w.writeByte('}');
        }
        w.writeByte(']');
        return w.written();
    }

    pub fn reviewCard(self: *Db, card_id: []const u8, rating_int: u8, now_ms: i64) DbError!void {
        const rating = Rating.fromInt(rating_int) orelse return error.InvalidRating;

        // Read current fsrs_state
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const read_sql = "SELECT difficulty, stability, reps, lapses, next_review FROM fsrs_state WHERE card_id=?";
        if (sqlite.sqlite3_prepare_v2(self.handle, read_sql, @intCast(read_sql.len), &stmt, null) != sqlite.SQLITE_OK) {
            return error.PrepareFailed;
        }

        var state = types.FSRSState{};
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, card_id.ptr, @intCast(card_id.len), sqlite.SQLITE_STATIC);
        if (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
            state.difficulty = sqlite.sqlite3_column_double(stmt.?, 0);
            state.stability = sqlite.sqlite3_column_double(stmt.?, 1);
            state.reps = @intCast(sqlite.sqlite3_column_int(stmt.?, 2));
            state.lapses = @intCast(sqlite.sqlite3_column_int(stmt.?, 3));
        }
        _ = sqlite.sqlite3_finalize(stmt.?);

        // Compute elapsed days
        const elapsed: f64 = if (state.reps == 0) 0.0 else blk: {
            // Re-read next_review from the state we already got
            var nr_stmt: ?*sqlite.sqlite3_stmt = null;
            const nr_sql = "SELECT next_review FROM fsrs_state WHERE card_id=?";
            if (sqlite.sqlite3_prepare_v2(self.handle, nr_sql, @intCast(nr_sql.len), &nr_stmt, null) != sqlite.SQLITE_OK) {
                break :blk 0.0;
            }
            defer _ = sqlite.sqlite3_finalize(nr_stmt.?);
            _ = sqlite.sqlite3_bind_text(nr_stmt.?, 1, card_id.ptr, @intCast(card_id.len), sqlite.SQLITE_STATIC);
            if (sqlite.sqlite3_step(nr_stmt.?) == sqlite.SQLITE_ROW) {
                if (sqlite.sqlite3_column_text(nr_stmt.?, 0)) |nr| {
                    const nr_len: usize = @intCast(sqlite.sqlite3_column_bytes(nr_stmt.?, 0));
                    const nr_ms = std.fmt.parseInt(i64, nr[0..nr_len], 10) catch 0;
                    break :blk @as(f64, @floatFromInt(now_ms - nr_ms)) / 86400000.0;
                }
            }
            break :blk 0.0;
        };

        const new_state = fsrs.review(state, rating, elapsed);
        const sched = fsrs.schedule(state, elapsed);
        const interval_days: f64 = switch (rating) {
            .again => sched.again.interval_days,
            .hard => sched.hard.interval_days,
            .good => sched.good.interval_days,
            .easy => sched.easy.interval_days,
        };
        const interval_ms: i64 = @intFromFloat(interval_days * 86400000.0);
        const next_review_ms = now_ms + interval_ms;

        // Format next_review as integer string
        var nr_buf: [24]u8 = undefined;
        const nr_str = intToSlice(next_review_ms, &nr_buf);

        var now_buf: [24]u8 = undefined;
        const now_str = intToSlice(now_ms, &now_buf);

        // Upsert fsrs_state
        {
            var upd: ?*sqlite.sqlite3_stmt = null;
            const upd_sql =
                \\INSERT INTO fsrs_state(card_id, difficulty, stability, reps, lapses, last_review, next_review, updated_at)
                \\VALUES(?, ?, ?, ?, ?, ?, ?, ?)
                \\ON CONFLICT(card_id) DO UPDATE SET
                \\  difficulty=excluded.difficulty, stability=excluded.stability,
                \\  reps=excluded.reps, lapses=excluded.lapses,
                \\  last_review=excluded.last_review, next_review=excluded.next_review,
                \\  updated_at=excluded.updated_at
            ;
            if (sqlite.sqlite3_prepare_v2(self.handle, upd_sql, @intCast(upd_sql.len), &upd, null) != sqlite.SQLITE_OK) {
                return error.PrepareFailed;
            }
            defer _ = sqlite.sqlite3_finalize(upd.?);
            _ = sqlite.sqlite3_bind_text(upd.?, 1, card_id.ptr, @intCast(card_id.len), sqlite.SQLITE_STATIC);
            _ = sqlite.sqlite3_bind_double(upd.?, 2, new_state.difficulty);
            _ = sqlite.sqlite3_bind_double(upd.?, 3, new_state.stability);
            _ = sqlite.sqlite3_bind_int(upd.?, 4, @intCast(new_state.reps));
            _ = sqlite.sqlite3_bind_int(upd.?, 5, @intCast(new_state.lapses));
            _ = sqlite.sqlite3_bind_text(upd.?, 6, now_str.ptr, @intCast(now_str.len), sqlite.SQLITE_STATIC);
            _ = sqlite.sqlite3_bind_text(upd.?, 7, nr_str.ptr, @intCast(nr_str.len), sqlite.SQLITE_STATIC);
            _ = sqlite.sqlite3_bind_int64(upd.?, 8, now_ms);
            if (sqlite.sqlite3_step(upd.?) != sqlite.SQLITE_DONE) return error.StepFailed;
        }

        // Insert review_log
        {
            var log_stmt: ?*sqlite.sqlite3_stmt = null;
            const log_sql =
                \\INSERT INTO review_log(id, card_id, rating, review_date, old_stability, new_stability, updated_at)
                \\VALUES(?, ?, ?, ?, ?, ?, ?)
            ;
            if (sqlite.sqlite3_prepare_v2(self.handle, log_sql, @intCast(log_sql.len), &log_stmt, null) != sqlite.SQLITE_OK) {
                return error.PrepareFailed;
            }
            defer _ = sqlite.sqlite3_finalize(log_stmt.?);

            // Generate review ID: card_id + "_" + now_ms
            var id_buf: [128]u8 = undefined;
            var id_pos: usize = 0;
            for (card_id) |c| {
                if (id_pos < id_buf.len) {
                    id_buf[id_pos] = c;
                    id_pos += 1;
                }
            }
            if (id_pos < id_buf.len) {
                id_buf[id_pos] = '_';
                id_pos += 1;
            }
            for (now_str) |c| {
                if (id_pos < id_buf.len) {
                    id_buf[id_pos] = c;
                    id_pos += 1;
                }
            }
            const review_id = id_buf[0..id_pos];

            _ = sqlite.sqlite3_bind_text(log_stmt.?, 1, review_id.ptr, @intCast(review_id.len), sqlite.SQLITE_STATIC);
            _ = sqlite.sqlite3_bind_text(log_stmt.?, 2, card_id.ptr, @intCast(card_id.len), sqlite.SQLITE_STATIC);
            _ = sqlite.sqlite3_bind_int(log_stmt.?, 3, @intFromEnum(rating));
            _ = sqlite.sqlite3_bind_text(log_stmt.?, 4, now_str.ptr, @intCast(now_str.len), sqlite.SQLITE_STATIC);
            _ = sqlite.sqlite3_bind_double(log_stmt.?, 5, state.stability);
            _ = sqlite.sqlite3_bind_double(log_stmt.?, 6, new_state.stability);
            _ = sqlite.sqlite3_bind_int64(log_stmt.?, 7, now_ms);
            if (sqlite.sqlite3_step(log_stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
        }
    }

    pub fn markCardRead(self: *Db, card_id: []const u8, now_ms: i64) DbError!void {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "UPDATE cards SET first_seen_at = ? WHERE id = ? AND first_seen_at IS NULL";
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) {
            return error.PrepareFailed;
        }
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
        _ = sqlite.sqlite3_bind_text(stmt.?, 2, card_id.ptr, @intCast(card_id.len), sqlite.SQLITE_STATIC);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    pub fn getUnreadCount(self: *Db, filter: ?[]const u8) i32 {
        var stmt: ?*sqlite.sqlite3_stmt = null;

        const sql_all = "SELECT COUNT(*) FROM cards WHERE first_seen_at IS NULL AND COALESCE(deleted, 0) = 0";
        const sql_lexicon = "SELECT COUNT(*) FROM cards WHERE first_seen_at IS NULL AND source_type = 'lexicon' AND COALESCE(deleted, 0) = 0";
        const sql_pack = "SELECT COUNT(*) FROM cards WHERE first_seen_at IS NULL AND pack_id = ? AND COALESCE(deleted, 0) = 0";

        if (filter) |f| {
            if (std.mem.eql(u8, f, "lexicon")) {
                if (sqlite.sqlite3_prepare_v2(self.handle, sql_lexicon, @intCast(sql_lexicon.len), &stmt, null) != sqlite.SQLITE_OK) return 0;
                defer _ = sqlite.sqlite3_finalize(stmt.?);
                if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_ROW) return 0;
                return sqlite.sqlite3_column_int(stmt.?, 0);
            } else {
                if (sqlite.sqlite3_prepare_v2(self.handle, sql_pack, @intCast(sql_pack.len), &stmt, null) != sqlite.SQLITE_OK) return 0;
                defer _ = sqlite.sqlite3_finalize(stmt.?);
                _ = sqlite.sqlite3_bind_text(stmt.?, 1, f.ptr, @intCast(f.len), sqlite.SQLITE_STATIC);
                if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_ROW) return 0;
                return sqlite.sqlite3_column_int(stmt.?, 0);
            }
        } else {
            if (sqlite.sqlite3_prepare_v2(self.handle, sql_all, @intCast(sql_all.len), &stmt, null) != sqlite.SQLITE_OK) return 0;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_ROW) return 0;
            return sqlite.sqlite3_column_int(stmt.?, 0);
        }
    }

    pub fn getUnreadCards(self: *Db, limit: u32, filter: ?[]const u8, buf: []u8) ?[]const u8 {
        var stmt: ?*sqlite.sqlite3_stmt = null;

        const select_cols =
            \\SELECT c.id, c.word, c.language, c.pinyin, c.translation, c.source_type
            \\FROM cards c
            \\WHERE c.first_seen_at IS NULL AND COALESCE(c.deleted, 0) = 0
        ;
        const order_limit = " ORDER BY c.created_at ASC LIMIT ?";

        const sql_all = select_cols ++ order_limit;
        const sql_lexicon = select_cols ++ " AND c.source_type = 'lexicon'" ++ order_limit;
        const sql_pack = select_cols ++ " AND c.pack_id = ?" ++ order_limit;

        if (filter) |f| {
            if (std.mem.eql(u8, f, "lexicon")) {
                if (sqlite.sqlite3_prepare_v2(self.handle, sql_lexicon, @intCast(sql_lexicon.len), &stmt, null) != sqlite.SQLITE_OK) return null;
                _ = sqlite.sqlite3_bind_int(stmt.?, 1, @intCast(limit));
            } else {
                if (sqlite.sqlite3_prepare_v2(self.handle, sql_pack, @intCast(sql_pack.len), &stmt, null) != sqlite.SQLITE_OK) return null;
                _ = sqlite.sqlite3_bind_text(stmt.?, 1, f.ptr, @intCast(f.len), sqlite.SQLITE_STATIC);
                _ = sqlite.sqlite3_bind_int(stmt.?, 2, @intCast(limit));
            }
        } else {
            if (sqlite.sqlite3_prepare_v2(self.handle, sql_all, @intCast(sql_all.len), &stmt, null) != sqlite.SQLITE_OK) return null;
            _ = sqlite.sqlite3_bind_int(stmt.?, 1, @intCast(limit));
        }
        defer _ = sqlite.sqlite3_finalize(stmt.?);

        var w = JsonWriter.init(buf);
        w.writeByte('[');
        var count: u32 = 0;

        while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
            if (count > 0) w.writeByte(',');
            count += 1;

            const id = colText(stmt.?, 0);
            const word = colText(stmt.?, 1);
            const lang = colText(stmt.?, 2);
            const pinyin_ptr = sqlite.sqlite3_column_text(stmt.?, 3);
            const trans_ptr = sqlite.sqlite3_column_text(stmt.?, 4);
            const source = colText(stmt.?, 5);

            w.writeByte('{');
            w.writeKey("id");
            w.writeJsonString(id);
            w.writeByte(',');
            w.writeKey("word");
            w.writeJsonString(word);
            w.writeByte(',');
            w.writeKey("language");
            w.writeJsonString(lang);
            w.writeByte(',');
            w.writeKey("pinyin");
            if (pinyin_ptr) |p| {
                const plen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 3));
                w.writeJsonString(p[0..plen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("translation");
            if (trans_ptr) |t| {
                const tlen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 4));
                w.writeJsonString(t[0..tlen]);
            } else {
                w.writeNull();
            }
            w.writeByte(',');
            w.writeKey("source_type");
            w.writeJsonString(source);
            w.writeByte('}');
        }
        w.writeByte(']');
        return w.written();
    }

    // === Sync: getChangesJson ===

    /// Get all rows changed since `since_ts` as JSON matching the sync contract.
    /// Format: {"rows":[{"table":"cards","id":"...","data":{...},"updated_at":N}, ...]}
    /// Returns bytes written, or null if buffer too small.
    pub fn getChangesJson(self: *Db, since_ts: i64, buf: [*]u8, buf_len: usize) DbError!?usize {
        var pos: usize = 0;

        const hdr = "{\"rows\":[";
        if (pos + hdr.len > buf_len) return null;
        @memcpy(buf[pos .. pos + hdr.len], hdr);
        pos += hdr.len;

        var first = true;

        // --- cards ---
        {
            const sql =
                \\SELECT id, word, language, pinyin, translation, grammar_tags, sentences,
                \\       decomposition, source_type, pack_id, lesson_id, context,
                \\       first_seen_at, created_at, updated_at, COALESCE(deleted, 0)
                \\FROM cards WHERE updated_at >= ?1
            ;
            var stmt: ?*sqlite.sqlite3_stmt = null;
            if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return error.PrepareFailed;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, since_ts);

            while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                if (!first) {
                    if (pos >= buf_len) return null;
                    buf[pos] = ',';
                    pos += 1;
                }

                const id = colText(stmt.?, 0);
                const word = colText(stmt.?, 1);
                const language = colText(stmt.?, 2);
                const pinyin_ptr = sqlite.sqlite3_column_text(stmt.?, 3);
                const pinyin_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 3));
                const trans_ptr = sqlite.sqlite3_column_text(stmt.?, 4);
                const trans_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 4));
                const grammar = colText(stmt.?, 5);
                const sentences = colText(stmt.?, 6);
                const decomp_ptr = sqlite.sqlite3_column_text(stmt.?, 7);
                const decomp_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 7));
                const source = colText(stmt.?, 8);
                const pack_ptr = sqlite.sqlite3_column_text(stmt.?, 9);
                const pack_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 9));
                const lesson_ptr = sqlite.sqlite3_column_text(stmt.?, 10);
                const lesson_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 10));
                const ctx_ptr = sqlite.sqlite3_column_text(stmt.?, 11);
                const ctx_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 11));
                const first_seen = sqlite.sqlite3_column_int64(stmt.?, 12);
                const created = sqlite.sqlite3_column_int64(stmt.?, 13);
                const updated = sqlite.sqlite3_column_int64(stmt.?, 14);
                const deleted = sqlite.sqlite3_column_int(stmt.?, 15);

                var w = JsonWriter.init(buf[pos..buf_len]);
                w.writeStr("{\"table\":\"cards\",\"id\":\"");
                w.writeStr(id);
                w.writeStr("\",\"data\":{");
                w.writeKey("word");
                w.writeJsonString(word);
                w.writeByte(',');
                w.writeKey("language");
                w.writeJsonString(language);
                w.writeByte(',');
                w.writeKey("pinyin");
                if (pinyin_ptr) |p| w.writeJsonString(p[0..pinyin_len]) else w.writeNull();
                w.writeByte(',');
                w.writeKey("translation");
                if (trans_ptr) |t| w.writeJsonString(t[0..trans_len]) else w.writeNull();
                w.writeByte(',');
                w.writeKey("grammar_tags");
                w.writeStr(grammar);
                w.writeByte(',');
                w.writeKey("sentences");
                w.writeStr(sentences);
                w.writeByte(',');
                w.writeKey("decomposition");
                if (decomp_ptr) |d| w.writeJsonString(d[0..decomp_len]) else w.writeNull();
                w.writeByte(',');
                w.writeKey("source_type");
                w.writeJsonString(source);
                w.writeByte(',');
                w.writeKey("pack_id");
                if (pack_ptr) |p| w.writeJsonString(p[0..pack_len]) else w.writeNull();
                w.writeByte(',');
                w.writeKey("lesson_id");
                if (lesson_ptr) |l| w.writeJsonString(l[0..lesson_len]) else w.writeNull();
                w.writeByte(',');
                w.writeKey("context");
                if (ctx_ptr) |ct| w.writeJsonString(ct[0..ctx_len]) else w.writeNull();
                w.writeByte(',');
                w.writeKey("first_seen_at");
                if (sqlite.sqlite3_column_type(stmt.?, 12) != sqlite.SQLITE_NULL) w.writeInt(first_seen) else w.writeNull();
                w.writeByte(',');
                w.writeKey("created_at");
                w.writeInt(created);
                w.writeByte(',');
                w.writeKey("deleted");
                w.writeInt(@as(i64, deleted));
                w.writeStr("},\"updated_at\":");
                w.writeInt(updated);
                w.writeByte('}');

                pos += w.pos;
                first = false;
            }
        }

        // --- fsrs_state ---
        {
            const sql =
                \\SELECT card_id, difficulty, stability, reps, lapses, last_review, next_review, updated_at
                \\FROM fsrs_state WHERE updated_at >= ?1
            ;
            var stmt: ?*sqlite.sqlite3_stmt = null;
            if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return error.PrepareFailed;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, since_ts);

            while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                if (!first) {
                    if (pos >= buf_len) return null;
                    buf[pos] = ',';
                    pos += 1;
                }

                const card_id = colText(stmt.?, 0);
                const difficulty = sqlite.sqlite3_column_double(stmt.?, 1);
                const stability = sqlite.sqlite3_column_double(stmt.?, 2);
                const reps = sqlite.sqlite3_column_int(stmt.?, 3);
                const lapses = sqlite.sqlite3_column_int(stmt.?, 4);
                const last_rev_ptr = sqlite.sqlite3_column_text(stmt.?, 5);
                const last_rev_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 5));
                const next_rev_ptr = sqlite.sqlite3_column_text(stmt.?, 6);
                const next_rev_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 6));
                const updated = sqlite.sqlite3_column_int64(stmt.?, 7);

                var w = JsonWriter.init(buf[pos..buf_len]);
                w.writeStr("{\"table\":\"fsrs_state\",\"id\":\"");
                w.writeStr(card_id);
                w.writeStr("\",\"data\":{");
                w.writeKey("difficulty");
                w.writeFloat(difficulty);
                w.writeByte(',');
                w.writeKey("stability");
                w.writeFloat(stability);
                w.writeByte(',');
                w.writeKey("reps");
                w.writeInt(@as(i64, reps));
                w.writeByte(',');
                w.writeKey("lapses");
                w.writeInt(@as(i64, lapses));
                w.writeByte(',');
                w.writeKey("last_review");
                if (last_rev_ptr) |lr| w.writeJsonString(lr[0..last_rev_len]) else w.writeNull();
                w.writeByte(',');
                w.writeKey("next_review");
                if (next_rev_ptr) |nr| w.writeJsonString(nr[0..next_rev_len]) else w.writeNull();
                w.writeStr("},\"updated_at\":");
                w.writeInt(updated);
                w.writeByte('}');

                pos += w.pos;
                first = false;
            }
        }

        // --- review_log ---
        {
            const sql =
                \\SELECT id, card_id, rating, review_date, time_ms, old_stability, new_stability, updated_at
                \\FROM review_log WHERE updated_at >= ?1
            ;
            var stmt: ?*sqlite.sqlite3_stmt = null;
            if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return error.PrepareFailed;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, since_ts);

            while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                if (!first) {
                    if (pos >= buf_len) return null;
                    buf[pos] = ',';
                    pos += 1;
                }

                const id = colText(stmt.?, 0);
                const card_id = colText(stmt.?, 1);
                const rating = sqlite.sqlite3_column_int(stmt.?, 2);
                const review_date = colText(stmt.?, 3);
                const time_ms = sqlite.sqlite3_column_int64(stmt.?, 4);
                const old_stab = sqlite.sqlite3_column_double(stmt.?, 5);
                const new_stab = sqlite.sqlite3_column_double(stmt.?, 6);
                const updated = sqlite.sqlite3_column_int64(stmt.?, 7);

                var w = JsonWriter.init(buf[pos..buf_len]);
                w.writeStr("{\"table\":\"review_log\",\"id\":\"");
                w.writeStr(id);
                w.writeStr("\",\"data\":{");
                w.writeKey("card_id");
                w.writeJsonString(card_id);
                w.writeByte(',');
                w.writeKey("rating");
                w.writeInt(@as(i64, rating));
                w.writeByte(',');
                w.writeKey("review_date");
                w.writeJsonString(review_date);
                w.writeByte(',');
                w.writeKey("time_ms");
                if (sqlite.sqlite3_column_type(stmt.?, 4) != sqlite.SQLITE_NULL) w.writeInt(time_ms) else w.writeNull();
                w.writeByte(',');
                w.writeKey("old_stability");
                w.writeFloat(old_stab);
                w.writeByte(',');
                w.writeKey("new_stability");
                w.writeFloat(new_stab);
                w.writeStr("},\"updated_at\":");
                w.writeInt(updated);
                w.writeByte('}');

                pos += w.pos;
                first = false;
            }
        }

        // --- packs ---
        {
            const sql =
                \\SELECT id, name, version, language_pair, word_count, installed_at, updated_at, COALESCE(deleted, 0)
                \\FROM packs WHERE updated_at >= ?1
            ;
            var stmt: ?*sqlite.sqlite3_stmt = null;
            if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return error.PrepareFailed;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, since_ts);

            while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                if (!first) {
                    if (pos >= buf_len) return null;
                    buf[pos] = ',';
                    pos += 1;
                }

                const id = colText(stmt.?, 0);
                const name = colText(stmt.?, 1);
                const version = sqlite.sqlite3_column_int(stmt.?, 2);
                const lang_pair = colText(stmt.?, 3);
                const word_count = sqlite.sqlite3_column_int(stmt.?, 4);
                const installed = sqlite.sqlite3_column_int64(stmt.?, 5);
                const updated = sqlite.sqlite3_column_int64(stmt.?, 6);
                const pack_deleted = sqlite.sqlite3_column_int(stmt.?, 7);

                var w = JsonWriter.init(buf[pos..buf_len]);
                w.writeStr("{\"table\":\"packs\",\"id\":\"");
                w.writeStr(id);
                w.writeStr("\",\"data\":{");
                w.writeKey("name");
                w.writeJsonString(name);
                w.writeByte(',');
                w.writeKey("version");
                w.writeInt(@as(i64, version));
                w.writeByte(',');
                w.writeKey("language_pair");
                w.writeJsonString(lang_pair);
                w.writeByte(',');
                w.writeKey("word_count");
                w.writeInt(@as(i64, word_count));
                w.writeByte(',');
                w.writeKey("installed_at");
                w.writeInt(installed);
                w.writeByte(',');
                w.writeKey("deleted");
                w.writeInt(@as(i64, pack_deleted));
                w.writeStr("},\"updated_at\":");
                w.writeInt(updated);
                w.writeByte('}');

                pos += w.pos;
                first = false;
            }
        }

        // --- lessons ---
        {
            const sql =
                \\SELECT id, pack_id, title, sort_order, updated_at
                \\FROM lessons WHERE updated_at >= ?1
            ;
            var stmt: ?*sqlite.sqlite3_stmt = null;
            if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return error.PrepareFailed;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, since_ts);

            while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                if (!first) {
                    if (pos >= buf_len) return null;
                    buf[pos] = ',';
                    pos += 1;
                }

                const id = colText(stmt.?, 0);
                const pack_id = colText(stmt.?, 1);
                const title_ptr = sqlite.sqlite3_column_text(stmt.?, 2);
                const title_len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 2));
                const sort_order = sqlite.sqlite3_column_int(stmt.?, 3);
                const updated = sqlite.sqlite3_column_int64(stmt.?, 4);

                var w = JsonWriter.init(buf[pos..buf_len]);
                w.writeStr("{\"table\":\"lessons\",\"id\":\"");
                w.writeStr(id);
                w.writeStr("\",\"data\":{");
                w.writeKey("pack_id");
                w.writeJsonString(pack_id);
                w.writeByte(',');
                w.writeKey("title");
                if (title_ptr) |t| w.writeJsonString(t[0..title_len]) else w.writeNull();
                w.writeByte(',');
                w.writeKey("sort_order");
                w.writeInt(@as(i64, sort_order));
                w.writeStr("},\"updated_at\":");
                w.writeInt(updated);
                w.writeByte('}');

                pos += w.pos;
                first = false;
            }
        }

        // Close array and object
        const footer = "]}";
        if (pos + footer.len > buf_len) return null;
        @memcpy(buf[pos .. pos + footer.len], footer);
        pos += footer.len;

        return pos;
    }

    // === Sync: applyChanges ===

    /// Apply incoming sync changes (JSON). Returns count of applied rows, or -1 on error.
    pub fn applyChanges(self: *Db, json: []const u8) DbError!i32 {
        const rows_key = "\"rows\"";
        const rows_pos = findInSlice(json, rows_key) orelse return 0;
        var i = rows_pos + rows_key.len;

        // Skip to '['
        while (i < json.len and json[i] != '[') : (i += 1) {}
        if (i >= json.len) return 0;
        i += 1;

        var applied: i32 = 0;

        while (i < json.len) {
            // Skip whitespace/commas
            while (i < json.len and (json[i] == ' ' or json[i] == ',' or json[i] == '\n' or json[i] == '\r' or json[i] == '\t')) : (i += 1) {}
            if (i >= json.len or json[i] == ']') break;
            if (json[i] != '{') break;

            // Find matching closing brace (skip quoted strings)
            const obj_start = i;
            var depth: i32 = 0;
            while (i < json.len) : (i += 1) {
                if (json[i] == '"') {
                    i += 1;
                    while (i < json.len) : (i += 1) {
                        if (json[i] == '\\') {
                            i += 1;
                            continue;
                        }
                        if (json[i] == '"') break;
                    }
                    continue;
                }
                if (json[i] == '{') depth += 1;
                if (json[i] == '}') {
                    depth -= 1;
                    if (depth == 0) {
                        i += 1;
                        break;
                    }
                }
            }
            const obj = json[obj_start..i];

            const table = jsonExtractStringFromSlice(obj, "\"table\"") orelse continue;
            const row_id = jsonExtractStringFromSlice(obj, "\"id\"") orelse continue;
            const updated_at = jsonExtractI64FromSlice(obj, "\"updated_at\"");
            if (updated_at == 0) continue;

            const data_str = extractDataObject(obj) orelse continue;

            if (std.mem.eql(u8, table, "cards")) {
                const local_ts = self.getRowUpdatedAt("cards", row_id);
                if (updated_at <= local_ts) continue;
                self.applyCardChange(row_id, data_str, updated_at) catch continue;
                applied += 1;
            } else if (std.mem.eql(u8, table, "fsrs_state")) {
                const local_ts = self.getRowUpdatedAt("fsrs_state", row_id);
                if (updated_at <= local_ts) continue;
                self.applyFsrsStateChange(row_id, data_str, updated_at) catch continue;
                applied += 1;
            } else if (std.mem.eql(u8, table, "review_log")) {
                const local_ts = self.getRowUpdatedAt("review_log", row_id);
                if (updated_at <= local_ts) continue;
                self.applyReviewLogChange(row_id, data_str, updated_at) catch continue;
                applied += 1;
            } else if (std.mem.eql(u8, table, "packs")) {
                const local_ts = self.getRowUpdatedAt("packs", row_id);
                if (updated_at <= local_ts) continue;
                self.applyPackChange(row_id, data_str, updated_at) catch continue;
                applied += 1;
            } else if (std.mem.eql(u8, table, "lessons")) {
                const local_ts = self.getRowUpdatedAt("lessons", row_id);
                if (updated_at <= local_ts) continue;
                self.applyLessonChange(row_id, data_str, updated_at) catch continue;
                applied += 1;
            }
        }

        return applied;
    }

    fn getRowUpdatedAt(self: *Db, table: []const u8, row_id: []const u8) i64 {
        const sql: [*:0]const u8 = if (std.mem.eql(u8, table, "cards"))
            "SELECT updated_at FROM cards WHERE id = ?"
        else if (std.mem.eql(u8, table, "fsrs_state"))
            "SELECT updated_at FROM fsrs_state WHERE card_id = ?"
        else if (std.mem.eql(u8, table, "review_log"))
            "SELECT updated_at FROM review_log WHERE id = ?"
        else if (std.mem.eql(u8, table, "packs"))
            "SELECT updated_at FROM packs WHERE id = ?"
        else if (std.mem.eql(u8, table, "lessons"))
            "SELECT updated_at FROM lessons WHERE id = ?"
        else
            return 0;

        var stmt: ?*sqlite.sqlite3_stmt = null;
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != sqlite.SQLITE_OK) return 0;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, row_id.ptr, @intCast(row_id.len), sqlite.SQLITE_STATIC);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_ROW) return 0;
        return sqlite.sqlite3_column_int64(stmt.?, 0);
    }

    fn applyCardChange(self: *Db, row_id: []const u8, data: []const u8, updated_at: i64) DbError!void {
        const word = jsonExtractStringFromSlice(data, "\"word\"") orelse return error.ExecFailed;
        const language = jsonExtractStringFromSlice(data, "\"language\"") orelse "zh";
        const pinyin = jsonExtractStringFromSlice(data, "\"pinyin\"");
        const translation = jsonExtractStringFromSlice(data, "\"translation\"");
        const source_type = jsonExtractStringFromSlice(data, "\"source_type\"") orelse "lexicon";
        const pack_id = jsonExtractStringFromSlice(data, "\"pack_id\"");
        const lesson_id = jsonExtractStringFromSlice(data, "\"lesson_id\"");
        const context = jsonExtractStringFromSlice(data, "\"context\"");
        const created_at = jsonExtractI64FromSlice(data, "\"created_at\"");
        const first_seen_at = jsonExtractI64FromSlice(data, "\"first_seen_at\"");
        const card_deleted = jsonExtractI64FromSlice(data, "\"deleted\"");

        const sql =
            \\INSERT OR REPLACE INTO cards
            \\  (id, word, language, pinyin, translation, source_type, pack_id, lesson_id, context, first_seen_at, deleted, created_at, updated_at)
            \\VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ;
        var stmt: ?*sqlite.sqlite3_stmt = null;
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, row_id.ptr, @intCast(row_id.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 2, word.ptr, @intCast(word.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 3, language.ptr, @intCast(language.len), sqlite.SQLITE_STATIC);
        if (pinyin) |p| {
            _ = sqlite.sqlite3_bind_text(stmt.?, 4, p.ptr, @intCast(p.len), sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 4);
        }
        if (translation) |t| {
            _ = sqlite.sqlite3_bind_text(stmt.?, 5, t.ptr, @intCast(t.len), sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 5);
        }
        _ = sqlite.sqlite3_bind_text(stmt.?, 6, source_type.ptr, @intCast(source_type.len), sqlite.SQLITE_STATIC);
        if (pack_id) |p| {
            _ = sqlite.sqlite3_bind_text(stmt.?, 7, p.ptr, @intCast(p.len), sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 7);
        }
        if (lesson_id) |l| {
            _ = sqlite.sqlite3_bind_text(stmt.?, 8, l.ptr, @intCast(l.len), sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 8);
        }
        if (context) |c| {
            _ = sqlite.sqlite3_bind_text(stmt.?, 9, c.ptr, @intCast(c.len), sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 9);
        }
        if (first_seen_at != 0) {
            _ = sqlite.sqlite3_bind_int64(stmt.?, 10, first_seen_at);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 10);
        }
        _ = sqlite.sqlite3_bind_int64(stmt.?, 11, card_deleted);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 12, if (created_at != 0) created_at else updated_at);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 13, updated_at);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    fn applyFsrsStateChange(self: *Db, card_id: []const u8, data: []const u8, updated_at: i64) DbError!void {
        const difficulty = jsonExtractFloatFromSlice(data, "\"difficulty\"");
        const stability = jsonExtractFloatFromSlice(data, "\"stability\"");
        const reps = jsonExtractI64FromSlice(data, "\"reps\"");
        const lapses = jsonExtractI64FromSlice(data, "\"lapses\"");
        const last_review = jsonExtractStringFromSlice(data, "\"last_review\"");
        const next_review = jsonExtractStringFromSlice(data, "\"next_review\"");

        const sql =
            \\INSERT OR REPLACE INTO fsrs_state
            \\  (card_id, difficulty, stability, reps, lapses, last_review, next_review, updated_at)
            \\VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ;
        var stmt: ?*sqlite.sqlite3_stmt = null;
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, card_id.ptr, @intCast(card_id.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_double(stmt.?, 2, difficulty);
        _ = sqlite.sqlite3_bind_double(stmt.?, 3, stability);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 4, reps);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 5, lapses);
        if (last_review) |lr| {
            _ = sqlite.sqlite3_bind_text(stmt.?, 6, lr.ptr, @intCast(lr.len), sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 6);
        }
        if (next_review) |nr| {
            _ = sqlite.sqlite3_bind_text(stmt.?, 7, nr.ptr, @intCast(nr.len), sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 7);
        }
        _ = sqlite.sqlite3_bind_int64(stmt.?, 8, updated_at);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    fn applyReviewLogChange(self: *Db, row_id: []const u8, data: []const u8, updated_at: i64) DbError!void {
        const card_id = jsonExtractStringFromSlice(data, "\"card_id\"") orelse return error.ExecFailed;
        const rating = jsonExtractI64FromSlice(data, "\"rating\"");
        const review_date = jsonExtractStringFromSlice(data, "\"review_date\"") orelse return error.ExecFailed;
        const time_ms = jsonExtractI64FromSlice(data, "\"time_ms\"");
        const old_stab = jsonExtractFloatFromSlice(data, "\"old_stability\"");
        const new_stab = jsonExtractFloatFromSlice(data, "\"new_stability\"");

        const sql =
            \\INSERT OR REPLACE INTO review_log
            \\  (id, card_id, rating, review_date, time_ms, old_stability, new_stability, updated_at)
            \\VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ;
        var stmt: ?*sqlite.sqlite3_stmt = null;
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, row_id.ptr, @intCast(row_id.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 2, card_id.ptr, @intCast(card_id.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 3, rating);
        _ = sqlite.sqlite3_bind_text(stmt.?, 4, review_date.ptr, @intCast(review_date.len), sqlite.SQLITE_STATIC);
        if (time_ms != 0) {
            _ = sqlite.sqlite3_bind_int64(stmt.?, 5, time_ms);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 5);
        }
        _ = sqlite.sqlite3_bind_double(stmt.?, 6, old_stab);
        _ = sqlite.sqlite3_bind_double(stmt.?, 7, new_stab);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 8, updated_at);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    fn applyPackChange(self: *Db, row_id: []const u8, data: []const u8, updated_at: i64) DbError!void {
        const name = jsonExtractStringFromSlice(data, "\"name\"") orelse return error.ExecFailed;
        const version = jsonExtractI64FromSlice(data, "\"version\"");
        const lang_pair = jsonExtractStringFromSlice(data, "\"language_pair\"") orelse "zh-de";
        const word_count = jsonExtractI64FromSlice(data, "\"word_count\"");
        const installed_at = jsonExtractI64FromSlice(data, "\"installed_at\"");
        const pack_deleted = jsonExtractI64FromSlice(data, "\"deleted\"");

        const sql =
            \\INSERT OR REPLACE INTO packs
            \\  (id, name, version, language_pair, word_count, installed_at, deleted, updated_at)
            \\VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ;
        var stmt: ?*sqlite.sqlite3_stmt = null;
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, row_id.ptr, @intCast(row_id.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 2, name.ptr, @intCast(name.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 3, version);
        _ = sqlite.sqlite3_bind_text(stmt.?, 4, lang_pair.ptr, @intCast(lang_pair.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 5, word_count);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 6, if (installed_at != 0) installed_at else updated_at);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 7, pack_deleted);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 8, updated_at);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    fn applyLessonChange(self: *Db, row_id: []const u8, data: []const u8, updated_at: i64) DbError!void {
        const pack_id = jsonExtractStringFromSlice(data, "\"pack_id\"") orelse return error.ExecFailed;
        const title = jsonExtractStringFromSlice(data, "\"title\"");
        const sort_order = jsonExtractI64FromSlice(data, "\"sort_order\"");

        const sql =
            \\INSERT OR REPLACE INTO lessons
            \\  (id, pack_id, title, sort_order, updated_at)
            \\VALUES (?, ?, ?, ?, ?)
        ;
        var stmt: ?*sqlite.sqlite3_stmt = null;
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, row_id.ptr, @intCast(row_id.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 2, pack_id.ptr, @intCast(pack_id.len), sqlite.SQLITE_STATIC);
        if (title) |t| {
            _ = sqlite.sqlite3_bind_text(stmt.?, 3, t.ptr, @intCast(t.len), sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 3);
        }
        _ = sqlite.sqlite3_bind_int64(stmt.?, 4, sort_order);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 5, updated_at);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    /// Hard-delete rows that have been soft-deleted for more than `retention_ms`.
    pub fn vacuumDeleted(self: *Db, now_ms: i64, retention_ms: i64) DbError!i32 {
        const cutoff = now_ms - retention_ms;
        var total: i32 = 0;

        // Delete fsrs_state + review_log for deleted cards
        inline for (.{
            "DELETE FROM review_log WHERE card_id IN (SELECT id FROM cards WHERE deleted = 1 AND updated_at < ?)",
            "DELETE FROM fsrs_state WHERE card_id IN (SELECT id FROM cards WHERE deleted = 1 AND updated_at < ?)",
            "DELETE FROM cards WHERE deleted = 1 AND updated_at < ?",
            "DELETE FROM lessons WHERE pack_id IN (SELECT id FROM packs WHERE deleted = 1 AND updated_at < ?)",
            "DELETE FROM packs WHERE deleted = 1 AND updated_at < ?",
        }) |sql| {
            var stmt: ?*sqlite.sqlite3_stmt = null;
            if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
                return error.PrepareFailed;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, cutoff);
            if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
            total += @intCast(sqlite.sqlite3_changes(self.handle));
        }
        return total;
    }

    fn seed(self: *Db) DbError!void {
        // Lóng neu L5 vocabulary — 25 cards
        const cards = [_]SeedCard{
            .{ .id = "l5_001", .word = "\u{8FC7}", .pinyin = "gu\u{00F2}", .translation = "verbringen, (Zeitdauer)" },
            .{ .id = "l5_002", .word = "\u{5DF2}\u{7ECF}", .pinyin = "y\u{01D0}j\u{012B}ng", .translation = "bereits, schon" },
            .{ .id = "l5_003", .word = "\u{867D}\u{7136}", .pinyin = "su\u{012B}r\u{00E1}n", .translation = "obwohl" },
            .{ .id = "l5_004", .word = "\u{4F46}\u{662F}", .pinyin = "d\u{00E0}nsh\u{00EC}", .translation = "aber, jedoch" },
            .{ .id = "l5_005", .word = "\u{7ECF}\u{5E38}", .pinyin = "j\u{012B}ngch\u{00E1}ng", .translation = "oft, h\u{00E4}ufig" },
            .{ .id = "l5_006", .word = "\u{4E00}\u{8FB9}", .pinyin = "y\u{00EC}bi\u{0101}n", .translation = "gleichzeitig, w\u{00E4}hrenddessen" },
            .{ .id = "l5_007", .word = "\u{7136}\u{540E}", .pinyin = "r\u{00E1}nh\u{00F2}u", .translation = "danach, dann" },
            .{ .id = "l5_008", .word = "\u{4EE5}\u{524D}", .pinyin = "y\u{01D0}qi\u{00E1}n", .translation = "fr\u{00FC}her, vorher" },
            .{ .id = "l5_009", .word = "\u{4EE5}\u{540E}", .pinyin = "y\u{01D0}h\u{00F2}u", .translation = "sp\u{00E4}ter, danach" },
            .{ .id = "l5_010", .word = "\u{6700}\u{8FD1}", .pinyin = "zu\u{00EC}j\u{00EC}n", .translation = "in letzter Zeit, k\u{00FC}rzlich" },
            .{ .id = "l5_011", .word = "\u{7A81}\u{7136}", .pinyin = "t\u{016B}r\u{00E1}n", .translation = "pl\u{00F6}tzlich" },
            .{ .id = "l5_012", .word = "\u{53EF}\u{80FD}", .pinyin = "k\u{011B}n\u{00E9}ng", .translation = "m\u{00F6}glich, vielleicht" },
            .{ .id = "l5_013", .word = "\u{5E94}\u{8BE5}", .pinyin = "y\u{012B}ngg\u{0101}i", .translation = "sollen, sollte" },
            .{ .id = "l5_014", .word = "\u{5FC5}\u{987B}", .pinyin = "b\u{00EC}x\u{016B}", .translation = "m\u{00FC}ssen, unbedingt" },
            .{ .id = "l5_015", .word = "\u{53EA}\u{8981}", .pinyin = "zh\u{01D0}y\u{00E0}o", .translation = "solange, wenn nur" },
            .{ .id = "l5_016", .word = "\u{4E0D}\u{7BA1}", .pinyin = "b\u{00F9}gu\u{01CE}n", .translation = "egal ob, ungeachtet" },
            .{ .id = "l5_017", .word = "\u{5982}\u{679C}", .pinyin = "r\u{00FA}gu\u{01D2}", .translation = "wenn, falls" },
            .{ .id = "l5_018", .word = "\u{56E0}\u{4E3A}", .pinyin = "y\u{012B}nw\u{00E8}i", .translation = "weil, da" },
            .{ .id = "l5_019", .word = "\u{6240}\u{4EE5}", .pinyin = "su\u{01D2}y\u{01D0}", .translation = "deshalb, daher" },
            .{ .id = "l5_020", .word = "\u{4E00}\u{76F4}", .pinyin = "y\u{00EC}zh\u{00ED}", .translation = "immer, st\u{00E4}ndig" },
            .{ .id = "l5_021", .word = "\u{9996}\u{5148}", .pinyin = "sh\u{01D2}uxi\u{0101}n", .translation = "zuerst, zun\u{00E4}chst" },
            .{ .id = "l5_022", .word = "\u{63A5}\u{7740}", .pinyin = "ji\u{0113}zhe", .translation = "anschlie\u{00DF}end, dann" },
            .{ .id = "l5_023", .word = "\u{6700}\u{540E}", .pinyin = "zu\u{00EC}h\u{00F2}u", .translation = "zum Schluss, zuletzt" },
            .{ .id = "l5_024", .word = "\u{5176}\u{5B9E}", .pinyin = "q\u{00ED}sh\u{00ED}", .translation = "eigentlich, tats\u{00E4}chlich" },
            .{ .id = "l5_025", .word = "\u{7279}\u{522B}", .pinyin = "t\u{00E8}bi\u{00E9}", .translation = "besonders, besondere" },
        };

        for (cards) |card| {
            self.insertSeedCard(card) catch continue;
        }
    }

    fn insertSeedCard(self: *Db, card: SeedCard) DbError!void {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql =
            \\INSERT OR IGNORE INTO cards(id, word, language, pinyin, translation, source_type, created_at, updated_at)
            \\VALUES(?, ?, 'zh', ?, ?, 'seed', 0, 0)
        ;
        if (sqlite.sqlite3_prepare_v2(self.handle, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) {
            return error.PrepareFailed;
        }
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, card.id.ptr, @intCast(card.id.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 2, card.word.ptr, @intCast(card.word.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 3, card.pinyin.ptr, @intCast(card.pinyin.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 4, card.translation.ptr, @intCast(card.translation.len), sqlite.SQLITE_STATIC);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }
};

const SeedCard = struct {
    id: []const u8,
    word: []const u8,
    pinyin: []const u8,
    translation: []const u8,
};

fn intToSlice(val: i64, buf: *[24]u8) []const u8 {
    if (val == 0) {
        buf[23] = '0';
        return buf[23..24];
    }
    var v: u64 = if (val < 0) @intCast(-val) else @intCast(val);
    var pos: usize = 24;
    while (v > 0) {
        pos -= 1;
        buf.*[pos] = @intCast('0' + (v % 10));
        v /= 10;
    }
    if (val < 0) {
        pos -= 1;
        buf.*[pos] = '-';
    }
    return buf[pos..24];
}

fn colText(stmt: ?*sqlite.sqlite3_stmt, col: c_int) []const u8 {
    const ptr = sqlite.sqlite3_column_text(stmt.?, col) orelse return "";
    const len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, col));
    return ptr[0..len];
}

// --- JSON parsing helpers for sync ---

fn findInSlice(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (haystack.len < needle.len) return null;
    const limit = haystack.len - needle.len + 1;
    for (0..limit) |i| {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) return i;
    }
    return null;
}

fn jsonExtractStringFromSlice(json: []const u8, key: []const u8) ?[]const u8 {
    const key_pos = findInSlice(json, key) orelse return null;
    var i = key_pos + key.len;
    while (i < json.len and (json[i] == ' ' or json[i] == ':' or json[i] == '\t')) : (i += 1) {}
    if (i >= json.len or json[i] != '"') return null;
    i += 1;
    const start = i;
    while (i < json.len) : (i += 1) {
        if (json[i] == '\\') {
            i += 1;
            continue;
        }
        if (json[i] == '"') break;
    }
    if (i >= json.len) return null;
    return json[start..i];
}

fn jsonExtractI64FromSlice(json: []const u8, key: []const u8) i64 {
    const key_pos = findInSlice(json, key) orelse return 0;
    var i = key_pos + key.len;
    while (i < json.len and (json[i] == ' ' or json[i] == ':' or json[i] == '\t')) : (i += 1) {}
    var negative = false;
    if (i < json.len and json[i] == '-') {
        negative = true;
        i += 1;
    }
    var result: i64 = 0;
    while (i < json.len and json[i] >= '0' and json[i] <= '9') : (i += 1) {
        result = result * 10 + @as(i64, json[i] - '0');
    }
    return if (negative) -result else result;
}

fn jsonExtractFloatFromSlice(json: []const u8, key: []const u8) f64 {
    const key_pos = findInSlice(json, key) orelse return 0.0;
    var i = key_pos + key.len;
    while (i < json.len and (json[i] == ' ' or json[i] == ':' or json[i] == '\t')) : (i += 1) {}
    var negative = false;
    if (i < json.len and json[i] == '-') {
        negative = true;
        i += 1;
    }
    var int_part: f64 = 0.0;
    while (i < json.len and json[i] >= '0' and json[i] <= '9') : (i += 1) {
        int_part = int_part * 10.0 + @as(f64, @floatFromInt(json[i] - '0'));
    }
    var frac_part: f64 = 0.0;
    if (i < json.len and json[i] == '.') {
        i += 1;
        var divisor: f64 = 10.0;
        while (i < json.len and json[i] >= '0' and json[i] <= '9') : (i += 1) {
            frac_part += @as(f64, @floatFromInt(json[i] - '0')) / divisor;
            divisor *= 10.0;
        }
    }
    const result = int_part + frac_part;
    return if (negative) -result else result;
}

fn extractDataObject(obj: []const u8) ?[]const u8 {
    const key = "\"data\"";
    const key_pos = findInSlice(obj, key) orelse return null;
    var j = key_pos + key.len;
    while (j < obj.len and (obj[j] == ' ' or obj[j] == ':' or obj[j] == '\t')) : (j += 1) {}
    if (j >= obj.len or obj[j] != '{') return null;
    const start = j;
    var depth: i32 = 0;
    while (j < obj.len) : (j += 1) {
        if (obj[j] == '"') {
            j += 1;
            while (j < obj.len) : (j += 1) {
                if (obj[j] == '\\') {
                    j += 1;
                    continue;
                }
                if (obj[j] == '"') break;
            }
            continue;
        }
        if (obj[j] == '{') depth += 1;
        if (obj[j] == '}') {
            depth -= 1;
            if (depth == 0) return obj[start .. j + 1];
        }
    }
    return null;
}

const schema_v1: [*:0]const u8 =
    \\CREATE TABLE IF NOT EXISTS cards (
    \\  id            TEXT PRIMARY KEY,
    \\  word          TEXT NOT NULL,
    \\  language      TEXT NOT NULL DEFAULT 'zh',
    \\  pinyin        TEXT,
    \\  translation   TEXT,
    \\  grammar_tags  TEXT DEFAULT '[]',
    \\  sentences     TEXT DEFAULT '[]',
    \\  decomposition TEXT,
    \\  source_type   TEXT NOT NULL DEFAULT 'seed',
    \\  pack_id       TEXT,
    \\  lesson_id     TEXT,
    \\  context       TEXT,
    \\  first_seen_at INTEGER,
    \\  deleted       INTEGER DEFAULT 0,
    \\  created_at    INTEGER NOT NULL,
    \\  updated_at    INTEGER NOT NULL
    \\);
    \\CREATE TABLE IF NOT EXISTS fsrs_state (
    \\  card_id       TEXT PRIMARY KEY REFERENCES cards(id),
    \\  difficulty    REAL NOT NULL DEFAULT 5.0,
    \\  stability     REAL NOT NULL DEFAULT 0.0,
    \\  reps          INTEGER NOT NULL DEFAULT 0,
    \\  lapses        INTEGER NOT NULL DEFAULT 0,
    \\  last_review   TEXT,
    \\  next_review   TEXT,
    \\  updated_at    INTEGER NOT NULL
    \\);
    \\CREATE TABLE IF NOT EXISTS review_log (
    \\  id              TEXT PRIMARY KEY,
    \\  card_id         TEXT NOT NULL REFERENCES cards(id),
    \\  rating          INTEGER NOT NULL,
    \\  review_date     TEXT NOT NULL,
    \\  time_ms         INTEGER,
    \\  old_stability   REAL,
    \\  new_stability   REAL,
    \\  updated_at      INTEGER NOT NULL
    \\);
    \\CREATE TABLE IF NOT EXISTS packs (
    \\  id            TEXT PRIMARY KEY,
    \\  name          TEXT NOT NULL,
    \\  version       INTEGER NOT NULL,
    \\  language_pair TEXT NOT NULL,
    \\  word_count    INTEGER NOT NULL DEFAULT 0,
    \\  installed_at  INTEGER NOT NULL,
    \\  deleted       INTEGER DEFAULT 0,
    \\  updated_at    INTEGER NOT NULL
    \\);
    \\CREATE TABLE IF NOT EXISTS lessons (
    \\  id          TEXT PRIMARY KEY,
    \\  pack_id     TEXT NOT NULL REFERENCES packs(id),
    \\  title       TEXT,
    \\  sort_order  INTEGER NOT NULL,
    \\  updated_at  INTEGER NOT NULL
    \\);
    \\CREATE TABLE IF NOT EXISTS grammar_points (
    \\  id          TEXT PRIMARY KEY,
    \\  pack_id     TEXT,
    \\  explanation TEXT,
    \\  examples    TEXT DEFAULT '[]',
    \\  updated_at  INTEGER NOT NULL
    \\);
    \\CREATE INDEX IF NOT EXISTS idx_cards_language ON cards(language);
    \\CREATE INDEX IF NOT EXISTS idx_cards_pack ON cards(pack_id);
    \\CREATE INDEX IF NOT EXISTS idx_cards_source ON cards(source_type);
    \\CREATE INDEX IF NOT EXISTS idx_fsrs_next ON fsrs_state(next_review);
    \\CREATE INDEX IF NOT EXISTS idx_revlog_card ON review_log(card_id);
    \\CREATE INDEX IF NOT EXISTS idx_revlog_date ON review_log(review_date);
;

// --- Tests (native only) ---

test "schema creation and seed data" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;
    var db = try Db.init(":memory:");
    defer db.close();

    const count = db.getDueCount(0);
    try std.testing.expectEqual(@as(i32, 25), count);
}

test "review reduces due count" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;
    var db = try Db.init(":memory:");
    defer db.close();

    const now: i64 = 1710000000000; // some timestamp
    try db.reviewCard("l5_001", 3, now); // rate "good"

    // Card should no longer be due at the same timestamp
    const count = db.getDueCount(now);
    try std.testing.expectEqual(@as(i32, 24), count);
}

test "searchCards SQL LIKE matches" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;
    var db = try Db.init(":memory:");
    defer db.close();

    const insert = "INSERT INTO cards(id, word, language, translation, context, source_type, created_at, updated_at) VALUES " ++
        "('t1','Apfel','de','apple',NULL,'lexicon',1,1)," ++
        "('t2','Banane','de','banana','Dune chapter 3','lexicon',1,1)," ++
        "('t3','Birne','de','pear',NULL,'lexicon',1,1)";
    try db.exec(insert);

    var buf: [8192]u8 = undefined;
    const json = db.searchCards("Apf", 10, &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, json, "Apfel") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "Banane") == null);

    const json2 = db.searchCards("banana", 10, &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, json2, "Banane") != null);

    // Context-field match: find Banane via its Kindle source "Dune"
    const json3 = db.searchCards("Dune", 10, &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, json3, "Banane") != null);
    try std.testing.expect(std.mem.indexOf(u8, json3, "Apfel") == null);
}

test "getDueCards returns JSON" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;
    var db = try Db.init(":memory:");
    defer db.close();

    var buf: [8192]u8 = undefined;
    const json = db.getDueCards(5, 0, &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expect(json.len > 2); // more than "[]"
    try std.testing.expect(json[0] == '[');
    try std.testing.expect(json[json.len - 1] == ']');
}
