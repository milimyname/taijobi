// Language detection via Unicode ranges + heuristics.
// Simple and good enough for 95% of cases.

const std = @import("std");

pub const Language = enum {
    zh, // Chinese (CJK Unified Ideographs)
    de, // German
    en, // English (fallback)

    pub fn code(self: Language) []const u8 {
        return switch (self) {
            .zh => "zh",
            .de => "de",
            .en => "en",
        };
    }
};

/// Detect language from a word or short phrase.
pub fn detect(text: []const u8) Language {
    if (text.len == 0) return .en;

    var has_cjk = false;
    var has_german_marker = false;
    var i: usize = 0;

    while (i < text.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(text[i]) catch {
            i += 1;
            continue;
        };
        if (i + cp_len > text.len) break;

        const cp = std.unicode.utf8Decode(text[i..][0..cp_len]) catch {
            i += cp_len;
            continue;
        };

        if (isCJK(cp)) {
            has_cjk = true;
        }

        if (isGermanMarker(cp)) {
            has_german_marker = true;
        }

        i += cp_len;
    }

    // CJK wins — even a single CJK char means Chinese
    if (has_cjk) return .zh;

    // German markers: umlauts, eszett
    if (has_german_marker) return .de;

    // Check for common German letter patterns (lowercase)
    if (hasGermanPatterns(text)) return .de;

    return .en;
}

fn isCJK(cp: u21) bool {
    // CJK Unified Ideographs
    if (cp >= 0x4E00 and cp <= 0x9FFF) return true;
    // CJK Extension A
    if (cp >= 0x3400 and cp <= 0x4DBF) return true;
    // CJK Extension B
    if (cp >= 0x20000 and cp <= 0x2A6DF) return true;
    // CJK Compatibility Ideographs
    if (cp >= 0xF900 and cp <= 0xFAFF) return true;
    // Bopomofo, Kangxi Radicals
    if (cp >= 0x2F00 and cp <= 0x2FDF) return true;
    if (cp >= 0x3100 and cp <= 0x312F) return true;
    return false;
}

fn isGermanMarker(cp: u21) bool {
    return switch (cp) {
        '\u{00E4}', '\u{00F6}', '\u{00FC}' => true, // ä ö ü
        '\u{00C4}', '\u{00D6}', '\u{00DC}' => true, // Ä Ö Ü
        '\u{00DF}' => true, // ß
        else => false,
    };
}

fn hasGermanPatterns(text: []const u8) bool {
    // Common German bigrams/trigrams not typical in English
    const patterns = [_][]const u8{ "sch", "ch", "ung", "heit", "keit", "lich", "isch" };
    const lower_buf_size = 128;
    var lower: [lower_buf_size]u8 = undefined;
    const len = @min(text.len, lower_buf_size);
    for (text[0..len], 0..) |c, j| {
        lower[j] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    const s = lower[0..len];
    for (patterns) |p| {
        if (std.mem.indexOf(u8, s, p) != null) return true;
    }
    return false;
}

// --- Tests ---

test "detect Chinese" {
    try std.testing.expectEqual(Language.zh, detect("\u{4F60}\u{597D}"));
    try std.testing.expectEqual(Language.zh, detect("\u{5B66}\u{4E60}"));
    try std.testing.expectEqual(Language.zh, detect("\u{8FC7}"));
}

test "detect German" {
    try std.testing.expectEqual(Language.de, detect("M\u{00F6}glich"));
    try std.testing.expectEqual(Language.de, detect("Stra\u{00DF}e"));
    try std.testing.expectEqual(Language.de, detect("\u{00FC}bung"));
    try std.testing.expectEqual(Language.de, detect("gleichzeitig"));
}

test "detect English fallback" {
    try std.testing.expectEqual(Language.en, detect("hello"));
    try std.testing.expectEqual(Language.en, detect("world"));
    try std.testing.expectEqual(Language.en, detect(""));
}
