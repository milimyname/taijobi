//! Web Push delivery — the native port of `taijobi-sync/src/push-send.ts`.
//!
//! VAPID JWT signing (RFC 8292, ES256) + payload encryption (RFC 8291,
//! aes128gcm per RFC 8188), all on `std.crypto`. Sending goes through
//! `std.http.Client` (TLS verified against the system CA bundle).
//!
//! The streak cron (`runCron`) mirrors the Worker's `scheduled()` handler:
//! subscriptions whose last review is 20–28 h old and that haven't been
//! notified in 18 h get one push; 410 Gone deletes the subscription.

const std = @import("std");
const Store = @import("store.zig").Store;

const P256 = std.crypto.ecc.P256;
const Ecdsa = std.crypto.sign.ecdsa.EcdsaP256Sha256;
const Hkdf = std.crypto.kdf.hkdf.HkdfSha256;
const Aes128Gcm = std.crypto.aead.aes_gcm.Aes128Gcm;
const b64url = std.base64.url_safe_no_pad;

extern fn arc4random_buf(buf: [*]u8, len: usize) void;

const VAPID_SUBJECT = "mailto:taijobi@mili-my.name";
const RECORD_SIZE: u32 = 4096;
const PUBLIC_KEY_LEN = 65; // uncompressed SEC1 P-256 point

pub const Vapid = struct {
    key_pair: Ecdsa.KeyPair,
    /// base64url of the uncompressed public key — the `k=` in the VAPID header
    /// and what browsers subscribed with (`VAPID_PUBLIC_KEY` in wrangler.toml).
    public_b64: [87]u8,

    /// Load from the Worker's secret format: a P-256 private JWK
    /// (`{"kty":"EC","crv":"P-256","d":"…","x":"…","y":"…"}`). Only `d` is needed.
    pub fn fromJwk(gpa: std.mem.Allocator, jwk: []const u8) !Vapid {
        const parsed = try std.json.parseFromSlice(std.json.Value, gpa, jwk, .{});
        defer parsed.deinit();
        if (parsed.value != .object) return error.InvalidJwk;
        const d = switch (parsed.value.object.get("d") orelse return error.InvalidJwk) {
            .string => |s| s,
            else => return error.InvalidJwk,
        };
        var secret: [32]u8 = undefined;
        if ((b64url.Decoder.calcSizeForSlice(d) catch return error.InvalidJwk) != 32) return error.InvalidJwk;
        try b64url.Decoder.decode(&secret, d);
        const kp = try Ecdsa.KeyPair.fromSecretKey(try Ecdsa.SecretKey.fromBytes(secret));
        var v = Vapid{ .key_pair = kp, .public_b64 = undefined };
        _ = b64url.Encoder.encode(&v.public_b64, &kp.public_key.toUncompressedSec1());
        return v;
    }

    /// `vapid t=<jwt>, k=<public key>` for an endpoint's origin.
    fn authorization(self: Vapid, gpa: std.mem.Allocator, audience: []const u8, now_s: i64) ![]u8 {
        const header_b64 = comptime blk: {
            const h = "{\"typ\":\"JWT\",\"alg\":\"ES256\"}";
            var out: [b64url.Encoder.calcSize(h.len)]u8 = undefined;
            _ = b64url.Encoder.encode(&out, h);
            break :blk out;
        };
        const claims = try std.fmt.allocPrint(gpa, "{{\"aud\":\"{s}\",\"exp\":{d},\"sub\":\"" ++ VAPID_SUBJECT ++ "\"}}", .{ audience, now_s + 12 * 3600 });
        defer gpa.free(claims);
        const claims_b64 = try gpa.alloc(u8, b64url.Encoder.calcSize(claims.len));
        defer gpa.free(claims_b64);
        _ = b64url.Encoder.encode(claims_b64, claims);

        const signing_input = try std.fmt.allocPrint(gpa, "{s}.{s}", .{ &header_b64, claims_b64 });
        defer gpa.free(signing_input);
        const sig = try self.key_pair.sign(signing_input, null);
        var sig_b64: [86]u8 = undefined;
        _ = b64url.Encoder.encode(&sig_b64, &sig.toBytes()); // JOSE: raw r || s

        return std.fmt.allocPrint(gpa, "vapid t={s}.{s}, k={s}", .{ signing_input, &sig_b64, &self.public_b64 });
    }
};

/// RFC 8291 encryption with caller-supplied ephemeral secret + salt (the
/// public `encrypt` draws them at random; tests pin them to the RFC vector).
fn encryptWith(
    gpa: std.mem.Allocator,
    payload: []const u8,
    ua_public: [PUBLIC_KEY_LEN]u8,
    auth_secret: [16]u8,
    local_secret: [32]u8,
    salt: [16]u8,
) ![]u8 {
    const ua_point = try P256.fromSec1(&ua_public);
    const local_public = (try P256.basePoint.mul(local_secret, .big)).toUncompressedSec1();
    const shared = (try ua_point.mul(local_secret, .big)).affineCoordinates().x.toBytes(.big);

    // IKM = HKDF(auth_secret, ecdh_secret, "WebPush: info\0" || ua_public || as_public, 32)
    var key_info: [14 + 2 * PUBLIC_KEY_LEN]u8 = undefined;
    @memcpy(key_info[0..14], "WebPush: info\x00");
    @memcpy(key_info[14..][0..PUBLIC_KEY_LEN], &ua_public);
    @memcpy(key_info[14 + PUBLIC_KEY_LEN ..], &local_public);
    var ikm: [32]u8 = undefined;
    Hkdf.expand(&ikm, &key_info, Hkdf.extract(&auth_secret, &shared));

    const prk = Hkdf.extract(&salt, &ikm);
    var cek: [16]u8 = undefined;
    Hkdf.expand(&cek, "Content-Encoding: aes128gcm\x00", prk);
    var nonce: [12]u8 = undefined;
    Hkdf.expand(&nonce, "Content-Encoding: nonce\x00", prk);

    // Header: salt (16) || rs (u32 BE) || idlen (1) || keyid (sender public key)
    const header_len = 16 + 4 + 1 + PUBLIC_KEY_LEN;
    const plain_len = payload.len + 1; // + 0x02 delimiter (last record, no padding)
    const out = try gpa.alloc(u8, header_len + plain_len + Aes128Gcm.tag_length);
    errdefer gpa.free(out);
    @memcpy(out[0..16], &salt);
    std.mem.writeInt(u32, out[16..20], RECORD_SIZE, .big);
    out[20] = PUBLIC_KEY_LEN;
    @memcpy(out[21..header_len], &local_public);

    const plain = try gpa.alloc(u8, plain_len);
    defer gpa.free(plain);
    @memcpy(plain[0..payload.len], payload);
    plain[payload.len] = 0x02;

    const ct = out[header_len..][0..plain_len];
    const tag = out[header_len + plain_len ..][0..Aes128Gcm.tag_length];
    Aes128Gcm.encrypt(ct, tag, plain, "", nonce, cek);
    return out;
}

/// Encrypt `payload` for a subscription's `p256dh` + `auth` (base64url).
pub fn encrypt(gpa: std.mem.Allocator, payload: []const u8, p256dh_b64: []const u8, auth_b64: []const u8) ![]u8 {
    var ua_public: [PUBLIC_KEY_LEN]u8 = undefined;
    if ((b64url.Decoder.calcSizeForSlice(p256dh_b64) catch return error.InvalidKey) != PUBLIC_KEY_LEN) return error.InvalidKey;
    try b64url.Decoder.decode(&ua_public, p256dh_b64);
    var auth: [16]u8 = undefined;
    if ((b64url.Decoder.calcSizeForSlice(auth_b64) catch return error.InvalidKey) != 16) return error.InvalidKey;
    try b64url.Decoder.decode(&auth, auth_b64);

    var local_secret: [32]u8 = undefined;
    var salt: [16]u8 = undefined;
    // A random 32-byte string is a valid P-256 scalar with overwhelming
    // probability; retry on the astronomically rare zero / out-of-range draw.
    while (true) {
        arc4random_buf(&local_secret, local_secret.len);
        arc4random_buf(&salt, salt.len);
        return encryptWith(gpa, payload, ua_public, auth, local_secret, salt) catch |err| switch (err) {
            error.IdentityElement, error.NonCanonical => continue,
            else => |e| return e,
        };
    }
}

/// `scheme://host[:port]` of an endpoint URL — the VAPID audience.
fn originOf(endpoint: []const u8) ?[]const u8 {
    const scheme_end = std.mem.indexOf(u8, endpoint, "://") orelse return null;
    const host_start = scheme_end + 3;
    const path_start = std.mem.indexOfScalarPos(u8, endpoint, host_start, '/') orelse endpoint.len;
    if (path_start == host_start) return null;
    return endpoint[0..path_start];
}

pub const Subscription = struct {
    endpoint: []const u8,
    p256dh: []const u8,
    auth: []const u8,
};

/// Send one push. Returns the push service's HTTP status.
pub fn send(client: *std.http.Client, gpa: std.mem.Allocator, vapid: Vapid, sub: Subscription, payload: []const u8, now_s: i64) !std.http.Status {
    const audience = originOf(sub.endpoint) orelse return error.InvalidEndpoint;
    const auth = try vapid.authorization(gpa, audience, now_s);
    defer gpa.free(auth);
    const body = try encrypt(gpa, payload, sub.p256dh, sub.auth);
    defer gpa.free(body);

    const res = try client.fetch(.{
        .location = .{ .url = sub.endpoint },
        .method = .POST,
        .payload = body,
        .keep_alive = false,
        .headers = .{ .authorization = .{ .override = auth }, .content_type = .{ .override = "application/octet-stream" } },
        .extra_headers = &.{
            .{ .name = "content-encoding", .value = "aes128gcm" },
            .{ .name = "ttl", .value = "86400" },
        },
    });
    return res.status;
}

/// Streak reminder text, same as the Worker's cron payload.
pub const STREAK_PAYLOAD = "{\"title\":\"🔥 Streak-Erinnerung\",\"body\":\"Dein Streak droht zu brechen — jetzt üben!\",\"url\":\"/drill\"}";

/// One cron tick: push every due subscription, mark successes, drop 410s.
pub fn runCron(gpa: std.mem.Allocator, io: std.Io, store: *Store, vapid: Vapid) void {
    const now_ms = std.Io.Clock.now(.real, io).toMilliseconds();
    var due = store.pushDue(gpa, now_ms) catch |err| {
        std.debug.print("[push-cron] query failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer due.deinit();
    if (due.subs.len == 0) return;

    var client: std.http.Client = .{ .allocator = gpa, .io = io };
    defer client.deinit();

    var ok: usize = 0;
    var failed: usize = 0;
    for (due.subs) |sub| {
        const status = send(&client, gpa, vapid, .{ .endpoint = sub.endpoint, .p256dh = sub.p256dh, .auth = sub.auth }, STREAK_PAYLOAD, @divTrunc(now_ms, 1000)) catch |err| {
            failed += 1;
            std.debug.print("[push-cron] send error: {s}\n", .{@errorName(err)});
            continue;
        };
        const code = @backingInt(status);
        if (code >= 200 and code < 300) {
            ok += 1;
            store.pushNotified(sub.sync_key_hash, now_ms) catch {};
        } else {
            failed += 1;
            std.debug.print("[push-cron] {s}… → HTTP {d}\n", .{ sub.sync_key_hash[0..@min(8, sub.sync_key_hash.len)], code });
            // 410 Gone / 404 = the subscription expired (FCM uses 404 for dead
            // tokens; the Worker only handled 410); stop trying.
            if (status == .gone or status == .not_found) store.pushUnsubscribe(sub.sync_key_hash) catch {};
        }
    }
    std.debug.print("[push-cron] Sent {d} pushes: {d} ok, {d} failed\n", .{ due.subs.len, ok, failed });
}

/// Background thread: run the cron at the top of every hour (the Worker's
/// `0 * * * *`). `run_now` fires one tick immediately — for testing, like
/// `wrangler dev --test-scheduled`.
pub fn cronThread(gpa: std.mem.Allocator, io: std.Io, store: *Store, vapid: Vapid, run_now: bool) void {
    if (run_now) runCron(gpa, io, store, vapid);
    while (true) {
        const now_ms = std.Io.Clock.now(.real, io).toMilliseconds();
        const hour_ms: i64 = 3600 * 1000;
        const wait_ms = hour_ms - @mod(now_ms, hour_ms);
        io.sleep(.fromMilliseconds(wait_ms), .real) catch return;
        runCron(gpa, io, store, vapid);
    }
}

/// Lowercase hex SHA-256 of a sync key — subscriptions are stored under the
/// hash, never the raw key (same as the Worker).
pub fn hashSyncKey(key: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(key, &digest, .{});
    var out: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&out, "{x}", .{&digest}) catch unreachable;
    return out;
}

fn decodeFixed(comptime n: usize, s: []const u8) ![n]u8 {
    var out: [n]u8 = undefined;
    if ((try b64url.Decoder.calcSizeForSlice(s)) != n) return error.BadLength;
    try b64url.Decoder.decode(&out, s);
    return out;
}

test "RFC 8291 section 5 test vector" {
    const gpa = std.testing.allocator;
    const body = try encryptWith(
        gpa,
        "When I grow up, I want to be a watermelon",
        try decodeFixed(65, "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4"),
        try decodeFixed(16, "BTBZMqHH6r4Tts7J_aSIgg"),
        try decodeFixed(32, "yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw"),
        try decodeFixed(16, "DGv6ra1nlYgDCS1FRnbzlw"),
    );
    defer gpa.free(body);
    const expected = "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPTpK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN";
    const got = try gpa.alloc(u8, b64url.Encoder.calcSize(body.len));
    defer gpa.free(got);
    try std.testing.expectEqualStrings(expected, b64url.Encoder.encode(got, body));
}

test "VAPID JWT verifies against the derived public key" {
    const gpa = std.testing.allocator;
    // Throwaway key generated for this test only.
    const jwk = "{\"kty\":\"EC\",\"crv\":\"P-256\",\"d\":\"yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw\"}";
    const vapid = try Vapid.fromJwk(gpa, jwk);
    const header = try vapid.authorization(gpa, "https://fcm.googleapis.com", 1_700_000_000);
    defer gpa.free(header);

    // "vapid t=<h>.<c>.<sig>, k=<pub>"
    const t_start = "vapid t=".len;
    const comma = std.mem.indexOf(u8, header, ", k=").?;
    const jwt = header[t_start..comma];
    try std.testing.expectEqualStrings(&vapid.public_b64, header[comma + 4 ..]);
    const last_dot = std.mem.lastIndexOfScalar(u8, jwt, '.').?;
    const sig = Ecdsa.Signature.fromBytes(try decodeFixed(64, jwt[last_dot + 1 ..]));
    try sig.verify(jwt[0..last_dot], vapid.key_pair.public_key);

    // Claims decode to the audience + 12 h expiry.
    const first_dot = std.mem.indexOfScalar(u8, jwt, '.').?;
    const claims_b64 = jwt[first_dot + 1 .. last_dot];
    const claims = try gpa.alloc(u8, try b64url.Decoder.calcSizeForSlice(claims_b64));
    defer gpa.free(claims);
    try b64url.Decoder.decode(claims, claims_b64);
    try std.testing.expectEqualStrings("{\"aud\":\"https://fcm.googleapis.com\",\"exp\":1700043200,\"sub\":\"mailto:taijobi@mili-my.name\"}", claims);
}

test "originOf and hashSyncKey" {
    try std.testing.expectEqualStrings("https://fcm.googleapis.com", originOf("https://fcm.googleapis.com/fcm/send/abc").?);
    try std.testing.expectEqualStrings("https://web.push.apple.com", originOf("https://web.push.apple.com").?);
    try std.testing.expect(originOf("not a url") == null);
    // Matches the Worker's crypto.subtle SHA-256 hex.
    try std.testing.expectEqualStrings("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae", &hashSyncKey("foo"));
}
