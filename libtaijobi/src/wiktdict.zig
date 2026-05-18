// Wiktionary dictionary lookup — binary search over compiled data.
//
// Binary format v3 (compiled by scripts/compile-wiktdict.ts):
//   Header:  "WKE3"/"WKD3" magic (4 bytes) + count: u32 LE
//   Offsets: count * u32 LE (byte offset into entry table)
//   Per entry (sorted by lowercase word, UTF-8 byte order):
//     u8  word_len, word bytes
//     u8  pos_count
//     for each POS:
//       u8  pos_len, pos bytes
//       u16 LE etymology_len, etymology bytes      (v3 new)
//       u8  sense_count
//       for each sense:
//         u8  tag_count
//         for each tag: u8 tag_len, tag bytes
//         u16 LE gloss_len, gloss bytes
//         u16 LE example_len, example bytes
//         u8  syn_count;  for each: u8 len, bytes  (v3 new)
//         u8  ant_count;  for each: u8 len, bytes  (v3 new)
//         u8  hyp_count;  for each: u8 len, bytes  (v3 new)
//
// v1 ("WKEN"/"WKDE") and v2 ("WKE2"/"WKD2") formats are no longer parsed —
// bumping the magic forces a re-download from /packs when users have a stale
// OPFS-cached file. The `isLoaded` helpers validate the magic so the UI
// reports "not installed" if the loaded slice is stale, instead of silently
// failing every lookup.

const std = @import("std");
const types = @import("types.zig");
const JsonWriter = types.JsonWriter;

pub const LookupHit = struct {
    /// Lowercased headword as stored in the binary.
    word: []const u8,
    /// First sense's gloss of the first POS group. Used by lexicon
    /// auto-enrichment, which needs a single flat string for the
    /// `cards.translation` column.
    first_gloss: []const u8,
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

/// True only when a slice is loaded AND it carries the v3 magic. A stale v1
/// or v2 cache (or any unrecognized bytes) reports false so the UI prompts a
/// re-install instead of silently returning empty lookups.
pub fn isEnLoaded() bool {
    return validMagic(en_data, "WKE3");
}

pub fn isDeLoaded() bool {
    return validMagic(de_data, "WKD3");
}

fn validMagic(d: []const u8, magic: *const [4]u8) bool {
    return d.len >= header_size and std.mem.eql(u8, d[0..4], magic);
}

// --- Binary search over the offset table ---

fn getCount(d: []const u8, magic: *const [4]u8) u32 {
    if (!validMagic(d, magic)) return 0;
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

/// Returns the word bytes at the given index, without parsing the rest of
/// the entry. Used as the comparator for binary search.
fn getWord(d: []const u8, count: u32, index: u32) []const u8 {
    const base = entryTableStart(count);
    const off = getOffset(d, index);
    const pos = base + off;
    if (pos + 1 > d.len) return "";
    const w_len: usize = d[pos];
    const w_start = pos + 1;
    if (w_start + w_len > d.len) return "";
    return d[w_start..][0..w_len];
}

/// Returns the byte range covering an entire entry (word + all POS groups).
fn getEntryBytes(d: []const u8, count: u32, index: u32) ?[]const u8 {
    const base = entryTableStart(count);
    const off = getOffset(d, index);
    const start = base + off;
    if (start >= d.len) return null;
    const next_idx = index + 1;
    const end: usize = if (next_idx < count) blk: {
        const next_off = getOffset(d, next_idx);
        break :blk base + next_off;
    } else d.len;
    if (end > d.len or end <= start) return null;
    return d[start..end];
}

fn toLowerByte(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn orderCaseInsensitive(a: []const u8, b: []const u8) std.math.Order {
    const min_len = @min(a.len, b.len);
    for (0..min_len) |i| {
        const ca = toLowerByte(a[i]);
        const cb = toLowerByte(b[i]);
        if (ca < cb) return .lt;
        if (ca > cb) return .gt;
    }
    return std.math.order(a.len, b.len);
}

fn startsWithCaseInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    for (0..needle.len) |i| {
        if (toLowerByte(haystack[i]) != toLowerByte(needle[i])) return false;
    }
    return true;
}

// --- Entry-bytes walker ---

const Reader = struct {
    data: []const u8,
    pos: usize = 0,

    fn u8val(self: *Reader) ?u8 {
        if (self.pos >= self.data.len) return null;
        const v = self.data[self.pos];
        self.pos += 1;
        return v;
    }

    fn u16val(self: *Reader) ?u16 {
        if (self.pos + 2 > self.data.len) return null;
        const v = std.mem.readInt(u16, self.data[self.pos..][0..2], .little);
        self.pos += 2;
        return v;
    }

    fn take(self: *Reader, n: usize) ?[]const u8 {
        if (self.pos + n > self.data.len) return null;
        const s = self.data[self.pos..][0..n];
        self.pos += n;
        return s;
    }
};

/// Writes a JSON string-array of u8-length-prefixed items pulled from the
/// reader. Returns false on malformed input.
fn emitU8StringArray(w: *JsonWriter, r: *Reader) bool {
    const count = r.u8val() orelse return false;
    w.writeByte('[');
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const len = r.u8val() orelse return false;
        const bytes = r.take(len) orelse return false;
        if (i > 0) w.writeByte(',');
        w.writeJsonString(bytes);
    }
    w.writeByte(']');
    return true;
}

/// Walks an entry's bytes and writes structured JSON for it. The opening
/// `{` and closing `}` are emitted by this function. Returns false on
/// malformed input so the caller can fail the lookup cleanly.
fn emitEntry(w: *JsonWriter, entry_bytes: []const u8) bool {
    var r = Reader{ .data = entry_bytes };

    const w_len = r.u8val() orelse return false;
    const word = r.take(w_len) orelse return false;

    w.writeByte('{');
    w.writeKey("word");
    w.writeJsonString(word);
    w.writeByte(',');
    w.writeKey("groups");
    w.writeByte('[');

    const pos_count = r.u8val() orelse return false;
    var gi: u32 = 0;
    while (gi < pos_count) : (gi += 1) {
        const p_len = r.u8val() orelse return false;
        const pos = r.take(p_len) orelse return false;

        const ety_len = r.u16val() orelse return false;
        const etymology = r.take(ety_len) orelse return false;

        const sense_count = r.u8val() orelse return false;

        if (gi > 0) w.writeByte(',');
        w.writeByte('{');
        w.writeKey("pos");
        w.writeJsonString(pos);
        w.writeByte(',');
        w.writeKey("etymology");
        w.writeJsonString(etymology);
        w.writeByte(',');
        w.writeKey("senses");
        w.writeByte('[');

        var si: u32 = 0;
        while (si < sense_count) : (si += 1) {
            if (si > 0) w.writeByte(',');
            w.writeByte('{');

            w.writeKey("tags");
            if (!emitU8StringArray(w, &r)) return false;

            const g_len = r.u16val() orelse return false;
            const gloss = r.take(g_len) orelse return false;
            w.writeByte(',');
            w.writeKey("gloss");
            w.writeJsonString(gloss);

            const e_len = r.u16val() orelse return false;
            const example = r.take(e_len) orelse return false;
            w.writeByte(',');
            w.writeKey("example");
            w.writeJsonString(example);

            w.writeByte(',');
            w.writeKey("synonyms");
            if (!emitU8StringArray(w, &r)) return false;

            w.writeByte(',');
            w.writeKey("antonyms");
            if (!emitU8StringArray(w, &r)) return false;

            w.writeByte(',');
            w.writeKey("hypernyms");
            if (!emitU8StringArray(w, &r)) return false;

            w.writeByte('}');
        }
        w.writeByte(']');
        w.writeByte('}');
    }

    w.writeByte(']');
    w.writeByte('}');
    return true;
}

/// Scans the entry far enough to find the first sense's gloss, then stops.
/// Used by the lexicon auto-enrichment path which only needs a flat string.
fn extractFirstGloss(entry_bytes: []const u8) ?LookupHit {
    var r = Reader{ .data = entry_bytes };
    const w_len = r.u8val() orelse return null;
    const word = r.take(w_len) orelse return null;

    const pos_count = r.u8val() orelse return null;
    if (pos_count == 0) return null;

    // Skip POS label
    const p_len = r.u8val() orelse return null;
    _ = r.take(p_len) orelse return null;

    // Skip etymology
    const ety_len = r.u16val() orelse return null;
    _ = r.take(ety_len) orelse return null;

    const sense_count = r.u8val() orelse return null;
    if (sense_count == 0) return null;

    // Skip tags of first sense
    const tag_count = r.u8val() orelse return null;
    var ti: u32 = 0;
    while (ti < tag_count) : (ti += 1) {
        const t_len = r.u8val() orelse return null;
        _ = r.take(t_len) orelse return null;
    }

    const g_len = r.u16val() orelse return null;
    const gloss = r.take(g_len) orelse return null;

    return .{ .word = word, .first_gloss = gloss };
}

// --- Public lookup API ---

fn lookupIn(d: []const u8, magic: *const [4]u8, query: []const u8) ?LookupHit {
    const count = getCount(d, magic);
    if (count == 0) return null;

    var lo: u32 = 0;
    var hi: u32 = count;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const word = getWord(d, count, mid);
        const cmp = orderCaseInsensitive(word, query);
        switch (cmp) {
            .eq => {
                const bytes = getEntryBytes(d, count, mid) orelse return null;
                return extractFirstGloss(bytes);
            },
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

    // Find the first entry >= query (case-insensitive)
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
        const word = getWord(d, count, i);
        if (!startsWithCaseInsensitive(word, query)) break;
        const bytes = getEntryBytes(d, count, i) orelse break;

        if (found > 0) w.writeByte(',');
        if (!emitEntry(&w, bytes)) {
            return w.written();
        }
        found += 1;
    }

    w.writeByte(']');
    return w.written();
}

// --- Public EN/DE API ---

pub fn lookupEn(query: []const u8) ?LookupHit {
    return lookupIn(en_data, "WKE3", query);
}

pub fn lookupDe(query: []const u8) ?LookupHit {
    return lookupIn(de_data, "WKD3", query);
}

pub fn searchEn(query: []const u8, max_results: u32, buf: []u8) ?[]const u8 {
    return searchIn(en_data, "WKE3", query, max_results, buf);
}

pub fn searchDe(query: []const u8, max_results: u32, buf: []u8) ?[]const u8 {
    return searchIn(de_data, "WKD3", query, max_results, buf);
}

// --- Tests against a hand-compiled fixture.
//
// To regenerate test_data/fixture_wikt.bin after format changes:
//   bun scripts/compile-wiktdict.ts \
//       libtaijobi/src/test_data/fixture_wikt.jsonl \
//       libtaijobi/src/test_data/fixture_wikt.bin WKE3
//
// Both the .jsonl source and the .bin output are checked in — the .bin so
// tests have a stable input without bundling a JSONL parser into the test
// binary, the .jsonl so the fixture is regeneratable.

test "parses v3 format: bank merges noun + verb groups" {
    const fixture = @embedFile("test_data/fixture_wikt.bin");
    loadEn(fixture.ptr, fixture.len);
    defer unloadEn();

    try std.testing.expect(isEnLoaded());

    const hit = lookupEn("bank") orelse return error.LookupMissed;
    try std.testing.expectEqualStrings("bank", hit.word);
    try std.testing.expectEqualStrings(
        "A financial institution where people deposit money.",
        hit.first_gloss,
    );
}

test "structured search emits POS groups, senses, examples, tags" {
    const fixture = @embedFile("test_data/fixture_wikt.bin");
    loadEn(fixture.ptr, fixture.len);
    defer unloadEn();

    var buf: [16 * 1024]u8 = undefined;
    const json = searchEn("limp", 5, &buf) orelse return error.SearchReturnedNull;

    try std.testing.expect(std.mem.indexOf(u8, json, "\"pos\":\"v\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"pos\":\"adj\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "He limped off the field after the tackle.") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"tags\":[]") != null);
}

test "tags are preserved per sense" {
    const fixture = @embedFile("test_data/fixture_wikt.bin");
    loadEn(fixture.ptr, fixture.len);
    defer unloadEn();

    var buf: [16 * 1024]u8 = undefined;
    const json = searchEn("obfuscate", 5, &buf) orelse return error.SearchReturnedNull;

    try std.testing.expect(std.mem.indexOf(u8, json, "\"tags\":[\"formal\"]") != null);
}

test "etymology is emitted per POS group" {
    const fixture = @embedFile("test_data/fixture_wikt.bin");
    loadEn(fixture.ptr, fixture.len);
    defer unloadEn();

    var buf: [16 * 1024]u8 = undefined;
    const json = searchEn("obfuscate", 5, &buf) orelse return error.SearchReturnedNull;

    try std.testing.expect(std.mem.indexOf(u8, json, "From Latin") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"etymology\":\"") != null);
}

test "synonyms, antonyms, hypernyms emitted per sense" {
    const fixture = @embedFile("test_data/fixture_wikt.bin");
    loadEn(fixture.ptr, fixture.len);
    defer unloadEn();

    var buf: [16 * 1024]u8 = undefined;
    const json = searchEn("obfuscate", 5, &buf) orelse return error.SearchReturnedNull;

    try std.testing.expect(std.mem.indexOf(u8, json, "\"synonyms\":[\"confuse\",\"obscure\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"antonyms\":[\"clarify\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"hypernyms\":[\"mislead\"") != null);
}

test "case-insensitive prefix search returns multiple hits" {
    const fixture = @embedFile("test_data/fixture_wikt.bin");
    loadEn(fixture.ptr, fixture.len);
    defer unloadEn();

    var buf: [16 * 1024]u8 = undefined;
    const json = searchEn("ban", 5, &buf) orelse return error.SearchReturnedNull;

    try std.testing.expect(std.mem.indexOf(u8, json, "\"word\":\"bank\"") != null);
}

test "stale v2 magic is rejected by isEnLoaded" {
    const stale_v2 = [_]u8{ 'W', 'K', 'E', '2', 0, 0, 0, 0 };
    loadEn(&stale_v2, stale_v2.len);
    defer unloadEn();

    try std.testing.expect(!isEnLoaded());
}
