const std = @import("std");

pub const Rating = enum(u8) {
    again = 1,
    hard = 2,
    good = 3,
    easy = 4,

    pub fn fromInt(v: u8) ?Rating {
        return switch (v) {
            1 => .again,
            2 => .hard,
            3 => .good,
            4 => .easy,
            else => null,
        };
    }
};

pub const Card = struct {
    id: []const u8,
    word: []const u8,
    language: []const u8,
    pinyin: ?[]const u8,
    translation: ?[]const u8,
    source_type: []const u8,
};

pub const FSRSState = struct {
    difficulty: f64 = 5.0,
    stability: f64 = 0.0,
    reps: u32 = 0,
    lapses: u32 = 0,
    last_review: ?[]const u8 = null,
    next_review: ?[]const u8 = null,
};

pub const IntervalInfo = struct {
    rating: Rating,
    interval_days: f64,
    new_stability: f64,
    new_difficulty: f64,
};

pub const ScheduleOutput = struct {
    again: IntervalInfo,
    hard: IntervalInfo,
    good: IntervalInfo,
    easy: IntervalInfo,
};

// --- Hand-written JSON helpers (no std.json, keeps WASM small) ---

pub const JsonWriter = struct {
    buf: []u8,
    pos: usize = 0,

    pub fn init(buf: []u8) JsonWriter {
        return .{ .buf = buf };
    }

    pub fn written(self: *const JsonWriter) []const u8 {
        return self.buf[0..self.pos];
    }

    pub fn writeByte(self: *JsonWriter, b: u8) void {
        if (self.pos < self.buf.len) {
            self.buf[self.pos] = b;
            self.pos += 1;
        }
    }

    pub fn writeStr(self: *JsonWriter, s: []const u8) void {
        for (s) |b| self.writeByte(b);
    }

    pub fn writeJsonString(self: *JsonWriter, s: []const u8) void {
        self.writeByte('"');
        for (s) |c| {
            switch (c) {
                '"' => {
                    self.writeByte('\\');
                    self.writeByte('"');
                },
                '\\' => {
                    self.writeByte('\\');
                    self.writeByte('\\');
                },
                '\n' => {
                    self.writeByte('\\');
                    self.writeByte('n');
                },
                '\r' => {
                    self.writeByte('\\');
                    self.writeByte('r');
                },
                '\t' => {
                    self.writeByte('\\');
                    self.writeByte('t');
                },
                else => self.writeByte(c),
            }
        }
        self.writeByte('"');
    }

    pub fn writeKey(self: *JsonWriter, key: []const u8) void {
        self.writeJsonString(key);
        self.writeByte(':');
    }

    pub fn writeInt(self: *JsonWriter, val: i64) void {
        var tmp: [24]u8 = undefined;
        const s = intToStr(val, &tmp);
        self.writeStr(s);
    }

    pub fn writeFloat(self: *JsonWriter, val: f64) void {
        // Write float with 1 decimal place
        const negative = val < 0;
        const abs_val = if (negative) -val else val;
        const int_part: i64 = @intFromFloat(abs_val);
        const frac = abs_val - @as(f64, @floatFromInt(int_part));
        const frac_digit: u8 = @intFromFloat(frac * 10.0 + 0.5);

        if (negative) self.writeByte('-');
        self.writeInt(int_part);
        self.writeByte('.');
        self.writeByte(@as(u8, '0') + @min(frac_digit, 9));
    }

    pub fn writeNull(self: *JsonWriter) void {
        self.writeStr("null");
    }
};

fn intToStr(val: i64, buf: *[24]u8) []const u8 {
    if (val == 0) {
        buf[23] = '0';
        return buf[23..24];
    }
    var v: u64 = if (val < 0) @intCast(-val) else @intCast(val);
    var pos: usize = 24;
    while (v > 0) {
        pos -= 1;
        buf[pos] = @intCast('0' + (v % 10));
        v /= 10;
    }
    if (val < 0) {
        pos -= 1;
        buf[pos] = '-';
    }
    return buf[pos..24];
}

test "intToStr basics" {
    var buf: [24]u8 = undefined;
    try std.testing.expectEqualStrings("0", intToStr(0, &buf));
    try std.testing.expectEqualStrings("42", intToStr(42, &buf));
    try std.testing.expectEqualStrings("-7", intToStr(-7, &buf));
    try std.testing.expectEqualStrings("1000", intToStr(1000, &buf));
}

test "JsonWriter string escaping" {
    var buf: [64]u8 = undefined;
    var w = JsonWriter.init(&buf);
    w.writeJsonString("hello \"world\"\n");
    try std.testing.expectEqualStrings("\"hello \\\"world\\\"\\n\"", w.written());
}
