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
            try self.setMeta("schema_version", "2");
            try self.seed();
        }
        if (version >= 1 and version < 2) {
            try self.exec("ALTER TABLE cards ADD COLUMN first_seen_at INTEGER");
            try self.setMeta("schema_version", "2");
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
        ;
        const sql_lexicon =
            \\SELECT COUNT(*) FROM cards c
            \\LEFT JOIN fsrs_state f ON c.id = f.card_id
            \\WHERE (f.card_id IS NULL OR f.reps = 0 OR f.next_review IS NULL OR CAST(f.next_review AS INTEGER) <= ?)
            \\  AND c.source_type = 'lexicon'
        ;
        const sql_pack =
            \\SELECT COUNT(*) FROM cards c
            \\LEFT JOIN fsrs_state f ON c.id = f.card_id
            \\WHERE (f.card_id IS NULL OR f.reps = 0 OR f.next_review IS NULL OR CAST(f.next_review AS INTEGER) <= ?)
            \\  AND c.pack_id = ?
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
            \\ WHERE (f.card_id IS NULL OR f.reps = 0 OR f.next_review IS NULL OR CAST(f.next_review AS INTEGER) <= ?)
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

        const sql_all = "SELECT COUNT(*) FROM cards WHERE first_seen_at IS NULL";
        const sql_lexicon = "SELECT COUNT(*) FROM cards WHERE first_seen_at IS NULL AND source_type = 'lexicon'";
        const sql_pack = "SELECT COUNT(*) FROM cards WHERE first_seen_at IS NULL AND pack_id = ?";

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
            \\WHERE c.first_seen_at IS NULL
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
