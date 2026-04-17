// Stroke data — delta-encoded compact binary with on-demand SVG/JSON reconstruction.
//
// Binary format (compiled by scripts/compile-strokes.py):
//   Header:  "STRK" magic (4 bytes) + count: u32 LE
//   Offsets: count * u32 LE (byte offset into entry table)
//   Entries: sorted by character (UTF-8 byte order) for binary search.
//
//   Each entry:
//     char_len: u8, stroke_count: u8, char: [char_len]u8
//     For each stroke:
//       median_count: u8, path_data_len: u16 LE, median_data_len: u16 LE
//       path_data: [path_data_len]u8 — delta-encoded path commands
//       median_data: [median_data_len]u8 — delta-encoded median points
//
//   Path commands:
//     0x01=M: always absolute u16 LE x, u16 LE y
//     0x02=L, 0x03=Q, 0x04=C: delta-encoded coord pairs
//     0x05=Z: no coords
//
//   Delta encoding per coord:
//     i8 value in -127..127: 1 byte (the delta itself)
//     0x80 (escape): followed by absolute u16 LE (3 bytes total)
//
//   Medians: first point absolute u16 x,y. Rest delta-encoded same scheme.

const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const JsonWriter = types.JsonWriter;

const is_wasm = builtin.cpu.arch == .wasm32;

var data: []const u8 = if (is_wasm) &.{} else @embedFile("strokes.bin");

pub fn load(ptr: [*]const u8, len: usize) void {
    data = ptr[0..len];
}

pub fn unload() void {
    data = &.{};
}

pub fn isLoaded() bool {
    return data.len > 0;
}

const header_size = 8;
const ESCAPE: i8 = -128; // 0x80

fn getCount() u32 {
    if (data.len < header_size) return 0;
    if (!std.mem.eql(u8, data[0..4], "STRK")) return 0;
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

fn getCharacter(count: u32, index: u32) []const u8 {
    const base = entryTableStart(count);
    const off = getOffset(index);
    const pos = base + off;
    if (pos + 2 > data.len) return "";
    const char_len: usize = data[pos];
    if (pos + 2 + char_len > data.len) return "";
    return data[pos + 2 ..][0..char_len];
}

fn findEntry(query: []const u8) ?usize {
    const count = getCount();
    if (count == 0) return null;

    var lo: u32 = 0;
    var hi: u32 = count;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const character = getCharacter(count, mid);
        const cmp = std.mem.order(u8, character, query);
        switch (cmp) {
            .eq => return entryTableStart(count) + getOffset(mid),
            .lt => lo = mid + 1,
            .gt => hi = mid,
        }
    }
    return null;
}

fn writeCoord(w: *JsonWriter, val: i32) void {
    w.writeInt(@as(i64, val));
}

/// Read u16 LE from a slice.
fn sliceU16(s: []const u8, pos: usize) u16 {
    if (pos + 2 > s.len) return 0;
    return std.mem.readInt(u16, s[pos..][0..2], .little);
}

/// Read a delta-encoded coordinate from a slice.
fn sliceDelta(s: []const u8, pos: usize, prev: i32) struct { val: i32, len: usize } {
    if (pos >= s.len) return .{ .val = prev, .len = 0 };
    const byte: i8 = @bitCast(s[pos]);
    if (byte == ESCAPE) {
        if (pos + 3 > s.len) return .{ .val = prev, .len = 1 };
        const abs_val: i32 = std.mem.readInt(u16, s[pos + 1 ..][0..2], .little);
        return .{ .val = abs_val, .len = 3 };
    }
    return .{ .val = prev + byte, .len = 1 };
}

/// Reconstruct SVG path string from delta-encoded binary commands.
fn writeSvgPath(w: *JsonWriter, path_data: []const u8) void {
    var i: usize = 0;
    var prev_x: i32 = 0;
    var prev_y: i32 = 0;

    while (i < path_data.len) {
        const cmd = path_data[i];
        i += 1;
        switch (cmd) {
            0x01 => { // M — absolute u16
                if (i + 4 > path_data.len) break;
                const x: i32 = sliceU16(path_data, i);
                const y: i32 = sliceU16(path_data, i + 2);
                w.writeStr("M ");
                writeCoord(w, x);
                w.writeByte(' ');
                writeCoord(w, y);
                w.writeByte(' ');
                prev_x = x;
                prev_y = y;
                i += 4;
            },
            0x02 => { // L — 1 delta pair
                const dx = sliceDelta(path_data, i, prev_x);
                i += dx.len;
                const dy = sliceDelta(path_data, i, prev_y);
                i += dy.len;
                w.writeStr("L ");
                writeCoord(w, dx.val);
                w.writeByte(' ');
                writeCoord(w, dy.val);
                w.writeByte(' ');
                prev_x = dx.val;
                prev_y = dy.val;
            },
            0x03 => { // Q — 2 delta pairs
                w.writeStr("Q ");
                inline for (0..2) |_| {
                    const dx = sliceDelta(path_data, i, prev_x);
                    i += dx.len;
                    const dy = sliceDelta(path_data, i, prev_y);
                    i += dy.len;
                    writeCoord(w, dx.val);
                    w.writeByte(' ');
                    writeCoord(w, dy.val);
                    w.writeByte(' ');
                    prev_x = dx.val;
                    prev_y = dy.val;
                }
            },
            0x04 => { // C — 3 delta pairs
                w.writeStr("C ");
                inline for (0..3) |_| {
                    const dx = sliceDelta(path_data, i, prev_x);
                    i += dx.len;
                    const dy = sliceDelta(path_data, i, prev_y);
                    i += dy.len;
                    writeCoord(w, dx.val);
                    w.writeByte(' ');
                    writeCoord(w, dy.val);
                    w.writeByte(' ');
                    prev_x = dx.val;
                    prev_y = dy.val;
                }
            },
            0x05 => { // Z
                w.writeByte('Z');
            },
            else => break,
        }
    }
}

/// Returns stroke data as JSON.
/// Format: { character, stroke_count, strokes: [svgPath, ...], medians: [[[x,y],...], ...] }
pub fn strokesAsJson(query: []const u8, buf: []u8) ?[]const u8 {
    const pos = findEntry(query) orelse return null;
    if (pos + 2 > data.len) return null;

    const char_len: usize = data[pos];
    const stroke_count: usize = data[pos + 1];
    const character = data[pos + 2 ..][0..char_len];

    var w = JsonWriter.init(buf);
    w.writeByte('{');

    w.writeKey("character");
    w.writeJsonString(character);
    w.writeByte(',');

    w.writeKey("stroke_count");
    w.writeInt(@intCast(stroke_count));
    w.writeByte(',');

    // First pass: collect stroke positions
    const StrokeInfo = struct {
        path_start: usize,
        path_len: usize,
        median_start: usize,
        median_data_len: usize,
        median_count: usize,
    };
    var stroke_infos: [64]StrokeInfo = undefined;
    var scan: usize = pos + 2 + char_len;

    for (0..stroke_count) |si| {
        if (scan + 5 > data.len) break;
        const median_count: usize = data[scan];
        const path_data_len: usize = sliceU16(data, scan + 1);
        const median_data_len: usize = sliceU16(data, scan + 3);
        const path_start = scan + 5;
        const median_start = path_start + path_data_len;
        if (si < 64) {
            stroke_infos[si] = .{
                .path_start = path_start,
                .path_len = path_data_len,
                .median_start = median_start,
                .median_data_len = median_data_len,
                .median_count = median_count,
            };
        }
        scan = median_start + median_data_len;
    }

    // Write strokes array (SVG path strings)
    w.writeKey("strokes");
    w.writeByte('[');
    for (0..stroke_count) |si| {
        if (si >= 64) break;
        if (si > 0) w.writeByte(',');
        w.writeByte('"');
        const sp = stroke_infos[si];
        if (sp.path_start + sp.path_len <= data.len) {
            writeSvgPath(&w, data[sp.path_start..][0..sp.path_len]);
        }
        w.writeByte('"');
    }
    w.writeByte(']');
    w.writeByte(',');

    // Write medians array (delta-decoded)
    w.writeKey("medians");
    w.writeByte('[');
    for (0..stroke_count) |si| {
        if (si >= 64) break;
        if (si > 0) w.writeByte(',');
        w.writeByte('[');
        const sp = stroke_infos[si];
        const md = data[sp.median_start..][0..sp.median_data_len];

        if (sp.median_count > 0 and md.len >= 4) {
            // First point: absolute u16
            var mx: i32 = std.mem.readInt(u16, md[0..2], .little);
            var my: i32 = std.mem.readInt(u16, md[2..4], .little);
            w.writeByte('[');
            w.writeInt(mx);
            w.writeByte(',');
            w.writeInt(my);
            w.writeByte(']');

            var mi: usize = 4;
            for (1..sp.median_count) |_| {
                w.writeByte(',');
                const dx = sliceDelta(md, mi, mx);
                mi += dx.len;
                const dy = sliceDelta(md, mi, my);
                mi += dy.len;
                mx = dx.val;
                my = dy.val;
                w.writeByte('[');
                w.writeInt(mx);
                w.writeByte(',');
                w.writeInt(my);
                w.writeByte(']');
            }
        }
        w.writeByte(']');
    }
    w.writeByte(']');

    w.writeByte('}');
    return w.written();
}

// --- Tests ---

test "strokes binary loaded" {
    const count = getCount();
    try std.testing.expect(count > 5000);
}

test "lookup known character strokes" {
    const pos = findEntry("\u{597D}");
    try std.testing.expect(pos != null);
}

test "strokes to json" {
    var buf: [32768]u8 = undefined;
    const json = strokesAsJson("\u{597D}", &buf);
    try std.testing.expect(json != null);
    if (json) |j| {
        try std.testing.expect(j.len > 10);
        try std.testing.expect(j[0] == '{');
        try std.testing.expect(std.mem.indexOf(u8, j, "strokes") != null);
        try std.testing.expect(std.mem.indexOf(u8, j, "medians") != null);
        try std.testing.expect(std.mem.indexOf(u8, j, "M ") != null);
    }
}
