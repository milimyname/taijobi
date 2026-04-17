// Wiktionary dictionary lookup — binary search over compiled data.
//
// Binary format (compiled by scripts/compile-wiktdict.ts):
//   Header:  "WKEN"/"WKDE" magic (4 bytes) + count: u32 LE
//   Offsets: count * u32 LE (byte offset into entry table)
//   Entries: each = { word_len: u8, pos_len: u8, def_len: u16 LE,
//                     word bytes, pos bytes, definition bytes }
//
// Entries sorted by word (UTF-8 byte order) for binary search.
// Separate data slots for English and German.

const std = @import("std");
const types = @import("types.zig");
const JsonWriter = types.JsonWriter;

pub const WiktEntry = struct {
    word: []const u8,
    pos: []const u8,
    definition: []const u8,
};

const header_size = 8; // magic + u32 count

var en_data: []const u8 = &.{};
var de_data: []const u8 = &.{};

pub fn loadEn(ptr: [*]const u8, len: usize) void {
    en_data = ptr[0..len];
}

pub fn loadDe(ptr: [*]const u8, len: usize) void {
    de_data = ptr[0..len];
}

pub fn unloadEn() void {
    en_data = &.{};
}

pub fn unloadDe() void {
    de_data = &.{};
}

pub fn isEnLoaded() bool {
    return en_data.len > 0;
}

pub fn isDeLoaded() bool {
    return de_data.len > 0;
}

// --- Internal helpers (operate on any data slice) ---

fn getCount(d: []const u8, magic: *const [4]u8) u32 {
    if (d.len < header_size) return 0;
    if (!std.mem.eql(u8, d[0..4], magic)) return 0;
    return std.mem.readInt(u32, d[4..8], .little);
}

fn getOffset(d: []const u8, index: u32) u32 {
    const off_start = header_size + index * 4;
    if (off_start + 4 > d.len) return 0;
    return std.mem.readInt(u32, d[off_start..][0..4], .little);
}

fn entryTableStart(count: u32) u32 {
    return @intCast(header_size + count * 4);
}

fn readEntry(d: []const u8, count: u32, index: u32) ?WiktEntry {
    const base = entryTableStart(count);
    const off = getOffset(d, index);
    const pos = base + off;
    if (pos + 4 > d.len) return null;

    const w_len: usize = d[pos];
    const p_len: usize = d[pos + 1];
    const def_len: usize = std.mem.readInt(u16, d[pos + 2 ..][0..2], .little);

    const w_start = pos + 4;
    const p_start = w_start + w_len;
    const d_start = p_start + p_len;
    const d_end = d_start + def_len;

    if (d_end > d.len) return null;

    return .{
        .word = d[w_start..][0..w_len],
        .pos = d[p_start..][0..p_len],
        .definition = d[d_start..][0..def_len],
    };
}

fn getWord(d: []const u8, count: u32, index: u32) []const u8 {
    const entry = readEntry(d, count, index) orelse return "";
    return entry.word;
}

/// Case-insensitive comparison for Latin text (ASCII lowercase).
fn orderCaseInsensitive(a: []const u8, b: []const u8) std.math.Order {
    const min_len = @min(a.len, b.len);
    for (0..min_len) |i| {
        const ca = if (a[i] >= 'A' and a[i] <= 'Z') a[i] + 32 else a[i];
        const cb = if (b[i] >= 'A' and b[i] <= 'Z') b[i] + 32 else b[i];
        if (ca < cb) return .lt;
        if (ca > cb) return .gt;
    }
    return std.math.order(a.len, b.len);
}

fn toLowerByte(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn startsWithCaseInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    for (0..needle.len) |i| {
        if (toLowerByte(haystack[i]) != toLowerByte(needle[i])) return false;
    }
    return true;
}

// --- Public lookup API ---

fn lookupIn(d: []const u8, magic: *const [4]u8, query: []const u8) ?WiktEntry {
    const count = getCount(d, magic);
    if (count == 0) return null;

    var lo: u32 = 0;
    var hi: u32 = count;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const word = getWord(d, count, mid);
        const cmp = orderCaseInsensitive(word, query);
        switch (cmp) {
            .eq => return readEntry(d, count, mid),
            .lt => lo = mid + 1,
            .gt => hi = mid,
        }
    }
    return null;
}

fn searchIn(d: []const u8, magic: *const [4]u8, query: []const u8, max_results: u32, buf: []u8) ?[]const u8 {
    const count = getCount(d, magic);
    if (count == 0 or query.len == 0) return null;

    var w = JsonWriter.init(buf);
    w.writeByte('[');
    var found: u32 = 0;

    // Binary search to find the first entry >= query (case-insensitive)
    var lo: u32 = 0;
    var hi: u32 = count;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const word = getWord(d, count, mid);
        if (orderCaseInsensitive(word, query) == .lt) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }

    // Scan forward for prefix matches
    var i = lo;
    while (i < count and found < max_results) : (i += 1) {
        const entry = readEntry(d, count, i) orelse break;
        if (!startsWithCaseInsensitive(entry.word, query)) break;

        if (found > 0) w.writeByte(',');
        writeEntryJson(&w, entry);
        found += 1;
    }

    w.writeByte(']');
    return w.written();
}

fn writeEntryJson(w: *JsonWriter, entry: WiktEntry) void {
    w.writeByte('{');
    w.writeKey("word");
    w.writeJsonString(entry.word);
    w.writeByte(',');
    w.writeKey("pos");
    w.writeJsonString(entry.pos);
    w.writeByte(',');
    w.writeKey("definition");
    w.writeJsonString(entry.definition);
    w.writeByte('}');
}

// --- Public EN/DE API ---

pub fn lookupEn(query: []const u8) ?WiktEntry {
    return lookupIn(en_data, "WKEN", query);
}

pub fn lookupDe(query: []const u8) ?WiktEntry {
    return lookupIn(de_data, "WKDE", query);
}

pub fn searchEn(query: []const u8, max_results: u32, buf: []u8) ?[]const u8 {
    return searchIn(en_data, "WKEN", query, max_results, buf);
}

pub fn searchDe(query: []const u8, max_results: u32, buf: []u8) ?[]const u8 {
    return searchIn(de_data, "WKDE", query, max_results, buf);
}
