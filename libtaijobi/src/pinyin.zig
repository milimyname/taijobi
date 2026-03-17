// Pinyin utilities — tone number ↔ diacritic conversion and normalization.
//
// Used for flexible answer checking: accept both "ni3 hao3" and "nǐ hǎo".

const std = @import("std");

// Tone diacritic mappings for each vowel and tone (1-4)
const Vowel = struct {
    base: u8,
    tones: [4][]const u8,
};

const vowels = [_]Vowel{
    .{ .base = 'a', .tones = .{ "ā", "á", "ǎ", "à" } },
    .{ .base = 'e', .tones = .{ "ē", "é", "ě", "è" } },
    .{ .base = 'i', .tones = .{ "ī", "í", "ǐ", "ì" } },
    .{ .base = 'o', .tones = .{ "ō", "ó", "ǒ", "ò" } },
    .{ .base = 'u', .tones = .{ "ū", "ú", "ǔ", "ù" } },
};

// ü tones
const u_umlaut_tones = [4][]const u8{ "ǖ", "ǘ", "ǚ", "ǜ" };

/// Normalize pinyin for comparison: lowercase, strip spaces, remove tone numbers.
/// Returns a slice of the output buffer.
pub fn normalize(input: []const u8, buf: []u8) []const u8 {
    var pos: usize = 0;
    var i: usize = 0;
    while (i < input.len and pos < buf.len) {
        const byte = input[i];

        // Skip spaces
        if (byte == ' ') {
            i += 1;
            continue;
        }

        // Skip trailing tone numbers (1-5)
        if (byte >= '1' and byte <= '5') {
            i += 1;
            continue;
        }

        // Try to match diacritic vowels (multi-byte UTF-8) and convert to base
        const replaced = replaceDiacritic(input[i..], buf[pos..]);
        if (replaced.consumed > 0) {
            pos += replaced.written;
            i += replaced.consumed;
            continue;
        }

        // Lowercase ASCII
        if (byte >= 'A' and byte <= 'Z') {
            buf[pos] = byte + 32;
        } else {
            buf[pos] = byte;
        }
        pos += 1;
        i += 1;
    }
    return buf[0..pos];
}

const ReplaceResult = struct {
    consumed: usize,
    written: usize,
};

fn replaceDiacritic(input: []const u8, out: []u8) ReplaceResult {
    if (out.len == 0) return .{ .consumed = 0, .written = 0 };

    // Check each vowel's diacritic forms
    for (vowels) |v| {
        for (v.tones) |tone_str| {
            if (tone_str.len <= input.len and std.mem.eql(u8, input[0..tone_str.len], tone_str)) {
                out[0] = v.base;
                return .{ .consumed = tone_str.len, .written = 1 };
            }
        }
    }

    // Check ü diacritics
    for (u_umlaut_tones) |tone_str| {
        if (tone_str.len <= input.len and std.mem.eql(u8, input[0..tone_str.len], tone_str)) {
            // Write 'v' as normalized form of ü
            out[0] = 'v';
            return .{ .consumed = tone_str.len, .written = 1 };
        }
    }

    // Plain ü -> v
    const u_umlaut = "ü";
    if (u_umlaut.len <= input.len and std.mem.eql(u8, input[0..u_umlaut.len], u_umlaut)) {
        out[0] = 'v';
        return .{ .consumed = u_umlaut.len, .written = 1 };
    }

    return .{ .consumed = 0, .written = 0 };
}

/// Compare two pinyin strings for equivalence.
/// Normalizes both, then compares.
pub fn pinyinEqual(a: []const u8, b: []const u8) bool {
    var buf_a: [256]u8 = undefined;
    var buf_b: [256]u8 = undefined;
    const norm_a = normalize(a, &buf_a);
    const norm_b = normalize(b, &buf_b);
    return std.mem.eql(u8, norm_a, norm_b);
}

// --- Tests ---

test "normalize tone numbers" {
    var buf: [256]u8 = undefined;
    const result = normalize("ni3 hao3", &buf);
    try std.testing.expectEqualStrings("nihao", result);
}

test "normalize diacritics" {
    var buf: [256]u8 = undefined;
    const result = normalize("nǐ hǎo", &buf);
    try std.testing.expectEqualStrings("nihao", result);
}

test "normalize mixed case" {
    var buf: [256]u8 = undefined;
    const result = normalize("Ni3 Hao3", &buf);
    try std.testing.expectEqualStrings("nihao", result);
}

test "pinyin equal different formats" {
    try std.testing.expect(pinyinEqual("ni3 hao3", "nǐ hǎo"));
    try std.testing.expect(pinyinEqual("ni3hao3", "nǐhǎo"));
    try std.testing.expect(pinyinEqual("NI3 HAO3", "nǐ hǎo"));
}

test "pinyin not equal" {
    try std.testing.expect(!pinyinEqual("ni3", "na3"));
    try std.testing.expect(!pinyinEqual("hao3", "hei1"));
}

test "normalize u umlaut" {
    var buf: [256]u8 = undefined;
    const result = normalize("lǜ", &buf);
    try std.testing.expectEqualStrings("lv", result);
}
