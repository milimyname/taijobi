//! Wire protocol for the sync endpoints — parses the push request body that
//! the web/iOS/Android clients send, into `Store.Row`s.
//!
//! Push body shape (identical to the Cloudflare Worker):
//!   {"rows":[{"table":"cards","id":"abc","data":{...},"updated_at":123}]}
//!
//! `data` is re-serialized with `std.json.Stringify` — exactly what the Worker's
//! `JSON.stringify(row.data)` did before storing.

const std = @import("std");
const Row = @import("store.zig").Row;

pub const ParsedPush = struct {
    parsed: std.json.Parsed(std.json.Value),
    rows: []Row,
    /// Owned `data` JSON buffers, freed on deinit (rows[i].data points here).
    data_bufs: [][]u8,
    gpa: std.mem.Allocator,

    pub fn deinit(self: *ParsedPush) void {
        for (self.data_bufs) |buf| self.gpa.free(buf);
        self.gpa.free(self.data_bufs);
        self.gpa.free(self.rows);
        self.parsed.deinit();
    }
};

pub const ParseError = error{ NotAnObject, MissingRows } || std.mem.Allocator.Error;

/// Parse a push body. Malformed individual rows are skipped (lenient), but a
/// body that isn't `{"rows":[...]}` is rejected.
pub fn parsePush(gpa: std.mem.Allocator, body: []const u8) !ParsedPush {
    const parsed = try std.json.parseFromSlice(std.json.Value, gpa, body, .{});
    errdefer parsed.deinit();

    if (parsed.value != .object) return error.NotAnObject;
    const rows_val = parsed.value.object.get("rows") orelse return error.MissingRows;
    if (rows_val != .array) return error.MissingRows;

    const items = rows_val.array.items;
    var rows = try std.ArrayList(Row).initCapacity(gpa, items.len);
    errdefer rows.deinit(gpa);
    var data_bufs = try std.ArrayList([]u8).initCapacity(gpa, items.len);
    errdefer {
        for (data_bufs.items) |b| gpa.free(b);
        data_bufs.deinit(gpa);
    }

    for (items) |item| {
        if (item != .object) continue;
        const obj = item.object;
        const table = asString(obj.get("table") orelse continue) orelse continue;
        const id = asString(obj.get("id") orelse continue) orelse continue;
        const updated_at = asInt(obj.get("updated_at") orelse continue) orelse continue;
        const data_val = obj.get("data") orelse continue;

        const data_buf = try std.json.Stringify.valueAlloc(gpa, data_val, .{});
        try data_bufs.append(gpa, data_buf);
        try rows.append(gpa, .{
            .table = table,
            .id = id,
            .data = data_buf,
            .updated_at = updated_at,
        });
    }

    return .{
        .parsed = parsed,
        .rows = try rows.toOwnedSlice(gpa),
        .data_bufs = try data_bufs.toOwnedSlice(gpa),
        .gpa = gpa,
    };
}

fn asString(v: std.json.Value) ?[]const u8 {
    return switch (v) {
        .string => |s| s,
        else => null,
    };
}

fn asInt(v: std.json.Value) ?i64 {
    return switch (v) {
        .integer => |i| i,
        .number_string => |s| std.fmt.parseInt(i64, s, 10) catch null,
        .float => |f| @intFromFloat(f),
        else => null,
    };
}

test "parsePush extracts rows and re-serializes data" {
    const gpa = std.testing.allocator;
    const body =
        \\{"rows":[
        \\  {"table":"cards","id":"abc","data":{"ct":"enc","n":"xx"},"updated_at":1717000000000},
        \\  {"table":"packs","id":"main","data":{"ct":"zz"},"updated_at":42}
        \\]}
    ;
    var push = try parsePush(gpa, body);
    defer push.deinit();

    try std.testing.expectEqual(@as(usize, 2), push.rows.len);
    try std.testing.expectEqualStrings("cards", push.rows[0].table);
    try std.testing.expectEqualStrings("abc", push.rows[0].id);
    try std.testing.expectEqual(@as(i64, 1717000000000), push.rows[0].updated_at);
    // data round-trips as valid JSON (key order may differ from input).
    try std.testing.expect(std.mem.indexOf(u8, push.rows[0].data, "\"ct\":\"enc\"") != null);
    try std.testing.expectEqualStrings("main", push.rows[1].id);
}

test "parsePush skips malformed rows but keeps valid ones" {
    const gpa = std.testing.allocator;
    const body =
        \\{"rows":[
        \\  {"table":"t","id":"ok","data":{},"updated_at":10},
        \\  {"table":"t","data":{},"updated_at":10},
        \\  {"id":"x","data":{},"updated_at":10}
        \\]}
    ;
    var push = try parsePush(gpa, body);
    defer push.deinit();
    try std.testing.expectEqual(@as(usize, 1), push.rows.len);
    try std.testing.expectEqualStrings("ok", push.rows[0].id);
}

test "parsePush rejects a non-object body" {
    const gpa = std.testing.allocator;
    try std.testing.expectError(error.NotAnObject, parsePush(gpa, "[1,2,3]"));
}
