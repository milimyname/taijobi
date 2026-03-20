const std = @import("std");

const HkdfSha256 = std.crypto.kdf.hkdf.HkdfSha256;
const XChaCha20Poly1305 = std.crypto.aead.chacha_poly.XChaCha20Poly1305;

const salt = "taijobi-e2e-v1";
const info = "aes-key";

/// Derive a 32-byte encryption key from a sync key using HKDF-SHA256.
pub fn deriveKey(sync_key: []const u8) [32]u8 {
    const prk = HkdfSha256.extract(salt, sync_key);
    var okm: [32]u8 = undefined;
    HkdfSha256.expand(&okm, info, prk);
    return okm;
}

/// XChaCha20-Poly1305 encrypt.
/// Writes nonce(24) + ciphertext + tag(16) into `out`.
/// Returns total bytes written: 24 + plaintext.len + 16.
pub fn encryptField(plaintext: []const u8, key: [32]u8, nonce: [24]u8, out: []u8) !usize {
    const total = 24 + plaintext.len + XChaCha20Poly1305.tag_length;
    if (out.len < total) return error.BufferTooSmall;

    // Write nonce
    @memcpy(out[0..24], &nonce);

    // Encrypt: ciphertext goes after nonce, tag goes after ciphertext
    XChaCha20Poly1305.encrypt(
        out[24 .. 24 + plaintext.len],
        out[24 + plaintext.len ..][0..XChaCha20Poly1305.tag_length],
        plaintext,
        &.{}, // no associated data
        nonce,
        key,
    );

    return total;
}

/// XChaCha20-Poly1305 decrypt.
/// Input: nonce(24) + ciphertext + tag(16).
/// Writes plaintext into `out`.
/// Returns plaintext length.
pub fn decryptField(input: []const u8, key: [32]u8, out: []u8) !usize {
    const overhead = 24 + XChaCha20Poly1305.tag_length;
    if (input.len < overhead) return error.InvalidInput;

    const plaintext_len = input.len - overhead;
    if (out.len < plaintext_len) return error.BufferTooSmall;

    const nonce: [24]u8 = input[0..24].*;
    const ciphertext = input[24 .. 24 + plaintext_len];
    const tag: [XChaCha20Poly1305.tag_length]u8 = input[24 + plaintext_len ..][0..XChaCha20Poly1305.tag_length].*;

    XChaCha20Poly1305.decrypt(
        out[0..plaintext_len],
        ciphertext,
        tag,
        &.{}, // no associated data
        nonce,
        key,
    ) catch return error.AuthenticationFailed;

    return plaintext_len;
}

// --- Tests ---

test "deriveKey produces deterministic 32-byte key" {
    const key1 = deriveKey("test-sync-key-1234");
    const key2 = deriveKey("test-sync-key-1234");
    try std.testing.expectEqual(key1, key2);

    // Different input → different key
    const key3 = deriveKey("different-key");
    try std.testing.expect(!std.mem.eql(u8, &key1, &key3));
}

test "encrypt then decrypt roundtrip" {
    const key = deriveKey("my-sync-key");
    const plaintext = "Hello, taijobi!";
    const nonce = [_]u8{1} ** 24;

    var encrypted: [256]u8 = undefined;
    const enc_len = try encryptField(plaintext, key, nonce, &encrypted);

    // Encrypted output should be nonce(24) + ciphertext(15) + tag(16) = 55
    try std.testing.expectEqual(@as(usize, 55), enc_len);

    var decrypted: [256]u8 = undefined;
    const dec_len = try decryptField(encrypted[0..enc_len], key, &decrypted);

    try std.testing.expectEqual(@as(usize, 15), dec_len);
    try std.testing.expectEqualStrings(plaintext, decrypted[0..dec_len]);
}

test "decrypt with wrong key fails" {
    const key1 = deriveKey("key-1");
    const key2 = deriveKey("key-2");
    const plaintext = "secret data";
    const nonce = [_]u8{42} ** 24;

    var encrypted: [256]u8 = undefined;
    const enc_len = try encryptField(plaintext, key1, nonce, &encrypted);

    var decrypted: [256]u8 = undefined;
    const result = decryptField(encrypted[0..enc_len], key2, &decrypted);
    try std.testing.expectError(error.AuthenticationFailed, result);
}

test "decrypt with tampered ciphertext fails" {
    const key = deriveKey("tamper-test");
    const plaintext = "important data";
    const nonce = [_]u8{7} ** 24;

    var encrypted: [256]u8 = undefined;
    const enc_len = try encryptField(plaintext, key, nonce, &encrypted);

    // Tamper with a ciphertext byte
    encrypted[30] ^= 0xff;

    var decrypted: [256]u8 = undefined;
    const result = decryptField(encrypted[0..enc_len], key, &decrypted);
    try std.testing.expectError(error.AuthenticationFailed, result);
}

test "empty plaintext encrypt/decrypt" {
    const key = deriveKey("empty-test");
    const nonce = [_]u8{0} ** 24;

    var encrypted: [256]u8 = undefined;
    const enc_len = try encryptField("", key, nonce, &encrypted);

    // nonce(24) + ciphertext(0) + tag(16) = 40
    try std.testing.expectEqual(@as(usize, 40), enc_len);

    var decrypted: [256]u8 = undefined;
    const dec_len = try decryptField(encrypted[0..enc_len], key, &decrypted);
    try std.testing.expectEqual(@as(usize, 0), dec_len);
}

test "large plaintext encrypt/decrypt" {
    const key = deriveKey("large-test");
    const nonce = [_]u8{99} ** 24;

    // 4KB plaintext
    var plaintext: [4096]u8 = undefined;
    for (&plaintext, 0..) |*b, i| b.* = @truncate(i);

    var encrypted: [4096 + 40]u8 = undefined;
    const enc_len = try encryptField(&plaintext, key, nonce, &encrypted);

    var decrypted: [4096]u8 = undefined;
    const dec_len = try decryptField(encrypted[0..enc_len], key, &decrypted);

    try std.testing.expectEqual(@as(usize, 4096), dec_len);
    try std.testing.expectEqualSlices(u8, &plaintext, decrypted[0..dec_len]);
}
