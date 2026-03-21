// CSV/TSV import and export for flashcard data.
//
// Supports Anki "Notes in Plain Text" exports, Quizlet, Memrise, and generic
// tab/comma/semicolon-delimited files. Heuristic column detection by header
// names or positional fallback. Strips HTML tags and [sound:...] references.

const std = @import("std");
const builtin = @import("builtin");
const sqlite = @import("sqlite_c.zig");
const types = @import("types.zig");
const lang = @import("lang.zig");

const JsonWriter = types.JsonWriter;

const CsvError = error{
    PrepareFailed,
    StepFailed,
    EmptyInput,
    NoWordsFound,
};

/// Detect delimiter by scanning the first line for tabs, commas, or semicolons.
fn detectDelimiter(data: []const u8) u8 {
    const first_line_end = std.mem.indexOfScalar(u8, data, '\n') orelse data.len;
    const line = data[0..first_line_end];

    var tabs: usize = 0;
    var commas: usize = 0;
    var semis: usize = 0;
    for (line) |c| {
        switch (c) {
            '\t' => tabs += 1,
            ',' => commas += 1,
            ';' => semis += 1,
            else => {},
        }
    }
    // Tab is Anki default, prefer it
    if (tabs > 0) return '\t';
    if (semis > commas and semis > 0) return ';';
    if (commas > 0) return ',';
    return '\t'; // fallback
}

const ColumnMap = struct {
    word: ?usize = null,
    pinyin: ?usize = null,
    translation: ?usize = null,
};

/// Known header names (case-insensitive matching done in caller).
const word_headers = [_][]const u8{ "word", "hanzi", "front", "chinese", "character", "vocabulary", "term" };
const pinyin_headers = [_][]const u8{ "pinyin", "reading", "pronunciation" };
const translation_headers = [_][]const u8{ "meaning", "english", "back", "deutsch", "definition", "translation" };

fn eqlLower(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        const la: u8 = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
        const lb: u8 = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
        if (la != lb) return false;
    }
    return true;
}

fn matchesAny(field: []const u8, headers: []const []const u8) bool {
    for (headers) |h| {
        if (eqlLower(field, h)) return true;
    }
    return false;
}

/// Try to detect column mapping from header row. Returns null if no known headers found.
fn detectColumns(line: []const u8, delimiter: u8) ?ColumnMap {
    var map = ColumnMap{};
    var col: usize = 0;
    var found: u32 = 0;
    var start: usize = 0;

    var i: usize = 0;
    while (i <= line.len) : (i += 1) {
        if (i == line.len or line[i] == delimiter) {
            const field = trimField(line[start..i]);
            if (matchesAny(field, &word_headers)) {
                map.word = col;
                found += 1;
            } else if (matchesAny(field, &pinyin_headers)) {
                map.pinyin = col;
                found += 1;
            } else if (matchesAny(field, &translation_headers)) {
                map.translation = col;
                found += 1;
            }
            col += 1;
            start = i + 1;
        }
    }

    if (found > 0) return map;
    return null;
}

/// Positional fallback: col 0 = word, col N-1 = translation, col 1 = pinyin (if 3+ cols).
fn positionalColumns(col_count: usize) ColumnMap {
    var map = ColumnMap{};
    map.word = 0;
    if (col_count >= 2) map.translation = col_count - 1;
    if (col_count >= 3) map.pinyin = 1;
    return map;
}

fn trimField(s: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = s.len;
    while (start < end and (s[start] == ' ' or s[start] == '\t' or s[start] == '\r' or s[start] == '"')) : (start += 1) {}
    while (end > start and (s[end - 1] == ' ' or s[end - 1] == '\t' or s[end - 1] == '\r' or s[end - 1] == '"')) : (end -= 1) {}
    return s[start..end];
}

/// Strip HTML tags and [sound:...] references from a field value.
fn stripHtml(input: []const u8, buf: []u8) []const u8 {
    var pos: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        // Strip [sound:...]
        if (i + 7 <= input.len and std.mem.eql(u8, input[i .. i + 7], "[sound:")) {
            while (i < input.len and input[i] != ']') : (i += 1) {}
            if (i < input.len) i += 1; // skip ]
            continue;
        }
        // Strip HTML tags
        if (input[i] == '<') {
            while (i < input.len and input[i] != '>') : (i += 1) {}
            if (i < input.len) i += 1; // skip >
            continue;
        }
        if (pos < buf.len) {
            buf[pos] = input[i];
            pos += 1;
        }
        i += 1;
    }
    return buf[0..pos];
}

/// Count columns in a line.
fn countColumns(line: []const u8, delimiter: u8) usize {
    var count: usize = 1;
    for (line) |c| {
        if (c == delimiter) count += 1;
    }
    return count;
}

/// Get field at column index from a delimited line.
fn getField(line: []const u8, delimiter: u8, col: usize) ?[]const u8 {
    var current: usize = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= line.len) : (i += 1) {
        if (i == line.len or line[i] == delimiter) {
            if (current == col) return trimField(line[start..i]);
            current += 1;
            start = i + 1;
        }
    }
    return null;
}

/// Generate a pack ID from the pack name using FNV hash.
fn makePackId(name: []const u8, buf: *[48]u8) []const u8 {
    const prefix = "csv-";
    @memcpy(buf[0..prefix.len], prefix);
    const hash = std.hash.Fnv1a_32.hash(name);
    const hex = "0123456789abcdef";
    var h = hash;
    for (0..8) |i| {
        buf[prefix.len + 7 - i] = hex[h & 0xf];
        h >>= 4;
    }
    return buf[0 .. prefix.len + 8];
}

/// Generate a card ID from pack_id + word hash.
fn makeCardId(pack_id: []const u8, word: []const u8, buf: *[64]u8) []const u8 {
    var pos: usize = 0;
    const max = buf.len - 9;
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

fn bindText(stmt: *sqlite.sqlite3_stmt, col: c_int, text: []const u8) void {
    _ = sqlite.sqlite3_bind_text(stmt, col, text.ptr, @intCast(text.len), sqlite.SQLITE_STATIC);
}

fn execSql(db: *sqlite.sqlite3, sql: [*:0]const u8) CsvError!void {
    if (sqlite.sqlite3_exec(db, sql, null, null, null) != sqlite.SQLITE_OK)
        return error.StepFailed;
}

fn colText(stmt: ?*sqlite.sqlite3_stmt, col: c_int) []const u8 {
    const ptr = sqlite.sqlite3_column_text(stmt.?, col) orelse return "";
    const len: usize = @intCast(sqlite.sqlite3_column_bytes(stmt.?, col));
    return ptr[0..len];
}

/// Import CSV/TSV data, creating a pack with cards. Returns number of cards imported.
pub fn importCsv(db: *sqlite.sqlite3, csv_data: []const u8, pack_name: []const u8, now_ms: i64) CsvError!u32 {
    if (csv_data.len == 0) return error.EmptyInput;

    const delimiter = detectDelimiter(csv_data);

    // Split into lines
    var lines_start: usize = 0;
    var first_line: []const u8 = "";
    {
        const nl = std.mem.indexOfScalar(u8, csv_data, '\n') orelse csv_data.len;
        first_line = if (nl > 0 and csv_data[nl - 1] == '\r') csv_data[0 .. nl - 1] else csv_data[0..nl];
        lines_start = if (nl < csv_data.len) nl + 1 else csv_data.len;
    }

    // Detect column mapping
    const col_count = countColumns(first_line, delimiter);
    const has_header = detectColumns(first_line, delimiter) != null;
    const columns = if (has_header)
        detectColumns(first_line, delimiter).?
    else
        positionalColumns(col_count);

    const word_col = columns.word orelse 0;
    const data_start = if (has_header) lines_start else 0;

    // Generate pack ID
    var pack_id_buf: [48]u8 = undefined;
    const pack_id = makePackId(pack_name, &pack_id_buf);

    // Begin transaction
    execSql(db, "BEGIN TRANSACTION") catch return error.StepFailed;
    errdefer _ = execSql(db, "ROLLBACK") catch {};

    // Delete existing pack if re-importing
    deletePack(db, pack_id) catch {};

    // Insert pack
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "INSERT INTO packs(id, name, version, language_pair, word_count, installed_at, updated_at) VALUES(?,?,1,'unknown',0,?,?)";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        bindText(stmt.?, 1, pack_id);
        bindText(stmt.?, 2, pack_name);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 3, now_ms);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 4, now_ms);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    // Insert single lesson
    const lesson_id = pack_id; // reuse pack_id as lesson_id for simplicity
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "INSERT INTO lessons(id, pack_id, title, sort_order, updated_at) VALUES(?,?,'Importiert',1,?)";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        bindText(stmt.?, 1, lesson_id);
        bindText(stmt.?, 2, pack_id);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 3, now_ms);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    // Parse and insert cards
    var word_count: u32 = 0;
    var zh_count: u32 = 0;
    var ar_count: u32 = 0;
    var de_count: u32 = 0;
    var html_buf: [1024]u8 = undefined;
    var pos = data_start;

    while (pos < csv_data.len) {
        // Find line end
        const line_end = std.mem.indexOfScalarPos(u8, csv_data, pos, '\n') orelse csv_data.len;
        var line = csv_data[pos..line_end];
        pos = if (line_end < csv_data.len) line_end + 1 else csv_data.len;

        // Strip trailing CR
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];

        // Skip empty lines and comments
        if (line.len == 0) continue;
        if (line[0] == '#') continue;

        // Extract word
        const raw_word = getField(line, delimiter, word_col) orelse continue;
        const word = stripHtml(raw_word, &html_buf);
        if (word.len == 0) continue;

        // Extract pinyin
        var pinyin_buf: [256]u8 = undefined;
        const pinyin: ?[]const u8 = if (columns.pinyin) |pc| blk: {
            const raw = getField(line, delimiter, pc) orelse break :blk null;
            const stripped = stripHtml(raw, &pinyin_buf);
            break :blk if (stripped.len > 0) stripped else null;
        } else null;

        // Extract translation
        var trans_buf: [512]u8 = undefined;
        const translation: ?[]const u8 = if (columns.translation) |tc| blk: {
            const raw = getField(line, delimiter, tc) orelse break :blk null;
            const stripped = stripHtml(raw, &trans_buf);
            break :blk if (stripped.len > 0) stripped else null;
        } else null;

        // Generate card ID
        var card_id_buf: [64]u8 = undefined;
        const card_id = makeCardId(pack_id, word, &card_id_buf);

        // Detect language from word content
        const detected = lang.detect(word);
        const lang_code = detected.code();
        if (detected == .zh) zh_count += 1;
        if (detected == .ar) ar_count += 1;
        if (detected == .de) de_count += 1;

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

    if (word_count == 0) {
        _ = execSql(db, "ROLLBACK") catch {};
        return error.NoWordsFound;
    }

    // Determine dominant language for the pack
    const dominant_lang: []const u8 = if (zh_count >= ar_count and zh_count >= de_count and zh_count > word_count / 3) "zh-de" else if (ar_count >= zh_count and ar_count >= de_count and ar_count > word_count / 3) "ar-en" else if (de_count >= zh_count and de_count >= ar_count and de_count > word_count / 3) "de-en" else "en-en";

    // Update word count and language pair
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "UPDATE packs SET word_count = ?, language_pair = ? WHERE id = ?";
        if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 1, @intCast(word_count));
        bindText(stmt.?, 2, dominant_lang);
        bindText(stmt.?, 3, pack_id);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    execSql(db, "COMMIT") catch return error.StepFailed;
    return word_count;
}

/// Export all cards as tab-separated CSV. Returns the CSV text written into buf.
pub fn exportCsv(db: *sqlite.sqlite3, buf: []u8) ?[]const u8 {
    var stmt: ?*sqlite.sqlite3_stmt = null;
    const sql =
        \\SELECT c.word, c.pinyin, c.translation, c.language, c.source_type
        \\FROM cards c ORDER BY c.created_at
    ;
    if (sqlite.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
        return null;
    defer _ = sqlite.sqlite3_finalize(stmt.?);

    var pos: usize = 0;
    // Write header
    const header = "word\tpinyin\ttranslation\tlanguage\tsource\n";
    if (pos + header.len > buf.len) return null;
    @memcpy(buf[pos..][0..header.len], header);
    pos += header.len;

    while (sqlite.sqlite3_step(stmt.?) == sqlite.SQLITE_ROW) {
        const word = colText(stmt, 0);
        const pinyin = colText(stmt, 1);
        const translation = colText(stmt, 2);
        const language = colText(stmt, 3);
        const source = colText(stmt, 4);

        // Estimate line length: fields + 4 tabs + newline
        const line_len = word.len + pinyin.len + translation.len + language.len + source.len + 5;
        if (pos + line_len > buf.len) break;

        @memcpy(buf[pos..][0..word.len], word);
        pos += word.len;
        buf[pos] = '\t';
        pos += 1;
        @memcpy(buf[pos..][0..pinyin.len], pinyin);
        pos += pinyin.len;
        buf[pos] = '\t';
        pos += 1;
        @memcpy(buf[pos..][0..translation.len], translation);
        pos += translation.len;
        buf[pos] = '\t';
        pos += 1;
        @memcpy(buf[pos..][0..language.len], language);
        pos += language.len;
        buf[pos] = '\t';
        pos += 1;
        @memcpy(buf[pos..][0..source.len], source);
        pos += source.len;
        buf[pos] = '\n';
        pos += 1;
    }

    return buf[0..pos];
}

/// Delete a pack and its associated data (helper for re-import).
fn deletePack(db: *sqlite.sqlite3, pack_id: []const u8) CsvError!void {
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

// --- Tests ---

test "detect delimiter - tab" {
    const data = "word\tpinyin\ttranslation\n你好\tnǐ hǎo\tHallo";
    try std.testing.expectEqual(@as(u8, '\t'), detectDelimiter(data));
}

test "detect delimiter - comma" {
    const data = "word,pinyin,translation\n你好,nǐ hǎo,Hallo";
    try std.testing.expectEqual(@as(u8, ','), detectDelimiter(data));
}

test "detect delimiter - semicolon" {
    const data = "word;pinyin;translation\n你好;nǐ hǎo;Hallo";
    try std.testing.expectEqual(@as(u8, ';'), detectDelimiter(data));
}

test "detect columns from header" {
    const line = "word\tpinyin\ttranslation";
    const map = detectColumns(line, '\t').?;
    try std.testing.expectEqual(@as(usize, 0), map.word.?);
    try std.testing.expectEqual(@as(usize, 1), map.pinyin.?);
    try std.testing.expectEqual(@as(usize, 2), map.translation.?);
}

test "detect columns case insensitive" {
    const line = "Front\tReading\tBack";
    const map = detectColumns(line, '\t').?;
    try std.testing.expectEqual(@as(usize, 0), map.word.?);
    try std.testing.expectEqual(@as(usize, 1), map.pinyin.?);
    try std.testing.expectEqual(@as(usize, 2), map.translation.?);
}

test "positional fallback" {
    const map = positionalColumns(3);
    try std.testing.expectEqual(@as(usize, 0), map.word.?);
    try std.testing.expectEqual(@as(usize, 1), map.pinyin.?);
    try std.testing.expectEqual(@as(usize, 2), map.translation.?);
}

test "strip HTML tags" {
    var buf: [256]u8 = undefined;
    const result = stripHtml("<b>hello</b> world", &buf);
    try std.testing.expectEqualStrings("hello world", result);
}

test "strip sound references" {
    var buf: [256]u8 = undefined;
    const result = stripHtml("hello [sound:file.mp3] world", &buf);
    try std.testing.expectEqualStrings("hello  world", result);
}

test "import CSV with header" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const db_mod = @import("db.zig");
    var db = try db_mod.Db.init(":memory:");
    defer db.close();

    const csv =
        "word\tpinyin\ttranslation\n" ++
        "你好\tnǐ hǎo\tHallo\n" ++
        "谢谢\txièxiè\tDanke\n";

    const count = try importCsv(db.handle, csv, "Test Import", 1000);
    try std.testing.expectEqual(@as(u32, 2), count);
}

test "import CSV without header (positional)" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const db_mod = @import("db.zig");
    var db = try db_mod.Db.init(":memory:");
    defer db.close();

    const csv = "你好\tnǐ hǎo\tHallo\n谢谢\txièxiè\tDanke\n";

    const count = try importCsv(db.handle, csv, "Positional", 1000);
    try std.testing.expectEqual(@as(u32, 2), count);
}

test "import CSV with HTML stripping" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const db_mod = @import("db.zig");
    var db = try db_mod.Db.init(":memory:");
    defer db.close();

    const csv = "word\ttranslation\n<b>你好</b>\tHallo [sound:nihao.mp3]\n";

    const count = try importCsv(db.handle, csv, "HTML Test", 1000);
    try std.testing.expectEqual(@as(u32, 1), count);
}

test "import empty CSV returns error" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const db_mod = @import("db.zig");
    var db = try db_mod.Db.init(":memory:");
    defer db.close();

    const result = importCsv(db.handle, "", "Empty", 1000);
    try std.testing.expectError(error.EmptyInput, result);
}

test "export CSV" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const db_mod = @import("db.zig");
    var db = try db_mod.Db.init(":memory:");
    defer db.close();

    // Import some data first
    const csv = "word\tpinyin\ttranslation\n你好\tnǐ hǎo\tHallo\n";
    _ = try importCsv(db.handle, csv, "Export Test", 1000);

    // Export
    var buf: [4096]u8 = undefined;
    const result = exportCsv(db.handle, &buf) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, result, "word\tpinyin\ttranslation") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "你好") != null);
}
