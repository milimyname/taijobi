// CC-CEDICT lookup — binary search over compiled dictionary.
//
// Binary format (compiled by scripts/compile-cedict.py):
//   Header:  "CEDI" magic (4 bytes) + count: u32 LE
//   Offsets: count * u32 LE (byte offset into entry table)
//   Entries: each = { simplified_len: u8, pinyin_len: u8, english_len: u16 LE,
//                     simplified bytes, pinyin bytes, english bytes }
//
// Entries sorted by simplified (UTF-8 byte order) for binary search.

const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const JsonWriter = types.JsonWriter;

const data = @embedFile("cedict.bin");

pub const CedictEntry = struct {
    simplified: []const u8,
    pinyin: []const u8,
    english: []const u8,
};

const header_size = 8; // "CEDI" + u32 count

fn getCount() u32 {
    if (data.len < header_size) return 0;
    if (!std.mem.eql(u8, data[0..4], "CEDI")) return 0;
    return std.mem.readInt(u32, data[4..8], .little);
}

fn getOffset(index: u32) u32 {
    const off_start = header_size + index * 4;
    if (off_start + 4 > data.len) return 0;
    return std.mem.readInt(u32, data[off_start..][0..4], .little);
}

fn entryTableStart(count: u32) u32 {
    return @intCast(header_size + count * 4);
}

fn readEntry(count: u32, index: u32) ?CedictEntry {
    const base = entryTableStart(count);
    const off = getOffset(index);
    const pos = base + off;
    if (pos + 4 > data.len) return null;

    const s_len: usize = data[pos];
    const p_len: usize = data[pos + 1];
    const e_len: usize = std.mem.readInt(u16, data[pos + 2 ..][0..2], .little);

    const s_start = pos + 4;
    const p_start = s_start + s_len;
    const e_start = p_start + p_len;
    const e_end = e_start + e_len;

    if (e_end > data.len) return null;

    return .{
        .simplified = data[s_start..][0..s_len],
        .pinyin = data[p_start..][0..p_len],
        .english = data[e_start..][0..e_len],
    };
}

fn getSimplified(count: u32, index: u32) []const u8 {
    const entry = readEntry(count, index) orelse return "";
    return entry.simplified;
}

/// Binary search for exact match by simplified characters.
pub fn lookup(query: []const u8) ?CedictEntry {
    const count = getCount();
    if (count == 0) return null;

    var lo: u32 = 0;
    var hi: u32 = count;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const simplified = getSimplified(count, mid);
        const cmp = std.mem.order(u8, simplified, query);
        switch (cmp) {
            .eq => return readEntry(count, mid),
            .lt => lo = mid + 1,
            .gt => hi = mid,
        }
    }
    return null;
}

/// Search for entries matching a prefix or substring. Returns up to max_results.
/// Writes JSON array to buf.
pub fn search(query: []const u8, max_results: u32, buf: []u8) ?[]const u8 {
    const count = getCount();
    if (count == 0 or query.len == 0) return null;

    var w = JsonWriter.init(buf);
    w.writeByte('[');
    var found: u32 = 0;

    // Binary search to find the first entry >= query
    var lo: u32 = 0;
    var hi: u32 = count;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const simplified = getSimplified(count, mid);
        if (std.mem.order(u8, simplified, query) == .lt) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }

    // Scan forward from the insertion point for prefix matches
    var i = lo;
    while (i < count and found < max_results) : (i += 1) {
        const entry = readEntry(count, i) orelse break;
        if (!std.mem.startsWith(u8, entry.simplified, query)) break;

        if (found > 0) w.writeByte(',');
        writeEntryJson(&w, entry);
        found += 1;
    }

    w.writeByte(']');
    return w.written();
}

fn writeEntryJson(w: *JsonWriter, entry: CedictEntry) void {
    w.writeByte('{');
    w.writeKey("simplified");
    w.writeJsonString(entry.simplified);
    w.writeByte(',');
    w.writeKey("pinyin");
    w.writeJsonString(entry.pinyin);
    w.writeByte(',');
    w.writeKey("english");
    w.writeJsonString(entry.english);
    w.writeByte('}');
}

// --- Tests ---

test "cedict binary loaded" {
    const count = getCount();
    // Should have > 100k entries
    try std.testing.expect(count > 100000);
}

test "lookup known word" {
    // 你好 should be in CEDICT
    const result = lookup("\u{4F60}\u{597D}");
    try std.testing.expect(result != null);
    if (result) |entry| {
        try std.testing.expect(entry.pinyin.len > 0);
        try std.testing.expect(entry.english.len > 0);
    }
}

test "lookup unknown returns null" {
    const result = lookup("zzzznotaword");
    try std.testing.expect(result == null);
}

test "search prefix" {
    var buf: [4096]u8 = undefined;
    const json = search("\u{4F60}", 5, &buf);
    try std.testing.expect(json != null);
    if (json) |j| {
        try std.testing.expect(j.len > 2); // more than "[]"
        try std.testing.expect(j[0] == '[');
    }
}
