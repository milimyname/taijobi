// .apkg import — extract vocabulary from Anki deck packages.
//
// .apkg = ZIP containing a SQLite database (collection.anki2 or collection.anki21).
// Notes are stored with fields separated by 0x1f (unit separator).
// We parse the ZIP, extract the SQLite bytes, open a temporary DB, query the
// notes table, strip HTML, and create cards in the main database.

const std = @import("std");
const builtin = @import("builtin");
const sqlite = @import("sqlite_c.zig");
const lang = @import("lang.zig");
const zip = std.zip;
const flate = std.compress.flate;
const IoReader = std.Io.Reader;

const FieldMap = struct {
    word: u8 = 0,
    pinyin: u8 = 255, // 255 = not found
    translation: u8 = 1,
};

const MAX_MODELS = 16;

const ModelFieldMaps = struct {
    model_ids: [MAX_MODELS]i64 = undefined,
    maps: [MAX_MODELS]FieldMap = undefined,
    count: u8 = 0,

    fn get(self: *const ModelFieldMaps, mid: i64) FieldMap {
        for (0..self.count) |i| {
            if (self.model_ids[i] == mid) return self.maps[i];
        }
        return FieldMap{}; // default fallback
    }
};

const ApkgError = error{
    PrepareFailed,
    StepFailed,
    InvalidZip,
    DatabaseNotFound,
    DecompressFailed,
    NoNotesFound,
    TempDbFailed,
};

/// Strip HTML tags and [sound:...] / [type:...] references.
fn stripHtml(input: []const u8, buf: []u8) []const u8 {
    var pos: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        // Strip cloze markup: {{c1::text}} or {{c1::text::hint}} → keep text
        if (input[i] == '{' and i + 1 < input.len and input[i + 1] == '{') {
            // Find the :: after cN
            var j = i + 2;
            // Skip "cN::" part
            while (j < input.len and input[j] != ':') : (j += 1) {}
            if (j + 1 < input.len and input[j] == ':' and input[j + 1] == ':') {
                j += 2; // skip ::
                // Copy the answer text until }} or ::
                while (j < input.len) {
                    if (j + 1 < input.len and input[j] == '}' and input[j + 1] == '}') {
                        i = j + 2;
                        break;
                    }
                    if (j + 1 < input.len and input[j] == ':' and input[j + 1] == ':') {
                        // Skip hint part until }}
                        j += 2;
                        while (j + 1 < input.len) : (j += 1) {
                            if (input[j] == '}' and input[j + 1] == '}') {
                                j += 2;
                                break;
                            }
                        }
                        i = j;
                        break;
                    }
                    if (pos < buf.len) {
                        buf[pos] = input[j];
                        pos += 1;
                    }
                    j += 1;
                }
                continue;
            }
        }
        // Strip [sound:...] and [type:...]
        if (input[i] == '[' and i + 1 < input.len) {
            const rest = input[i..];
            if (startsWith(rest, "[sound:") or startsWith(rest, "[type:")) {
                while (i < input.len and input[i] != ']') : (i += 1) {}
                if (i < input.len) i += 1;
                continue;
            }
        }
        // Strip HTML tags
        if (input[i] == '<') {
            while (i < input.len and input[i] != '>') : (i += 1) {}
            if (i < input.len) i += 1;
            continue;
        }
        // Convert &nbsp; and common entities
        if (input[i] == '&' and i + 1 < input.len) {
            const rest = input[i..];
            if (startsWith(rest, "&nbsp;")) {
                if (pos < buf.len) {
                    buf[pos] = ' ';
                    pos += 1;
                }
                i += 6;
                continue;
            } else if (startsWith(rest, "&amp;")) {
                if (pos < buf.len) {
                    buf[pos] = '&';
                    pos += 1;
                }
                i += 5;
                continue;
            } else if (startsWith(rest, "&lt;")) {
                if (pos < buf.len) {
                    buf[pos] = '<';
                    pos += 1;
                }
                i += 4;
                continue;
            } else if (startsWith(rest, "&gt;")) {
                if (pos < buf.len) {
                    buf[pos] = '>';
                    pos += 1;
                }
                i += 4;
                continue;
            } else if (startsWith(rest, "&quot;")) {
                if (pos < buf.len) {
                    buf[pos] = '"';
                    pos += 1;
                }
                i += 6;
                continue;
            }
        }
        // Pass through multi-byte UTF-8 sequences intact
        if (input[i] >= 0xC0) {
            // Lead byte: determine sequence length
            const seq_len: usize = if (input[i] >= 0xF0) 4 else if (input[i] >= 0xE0) 3 else 2;
            const end_idx = @min(i + seq_len, input.len);
            while (i < end_idx) : (i += 1) {
                if (pos < buf.len) {
                    buf[pos] = input[i];
                    pos += 1;
                }
            }
            continue;
        } else if (input[i] >= 0x80) {
            // Stray continuation byte (not preceded by lead byte) — skip
            i += 1;
            continue;
        }
        if (pos < buf.len) {
            buf[pos] = input[i];
            pos += 1;
        }
        i += 1;
    }
    // Trim whitespace
    var start: usize = 0;
    var end: usize = pos;
    while (start < end and (buf[start] == ' ' or buf[start] == '\t' or buf[start] == '\n' or buf[start] == '\r')) : (start += 1) {}
    while (end > start and (buf[end - 1] == ' ' or buf[end - 1] == '\t' or buf[end - 1] == '\n' or buf[end - 1] == '\r')) : (end -= 1) {}
    return buf[start..end];
}

fn startsWith(haystack: []const u8, needle: []const u8) bool {
    if (haystack.len < needle.len) return false;
    return std.mem.eql(u8, haystack[0..needle.len], needle);
}

/// Find the SQLite database inside a ZIP archive. Returns the decompressed bytes.
/// Looks for collection.anki21, collection.anki2, or any .anki2/.anki21 file.
fn extractSqliteFromZip(zip_data: []const u8, out_buf: []u8) ApkgError![]const u8 {
    // ZIP end of central directory is at the end of the file.
    // Search backwards for the EOCD signature: PK\x05\x06
    if (zip_data.len < 22) return error.InvalidZip;

    // Scan local file headers from the start (simpler for our case)
    var offset: usize = 0;
    while (offset + @sizeOf(zip.LocalFileHeader) < zip_data.len) {
        const header_bytes = zip_data[offset..][0..@sizeOf(zip.LocalFileHeader)];
        const header: *const zip.LocalFileHeader = @ptrCast(@alignCast(header_bytes.ptr));

        if (!std.mem.eql(u8, &header.signature, &zip.local_file_header_sig))
            break;

        const name_start = offset + @sizeOf(zip.LocalFileHeader);
        const name_end = name_start + header.filename_len;
        if (name_end > zip_data.len) return error.InvalidZip;

        const filename = zip_data[name_start..name_end];
        const data_start = name_end + header.extra_len;
        const data_end = data_start + header.compressed_size;
        if (data_end > zip_data.len) return error.InvalidZip;

        const compressed_data = zip_data[data_start..data_end];

        // Check if this is the SQLite database
        const is_db = endsWith(filename, "collection.anki21") or
            endsWith(filename, "collection.anki2") or
            endsWith(filename, ".anki21") or
            endsWith(filename, ".anki2");

        if (is_db) {
            const uncompressed_size: usize = @intCast(header.uncompressed_size);
            if (uncompressed_size > out_buf.len) return error.DecompressFailed;

            switch (header.compression_method) {
                .store => {
                    // No compression — direct copy
                    if (compressed_data.len > out_buf.len) return error.DecompressFailed;
                    @memcpy(out_buf[0..compressed_data.len], compressed_data);
                    return out_buf[0..compressed_data.len];
                },
                .deflate => {
                    var input: IoReader = .fixed(compressed_data);
                    var window_buf: [flate.max_window_len]u8 = undefined;
                    var decompressor = flate.Decompress.init(&input, .raw, &window_buf);
                    const n = decompressor.reader.readSliceShort(out_buf) catch return error.DecompressFailed;
                    return out_buf[0..n];
                },
                _ => return error.DecompressFailed,
            }
        }

        // Move to next local file header
        offset = data_end;
    }

    return error.DatabaseNotFound;
}

fn endsWith(haystack: []const u8, needle: []const u8) bool {
    if (haystack.len < needle.len) return false;
    return std.mem.eql(u8, haystack[haystack.len - needle.len ..], needle);
}

/// Detect field mappings for all models in Anki's models JSON.
/// Models JSON: {"1234":{"flds":[{"name":"中文"},...],...}, "5678":{...}}
/// Returns a mapping per model ID so each note type gets correct field indices.
fn detectFieldMaps(models_json: []const u8) ModelFieldMaps {
    var result = ModelFieldMaps{};

    // Iterate top-level keys (model IDs). Format: "digits" : { ... }
    var i: usize = 0;
    while (i < models_json.len and result.count < MAX_MODELS) {
        // Find next quoted model ID (digits)
        while (i < models_json.len and models_json[i] != '"') : (i += 1) {}
        if (i >= models_json.len) break;
        i += 1; // skip "
        const id_start = i;
        while (i < models_json.len and models_json[i] != '"') : (i += 1) {}
        if (i >= models_json.len) break;
        const id_str = models_json[id_start..i];
        i += 1; // skip "

        // Try to parse as integer (model ID)
        const mid = std.fmt.parseInt(i64, id_str, 10) catch {
            continue;
        };

        // Find the next "flds" array for this model
        const flds_marker = "\"flds\"";
        const flds_pos = std.mem.indexOfPos(u8, models_json, i, flds_marker) orelse break;
        i = flds_pos;

        const map = detectFieldMapFromFlds(models_json[i..]);
        result.model_ids[result.count] = mid;
        result.maps[result.count] = map;
        result.count += 1;

        // Skip past this model's flds array
        i += flds_marker.len;
    }

    return result;
}

/// Parse a single "flds" array to build a FieldMap.
fn detectFieldMapFromFlds(json: []const u8) FieldMap {

    // Known field names for each role (case-insensitive matching)
    const word_names = [_][]const u8{
        // CJK field names
        "\xe4\xb8\xad\xe6\x96\x87", // 中文
        "\xe6\xb1\x89\xe5\xad\x97", // 汉字
        "hanzi",
        "word",
        "front",
        "chinese",
        "character",
        "term",
        "vocabulary",
        "expression",
        "sentence",
        "question",
        "text",
    };
    const pinyin_names = [_][]const u8{
        "pinyin", "reading", "pronunciation", "romanization",
    };
    const translation_names = [_][]const u8{
        "english", "meaning", "back",        "deutsch", "definition", "translation",
        "answer",  "german",  "explanation", "extra",
    };

    // json starts at "flds" — find the [ to start the array
    const flds_marker = "\"flds\"";
    const flds_pos = std.mem.indexOf(u8, json, flds_marker) orelse return FieldMap{};

    var i = flds_pos + flds_marker.len;
    while (i < json.len and json[i] != '[') : (i += 1) {}
    if (i >= json.len) return FieldMap{};

    // Parse field names: look for "name":"..." patterns inside the flds array
    var field_idx: u8 = 0;
    var result = FieldMap{};
    var depth: i32 = 0;

    while (i < json.len) : (i += 1) {
        if (json[i] == '[') depth += 1;
        if (json[i] == ']') {
            depth -= 1;
            if (depth <= 0) break;
        }

        // Look for "name" : "value"
        if (i + 7 < json.len and std.mem.eql(u8, json[i .. i + 6], "\"name\"")) {
            var j = i + 6;
            while (j < json.len and (json[j] == ':' or json[j] == ' ' or json[j] == '\t')) : (j += 1) {}
            if (j < json.len and json[j] == '"') {
                j += 1;
                const name_start = j;
                while (j < json.len and json[j] != '"') : (j += 1) {}
                const name = json[name_start..j];

                // Match against known field names
                for (word_names) |wn| {
                    if (eqlLowerOrExact(name, wn)) {
                        result.word = field_idx;
                        break;
                    }
                }
                for (pinyin_names) |pn| {
                    if (eqlLowerOrExact(name, pn)) {
                        result.pinyin = field_idx;
                        break;
                    }
                }
                for (translation_names) |tn| {
                    if (eqlLowerOrExact(name, tn)) {
                        result.translation = field_idx;
                        break;
                    }
                }

                field_idx += 1;
                i = j;
            }
        }
    }

    return result;
}

/// Case-insensitive comparison for ASCII, or exact match for non-ASCII (CJK).
fn eqlLowerOrExact(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    // If either contains non-ASCII, do exact match
    for (a) |c| {
        if (c > 127) return std.mem.eql(u8, a, b);
    }
    // ASCII case-insensitive
    for (a, b) |ca, cb| {
        const la: u8 = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
        const lb: u8 = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
        if (la != lb) return false;
    }
    return true;
}

fn bindText(stmt: *sqlite.sqlite3_stmt, col: c_int, text: []const u8) void {
    _ = sqlite.sqlite3_bind_text(stmt, col, text.ptr, @intCast(text.len), sqlite.SQLITE_STATIC);
}

fn execSql(db: *sqlite.sqlite3, sql: [*:0]const u8) ApkgError!void {
    if (sqlite.sqlite3_exec(db, sql, null, null, null) != sqlite.SQLITE_OK)
        return error.StepFailed;
}

/// Generate a pack ID from pack name.
fn makePackId(name: []const u8, buf: *[48]u8) []const u8 {
    const prefix = "apkg-";
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

/// Import an .apkg file. Extracts the SQLite DB from the ZIP, reads the notes
/// table, strips HTML, and creates cards in the main database.
pub fn importApkg(main_db: *sqlite.sqlite3, apkg_data: []const u8, pack_name: []const u8, now_ms: i64, scratch: []u8) ApkgError!u32 {
    // Extract SQLite bytes from ZIP
    const db_bytes = try extractSqliteFromZip(apkg_data, scratch);

    // Load into WASM VFS as a temp file, or write to temp path for native
    const tmp_name = "_anki_tmp.db";
    const is_wasm = builtin.cpu.arch == .wasm32;

    if (is_wasm) {
        // Load into the WASM VFS
        const rc = sqlite.wasm_vfs.wasm_vfs_load_db(tmp_name, db_bytes.ptr, @intCast(db_bytes.len));
        if (rc != 0) return error.TempDbFailed;
    }

    // Open the Anki database
    var anki_db: ?*sqlite.sqlite3 = null;
    const open_path: [*:0]const u8 = if (is_wasm) tmp_name else ":memory:";
    if (sqlite.sqlite3_open(open_path, &anki_db) != sqlite.SQLITE_OK)
        return error.TempDbFailed;
    defer _ = sqlite.sqlite3_close(anki_db.?);

    // For native (tests), load via backup API or deserialize
    if (!is_wasm) {
        // On native with :memory:, we need to load the bytes somehow.
        // Use the SQL interface to attach and load — actually simplest is to
        // just write bytes and re-open. For tests, write to a temp file.
        _ = sqlite.sqlite3_close(anki_db.?);
        anki_db = null;

        // Write temp file
        const tmp_path: [*:0]const u8 = "/tmp/_anki_test_tmp.db";
        if (builtin.target.os.tag != .freestanding) {
            const file = std.fs.cwd().createFileZ(tmp_path, .{}) catch return error.TempDbFailed;
            file.writeAll(db_bytes) catch {
                file.close();
                return error.TempDbFailed;
            };
            file.close();
        }

        if (sqlite.sqlite3_open(tmp_path, &anki_db) != sqlite.SQLITE_OK)
            return error.TempDbFailed;
    }

    // Read model field names from col.models to get correct column mapping.
    // Anki stores models as JSON: {"mid": {"flds": [{"name": "..."}, ...], ...}}
    // We extract field names and match them to word/pinyin/translation roles.
    var model_maps = ModelFieldMaps{};
    {
        var model_stmt: ?*sqlite.sqlite3_stmt = null;
        const model_sql = "SELECT models FROM col LIMIT 1";
        if (sqlite.sqlite3_prepare_v2(anki_db.?, model_sql, @intCast(model_sql.len), &model_stmt, null) == sqlite.SQLITE_OK) {
            defer _ = sqlite.sqlite3_finalize(model_stmt.?);
            if (sqlite.sqlite3_step(model_stmt.?) == sqlite.SQLITE_ROW) {
                const models_ptr = sqlite.sqlite3_column_text(model_stmt.?, 0);
                if (models_ptr) |ptr| {
                    const models_len: usize = @intCast(sqlite.sqlite3_column_bytes(model_stmt.?, 0));
                    const models_json = ptr[0..models_len];
                    model_maps = detectFieldMaps(models_json);
                }
            }
        }
    }

    // Query notes with model ID for per-model field mapping
    var notes_stmt: ?*sqlite.sqlite3_stmt = null;
    const notes_sql = "SELECT mid, flds FROM notes";
    if (sqlite.sqlite3_prepare_v2(anki_db.?, notes_sql, @intCast(notes_sql.len), &notes_stmt, null) != sqlite.SQLITE_OK)
        return error.TempDbFailed;
    defer _ = sqlite.sqlite3_finalize(notes_stmt.?);

    // Generate pack ID
    var pack_id_buf: [48]u8 = undefined;
    const pack_id = makePackId(pack_name, &pack_id_buf);

    // Begin transaction on main DB
    execSql(main_db, "BEGIN TRANSACTION") catch return error.StepFailed;
    errdefer _ = execSql(main_db, "ROLLBACK") catch {};

    // Delete existing pack if re-importing
    deletePack(main_db, pack_id) catch {};

    // Insert pack
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "INSERT INTO packs(id, name, version, language_pair, word_count, installed_at, updated_at) VALUES(?,?,1,'unknown',0,?,?)";
        if (sqlite.sqlite3_prepare_v2(main_db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        bindText(stmt.?, 1, pack_id);
        bindText(stmt.?, 2, pack_name);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 3, now_ms);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 4, now_ms);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    // Insert lesson
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "INSERT INTO lessons(id, pack_id, title, sort_order, updated_at) VALUES(?,?,'Importiert',1,?)";
        if (sqlite.sqlite3_prepare_v2(main_db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        bindText(stmt.?, 1, pack_id);
        bindText(stmt.?, 2, pack_id);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 3, now_ms);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    // Process notes using detected field mapping
    var word_count: u32 = 0;
    var zh_count: u32 = 0;
    var de_count: u32 = 0;
    var html_buf: [2048]u8 = undefined;

    while (sqlite.sqlite3_step(notes_stmt.?) == sqlite.SQLITE_ROW) {
        const mid = sqlite.sqlite3_column_int64(notes_stmt.?, 0);
        const flds_ptr = sqlite.sqlite3_column_text(notes_stmt.?, 1) orelse continue;
        const flds_len: usize = @intCast(sqlite.sqlite3_column_bytes(notes_stmt.?, 1));
        const flds = flds_ptr[0..flds_len];
        const field_map = model_maps.get(mid);

        // Split fields by 0x1f and collect into array
        var fields: [32][]const u8 = undefined;
        var field_count: u8 = 0;
        var field_start: usize = 0;
        var fi: usize = 0;
        while (fi <= flds.len) : (fi += 1) {
            if (fi == flds.len or flds[fi] == 0x1f) {
                if (field_count < 32) {
                    fields[field_count] = flds[field_start..fi];
                    field_count += 1;
                }
                field_start = fi + 1;
            }
        }

        // Extract word, pinyin, translation using the field map
        const word_raw = if (field_map.word < field_count) fields[field_map.word] else "";
        const word = stripHtml(word_raw, &html_buf);
        if (word.len == 0) continue;

        var pinyin_buf: [512]u8 = undefined;
        const pinyin: []const u8 = if (field_map.pinyin < field_count) stripHtml(fields[field_map.pinyin], &pinyin_buf) else "";

        var trans_buf: [1024]u8 = undefined;
        const translation: []const u8 = if (field_map.translation < field_count) stripHtml(fields[field_map.translation], &trans_buf) else "";

        // Generate card ID
        var card_id_buf: [64]u8 = undefined;
        const card_id = makeCardId(pack_id, word, &card_id_buf);

        // Detect language from word content
        const detected = lang.detect(word);
        const lang_code = detected.code();
        if (detected == .zh) zh_count += 1;
        if (detected == .de) de_count += 1;

        // Insert card
        {
            var stmt: ?*sqlite.sqlite3_stmt = null;
            const sql =
                \\INSERT OR IGNORE INTO cards(id, word, language, pinyin, translation, source_type, pack_id, lesson_id, created_at, updated_at)
                \\VALUES(?, ?, ?, ?, ?, 'pack', ?, ?, ?, ?)
            ;
            if (sqlite.sqlite3_prepare_v2(main_db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
                return error.PrepareFailed;
            defer _ = sqlite.sqlite3_finalize(stmt.?);
            bindText(stmt.?, 1, card_id);
            bindText(stmt.?, 2, word);
            bindText(stmt.?, 3, lang_code);
            if (pinyin.len > 0) bindText(stmt.?, 4, pinyin) else _ = sqlite.sqlite3_bind_null(stmt.?, 4);
            if (translation.len > 0) bindText(stmt.?, 5, translation) else _ = sqlite.sqlite3_bind_null(stmt.?, 5);
            bindText(stmt.?, 6, pack_id);
            bindText(stmt.?, 7, pack_id);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 8, now_ms);
            _ = sqlite.sqlite3_bind_int64(stmt.?, 9, now_ms);
            if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
        }
        word_count += 1;
    }

    if (word_count == 0) {
        _ = execSql(main_db, "ROLLBACK") catch {};
        return error.NoNotesFound;
    }

    // Determine dominant language for the pack
    const dominant_lang: []const u8 = if (zh_count > de_count and zh_count > word_count / 3) "zh-de" else if (de_count > zh_count and de_count > word_count / 3) "de-en" else "en-en";

    // Update word count and language pair
    {
        var stmt: ?*sqlite.sqlite3_stmt = null;
        const sql = "UPDATE packs SET word_count = ?, language_pair = ? WHERE id = ?";
        if (sqlite.sqlite3_prepare_v2(main_db, sql, @intCast(sql.len), &stmt, null) != sqlite.SQLITE_OK)
            return error.PrepareFailed;
        defer _ = sqlite.sqlite3_finalize(stmt.?);
        _ = sqlite.sqlite3_bind_int64(stmt.?, 1, @intCast(word_count));
        bindText(stmt.?, 2, dominant_lang);
        bindText(stmt.?, 3, pack_id);
        if (sqlite.sqlite3_step(stmt.?) != sqlite.SQLITE_DONE) return error.StepFailed;
    }

    execSql(main_db, "COMMIT") catch return error.StepFailed;

    // Clean up native temp file (WASM VFS slot gets reused on next import)
    if (!is_wasm and builtin.target.os.tag != .freestanding) {
        std.fs.cwd().deleteFileZ("/tmp/_anki_test_tmp.db") catch {};
    }

    return word_count;
}

/// Delete a pack and its associated data.
fn deletePack(db: *sqlite.sqlite3, pack_id: []const u8) ApkgError!void {
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

test "strip cloze markup" {
    var buf: [256]u8 = undefined;
    const result = stripHtml("{{c1::pain}}, {{c2::pressure}}", &buf);
    try std.testing.expectEqualStrings("pain, pressure", result);
}

test "strip cloze with hint" {
    var buf: [256]u8 = undefined;
    const result = stripHtml("{{c1::fast::type}} fibers", &buf);
    try std.testing.expectEqualStrings("fast fibers", result);
}

test "strip HTML entities" {
    var buf: [256]u8 = undefined;
    const result = stripHtml("A &amp; B &nbsp; C", &buf);
    try std.testing.expectEqualStrings("A & B   C", result);
}

test "import apkg - invalid zip" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const db_mod = @import("db.zig");
    var db = try db_mod.Db.init(":memory:");
    defer db.close();

    var scratch: [1024]u8 = undefined;
    const result = importApkg(db.handle, "not a zip file", "Test", 1000, &scratch);
    try std.testing.expectError(error.InvalidZip, result);
}

test "import apkg - STORE compression" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const db_mod = @import("db.zig");
    var db = try db_mod.Db.init(":memory:");
    defer db.close();

    const apkg_data = @embedFile("test_data/test_deck_store.apkg");
    var scratch: [64 * 1024]u8 = undefined;
    const count = try importApkg(db.handle, apkg_data, "Store Test", 1000, &scratch);
    try std.testing.expectEqual(@as(u32, 2), count);
}

test "import apkg - DEFLATE compression" {
    if (builtin.cpu.arch == .wasm32) return error.SkipZigTest;

    const db_mod = @import("db.zig");
    var db = try db_mod.Db.init(":memory:");
    defer db.close();

    const apkg_data = @embedFile("test_data/test_deck_deflate.apkg");
    var scratch: [64 * 1024]u8 = undefined;
    const count = try importApkg(db.handle, apkg_data, "Deflate Test", 1000, &scratch);
    try std.testing.expectEqual(@as(u32, 2), count);
}
