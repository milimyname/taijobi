// Character decomposition — binary search over compiled Make Me a Hanzi data.
//
// Binary format (compiled by scripts/compile-decomp.py):
//   Header:  "DCMP" magic (4 bytes) + count: u32 LE
//   Offsets: count * u32 LE (byte offset into entry table)
//   Entries: each = { char_len: u8, radical_len: u8, decomp_len: u8, pinyin_len: u8,
//                     def_len: u16 LE, ety_type_len: u8, ety_hint_len: u8,
//                     char bytes, radical bytes, decomp bytes, pinyin bytes,
//                     definition bytes, ety_type bytes, ety_hint bytes }
//
// Entries sorted by character (UTF-8 byte order) for binary search.

const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const JsonWriter = types.JsonWriter;

const is_wasm = builtin.cpu.arch == .wasm32;

var data: []const u8 = if (is_wasm) &.{} else @embedFile("decomp.bin");

pub fn load(ptr: [*]const u8, len: usize) void {
    data = ptr[0..len];
}

pub fn isLoaded() bool {
    return data.len > 0;
}

pub const DecompEntry = struct {
    character: []const u8,
    radical: []const u8,
    decomposition: []const u8,
    pinyin: []const u8,
    definition: []const u8,
    etymology_type: []const u8,
    etymology_hint: []const u8,
};

const header_size = 8; // "DCMP" + u32 count

fn getCount() u32 {
    if (data.len < header_size) return 0;
    if (!std.mem.eql(u8, data[0..4], "DCMP")) return 0;
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

fn readEntry(count: u32, index: u32) ?DecompEntry {
    const base = entryTableStart(count);
    const off = getOffset(index);
    const pos = base + off;
    if (pos + 8 > data.len) return null;

    const char_len: usize = data[pos];
    const radical_len: usize = data[pos + 1];
    const decomp_len: usize = data[pos + 2];
    const pinyin_len: usize = data[pos + 3];
    const def_len: usize = std.mem.readInt(u16, data[pos + 4 ..][0..2], .little);
    const ety_type_len: usize = data[pos + 6];
    const ety_hint_len: usize = data[pos + 7];

    const hdr = 8;
    const c_start = pos + hdr;
    const r_start = c_start + char_len;
    const d_start = r_start + radical_len;
    const p_start = d_start + decomp_len;
    const df_start = p_start + pinyin_len;
    const et_start = df_start + def_len;
    const eh_start = et_start + ety_type_len;
    const eh_end = eh_start + ety_hint_len;

    if (eh_end > data.len) return null;

    return .{
        .character = data[c_start..][0..char_len],
        .radical = data[r_start..][0..radical_len],
        .decomposition = data[d_start..][0..decomp_len],
        .pinyin = data[p_start..][0..pinyin_len],
        .definition = data[df_start..][0..def_len],
        .etymology_type = data[et_start..][0..ety_type_len],
        .etymology_hint = data[eh_start..][0..ety_hint_len],
    };
}

fn getCharacter(count: u32, index: u32) []const u8 {
    const entry = readEntry(count, index) orelse return "";
    return entry.character;
}

/// Binary search for exact match by character.
pub fn lookup(query: []const u8) ?DecompEntry {
    const count = getCount();
    if (count == 0) return null;

    var lo: u32 = 0;
    var hi: u32 = count;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const character = getCharacter(count, mid);
        const cmp = std.mem.order(u8, character, query);
        switch (cmp) {
            .eq => return readEntry(count, mid),
            .lt => lo = mid + 1,
            .gt => hi = mid,
        }
    }
    return null;
}

/// Parse IDS decomposition string into component characters.
/// IDS operators: ⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻
/// Returns JSON with entry data + components array.
pub fn decomposeToJson(query: []const u8, buf: []u8) ?[]const u8 {
    const entry = lookup(query) orelse return null;

    var w = JsonWriter.init(buf);
    w.writeByte('{');

    w.writeKey("character");
    w.writeJsonString(entry.character);
    w.writeByte(',');

    w.writeKey("radical");
    w.writeJsonString(entry.radical);
    w.writeByte(',');

    w.writeKey("decomposition");
    w.writeJsonString(entry.decomposition);
    w.writeByte(',');

    w.writeKey("pinyin");
    w.writeJsonString(entry.pinyin);
    w.writeByte(',');

    w.writeKey("definition");
    w.writeJsonString(entry.definition);
    w.writeByte(',');

    w.writeKey("etymology_type");
    w.writeJsonString(entry.etymology_type);
    w.writeByte(',');

    w.writeKey("etymology_hint");
    w.writeJsonString(entry.etymology_hint);
    w.writeByte(',');

    // Parse components from IDS decomposition
    w.writeKey("components");
    w.writeByte('[');
    var comp_count: u32 = 0;
    var i: usize = 0;
    while (i < entry.decomposition.len) {
        const byte = entry.decomposition[i];
        // UTF-8 decode to check for IDS operators (U+2FF0-U+2FFB)
        // These are 3-byte UTF-8: E2 BF B0 through E2 BF BB
        if (byte == 0xE2 and i + 2 < entry.decomposition.len) {
            if (entry.decomposition[i + 1] == 0xBF and
                entry.decomposition[i + 2] >= 0xB0 and entry.decomposition[i + 2] <= 0xBB)
            {
                // Skip IDS operator
                i += 3;
                continue;
            }
        }

        // Extract UTF-8 character
        const char_len = utf8CharLen(byte);
        if (char_len == 0 or i + char_len > entry.decomposition.len) {
            i += 1;
            continue;
        }

        const component = entry.decomposition[i..][0..char_len];

        if (comp_count > 0) w.writeByte(',');
        w.writeByte('{');

        w.writeKey("char");
        w.writeJsonString(component);

        // Look up the component for its meaning
        if (lookup(component)) |comp_entry| {
            w.writeByte(',');
            w.writeKey("definition");
            w.writeJsonString(comp_entry.definition);
            w.writeByte(',');
            w.writeKey("type");
            // If this component is the radical, label it
            if (std.mem.eql(u8, component, entry.radical)) {
                w.writeJsonString("radical");
            } else {
                w.writeJsonString("component");
            }
        } else {
            w.writeByte(',');
            w.writeKey("definition");
            w.writeJsonString("");
            w.writeByte(',');
            w.writeKey("type");
            if (std.mem.eql(u8, component, entry.radical)) {
                w.writeJsonString("radical");
            } else {
                w.writeJsonString("component");
            }
        }

        w.writeByte('}');
        comp_count += 1;
        i += char_len;
    }
    w.writeByte(']');

    w.writeByte('}');
    return w.written();
}

fn utf8CharLen(first_byte: u8) usize {
    if (first_byte < 0x80) return 1;
    if (first_byte & 0xE0 == 0xC0) return 2;
    if (first_byte & 0xF0 == 0xE0) return 3;
    if (first_byte & 0xF8 == 0xF0) return 4;
    return 0;
}

// --- Tests ---

test "decomp binary loaded" {
    const count = getCount();
    try std.testing.expect(count > 5000);
}

test "lookup known character" {
    // 好 should be in the dictionary
    const result = lookup("\u{597D}");
    try std.testing.expect(result != null);
    if (result) |entry| {
        try std.testing.expect(entry.character.len > 0);
        try std.testing.expect(entry.radical.len > 0);
        try std.testing.expect(entry.decomposition.len > 0);
    }
}

test "lookup unknown returns null" {
    const result = lookup("X");
    try std.testing.expect(result == null);
}

test "decompose to json" {
    var buf: [8192]u8 = undefined;
    const json = decomposeToJson("\u{597D}", &buf);
    try std.testing.expect(json != null);
    if (json) |j| {
        try std.testing.expect(j.len > 10);
        try std.testing.expect(j[0] == '{');
        // Should contain "components"
        try std.testing.expect(std.mem.indexOf(u8, j, "components") != null);
    }
}
