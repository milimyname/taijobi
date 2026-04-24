// Content packs — install/remove curriculum packs, query lessons & progress.
//
// Pack JSON format:
// {
//   "id": "long-neu-l5",
//   "name": "Lóng neu L5",
//   "version": 1,
//   "language_pair": "zh-de",
//   "lessons": [
//     {
//       "id": "long-neu-l5-01",
//       "title": "Im Restaurant",
//       "sort_order": 1,
//       "vocabulary": [
//         { "word": "买", "pinyin": "mǎi", "translation": "kaufen" },
//         ...
//       ]
//     }
//   ]
// }

const std = @import("std");
const builtin = @import("builtin");
const sqlite = @import("sqlite_c.zig");
const types = @import("types.zig");
const lang = @import("lang.zig");

const JsonWriter = types.JsonWriter;

const CurriculumError = error{
    PrepareFailed,
    StepFailed,
    InvalidJson,
    PackNotFound,
};

// --- Simple JSON tokenizer for pack parsing ---
// Extracts string values by key from a flat-ish JSON structure.
// Good enough for our pack format — no nesting ambiguity.

fn jsonStringValue(json: []const u8, key: []const u8) ?[]const u8 {
    // Search for "key":"value" or "key": "value"
    var i: usize = 0;
    while (i + key.len + 3 < json.len) : (i += 1) {
        if (json[i] == '"' and i + 1 + key.len < json.len and
            std.mem.eql(u8, json[i + 1 .. i + 1 + key.len], key) and
            json[i + 1 + key.len] == '"')
        {
            // Found key, skip to value
            var j = i + 2 + key.len;
            // Skip : and whitespace
            while (j < json.len and (json[j] == ':' or json[j] == ' ' or json[j] == '\t')) : (j += 1) {}
            if (j < json.len and json[j] == '"') {
                j += 1; // skip opening quote
                const start = j;
                while (j < json.len and json[j] != '"') : (j += 1) {}
                return json[start..j];
            }
        }
    }
    return null;
}

fn jsonIntValue(json: []const u8, key: []const u8) ?i64 {
    var i: usize = 0;
    while (i + key.len + 3 < json.len) : (i += 1) {
        if (json[i] == '"' and i + 1 + key.len < json.len and
            std.mem.eql(u8, json[i + 1 .. i + 1 + key.len], key) and
            json[i + 1 + key.len] == '"')
        {
            var j = i + 2 + key.len;
            while (j < json.len and (json[j] == ':' or json[j] == ' ' or json[j] == '\t')) : (j += 1) {}
            const start = j;
            while (j < json.len and (json[j] >= '0' and json[j] <= '9')) : (j += 1) {}
            if (j > start) {
                return std.fmt.parseInt(i64, json[start..j], 10) catch null;
            }
        }
    }
    return null;
}

/// Find the next JSON object boundary { ... } starting from pos.
/// Returns the slice containing the object, or null.
fn nextObject(json: []const u8, start: usize) ?struct { obj: []const u8, end: usize } {
    var i = start;
    // Find opening brace
    while (i < json.len and json[i] != '{') : (i += 1) {}
    if (i >= json.len) return null;

    const obj_start = i;
    var depth: i32 = 0;
    var in_string = false;
    while (i < json.len) : (i += 1) {
        if (json[i] == '"' and (i == 0 or json[i - 1] != '\\')) {
            in_string = !in_string;
        } else if (!in_string) {
            if (json[i] == '{') depth += 1;
            if (json[i] == '}') {
                depth -= 1;
                if (depth == 0) {
                    return .{ .obj = json[obj_start .. i + 1], .end = i + 1 };
                }
            }
        }
    }
    return null;
}

/// Find the array value for a given key. Returns the content between [ and ].
fn jsonArrayValue(json: []const u8, key: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i + key.len + 3 < json.len) : (i += 1) {
        if (json[i] == '"' and i + 1 + key.len < json.len and
            std.mem.eql(u8, json[i + 1 .. i + 1 + key.len], key) and
            json[i + 1 + key.len] == '"')
        {
            var j = i + 2 + key.len;
            while (j < json.len and (json[j] == ':' or json[j] == ' ' or json[j] == '\t')) : (j += 1) {}
            if (j < json.len and json[j] == '[') {
                const arr_start = j;
                var depth: i32 = 0;
                var in_string = false;
                while (j < json.len) : (j += 1) {
                    if (json[j] == '"' and (j == 0 or json[j - 1] != '\\')) {
                        in_string = !in_string;
                    } else if (!in_string) {
                        if (json[j] == '[') depth += 1;
                        if (json[j] == ']') {
                            depth -= 1;
                            if (depth == 0) {
                                return json[arr_start .. j + 1];
                            }
                        }
                    }
                }
            }
        }
    }
    return null;
}

/// Install a content pack from JSON. Inserts pack, lessons, and cards in one transaction.
pub fn installPack(db: *sqlite.sqlite3, json: []const u8, now_ms: i64) CurriculumError!void {
    const pack_id = jsonStringValue(json, "id") orelse return error.InvalidJson;
    const pack_name = jsonStringValue(json, "name") orelse return error.InvalidJson;
    const version = jsonIntValue(json, "version") orelse 1;
    const lang_pair = jsonStringValue(json, "language_pair") orelse "zh-de";

    // Begin transaction
    execSql(db, "BEGIN TRANSACTION") catch return error.StepFailed;
    errdefer _ = execSql(db, "ROLLBACK") catch {};

    // Hard-delete existing pack data if upgrading (not soft-delete — we're replacing)
    hardDeletePack(db, pack_id) catch {};

    // Insert pack
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "INSERT INTO packs(id, name, version, language_pair, word_count, installed_at, updated_at) VALUES(?,?,?,?,0,?,?)";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        bindText(stmt.?, 1, pack_id);
        bindText(stmt.?, 2, pack_name);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 3, version);
        bindText(stmt.?, 4, lang_pair);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 5, now_ms);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 6, now_ms);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    // Parse and insert lessons + vocabulary
    const lessons_arr = jsonArrayValue(json, "lessons") orelse {
        // Pack with no lessons — just commit the pack record
        execSql(db, "COMMIT") catch return error.StepFailed;
        return;
    };

    var word_count: i64 = 0;
    var lesson_pos: usize = 0;
    while (nextObject(lessons_arr, lesson_pos)) |lesson_result| {
        const lesson = lesson_result.obj;
        lesson_pos = lesson_result.end;

        const lesson_id = jsonStringValue(lesson, "id") orelse continue;
        const lesson_title = jsonStringValue(lesson, "title");
        const sort_order = jsonIntValue(lesson, "sort_order") orelse 0;

        // Insert lesson
        {
            var stmt: ?*sqlite.sqlite3_stmt = null;
            const sql = "INSERT OR REPLACE INTO lessons(id, pack_id, title, sort_order, updated_at) VALUES(?,?,?,?,?)";
            if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
                return error.PrepareFailed;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            bindText(stmt.?, 1, lesson_id);
            bindText(stmt.?, 2, pack_id);
            if (lesson_title) |t| bindText(stmt.?, 3, t) else _ = sqlite.sqlite3_bind_null(stmt.?, 3);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 4, sort_order);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 5, now_ms);
            if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
        }

        // Parse vocabulary array
        const vocab_arr = jsonArrayValue(lesson, "vocabulary") orelse continue;
        var vocab_pos: usize = 0;
        while (nextObject(vocab_arr, vocab_pos)) |vocab_result| {
            const vocab = vocab_result.obj;
            vocab_pos = vocab_result.end;

            const word = jsonStringValue(vocab, "word") orelse continue;
            const pinyin = jsonStringValue(vocab, "pinyin");
            const translation = jsonStringValue(vocab, "translation");

            // Detect language from the word's script so Arabic / Japanese /
            // German packs don't silently tag every card as Chinese (which
            // would break per-language filtering + pick the wrong TTS voice).
            // Pack-level `language_pair` from the JSON header still wins for
            // the pack row — author's declaration is authoritative there.
            const lang_code = lang.detect(word).code();

            // Generate card ID: pack_id + "_" + word hash
            var id_buf: [64]u8 = undefined;
            const card_id = makeCardId(pack_id, word, &id_buf);

            // Insert card
            {
                var stmt: ?*sqlite.sqlite3_stmt = null;
                const sql =
                    \\INSERT OR IGNORE INTO cards(id, word, language, pinyin, translation, source_type, pack_id, lesson_id, created_at, updated_at)
                    \\VALUES(?, ?, ?, ?, ?, 'pack', ?, ?, ?, ?)
                ;
                if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
                    return error.PrepareFailed;
                defer _ = sqlite.sqlite3_finalize(stmt.?);
                bindText(stmt.?, 1, card_id);
                bindText(stmt.?, 2, word);
                bindText(stmt.?, 3, lang_code);
                if (pinyin) |p| bindText(stmt.?, 4, p) else _ = sqlite.sqlite3_bind_null(stmt.?, 4);
                if (translation) |t| bindText(stmt.?, 5, t) else _ = sqlite.sqlite3_bind_null(stmt.?, 5);
                bindText(stmt.?, 6, pack_id);
                bindText(stmt.?, 7, lesson_id);
                _ = sqlite.sqlite3_bind_int64(stmt.?, 8, now_ms);
                _ = sqlite.sqlite3_bind_int64(stmt.?, 9, now_ms);
                if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
            }
            word_count += 1;
        }
    }

    // Update word count
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "UPDATE packs SET word_count = ? WHERE id = ?";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 1, word_count);
        bindText(stmt.?, 2, pack_id);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    execSql(db, "COMMIT") catch return error.StepFailed;
}

/// Append (or upsert) a single lesson + its vocabulary into an existing pack.
///
/// Non-destructive sibling of `installPack`: does NOT hard-delete the pack
/// first, so earlier lessons and their review state stay intact. Intended for
/// the flow where Claude added a pack, then the user remembers a block of
/// words that belongs in the same pack — calling installPack again would wipe
/// the pack, FSRS state included.
///
/// Behavior:
///   - pack_id must reference an existing, non-deleted pack → else PackNotFound.
///   - Lesson is INSERT OR REPLACE (updating title / sort_order is fine).
///   - Cards are INSERT OR IGNORE (existing cards with the same id are left
///     alone, so scheduler state is preserved).
///   - packs.word_count is recomputed from the current cards table.
pub fn addLessonToPack(
    db: *sqlite.sqlite3,
    pack_id: []const u8,
    lesson_json: []const u8,
    now_ms: i64,
) CurriculumError!void {
    // Verify the pack exists and isn't soft-deleted
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "SELECT 1 FROM packs WHERE id = ? AND COALESCE(deleted, 0) = 0";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        bindText(stmt.?, 1, pack_id);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_ROW) return error.PackNotFound;
    }

    const lesson_id = jsonStringValue(lesson_json, "id") orelse return error.InvalidJson;
    const lesson_title = jsonStringValue(lesson_json, "title");
    const sort_order = jsonIntValue(lesson_json, "sort_order") orelse 0;

    execSql(db, "BEGIN TRANSACTION") catch return error.StepFailed;
    errdefer _ = execSql(db, "ROLLBACK") catch {};

    // Upsert lesson
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "INSERT OR REPLACE INTO lessons(id, pack_id, title, sort_order, updated_at) VALUES(?,?,?,?,?)";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        bindText(stmt.?, 1, lesson_id);
        bindText(stmt.?, 2, pack_id);
        if (lesson_title) |t| bindText(stmt.?, 3, t) else _ = sqlite.sqlite3_bind_null(stmt.?, 3);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 4, sort_order);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 5, now_ms);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    // Insert cards (OR IGNORE preserves existing FSRS state)
    if (jsonArrayValue(lesson_json, "vocabulary")) |vocab_arr| {
        var vocab_pos: usize = 0;
        while (nextObject(vocab_arr, vocab_pos)) |vocab_result| {
            const vocab = vocab_result.obj;
            vocab_pos = vocab_result.end;

            const word = jsonStringValue(vocab, "word") orelse continue;
            const pinyin = jsonStringValue(vocab, "pinyin");
            const translation = jsonStringValue(vocab, "translation");
            const lang_code = lang.detect(word).code();

            var id_buf: [64]u8 = undefined;
            const card_id = makeCardId(pack_id, word, &id_buf);

            var stmt: ?*sqlite.sqlite3_stmt = null;
            const sql =
                \\INSERT OR IGNORE INTO cards(id, word, language, pinyin, translation, source_type, pack_id, lesson_id, created_at, updated_at)
                \\VALUES(?, ?, ?, ?, ?, 'pack', ?, ?, ?, ?)
            ;
            if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
                return error.PrepareFailed;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            bindText(stmt.?, 1, card_id);
            bindText(stmt.?, 2, word);
            bindText(stmt.?, 3, lang_code);
            if (pinyin) |p| bindText(stmt.?, 4, p) else _ = sqlite.sqlite3_bind_null(stmt.?, 4);
            if (translation) |t| bindText(stmt.?, 5, t) else _ = sqlite.sqlite3_bind_null(stmt.?, 5);
            bindText(stmt.?, 6, pack_id);
            bindText(stmt.?, 7, lesson_id);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 8, now_ms);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 9, now_ms);
            if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
        }
    }

    // Recompute pack word_count from current cards
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql =
            \\UPDATE packs
            \\SET word_count = (SELECT COUNT(*) FROM cards WHERE pack_id = ? AND COALESCE(deleted, 0) = 0),
            \\    updated_at = ?
            \\WHERE id = ?
        ;
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        bindText(stmt.?, 1, pack_id);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 2, now_ms);
        bindText(stmt.?, 3, pack_id);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    execSql(db, "COMMIT") catch return error.StepFailed;
}

/// Soft-delete a pack and its cards (sets deleted=1, updated_at=now).
pub fn removePack(db: *sqlite.sqlite3, pack_id: []const u8, now_ms: i64) CurriculumError!void {
    // Soft-delete cards belonging to this pack
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "UPDATE cards SET deleted = 1, updated_at = ? WHERE pack_id = ? AND COALESCE(deleted, 0) = 0";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
        bindText(stmt.?, 2, pack_id);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }
    // Soft-delete pack
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "UPDATE packs SET deleted = 1, updated_at = ? WHERE id = ? AND COALESCE(deleted, 0) = 0";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
        bindText(stmt.?, 2, pack_id);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
        if (sqlite.sqlite3_changes(db) == 0) return error.PackNotFound;
    }
}

/// Get all installed packs as JSON array.
pub fn getPacks(db: *sqlite.sqlite3, buf: []u8) ?[]const u8 {
    var stmt: ?*sqlite.sqlite3_stmt = null;
    const sql = "SELECT id, name, version, language_pair, word_count, installed_at FROM packs WHERE COALESCE(deleted, 0) = 0 ORDER BY installed_at DESC";
    if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
        return null;
    defer _ = sqlite.sqlite3_finalize(stmt.?);

    var w = JsonWriter.init(buf);
    w.writeByte('[');
    var count: u32 = 0;

    while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
        if (count > 0) w.writeByte(',');
        count += 1;

        w.writeByte('{');
        w.writeKey("id");
        w.writeJsonString(colText(stmt.?, 0));
        w.writeByte(',');
        w.writeKey("name");
        w.writeJsonString(colText(stmt.?, 1));
        w.writeByte(',');
        w.writeKey("version");
        w.writeInt(sqlite.sqlite3_column_int(stmt.?, 2));
        w.writeByte(',');
        w.writeKey("language_pair");
        w.writeJsonString(colText(stmt.?, 3));
        w.writeByte(',');
        w.writeKey("word_count");
        w.writeInt(sqlite.sqlite3_column_int(stmt.?, 4));
        w.writeByte('}');
    }
    w.writeByte(']');
    return w.written();
}

/// Get lessons for a pack as JSON array, with progress.
pub fn getLessons(db: *sqlite.sqlite3, pack_id: []const u8, buf: []u8) ?[]const u8 {
    var stmt: ?*sqlite.sqlite3_stmt = null;
    const sql =
        \\SELECT l.id, l.title, l.sort_order,
        \\       COUNT(c.id) as total,
        \\       SUM(CASE WHEN f.reps > 0 AND f.stability > 5.0 THEN 1 ELSE 0 END) as mastered
        \\FROM lessons l
        \\LEFT JOIN cards c ON c.lesson_id = l.id AND COALESCE(c.deleted, 0) = 0
        \\LEFT JOIN fsrs_state f ON f.card_id = c.id
        \\WHERE l.pack_id = ?
        \\GROUP BY l.id
        \\ORDER BY l.sort_order
    ;
    if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
        return null;
    defer _ = sqlite.sqlite3_finalize(stmt.?);
    bindText(stmt.?, 1, pack_id);

    var w = JsonWriter.init(buf);
    w.writeByte('[');
    var count: u32 = 0;

    while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
        if (count > 0) w.writeByte(',');
        count += 1;

        const total = sqlite.sqlite3_column_int(stmt.?, 3);
        const mastered = sqlite.sqlite3_column_int(stmt.?, 4);

        w.writeByte('{');
        w.writeKey("id");
        w.writeJsonString(colText(stmt.?, 0));
        w.writeByte(',');
        w.writeKey("title");
        if (sqlite.sqlite3_column_text(stmt.?, 1)) |t| {
            const tlen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 1));
            w.writeJsonString(t[0..tlen]);
        } else {
            w.writeNull();
        }
        w.writeByte(',');
        w.writeKey("sort_order");
        w.writeInt(sqlite.sqlite3_column_int(stmt.?, 2));
        w.writeByte(',');
        w.writeKey("total");
        w.writeInt(total);
        w.writeByte(',');
        w.writeKey("mastered");
        w.writeInt(mastered);
        w.writeByte('}');
    }
    w.writeByte(']');
    return w.written();
}

/// Get vocabulary for a lesson as JSON array.
pub fn getVocabulary(db: *sqlite.sqlite3, lesson_id: []const u8, offset: u32, limit: u32, buf: []u8) ?[]const u8 {
    var stmt: ?*sqlite.sqlite3_stmt = null;
    const sql =
        \\SELECT c.id, c.word, c.pinyin, c.translation,
        \\       COALESCE(f.reps, 0), COALESCE(f.stability, 0.0)
        \\FROM cards c
        \\LEFT JOIN fsrs_state f ON f.card_id = c.id
        \\WHERE c.lesson_id = ? AND COALESCE(c.deleted, 0) = 0
        \\ORDER BY c.created_at
        \\LIMIT ?2 OFFSET ?3
    ;
    if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
        return null;
    defer _ = sqlite.sqlite3_finalize(stmt.?);
    bindText(stmt.?, 1, lesson_id);
    _ = sqlite.sqlite3_bind_int(stmt.?, 2, @intCast(limit));
    _ = sqlite.sqlite3_bind_int(stmt.?, 3, @intCast(offset));

    var w = JsonWriter.init(buf);
    w.writeByte('[');
    var count: u32 = 0;

    while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
        if (count > 0) w.writeByte(',');
        count += 1;

        w.writeByte('{');
        w.writeKey("id");
        w.writeJsonString(colText(stmt.?, 0));
        w.writeByte(',');
        w.writeKey("word");
        w.writeJsonString(colText(stmt.?, 1));
        w.writeByte(',');
        w.writeKey("pinyin");
        if (sqlite.sqlite3_column_text(stmt.?, 2)) |p| {
            const plen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 2));
            w.writeJsonString(p[0..plen]);
        } else {
            w.writeNull();
        }
        w.writeByte(',');
        w.writeKey("translation");
        if (sqlite.sqlite3_column_text(stmt.?, 3)) |t| {
            const tlen: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, 3));
            w.writeJsonString(t[0..tlen]);
        } else {
            w.writeNull();
        }
        w.writeByte(',');
        w.writeKey("reps");
        w.writeInt(sqlite.sqlite3_column_int(stmt.?, 4));
        w.writeByte(',');
        w.writeKey("stability");
        w.writeFloat(sqlite.sqlite3_column_double(stmt.?, 5));
        w.writeByte('}');
    }
    w.writeByte(']');
    return w.written();
}

/// Get progress for a pack as JSON.
pub fn getProgress(db: *sqlite.sqlite3, pack_id: []const u8, buf: []u8) ?[]const u8 {
    var stmt: ?*sqlite.sqlite3_stmt = null;
    const sql =
        \\SELECT COUNT(c.id),
        \\       SUM(CASE WHEN f.reps > 0 THEN 1 ELSE 0 END),
        \\       SUM(CASE WHEN f.reps > 0 AND f.stability > 5.0 THEN 1 ELSE 0 END)
        \\FROM cards c
        \\LEFT JOIN fsrs_state f ON f.card_id = c.id
        \\WHERE c.pack_id = ? AND COALESCE(c.deleted, 0) = 0
    ;
    if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
        return null;
    defer _ = sqlite.sqlite3_finalize(stmt.?);
    bindText(stmt.?, 1, pack_id);

    if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_ROW) return null;

    var w = JsonWriter.init(buf);
    w.writeByte('{');
    w.writeKey("total");
    w.writeInt(sqlite.sqlite3_column_int(stmt.?, 0));
    w.writeByte(',');
    w.writeKey("reviewed");
    w.writeInt(sqlite.sqlite3_column_int(stmt.?, 1));
    w.writeByte(',');
    w.writeKey("mastered");
    w.writeInt(sqlite.sqlite3_column_int(stmt.?, 2));
    w.writeByte('}');
    return w.written();
}

// --- Helpers ---

fn makeCardId(pack_id: []const u8, word: []const u8, buf: *[64]u8) []const u8 {
    var pos: usize = 0;
    const max = buf.len - 9; // room for "_" + 8 hex chars
    for (pack_id) |c| {
        if (pos >= max) break;
        buf[pos] = c;
        pos += 1;
    }
    buf[pos] = '_';
    pos += 1;
    const hash = std.hash.Fnv1a_32.hash(word);
    const hex = "0123456789abcdef";
    var h = hash;
    for (0..8) |i| {
        buf[pos + 7 - i] = hex[h & 0xf];
        h >>= 4;
    }
    pos += 8;
    return buf[0..pos];
}

/// Restore a soft-deleted pack and its cards (undo deletion).
pub fn restorePack(db: *sqlite.sqlite3, pack_id: []const u8, now_ms: i64) CurriculumError!void {
    // Restore cards
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "UPDATE cards SET deleted = 0, updated_at = ? WHERE pack_id = ? AND deleted = 1";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
        bindText(stmt.?, 2, pack_id);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }
    // Restore pack
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "UPDATE packs SET deleted = 0, updated_at = ? WHERE id = ? AND deleted = 1";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 1, now_ms);
        bindText(stmt.?, 2, pack_id);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
        if (sqlite.sqlite3_changes(db) == 0) return error.PackNotFound;
    }
}

/// Hard-delete a pack and all associated data (for reinstall/upgrade, not user-facing delete).
fn hardDeletePack(db: *sqlite.sqlite3, pack_id: []const u8) CurriculumError!void {
    inline for (.{
        "DELETE FROM fsrs_state WHERE card_id IN (SELECT id FROM cards WHERE pack_id = ?)",
        "DELETE FROM cards WHERE pack_id = ?",
        "DELETE FROM lessons WHERE pack_id = ?",
        "DELETE FROM packs WHERE id = ?",
    }) |sql| {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        bindText(stmt.?, 1, pack_id);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }
}

fn bindText(stmt: *sqlite.sqlite3_stmt, col: c_int, text: []const u8) void {
    _ = sqlite.sqlite3_bind_text(stmt, col, text.ptr, @intCast(text.len), sqlite.SQLITE_STATIC);
}

fn colText(stmt: ?*sqlite.sqlite3_stmt, col: c_int) []const u8 {
    const ptr = sqlite.sqlite3_column_text(stmt.?, col) orelse return "";
    const len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, col));
    return ptr[0..len];
}

fn execSql(db: *sqlite.sqlite3, sql: [*:0]const u8) CurriculumError!void {
    if (sqlite.sqlite3_exec(db, sql, null, null, null) != sqlite.SQLITE_OK)
        return error.StepFailed;
}

// --- Tests ---

test "install and query pack" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const db_mod = @import("db.zig");
    var db = try db_mod.Db.init(":memory:");
    defer db.close();

    const pack_json =
        \\{"id":"test-pack","name":"Test Pack","version":1,"language_pair":"zh-de",
        \\"lessons":[{"id":"test-l1","title":"Lesson 1","sort_order":1,
        \\"vocabulary":[
        \\{"word":"你好","pinyin":"nǐ hǎo","translation":"Hallo"},
        \\{"word":"谢谢","pinyin":"xièxiè","translation":"Danke"}
        \\]}]}
    ;

    try installPack(db.handle, pack_json, 1000);

    // Check packs
    var buf: [4096]u8 = undefined;
    const packs_json = getPacks(db.handle, &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expect(packs_json.len > 2);
    try std.testing.expect(std.mem.indexOf(u8, packs_json, "Test Pack") != null);

    // Check lessons
    const lessons_json = getLessons(db.handle, "test-pack", &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, lessons_json, "Lesson 1") != null);

    // Check vocabulary
    const vocab_json = getVocabulary(db.handle, "test-l1", 0, 200, &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, vocab_json, "nǐ hǎo") != null);

    // Check progress
    const progress_json = getProgress(db.handle, "test-pack", &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, progress_json, "\"total\":2") != null);

    // Remove pack
    try removePack(db.handle, "test-pack", 2000);
    const packs_after = getPacks(db.handle, &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("[]", packs_after);
}
