// Personal lexicon — add words from reading, auto-detect language.
// Chinese words get auto-enriched from CC-CEDICT.

const std = @import("std");
const builtin = @import("builtin");
const sqlite = @import("sqlite_c.zig");
const types = @import("types.zig");
const lang = @import("lang.zig");
const cedict = @import("cedict.zig");
const wiktdict = @import("wiktdict.zig");

const JsonWriter = types.JsonWriter;

pub const LexiconError = error{
    PrepareFailed,
    StepFailed,
    WordEmpty,
    AlreadyExists,
    NotFound,
};

/// Add a single word to the lexicon. Detects language, creates card + fsrs_state.
/// Chinese words are auto-enriched with pinyin + translation from CEDICT.
/// Returns the detected language code.
pub fn addWord(
    db: *sqlite.sqlite3,
    word: []const u8,
    context: ?[]const u8,
    now_ms: i64,
) LexiconError![]const u8 {
    if (word.len == 0) return error.WordEmpty;

    const detected = lang.detect(word);
    var lang_code = detected.code();

    // Auto-enrich from dictionaries. Cross-dict fallback: language detection is
    // heuristic — many German words (e.g. "hinken", "laufen") have no umlauts
    // and don't match German-pattern bigrams, so they're misclassified as en.
    // After the primary lookup misses, try the other Wiktionary dict and
    // correct the language code from the dict that actually hit.
    var pinyin: ?[]const u8 = null;
    var translation: ?[]const u8 = null;
    if (detected == .zh) {
        if (cedict.lookup(word)) |entry| {
            pinyin = entry.pinyin;
            translation = entry.english;
        }
    } else if (detected == .en) {
        if (wiktdict.lookupEn(word)) |entry| {
            translation = entry.definition;
        } else if (wiktdict.lookupDe(word)) |entry| {
            translation = entry.definition;
            lang_code = lang.Language.de.code();
        }
    } else if (detected == .de) {
        if (wiktdict.lookupDe(word)) |entry| {
            translation = entry.definition;
        } else if (wiktdict.lookupEn(word)) |entry| {
            translation = entry.definition;
            lang_code = lang.Language.en.code();
        }
    }

    // Generate ID: "lex_" + first 8 chars of word hash
    var id_buf: [20]u8 = undefined;
    const hash = std.hash.Fnv1a_32.hash(word);
    const id = formatLexId(hash, &id_buf);

    // Insert card
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql =
            \\INSERT OR IGNORE INTO cards(id, word, language, pinyin, translation, source_type, context, created_at, updated_at)
            \\VALUES(?, ?, ?, ?, ?, 'lexicon', ?, ?, ?)
        ;
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) {
            return error.PrepareFailed;
        }
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_text(stmt.?, 1, id.ptr, @intCast(id.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 2, word.ptr, @intCast(word.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt.?, 3, lang_code.ptr, @intCast(lang_code.len), sqlite.SQLITE_STATIC);
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
        if (context) |ctx| {
            _ = sqlite.sqlite3_bind_text(stmt.?, 6, ctx.ptr, @intCast(ctx.len), sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt.?, 6);
        }
        _ = sqlite.sqlite3_bind_int64(stmt.?, 7, now_ms);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 8, now_ms);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;

        // Check if actually inserted (not ignored due to duplicate)
        if (sqlite.sqlite3_changes(db) == 0) return error.AlreadyExists;
    }

    return lang_code;
}

/// Bulk-add words inside one SQLite transaction. Duplicates are counted as
/// "skipped" (not failed). Returns the counts via out-parameters.
///
/// Wrapping the N inserts in a single BEGIN/COMMIT is the whole point — it
/// collapses 100× fsync-style work (and, on the JS side, one OPFS save)
/// into one. This is the critical path for Kindle `My Clippings.txt`
/// imports where you routinely add tens to hundreds of entries at once.
pub fn bulkAddWords(
    db: *sqlite.sqlite3,
    words: []const []const u8,
    now_ms: i64,
    added_out: *u32,
    skipped_out: *u32,
    failed_out: *u32,
) LexiconError!void {
    added_out.* = 0;
    skipped_out.* = 0;
    failed_out.* = 0;

    if (sqlite.sqlite3_exec(db, "BEGIN TRANSACTION", null, null, null) != sqlite.SQLITE_OK) {
        return error.StepFailed;
    }
    errdefer _ = sqlite.sqlite3_exec(db, "ROLLBACK", null, null, null);

    for (words) |word| {
        const trimmed = std.mem.trim(u8, word, " \t\r\n");
        if (trimmed.len == 0) {
            failed_out.* += 1;
            continue;
        }
        _ = addWord(db, trimmed, null, now_ms) catch |err| switch (err) {
            error.AlreadyExists => {
                skipped_out.* += 1;
                continue;
            },
            error.WordEmpty => {
                failed_out.* += 1;
                continue;
            },
            // Prepare/Step failures are fatal — roll back the whole batch.
            error.PrepareFailed, error.StepFailed, error.NotFound => return err,
        };
        added_out.* += 1;
    }

    if (sqlite.sqlite3_exec(db, "COMMIT", null, null, null) != sqlite.SQLITE_OK) {
        return error.StepFailed;
    }
}

/// Soft-delete a lexicon word (sets deleted=1, updated_at=now).
pub fn removeWord(db: *sqlite.sqlite3, card_id: []const u8, now_ms: i64) LexiconError!void {
    var stmt: ?*sqlite.sqlite3_stmt = null;
    const sql = "UPDATE cards SET deleted = 1, updated_at = ? WHERE id = ? AND source_type = 'lexicon' AND COALESCE(deleted, 0) = 0";
    if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) {
        return error.PrepareFailed;
    }
    defer _ = sqlite.sqlite3_finalize(stmt.?);
    _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
    _ = sqlite.sqlite3_bind_text(stmt.?, 2, card_id.ptr, @intCast(card_id.len), sqlite.SQLITE_STATIC);
    if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    if (sqlite.sqlite3_changes(db) == 0) return error.NotFound;
}

/// Update a lexicon word's translation field.
pub fn updateWord(db: *sqlite.sqlite3, card_id: []const u8, translation: []const u8, now_ms: i64) LexiconError!void {
    var stmt: ?*sqlite.sqlite3_stmt = null;
    const sql = "UPDATE cards SET translation = ?, updated_at = ? WHERE id = ? AND source_type = 'lexicon'";
    if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) {
        return error.PrepareFailed;
    }
    defer _ = sqlite.sqlite3_finalize(stmt.?);
    _ = sqlite.sqlite3_bind_text(stmt.?, 1, translation.ptr, @intCast(translation.len), sqlite.SQLITE_STATIC);
    _ = sqlite.sqlite3_bind_int64(stmt.?, 2, now_ms);
    _ = sqlite.sqlite3_bind_text(stmt.?, 3, card_id.ptr, @intCast(card_id.len), sqlite.SQLITE_STATIC);
    if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    if (sqlite.sqlite3_changes(db) == 0) return error.NotFound;
}

/// Get all lexicon words as JSON array.
pub fn getLexicon(db: *sqlite.sqlite3, buf: []u8) ?[]const u8 {
    var stmt: ?*sqlite.sqlite3_stmt = null;
    const sql =
        \\SELECT c.id, c.word, c.language, c.pinyin, c.translation, c.context,
        \\       COALESCE(f.reps, 0), COALESCE(f.stability, 0.0)
        \\FROM cards c
        \\LEFT JOIN fsrs_state f ON c.id = f.card_id
        \\WHERE c.source_type = 'lexicon' AND COALESCE(c.deleted, 0) = 0
        \\ORDER BY c.created_at DESC
    ;
    if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK) {
        return null;
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
        const language = colText(stmt.?, 2);
        const reps = sqlite.sqlite3_column_int(stmt.?, 6);
        const stability = sqlite.sqlite3_column_double(stmt.?, 7);

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
        w.writeKey("context");
        if (sqlite.sqlite3_column_text(stmt.?, 5)) |c| {
            const clen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 5));
            w.writeJsonString(c[0..clen]);
        } else {
            w.writeNull();
        }
        w.writeByte(',');
        w.writeKey("reps");
        w.writeInt(reps);
        w.writeByte(',');
        w.writeKey("stability");
        w.writeFloat(stability);
        w.writeByte('}');
    }
    w.writeByte(']');
    return w.written();
}

/// Get drill stats: cards reviewed today, total reviews, accuracy.
pub fn getDrillStats(db: *sqlite.sqlite3, now_ms: i64, buf: []u8) ?[]const u8 {
    // Today = last 24 hours
    const day_start = now_ms - 86400000;

    var w = JsonWriter.init(buf);
    w.writeByte('{');

    // Reviews today
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "SELECT COUNT(*), SUM(CASE WHEN rating >= 3 THEN 1 ELSE 0 END) FROM review_log WHERE CAST(review_date AS INTEGER) > ?";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) == sqlite.SQLITE_OK) {
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, day_start);
            if (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                const today_count = sqlite.sqlite3_column_int(stmt.?, 0);
                const today_correct = sqlite.sqlite3_column_int(stmt.?, 1);
                w.writeKey("reviewed_today");
                w.writeInt(today_count);
                w.writeByte(',');
                w.writeKey("correct_today");
                w.writeInt(today_correct);
            }
        }
    }

    // Total cards + lexicon count
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "SELECT COUNT(*), SUM(CASE WHEN source_type='lexicon' THEN 1 ELSE 0 END) FROM cards WHERE COALESCE(deleted, 0) = 0";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) == sqlite.SQLITE_OK) {
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            if (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                w.writeByte(',');
                w.writeKey("total_cards");
                w.writeInt(sqlite.sqlite3_column_int(stmt.?, 0));
                w.writeByte(',');
                w.writeKey("lexicon_count");
                w.writeInt(sqlite.sqlite3_column_int(stmt.?, 1));
            }
        }
    }

    w.writeByte('}');
    return w.written();
}

/// Get stats for the dashboard: daily reviews/accuracy, rating distribution, streak.
/// `days` controls how many days of history to include (e.g. 30).
pub fn getStats(db: *sqlite.sqlite3, now_ms: i64, days: u32, buf: []u8) ?[]const u8 {
    const ms_per_day: i64 = 86400000;
    const today_day: i64 = @divTrunc(now_ms, ms_per_day);
    const since_ms = now_ms - @as(i64, @intCast(days)) * ms_per_day;

    var w = JsonWriter.init(buf);
    w.writeByte('{');

    // 1. Daily reviews + accuracy
    w.writeKey("days");
    w.writeByte('[');
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql =
            \\SELECT CAST(CAST(review_date AS INTEGER) / 86400000 AS INTEGER) AS day,
            \\       COUNT(*), SUM(CASE WHEN rating >= 3 THEN 1 ELSE 0 END)
            \\FROM review_log
            \\WHERE CAST(review_date AS INTEGER) > ?
            \\GROUP BY day ORDER BY day
        ;
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) == sqlite.SQLITE_OK) {
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 1, since_ms);
            var count: u32 = 0;
            while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                if (count > 0) w.writeByte(',');
                count += 1;
                const day = sqlite.sqlite3_column_int64(stmt.?, 0);
                const total = sqlite.sqlite3_column_int(stmt.?, 1);
                const correct = sqlite.sqlite3_column_int(stmt.?, 2);
                w.writeByte('{');
                w.writeKey("d");
                w.writeInt(day);
                w.writeByte(',');
                w.writeKey("c");
                w.writeInt(total);
                w.writeByte(',');
                w.writeKey("r");
                w.writeInt(correct);
                w.writeByte('}');
            }
        }
    }
    w.writeByte(']');

    // 2. Rating distribution (all time) — index 0=rating1, 1=rating2, 2=rating3, 3=rating4
    w.writeByte(',');
    w.writeKey("ratings");
    w.writeByte('[');
    {
        var counts = [4]i64{ 0, 0, 0, 0 };
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "SELECT rating, COUNT(*) FROM review_log GROUP BY rating";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) == sqlite.SQLITE_OK) {
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                const rating = sqlite.sqlite3_column_int(stmt.?, 0);
                const cnt = sqlite.sqlite3_column_int64(stmt.?, 1);
                if (rating >= 1 and rating <= 4) {
                    counts[@intCast(rating - 1)] = cnt;
                }
            }
        }
        for (0..4) |i| {
            if (i > 0) w.writeByte(',');
            w.writeInt(counts[i]);
        }
    }
    w.writeByte(']');

    // 3. Streak calculation — distinct review days, descending
    w.writeByte(',');
    {
        var current_streak: i64 = 0;
        var longest_streak: i64 = 0;
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql =
            \\SELECT DISTINCT CAST(CAST(review_date AS INTEGER) / 86400000 AS INTEGER) AS day
            \\FROM review_log ORDER BY day DESC
        ;
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) == sqlite.SQLITE_OK) {
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            var expected_day = today_day;
            var streak: i64 = 0;
            var first = true;

            while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                const day = sqlite.sqlite3_column_int64(stmt.?, 0);
                if (first) {
                    // Allow today or yesterday as streak start
                    if (day == today_day or day == today_day - 1) {
                        streak = 1;
                        expected_day = day - 1;
                    } else {
                        break; // No recent activity
                    }
                    first = false;
                } else {
                    if (day == expected_day) {
                        streak += 1;
                        expected_day = day - 1;
                    } else {
                        break;
                    }
                }
            }
            current_streak = streak;

            // For longest streak, iterate all days ascending
            _ = sqlite.sqlite3_finalize(stmt.?);
            stmt = null;
            const sql2 =
                \\SELECT DISTINCT CAST(CAST(review_date AS INTEGER) / 86400000 AS INTEGER) AS day
                \\FROM review_log ORDER BY day ASC
            ;
            if (sqlite.sqlite3_prepare_v2(db, sql2, @intCast(sql2.len), &stmt, null) == sqlite.SQLITE_OK) {
                var prev_day: i64 = -999;
                var run: i64 = 0;
                while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
                    const day = sqlite.sqlite3_column_int64(stmt.?, 0);
                    if (day == prev_day + 1) {
                        run += 1;
                    } else {
                        run = 1;
                    }
                    if (run > longest_streak) longest_streak = run;
                    prev_day = day;
                }
                _ = sqlite.sqlite3_finalize(stmt.?);
                stmt = null;
            }
        }
        if (longest_streak < current_streak) longest_streak = current_streak;

        w.writeKey("streak");
        w.writeInt(current_streak);
        w.writeByte(',');
        w.writeKey("longest_streak");
        w.writeInt(longest_streak);
    }

    w.writeByte('}');
    return w.written();
}

fn formatLexId(hash: u32, buf: *[20]u8) []const u8 {
    const prefix = "lex_";
    @memcpy(buf[0..4], prefix);
    const hex = "0123456789abcdef";
    var h = hash;
    for (0..8) |i| {
        buf[4 + 7 - i] = hex[h & 0xf];
        h >>= 4;
    }
    return buf[0..12];
}

fn colText(stmt: ?*sqlite.sqlite3_stmt, col: c_int) []const u8 {
    const ptr = sqlite.sqlite3_column_text(stmt.?, col) orelse return "";
    const len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, col));
    return ptr[0..len];
}

// --- Tests ---

test "formatLexId" {
    var buf: [20]u8 = undefined;
    const id = formatLexId(0xDEADBEEF, &buf);
    try std.testing.expectEqualStrings("lex_deadbeef", id);
}

test "addWord and getLexicon" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;
    // Tested via db.zig integration tests
}
