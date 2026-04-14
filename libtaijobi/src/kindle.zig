// Kindle `My Clippings.txt` parser.
//
// Format: entries separated by `==========` on its own line. Each entry is:
//
//   Title (Author)
//   - Your Highlight on page X | Location Y-Z | Added on <date>
//
//   <the highlighted text, possibly multi-line>
//
// Metadata lines are localized (German: "Ihre Markierung auf Seite X | Position
// Y-Z | Hinzugefügt am ..."), but the overall structure holds for every locale.

const std = @import("std");
const types = @import("types.zig");

const JsonWriter = types.JsonWriter;

pub const ClippingType = enum {
    highlight,
    note,
    bookmark,

    fn asString(self: ClippingType) []const u8 {
        return switch (self) {
            .highlight => "highlight",
            .note => "note",
            .bookmark => "bookmark",
        };
    }
};

/// Strip UTF-8 BOM if present. Returns a sub-slice of the input.
fn stripBom(data: []const u8) []const u8 {
    if (data.len >= 3 and data[0] == 0xEF and data[1] == 0xBB and data[2] == 0xBF) {
        return data[3..];
    }
    return data;
}

/// Normalize CRLF/CR line endings to LF by making a sanitized copy in `scratch`.
/// Returns the usable slice of `scratch`. If there are no CR bytes, returns the
/// original slice to avoid a copy.
fn normalizeNewlines(data: []const u8, scratch: []u8) []const u8 {
    if (std.mem.indexOfScalar(u8, data, '\r') == null) return data;
    var out_len: usize = 0;
    var i: usize = 0;
    while (i < data.len) : (i += 1) {
        const c = data[i];
        if (c == '\r') {
            // CRLF → LF, lone CR → LF
            if (out_len < scratch.len) {
                scratch[out_len] = '\n';
                out_len += 1;
            }
            if (i + 1 < data.len and data[i + 1] == '\n') i += 1;
        } else {
            if (out_len < scratch.len) {
                scratch[out_len] = c;
                out_len += 1;
            }
        }
    }
    return scratch[0..out_len];
}

/// Parse `Title (Author)`. If no parens, the whole line is the book title.
fn parseTitleAndAuthor(line: []const u8, book_out: *[]const u8, author_out: *[]const u8) void {
    const trimmed = std.mem.trim(u8, line, " \t");
    if (trimmed.len == 0) {
        book_out.* = "";
        author_out.* = "";
        return;
    }
    // Find the LAST '(' so titles containing parens keep them on the book side.
    if (std.mem.lastIndexOfScalar(u8, trimmed, '(')) |open_idx| {
        // Must close at the very end and have content inside.
        if (trimmed[trimmed.len - 1] == ')' and open_idx + 1 < trimmed.len - 1) {
            const before = std.mem.trimRight(u8, trimmed[0..open_idx], " \t");
            const inside = trimmed[open_idx + 1 .. trimmed.len - 1];
            book_out.* = before;
            author_out.* = std.mem.trim(u8, inside, " \t");
            return;
        }
    }
    book_out.* = trimmed;
    author_out.* = "";
}

fn containsNoCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var match = true;
        for (0..needle.len) |k| {
            const a = haystack[i + k];
            const b = needle[k];
            const aa = if (a >= 'A' and a <= 'Z') a + 32 else a;
            const bb = if (b >= 'A' and b <= 'Z') b + 32 else b;
            if (aa != bb) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

fn detectType(meta_line: []const u8) ClippingType {
    if (containsNoCase(meta_line, "note") or containsNoCase(meta_line, "notiz")) {
        return .note;
    }
    if (containsNoCase(meta_line, "bookmark") or
        containsNoCase(meta_line, "lesezeichen") or
        containsNoCase(meta_line, "marque-page"))
    {
        return .bookmark;
    }
    return .highlight;
}

/// Parse a whole `My Clippings.txt` and write a JSON array of entries.
/// Skips bookmarks (they have no body text). Returns the written slice or
/// null if the output buffer overflowed.
pub fn parseClippings(raw: []const u8, scratch: []u8, out_buf: []u8) ?[]const u8 {
    const no_bom = stripBom(raw);
    const normalized = normalizeNewlines(no_bom, scratch);

    var w = JsonWriter.init(out_buf);
    w.writeByte('[');

    var first = true;
    var pos: usize = 0;
    while (pos < normalized.len) {
        // Find the next `==========` on its own line (or EOF).
        const block_end = findNextSeparator(normalized, pos);
        const block = normalized[pos..block_end];
        pos = advancePastSeparator(normalized, block_end);

        const trimmed = std.mem.trim(u8, block, " \t\r\n");
        if (trimmed.len == 0) continue;

        // Split on '\n' — first line is title, second is metadata, rest is body.
        var lines_iter = std.mem.splitScalar(u8, trimmed, '\n');
        const title_line = lines_iter.next() orelse continue;
        const meta_line = lines_iter.next() orelse continue;
        // Remainder of the iterator is the body (may span multiple lines).
        const body_start_in_trimmed = (lines_iter.index orelse trimmed.len);
        const body_raw = if (body_start_in_trimmed <= trimmed.len)
            trimmed[body_start_in_trimmed..]
        else
            "";
        const body = std.mem.trim(u8, body_raw, " \t\r\n");
        if (body.len == 0) continue;

        const ctype = detectType(meta_line);
        if (ctype == .bookmark) continue;

        var book: []const u8 = "";
        var author: []const u8 = "";
        parseTitleAndAuthor(title_line, &book, &author);

        if (!first) w.writeByte(',');
        first = false;

        w.writeByte('{');
        w.writeKey("book");
        w.writeJsonString(book);
        w.writeByte(',');
        w.writeKey("author");
        w.writeJsonString(author);
        w.writeByte(',');
        w.writeKey("type");
        w.writeJsonString(ctype.asString());
        w.writeByte(',');
        w.writeKey("text");
        w.writeJsonString(body);
        w.writeByte('}');
    }
    w.writeByte(']');

    const written = w.written();
    // Detect buffer overflow — JsonWriter silently drops on full buffer.
    if (written.len == out_buf.len) return null;
    return written;
}

/// Return the index just before the next `==========` line (or data.len).
fn findNextSeparator(data: []const u8, start: usize) usize {
    var i = start;
    while (i < data.len) {
        // Line begin — either `i == 0` or preceded by '\n'.
        const line_begin = i;
        const line_end = std.mem.indexOfScalarPos(u8, data, i, '\n') orelse data.len;
        const line = data[line_begin..line_end];
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len >= 10 and std.mem.eql(u8, trimmed, "==========")) {
            return line_begin;
        }
        if (line_end >= data.len) return data.len;
        i = line_end + 1;
    }
    return data.len;
}

/// Advance past a separator line (returns index of the next block start).
fn advancePastSeparator(data: []const u8, sep_start: usize) usize {
    if (sep_start >= data.len) return data.len;
    const line_end = std.mem.indexOfScalarPos(u8, data, sep_start, '\n') orelse data.len;
    return @min(line_end + 1, data.len);
}

// --- Tests ---

test "parseClippings basic" {
    const raw =
        "Title (Author)\n" ++
        "- Your Highlight on page 1 | Location 1-2 | Added on ...\n" ++
        "\n" ++
        "hello world\n" ++
        "==========\n" ++
        "Book2 (Auth2)\n" ++
        "- Your Highlight on page 2 | ...\n" ++
        "\n" ++
        "second\n" ++
        "==========\n";
    var scratch: [1024]u8 = undefined;
    var out: [2048]u8 = undefined;
    const json = parseClippings(raw, &scratch, &out) orelse unreachable;
    // Spot-check key substrings rather than parse JSON back.
    try std.testing.expect(std.mem.indexOf(u8, json, "\"book\":\"Title\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"author\":\"Author\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"text\":\"hello world\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"text\":\"second\"") != null);
}

test "parseClippings skips bookmarks" {
    const raw =
        "T (A)\n- Your Bookmark on page 5 | ...\n\n\n==========\n" ++
        "T (A)\n- Your Highlight on page 6 | ...\n\nkeep me\n==========\n";
    var scratch: [512]u8 = undefined;
    var out: [1024]u8 = undefined;
    const json = parseClippings(raw, &scratch, &out) orelse unreachable;
    try std.testing.expect(std.mem.indexOf(u8, json, "bookmark") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "keep me") != null);
}

test "parseClippings handles CRLF and BOM" {
    const raw = "\xEF\xBB\xBFTitle (Author)\r\n- Your Highlight...\r\n\r\nhi\r\n==========\r\n";
    var scratch: [256]u8 = undefined;
    var out: [512]u8 = undefined;
    const json = parseClippings(raw, &scratch, &out) orelse unreachable;
    try std.testing.expect(std.mem.indexOf(u8, json, "\"text\":\"hi\"") != null);
}
