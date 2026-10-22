//! MCP (Model Context Protocol) over Streamable HTTP — the native port of
//! `../taijobi-sync/src/mcp-tools.ts` + `mcp-session.ts`. Structure follows
//! wimg's `wimg-sync-zig/src/mcp.zig`.
//!
//! Ten tools, same names, arguments and result shapes as the Worker:
//!   read:  due_count, get_due_cards, search_cards, get_lexicon, list_packs, get_stats
//!   write: add_word, review_card, install_pack, add_lesson_to_pack
//!
//! libtaijobi is a singleton (one global DB + one fixed-buffer arena), so MCP
//! requests are serialized by `lib_spin`. Per request we load the caller's
//! decrypted rows into a fresh in-memory libtaijobi DB, run the tool, and (for
//! writes) re-encrypt the changed rows back into our own Store so they persist
//! and fan out over WebSocket.
//!
//! Transport: MCP 2026-07-28 only (stateless). Every request carries its
//! version in `_meta["io.modelcontextprotocol/protocolVersion"]`; there is no
//! handshake and no session. `server/discover`, mirrored-header validation,
//! `resultType` + cache hints. Older initialize-based clients get a 400
//! `UnsupportedProtocolVersion` naming the one version we speak.
//!
//! Natively we share libtaijobi's address space, so strings are passed by
//! (ptr, len) directly — no `hanzi_alloc` bounce. Every length-prefixed result
//! lives in libtaijobi's arena, which `hanzi_reset_alloc` resets wholesale; so
//! each result is copied out immediately.

const std = @import("std");
const store_mod = @import("store.zig");
const Store = store_mod.Store;
const Row = store_mod.Row;

// --- libtaijobi C ABI (resolved at link time) ---
extern fn hanzi_init(path: [*:0]const u8) i32;
extern fn hanzi_close() void;
extern fn hanzi_reset_alloc() void;
extern fn hanzi_get_error() ?[*]const u8;
extern fn hanzi_get_due_count() i32;
extern fn hanzi_get_due_count_filtered(filter: [*]const u8, filter_len: usize) i32;
extern fn hanzi_get_due_cards(limit: u32) ?[*]const u8;
extern fn hanzi_get_due_cards_filtered(filter: [*]const u8, filter_len: usize, limit: u32) ?[*]const u8;
extern fn hanzi_search_cards(query: [*]const u8, query_len: usize, limit: u32) ?[*]const u8;
extern fn hanzi_get_lexicon() ?[*]const u8;
extern fn hanzi_get_stats(days: u32) ?[*]const u8;
extern fn hanzi_get_packs() ?[*]const u8;
extern fn hanzi_add_word(word: [*]const u8, len: usize) ?[*]const u8;
extern fn hanzi_review_card(id: [*]const u8, id_len: usize, rating: u8) i32;
extern fn hanzi_install_pack(json: [*]const u8, len: usize) i32;
extern fn hanzi_add_lesson_to_pack(pack_id: [*]const u8, pack_id_len: usize, lesson: [*]const u8, lesson_len: usize) i32;
extern fn hanzi_get_changes(since_ts: i64) ?[*]const u8;
extern fn hanzi_apply_changes(data: [*]const u8, len: u32) i32;
extern fn hanzi_derive_key(sync_key: [*]const u8, sync_key_len: u32) ?[*]const u8;
extern fn hanzi_encrypt_field(pt: [*]const u8, pt_len: u32, key: [*]const u8, nonce: [*]const u8) ?[*]const u8;
extern fn hanzi_decrypt_field(ct: [*]const u8, ct_len: u32, key: [*]const u8) ?[*]const u8;

// libc CSPRNG for the encryption nonce (macOS + glibc ≥ 2.36 / BSD).
extern fn arc4random_buf(buf: [*]u8, len: usize) void;

/// libtaijobi's global DB + arena are process-wide singletons, so all MCP work
/// is serialized on this lock.
var lib_spin: SpinLock = .{};

const SpinLock = struct {
    locked: std.atomic.Value(bool) = .init(false),
    fn lock(self: *SpinLock) void {
        while (self.locked.cmpxchgWeak(false, true, .acquire, .monotonic) != null) std.atomic.spinLoopHint();
    }
    fn unlock(self: *SpinLock) void {
        self.locked.store(false, .release);
    }
};

pub const RpcResult = struct {
    /// HTTP status: 400/404 for protocol errors.
    status: std.http.Status = .ok,
    /// JSON-RPC response body.
    body: []u8,
    /// `{"type":"changes","rows":[...]}` to broadcast to this key's WebSocket
    /// listeners, or null when the request made no writes.
    broadcast: ?[]u8 = null,
};

const PROTOCOL_VERSION = "2026-07-28";
const SUPPORTED_VERSIONS_JSON = "[\"" ++ PROTOCOL_VERSION ++ "\"]";
const SERVER_INFO_JSON = "{\"name\":\"taijobi\",\"version\":\"0.2.0\"}";
/// Tool list and discovery never vary per user, so shared caches may keep them.
const CACHE_HINTS_JSON = "\"ttlMs\":3600000,\"cacheScope\":\"public\"";

/// The MCP request headers the HTTP layer captured (empty when absent).
pub const Headers = struct {
    protocol_version: []const u8 = "",
    method: []const u8 = "",
    name: []const u8 = "",
};

// --- length-prefixed helpers ---

fn lenOf(ptr: [*]const u8) usize {
    return std.mem.readInt(u32, ptr[0..4], .little);
}

/// Copy a libtaijobi length-prefixed result into `gpa` memory, then reset the arena.
fn dupResult(gpa: std.mem.Allocator, ptr: ?[*]const u8) !?[]u8 {
    const p = ptr orelse return null;
    const out = try gpa.dupe(u8, p[4 .. 4 + lenOf(p)]);
    hanzi_reset_alloc();
    return out;
}

/// libtaijobi's last error message, or `fallback`.
fn lastError(gpa: std.mem.Allocator, fallback: []const u8) ![]u8 {
    if (try dupResult(gpa, hanzi_get_error())) |msg| return msg;
    return gpa.dupe(u8, fallback);
}

// --- public entry point ---

/// Handle one JSON-RPC request body. Caller holds nothing; this serializes on
/// the libtaijobi lock internally. Returned slices are owned by `gpa`.
pub fn handleRpc(gpa: std.mem.Allocator, store: *Store, key: []const u8, body: []const u8, headers: Headers) !RpcResult {
    const parsed = std.json.parseFromSlice(std.json.Value, gpa, body, .{}) catch
        return rpcError(gpa, null, .bad_request, -32700, "Parse error", null);
    defer parsed.deinit();
    if (parsed.value != .object) return rpcError(gpa, null, .bad_request, -32600, "Invalid request", null);
    const obj = parsed.value.object;

    const method = switch (obj.get("method") orelse return rpcError(gpa, null, .bad_request, -32600, "Missing method", null)) {
        .string => |s| s,
        else => return rpcError(gpa, null, .bad_request, -32600, "Invalid method", null),
    };

    // Echo the request id verbatim (number, string, or null).
    const id_json: ?[]u8 = if (obj.get("id")) |v|
        try std.json.Stringify.valueAlloc(gpa, v, .{})
    else
        null;
    defer if (id_json) |id| gpa.free(id);

    const params = obj.get("params");
    const version = metaVersion(params) orelse
        // An initialize-era client (no per-request _meta). It has no way to
        // fall forward, so name the version we speak; `requested` is what its
        // initialize asked for, when there is one.
        return unsupportedVersion(gpa, id_json, legacyRequestedVersion(params) orelse headers.protocol_version);
    if (!std.mem.eql(u8, version, PROTOCOL_VERSION)) return unsupportedVersion(gpa, id_json, version);

    // Mirrored headers must be present and match the body (SEP-2243), so a
    // gateway routing on headers can't be steered apart from what we execute.
    if (!std.mem.eql(u8, headers.protocol_version, version))
        return rpcError(gpa, id_json, .bad_request, -32020, "Header mismatch: MCP-Protocol-Version", null);
    if (!std.mem.eql(u8, headers.method, method))
        return rpcError(gpa, id_json, .bad_request, -32020, "Header mismatch: Mcp-Method", null);
    if (std.mem.eql(u8, method, "tools/call")) {
        const body_name = if (params) |p| (if (p == .object) optStr(p.object, "name") else null) else null;
        var name_buf: [256]u8 = undefined;
        const header_name = decodeHeaderValue(headers.name, &name_buf) orelse
            return rpcError(gpa, id_json, .bad_request, -32020, "Header mismatch: Mcp-Name malformed", null);
        if (body_name == null or !std.mem.eql(u8, header_name, body_name.?))
            return rpcError(gpa, id_json, .bad_request, -32020, "Header mismatch: Mcp-Name", null);
    }

    if (std.mem.eql(u8, method, "server/discover")) {
        return .{ .body = try result(gpa, id_json, "{\"supportedVersions\":" ++ SUPPORTED_VERSIONS_JSON ++
            ",\"capabilities\":{\"tools\":{}},\"instructions\":\"taijobi vocabulary trainer: read due cards, stats and the lexicon; add words, record reviews, install packs. Call list_packs before install_pack or add_lesson_to_pack.\"," ++ CACHE_HINTS_JSON ++ "}") };
    }
    if (std.mem.eql(u8, method, "tools/list")) {
        // TOOLS_LIST is `{"tools":[...]}` — splice the cache hints in before its closing brace.
        const with_hints = TOOLS_LIST[0 .. TOOLS_LIST.len - 1] ++ "," ++ CACHE_HINTS_JSON ++ "}";
        return .{ .body = try result(gpa, id_json, with_hints) };
    }
    if (std.mem.eql(u8, method, "tools/call")) {
        return handleToolCall(gpa, store, key, id_json, params);
    }
    // initialize, ping, notifications and the rest don't exist in 2026-07-28.
    return rpcError(gpa, id_json, .not_found, -32601, "Method not found", null);
}

/// `params._meta["io.modelcontextprotocol/protocolVersion"]`.
fn metaVersion(params: ?std.json.Value) ?[]const u8 {
    const p = params orelse return null;
    if (p != .object) return null;
    const meta = p.object.get("_meta") orelse return null;
    if (meta != .object) return null;
    return optStr(meta.object, "io.modelcontextprotocol/protocolVersion");
}

/// `params.protocolVersion` — what an old client's `initialize` asks for.
fn legacyRequestedVersion(params: ?std.json.Value) ?[]const u8 {
    const p = params orelse return null;
    return if (p == .object) optStr(p.object, "protocolVersion") else null;
}

fn unsupportedVersion(gpa: std.mem.Allocator, id_json: ?[]u8, requested: []const u8) !RpcResult {
    var data: std.ArrayList(u8) = .empty;
    defer data.deinit(gpa);
    try data.appendSlice(gpa, "{\"supported\":" ++ SUPPORTED_VERSIONS_JSON ++ ",\"requested\":");
    if (requested.len > 0) try appendJsonString(gpa, &data, requested) else try data.appendSlice(gpa, "null");
    try data.append(gpa, '}');
    return rpcError(gpa, id_json, .bad_request, -32022, "Unsupported protocol version (this server speaks " ++ PROTOCOL_VERSION ++ " only)", data.items);
}

/// Decode an `Mcp-Name` value: plain ASCII, or the `=?base64?…?=` sentinel.
fn decodeHeaderValue(value: []const u8, buf: []u8) ?[]const u8 {
    const prefix = "=?base64?";
    const suffix = "?=";
    if (!(std.mem.startsWith(u8, value, prefix) and std.mem.endsWith(u8, value, suffix) and value.len >= prefix.len + suffix.len))
        return value;
    const enc = value[prefix.len .. value.len - suffix.len];
    const n = std.base64.standard.Decoder.calcSizeForSlice(enc) catch return null;
    if (n > buf.len) return null;
    std.base64.standard.Decoder.decode(buf[0..n], enc) catch return null;
    return buf[0..n];
}

fn rpcError(gpa: std.mem.Allocator, id_json: ?[]u8, status: std.http.Status, code: i32, message: []const u8, data: ?[]const u8) !RpcResult {
    const id = id_json orelse "null";
    const body = if (data) |d|
        try std.fmt.allocPrint(gpa, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"error\":{{\"code\":{d},\"message\":\"{s}\",\"data\":{s}}}}}", .{ id, code, message, d })
    else
        try std.fmt.allocPrint(gpa, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"error\":{{\"code\":{d},\"message\":\"{s}\"}}}}", .{ id, code, message });
    return .{ .body = body, .status = status };
}

const Tool = enum {
    due_count,
    get_due_cards,
    search_cards,
    get_lexicon,
    list_packs,
    get_stats,
    add_word,
    review_card,
    install_pack,
    add_lesson_to_pack,

    fn isWrite(self: Tool) bool {
        return switch (self) {
            .add_word, .review_card, .install_pack, .add_lesson_to_pack => true,
            else => false,
        };
    }
};

/// Per-call state: the decrypted DB is loaded, `enc_key` encrypts write-backs,
/// and `watermark` is the newest `updated_at` loaded from the Store — anything
/// libtaijobi reports past it was written by this tool call.
const Session = struct {
    gpa: std.mem.Allocator,
    store: *Store,
    key: []const u8,
    enc_key: [32]u8 = undefined,
    watermark: i64 = 0,
};

/// A tool's outcome: JSON text for the MCP `text` content, or an error message
/// the client sees as `{"error": msg}` with `isError: true` (Worker contract).
const Outcome = union(enum) {
    ok: []u8,
    err: []u8,

    fn deinit(self: Outcome, gpa: std.mem.Allocator) void {
        switch (self) {
            inline else => |s| gpa.free(s),
        }
    }
};

fn handleToolCall(gpa: std.mem.Allocator, store: *Store, key: []const u8, id_json: ?[]u8, params: ?std.json.Value) !RpcResult {
    const p = (params orelse return rpcError(gpa, id_json, .ok, -32602, "Missing params", null));
    if (p != .object) return rpcError(gpa, id_json, .ok, -32602, "Invalid params", null);
    const name = switch (p.object.get("name") orelse return rpcError(gpa, id_json, .ok, -32602, "Missing tool name", null)) {
        .string => |s| s,
        else => return rpcError(gpa, id_json, .ok, -32602, "Invalid tool name", null),
    };
    const tool = std.meta.stringToEnum(Tool, name) orelse
        return rpcError(gpa, id_json, .ok, -32602, "Unknown tool", null);
    const args: ?std.json.ObjectMap = if (p.object.get("arguments")) |a| switch (a) {
        .object => |o| o,
        else => null,
    } else null;

    lib_spin.lock();
    defer lib_spin.unlock();

    // Fresh in-memory DB loaded with this key's decrypted rows.
    if (hanzi_init(":memory:") != 0) return rpcError(gpa, id_json, .internal_server_error, -32603, "hanzi_init failed", null);
    defer hanzi_close();

    var s = Session{ .gpa = gpa, .store = store, .key = key };
    loadKeyData(&s) catch return rpcError(gpa, id_json, .internal_server_error, -32603, "Failed to load data", null);

    const outcome = try runTool(&s, tool, args);
    defer outcome.deinit(gpa);

    switch (outcome) {
        .err => |msg| {
            var text: std.ArrayList(u8) = .empty;
            defer text.deinit(gpa);
            try text.appendSlice(gpa, "{\"error\":");
            try appendJsonString(gpa, &text, msg);
            try text.append(gpa, '}');
            return toolResult(gpa, id_json, text.items, true);
        },
        .ok => |text| {
            var r = try toolResult(gpa, id_json, text, false);
            if (tool.isWrite()) r.broadcast = try writeBackChanges(&s);
            return r;
        },
    }
}

fn runTool(s: *Session, tool: Tool, args: ?std.json.ObjectMap) !Outcome {
    const gpa = s.gpa;
    switch (tool) {
        .due_count => {
            const filter = optStr(args, "filter");
            const due = if (filter) |f| hanzi_get_due_count_filtered(f.ptr, f.len) else hanzi_get_due_count();
            return .{ .ok = try std.fmt.allocPrint(gpa, "{{\"due\":{d}}}", .{due}) };
        },
        .get_due_cards => {
            const limit: u32 = @intCast(std.math.clamp(optInt(args, "limit") orelse 20, 1, 200));
            const res = if (optStr(args, "filter")) |f|
                hanzi_get_due_cards_filtered(f.ptr, f.len, limit)
            else
                hanzi_get_due_cards(limit);
            return listResult(gpa, "cards", try dupResult(gpa, res));
        },
        .search_cards => {
            const query = optStr(args, "query") orelse "";
            if (query.len == 0) return .{ .err = try gpa.dupe(u8, "query is empty") };
            const limit: u32 = @intCast(std.math.clamp(optInt(args, "limit") orelse 20, 1, 100));
            return listResult(gpa, "cards", try dupResult(gpa, hanzi_search_cards(query.ptr, query.len, limit)));
        },
        .get_lexicon => return listResult(gpa, "entries", try dupResult(gpa, hanzi_get_lexicon())),
        .list_packs => {
            const packs = (try dupResult(gpa, hanzi_get_packs())) orelse
                return .{ .err = try lastError(gpa, "getPacks failed") };
            return listResult(gpa, "packs", packs);
        },
        .get_stats => {
            const days: u32 = @intCast(std.math.clamp(optInt(args, "days") orelse 30, 1, 365));
            const stats = (try dupResult(gpa, hanzi_get_stats(days))) orelse
                try gpa.dupe(u8, "{\"days\":[],\"ratings\":[0,0,0,0],\"streak\":0,\"longest_streak\":0}");
            return .{ .ok = stats };
        },
        .add_word => {
            const word = std.mem.trim(u8, optStr(args, "word") orelse "", " \t\r\n");
            if (word.len == 0) return .{ .err = try gpa.dupe(u8, "word is empty") };
            const res = (try dupResult(gpa, hanzi_add_word(word.ptr, word.len))) orelse
                return .{ .err = try lastError(gpa, "addWord failed") };
            return .{ .ok = res };
        },
        .review_card => {
            const id = optStr(args, "id") orelse "";
            if (id.len == 0) return .{ .err = try gpa.dupe(u8, "id is empty") };
            const rating = optInt(args, "rating") orelse 0;
            if (rating < 1 or rating > 4) return .{ .err = try gpa.dupe(u8, "rating must be 1..4") };
            if (hanzi_review_card(id.ptr, id.len, @intCast(rating)) != 0)
                return .{ .err = try lastError(gpa, "reviewCard failed") };
            var out: std.ArrayList(u8) = .empty;
            errdefer out.deinit(gpa);
            try out.appendSlice(gpa, "{\"reviewed\":");
            try appendJsonString(gpa, &out, id);
            try out.print(gpa, ",\"rating\":{d}}}", .{rating});
            return .{ .ok = try out.toOwnedSlice(gpa) };
        },
        .install_pack => return installPack(s, args),
        .add_lesson_to_pack => return addLessonToPack(s, args),
    }
}

/// `{"<field>":<array>,"count":N}` around a libtaijobi JSON array result
/// (null → empty array, matching the Worker's `return []`).
fn listResult(gpa: std.mem.Allocator, field: []const u8, array_json: ?[]u8) !Outcome {
    const arr = array_json orelse try gpa.dupe(u8, "[]");
    defer gpa.free(arr);
    const count = jsonArrayLen(gpa, arr);
    return .{ .ok = try std.fmt.allocPrint(gpa, "{{\"{s}\":{s},\"count\":{d}}}", .{ field, arr, count }) };
}

fn jsonArrayLen(gpa: std.mem.Allocator, json: []const u8) usize {
    const parsed = std.json.parseFromSlice(std.json.Value, gpa, json, .{}) catch return 0;
    defer parsed.deinit();
    return if (parsed.value == .array) parsed.value.array.items.len else 0;
}

// --- install_pack / add_lesson_to_pack ---

fn installPack(s: *Session, args: ?std.json.ObjectMap) !Outcome {
    const gpa = s.gpa;
    const raw = std.mem.trim(u8, optStr(args, "pack_json") orelse "", " \t\r\n");
    if (raw.len == 0) return .{ .err = try gpa.dupe(u8, "pack_json is empty") };

    const parsed = std.json.parseFromSlice(std.json.Value, gpa, raw, .{}) catch
        return .{ .err = try gpa.dupe(u8, "pack_json: invalid JSON") };
    defer parsed.deinit();

    var reason: std.ArrayList(u8) = .empty;
    defer reason.deinit(gpa);
    const summary = validatePackLenient(gpa, parsed.value, &reason) catch |err| switch (err) {
        error.Invalid => return .{ .err = try reason.toOwnedSlice(gpa) },
        else => |e| return e,
    };

    if (hanzi_install_pack(raw.ptr, raw.len) != 0)
        return .{ .err = try lastError(gpa, "installPack failed") };

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa, "{\"pack_id\":");
    try appendJsonString(gpa, &out, summary.id);
    try out.appendSlice(gpa, ",\"name\":");
    try appendJsonString(gpa, &out, summary.name);
    try out.print(gpa, ",\"word_count\":{d},\"lessons\":{d}}}", .{ summary.word_count, summary.lessons });
    return .{ .ok = try out.toOwnedSlice(gpa) };
}

fn addLessonToPack(s: *Session, args: ?std.json.ObjectMap) !Outcome {
    const gpa = s.gpa;
    const pack_id = std.mem.trim(u8, optStr(args, "pack_id") orelse "", " \t\r\n");
    const raw = std.mem.trim(u8, optStr(args, "lesson_json") orelse "", " \t\r\n");
    if (pack_id.len == 0) return .{ .err = try gpa.dupe(u8, "pack_id is empty") };
    if (raw.len == 0) return .{ .err = try gpa.dupe(u8, "lesson_json is empty") };

    const parsed = std.json.parseFromSlice(std.json.Value, gpa, raw, .{}) catch
        return .{ .err = try gpa.dupe(u8, "lesson_json: invalid JSON") };
    defer parsed.deinit();

    // Shape check — keep it shallow; Zig re-parses for insertion and returns
    // "invalid lesson JSON" on semantic problems.
    if (parsed.value != .object) return .{ .err = try gpa.dupe(u8, "lesson_json must be an object") };
    const lesson = parsed.value.object;
    const lesson_id = optStr(lesson, "id") orelse "";
    if (!isValidId(lesson_id)) return .{ .err = try gpa.dupe(u8, "lesson.id must match ^[a-z0-9][a-z0-9-]*$") };
    const vocab_len = if (lesson.get("vocabulary")) |v| (if (v == .array) v.array.items.len else 0) else 0;
    if (vocab_len == 0) return .{ .err = try gpa.dupe(u8, "lesson.vocabulary must be a non-empty array") };

    if (hanzi_add_lesson_to_pack(pack_id.ptr, pack_id.len, raw.ptr, raw.len) != 0)
        return .{ .err = try lastError(gpa, "addLessonToPack failed") };

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa, "{\"pack_id\":");
    try appendJsonString(gpa, &out, pack_id);
    try out.appendSlice(gpa, ",\"lesson_id\":");
    try appendJsonString(gpa, &out, lesson_id);
    try out.print(gpa, ",\"added\":{d}}}", .{vocab_len});
    return .{ .ok = try out.toOwnedSlice(gpa) };
}

// --- pack validation (port of packs/validator.ts validatePackLenient) ---

const PackSummary = struct { id: []const u8, name: []const u8, word_count: usize, lessons: usize };

/// `^[a-z0-9][a-z0-9-]*$`
fn isValidId(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s, 0..) |ch, i| {
        const ok = std.ascii.isLower(ch) or std.ascii.isDigit(ch) or (i > 0 and ch == '-');
        if (!ok) return false;
    }
    return true;
}

/// `^[a-z]{2}(-[a-z]{2})?$`
fn isValidLangPair(s: []const u8) bool {
    if (s.len != 2 and s.len != 5) return false;
    for (s, 0..) |ch, i| {
        if (i == 2) {
            if (ch != '-') return false;
        } else if (!std.ascii.isLower(ch)) return false;
    }
    return true;
}

/// Throws on the first bad field with `path: reason` in `reason`, like the TS
/// validator. Unknown fields are rejected; translation is optional.
fn validatePackLenient(gpa: std.mem.Allocator, v: std.json.Value, reason: *std.ArrayList(u8)) !PackSummary {
    const V = struct {
        gpa: std.mem.Allocator,
        reason: *std.ArrayList(u8),

        fn fail(self: @This(), comptime fmt: []const u8, args: anytype) error{ Invalid, OutOfMemory } {
            try self.reason.print(self.gpa, fmt, args);
            return error.Invalid;
        }
        fn object(self: @This(), val: std.json.Value, path: []const u8, allowed: []const []const u8) !std.json.ObjectMap {
            if (val != .object) return self.fail("{s}: expected object", .{if (path.len == 0) "(root)" else path});
            var it = val.object.iterator();
            outer: while (it.next()) |e| {
                for (allowed) |a| if (std.mem.eql(u8, a, e.key_ptr.*)) continue :outer;
                return self.fail("{s}{s}{s}: unknown field", .{ path, if (path.len == 0) "" else ".", e.key_ptr.* });
            }
            return val.object;
        }
        fn str(self: @This(), o: std.json.ObjectMap, field: []const u8, path: []const u8, required: bool, allow_empty: bool) !?[]const u8 {
            const val = o.get(field) orelse {
                if (!required) return null;
                return self.fail("{s}{s}{s}: expected string", .{ path, if (path.len == 0) "" else ".", field });
            };
            if (val != .string) return self.fail("{s}{s}{s}: expected string", .{ path, if (path.len == 0) "" else ".", field });
            if (!allow_empty and val.string.len == 0) return self.fail("{s}{s}{s}: must not be empty", .{ path, if (path.len == 0) "" else ".", field });
            return val.string;
        }
        fn int(self: @This(), o: std.json.ObjectMap, field: []const u8, path: []const u8, min: i64) !i64 {
            const val = o.get(field) orelse std.json.Value{ .null = {} };
            const n: ?i64 = switch (val) {
                .integer => |i| i,
                .float => |f| if (@floor(f) == f) @as(i64, @intFromFloat(f)) else null,
                else => null,
            };
            if (n == null or n.? < min) return self.fail("{s}{s}{s}: expected integer >= {d}", .{ path, if (path.len == 0) "" else ".", field, min });
            return n.?;
        }
        fn array(self: @This(), o: std.json.ObjectMap, field: []const u8, path: []const u8) ![]std.json.Value {
            const val = o.get(field) orelse std.json.Value{ .null = {} };
            if (val != .array) return self.fail("{s}{s}{s}: expected array", .{ path, if (path.len == 0) "" else ".", field });
            if (val.array.items.len == 0) return self.fail("{s}{s}{s}: must have at least one entry", .{ path, if (path.len == 0) "" else ".", field });
            return val.array.items;
        }
    };
    const vd = V{ .gpa = gpa, .reason = reason };

    const root = try vd.object(v, "", &.{ "id", "name", "version", "language_pair", "description", "lessons" });
    const id = (try vd.str(root, "id", "", true, false)).?;
    if (!isValidId(id)) return vd.fail("id: must match ^[a-z0-9][a-z0-9-]*$", .{});
    const name = (try vd.str(root, "name", "", true, false)).?;
    _ = try vd.int(root, "version", "", 1);
    const lp = (try vd.str(root, "language_pair", "", true, false)).?;
    if (!isValidLangPair(lp)) return vd.fail("language_pair: must match ^[a-z]{{2}}(-[a-z]{{2}})?$", .{});
    _ = try vd.str(root, "description", "", false, true);

    var word_count: usize = 0;
    const lessons = try vd.array(root, "lessons", "");
    var path_buf: [96]u8 = undefined;
    var wpath_buf: [128]u8 = undefined;
    for (lessons, 0..) |item, li| {
        const p = std.fmt.bufPrint(&path_buf, "lessons[{d}]", .{li}) catch "lessons[?]";
        const l = try vd.object(item, p, &.{ "id", "title", "sort_order", "vocabulary" });
        const lid = (try vd.str(l, "id", p, true, false)).?;
        if (!isValidId(lid)) return vd.fail("{s}.id: must match ^[a-z0-9][a-z0-9-]*$", .{p});
        _ = try vd.str(l, "title", p, false, true);
        _ = try vd.int(l, "sort_order", p, 0);
        const vocab = try vd.array(l, "vocabulary", p);
        for (vocab, 0..) |w_item, wi| {
            const wp = std.fmt.bufPrint(&wpath_buf, "{s}.vocabulary[{d}]", .{ p, wi }) catch "vocabulary[?]";
            const w = try vd.object(w_item, wp, &.{ "word", "pinyin", "translation" });
            _ = try vd.str(w, "word", wp, true, false);
            _ = try vd.str(w, "pinyin", wp, false, true);
            _ = try vd.str(w, "translation", wp, false, true);
        }
        word_count += vocab.len;
    }
    return .{ .id = id, .name = name, .word_count = word_count, .lessons = lessons.len };
}

// --- data loading (decrypt our Store rows → libtaijobi) ---

fn loadKeyData(s: *Session) !void {
    const gpa = s.gpa;
    // Derive the 32-byte encryption key from the sync key.
    const key_buf = (try dupResult(gpa, hanzi_derive_key(s.key.ptr, @intCast(s.key.len)))) orelse return error.KeyDerivation;
    defer gpa.free(key_buf);
    if (key_buf.len != 32) return error.KeyDerivation;
    @memcpy(&s.enc_key, key_buf[0..32]);

    // Pull all stored rows for this key (encrypted), then decrypt each `data`.
    var pull: std.ArrayList(u8) = .empty;
    defer pull.deinit(gpa);
    try s.store.rowsSinceJson(gpa, s.key, 0, &pull);

    const parsed = try std.json.parseFromSlice(std.json.Value, gpa, pull.items, .{});
    defer parsed.deinit();
    const rows = (parsed.value.object.get("rows") orelse return).array.items;
    if (rows.len == 0) return;

    var apply: std.ArrayList(u8) = .empty;
    defer apply.deinit(gpa);
    try apply.appendSlice(gpa, "{\"rows\":[");
    var wrote = false;
    for (rows) |row| {
        if (row != .object) continue;
        const o = row.object;
        const table = optStr(o, "table") orelse continue;
        const id = optStr(o, "id") orelse continue;
        const updated_at = optInt(o, "updated_at") orelse continue;
        const data_val = o.get("data") orelse continue;

        // Encrypted rows carry `data` as a base64 string; dev rows as an object.
        const plaintext: []u8 = switch (data_val) {
            .string => |ct| (try dupResult(gpa, hanzi_decrypt_field(ct.ptr, @intCast(ct.len), &s.enc_key))) orelse continue,
            else => try std.json.Stringify.valueAlloc(gpa, data_val, .{}),
        };
        defer gpa.free(plaintext);

        if (wrote) try apply.append(gpa, ',');
        wrote = true;
        try apply.appendSlice(gpa, "{\"table\":");
        try appendJsonString(gpa, &apply, table);
        try apply.appendSlice(gpa, ",\"id\":");
        try appendJsonString(gpa, &apply, id);
        try apply.appendSlice(gpa, ",\"data\":");
        try apply.appendSlice(gpa, plaintext);
        try apply.print(gpa, ",\"updated_at\":{d}}}", .{updated_at});
        s.watermark = @max(s.watermark, updated_at);
    }
    try apply.appendSlice(gpa, "]}");

    const rc = hanzi_apply_changes(apply.items.ptr, @intCast(apply.items.len));
    hanzi_reset_alloc();
    if (rc < 0) return error.ApplyFailed;
}

/// Re-encrypt the rows this tool call changed and merge them into our Store.
/// Returns a `{"type":"changes",...}` broadcast payload (or null if nothing
/// changed). `hanzi_get_changes` is inclusive (`updated_at >= since`), so ask
/// for strictly newer than the loaded watermark.
fn writeBackChanges(s: *Session) !?[]u8 {
    const gpa = s.gpa;
    const changes = (try dupResult(gpa, hanzi_get_changes(s.watermark + 1))) orelse return null;
    defer gpa.free(changes);

    const parsed = std.json.parseFromSlice(std.json.Value, gpa, changes, .{}) catch return null;
    defer parsed.deinit();
    const rows = (parsed.value.object.get("rows") orelse return null).array.items;
    if (rows.len == 0) return null;

    var enc_rows = try std.ArrayList(Row).initCapacity(gpa, rows.len);
    defer enc_rows.deinit(gpa);
    var owned = try std.ArrayList([]u8).initCapacity(gpa, rows.len);
    defer {
        for (owned.items) |b| gpa.free(b);
        owned.deinit(gpa);
    }

    for (rows) |row| {
        if (row != .object) continue;
        const o = row.object;
        const table = optStr(o, "table") orelse continue;
        const id = optStr(o, "id") orelse continue;
        const updated_at = optInt(o, "updated_at") orelse continue;
        const data_val = o.get("data") orelse continue;

        const plaintext = try std.json.Stringify.valueAlloc(gpa, data_val, .{});
        defer gpa.free(plaintext);

        var nonce: [24]u8 = undefined;
        arc4random_buf(&nonce, nonce.len);
        const ct = (try dupResult(gpa, hanzi_encrypt_field(plaintext.ptr, @intCast(plaintext.len), &s.enc_key, &nonce))) orelse continue;
        defer gpa.free(ct);
        // Store `data` as a JSON string value: "<ciphertext>".
        var quoted: std.ArrayList(u8) = .empty;
        try appendJsonString(gpa, &quoted, ct);
        const quoted_slice = try quoted.toOwnedSlice(gpa);
        try owned.append(gpa, quoted_slice);
        // table/id point into `parsed`, which outlives enc_rows.
        try enc_rows.append(gpa, .{ .table = table, .id = id, .data = quoted_slice, .updated_at = updated_at });
    }

    if (enc_rows.items.len == 0) return null;
    _ = s.store.merge(s.key, enc_rows.items) catch {};

    var bc: std.ArrayList(u8) = .empty;
    errdefer bc.deinit(gpa);
    try bc.appendSlice(gpa, "{\"type\":\"changes\",\"rows\":");
    try store_mod.appendRowsArrayJson(gpa, &bc, enc_rows.items);
    try bc.append(gpa, '}');
    return try bc.toOwnedSlice(gpa);
}

// --- response builders ---

/// Wrap a result object with `resultType` and the server's identity in
/// `_meta` (`result_json` must be a non-empty object).
fn result(gpa: std.mem.Allocator, id_json: ?[]u8, result_json: []const u8) ![]u8 {
    const id = id_json orelse "null";
    return std.fmt.allocPrint(gpa, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{{\"resultType\":\"complete\",\"_meta\":{{\"io.modelcontextprotocol/serverInfo\":{s}}},{s}}}", .{ id, SERVER_INFO_JSON, result_json[1..] });
}

/// MCP `tools/call` result: `{content:[{type:"text",text:<payload>}]}`, plus
/// `isError:true` for tool failures.
fn toolResult(gpa: std.mem.Allocator, id_json: ?[]u8, payload: []const u8, is_error: bool) !RpcResult {
    var content: std.ArrayList(u8) = .empty;
    defer content.deinit(gpa);
    try content.appendSlice(gpa, "{\"content\":[{\"type\":\"text\",\"text\":");
    try appendJsonString(gpa, &content, payload);
    try content.appendSlice(gpa, if (is_error) "}],\"isError\":true}" else "}]}");
    return .{ .body = try result(gpa, id_json, content.items) };
}

// --- small helpers ---

fn optStr(o: ?std.json.ObjectMap, name: []const u8) ?[]const u8 {
    return switch ((o orelse return null).get(name) orelse return null) {
        .string => |s| s,
        else => null,
    };
}

fn optInt(o: ?std.json.ObjectMap, name: []const u8) ?i64 {
    return switch ((o orelse return null).get(name) orelse return null) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        .number_string => |s| std.fmt.parseInt(i64, s, 10) catch null,
        else => null,
    };
}

fn appendJsonString(gpa: std.mem.Allocator, out: *std.ArrayList(u8), s: []const u8) !void {
    try out.append(gpa, '"');
    for (s) |ch| switch (ch) {
        '"' => try out.appendSlice(gpa, "\\\""),
        '\\' => try out.appendSlice(gpa, "\\\\"),
        '\n' => try out.appendSlice(gpa, "\\n"),
        '\r' => try out.appendSlice(gpa, "\\r"),
        '\t' => try out.appendSlice(gpa, "\\t"),
        0...8, 11, 12, 14...31 => {
            var esc: [6]u8 = undefined;
            try out.appendSlice(gpa, std.fmt.bufPrint(&esc, "\\u{x:0>4}", .{ch}) catch unreachable);
        },
        else => try out.append(gpa, ch),
    };
    try out.append(gpa, '"');
}

// Descriptions copied verbatim from taijobi-sync/src/mcp-tools.ts.
const TOOLS_LIST =
    \\{"tools":[
    \\{"name":"due_count","description":"Return the number of cards currently due for review. Optionally filter by pack id (e.g. 'hsk3') or 'lexicon' for personal words only.","inputSchema":{"type":"object","properties":{"filter":{"type":"string","description":"Pack id, 'lexicon', or omit for all cards"}}}},
    \\{"name":"get_due_cards","description":"Return cards currently due for review, with their word, language, pinyin, translation, and source pack. Use this when the user asks what to study next or wants to see what's due.","inputSchema":{"type":"object","properties":{"limit":{"type":"number","description":"Max number of cards to return (default 20)"},"filter":{"type":"string","description":"Pack id, 'lexicon', or omit for all cards"}}}},
    \\{"name":"search_cards","description":"Search cards in the user's library by word, pinyin, or translation. Returns matching cards with metadata. Use when the user asks 'do I have X?' or wants to look up a specific word they've studied.","inputSchema":{"type":"object","properties":{"query":{"type":"string","description":"Search query (word / pinyin / translation)"},"limit":{"type":"number","description":"Max results (default 20)"}},"required":["query"]}},
    \\{"name":"get_lexicon","description":"Return the user's personal lexicon — words they've collected while reading, with review state (reps, stability). Use when the user asks about their saved words or wants a vocabulary snapshot.","inputSchema":{"type":"object","properties":{}}},
    \\{"name":"list_packs","description":"List all installed content packs in the user's library (id, name, language_pair, word_count). ALWAYS call this before install_pack or add_lesson_to_pack so you can find the right existing pack instead of creating a duplicate one. If the user says something like 'I forgot these words for the Geld pack', look up the pack id here and use add_lesson_to_pack.","inputSchema":{"type":"object","properties":{}}},
    \\{"name":"get_stats","description":"Return study statistics: daily review counts + accuracy for the last N days, rating distribution, current streak, longest streak. Use when the user asks how they're doing or for a progress summary.","inputSchema":{"type":"object","properties":{"days":{"type":"number","description":"Days of history to include (default 30)"}}}},
    \\{"name":"add_word","description":"Add a single word to the user's personal lexicon. Language is auto-detected (Chinese / German / English / Arabic / etc.). Chinese words are enriched from CC-CEDICT, English from Wiktionary, German from Wiktionary. Idempotent — adding a word that already exists is a no-op.","inputSchema":{"type":"object","properties":{"word":{"type":"string","description":"The word to add"}},"required":["word"]}},
    \\{"name":"review_card","description":"Record a review for a card. Rating is 1 (Again) / 2 (Hard) / 3 (Good) / 4 (Easy). The FSRS scheduler uses this to plan the next review. Call after the user self-assesses how well they remembered.","inputSchema":{"type":"object","properties":{"id":{"type":"string","description":"Card id (from get_due_cards)"},"rating":{"type":"number","description":"FSRS rating: 1 Again / 2 Hard / 3 Good / 4 Easy"}},"required":["id","rating"]}},
    \\{"name":"install_pack","description":"Install a content pack into the user's library. Use for structured vocabulary (OCR from a textbook, PDF chapter, pasted list) — NOT for single words (use add_word). Input is a single JSON string matching the shape of packs/official/hsk-1.json. Example:\n{\"id\":\"mein-pack\",\"name\":\"Kapitel 3\",\"version\":1,\"language_pair\":\"zh-de\",\"lessons\":[{\"id\":\"mein-pack-l1\",\"title\":\"Geld & Zahlen\",\"sort_order\":1,\"vocabulary\":[{\"word\":\"人民币\",\"pinyin\":\"Rénmínbì\",\"translation\":\"RMB\"}]}]}\nRules: `id` and every `lessons[].id` match ^[a-z0-9][a-z0-9-]*$. `language_pair` like \"zh-de\" / \"ar-en\". `translation` is optional — partial packs are fine (words can be filled in later). Per-card language auto-detected from the word's script. Appears in /packs under 'Eigene' (tag=personal) and syncs privately to the user's other devices.","inputSchema":{"type":"object","properties":{"pack_json":{"type":"string","description":"Full pack JSON as a single string. Must match packs/official/hsk-1.json structure — see the example in the tool description."}},"required":["pack_json"]}},
    \\{"name":"add_lesson_to_pack","description":"Append a single lesson (with its vocabulary) to an EXISTING pack — non-destructively. Use this when the user mentions they forgot some words that belong in a pack you (or they) already created; creating a new pack in that case leaves duplicate entries in /packs. Always call list_packs first to find the correct pack_id.\nInput: pack_id + lesson_json (a single lesson object). Example:\n{\"pack_id\":\"chinesisch-geld-zimmer\",\"lesson_json\":\"{\\\"id\\\":\\\"chinesisch-geld-zimmer-l4\\\",\\\"title\\\":\\\"Bank\\\",\\\"sort_order\\\":4,\\\"vocabulary\\\":[{\\\"word\\\":\\\"银行\\\",\\\"pinyin\\\":\\\"yínháng\\\",\\\"translation\\\":\\\"Bank\\\"}]}\"}\nRules: lesson_id must match ^[a-z0-9][a-z0-9-]*$ and must be unique within the pack (upsert — re-using an existing lesson_id just updates its metadata and merges new vocab). Existing cards keep their FSRS/review state. Partial packs are fine; translation is optional.","inputSchema":{"type":"object","properties":{"pack_id":{"type":"string","description":"Id of an existing pack (from list_packs)"},"lesson_json":{"type":"string","description":"Single lesson JSON: {id, title?, sort_order, vocabulary: [{word, pinyin?, translation?}]}"}},"required":["pack_id","lesson_json"]}}
    \\]}
;

test "TOOLS_LIST is valid JSON with all ten tools" {
    const gpa = std.testing.allocator;
    const parsed = try std.json.parseFromSlice(std.json.Value, gpa, TOOLS_LIST, .{});
    defer parsed.deinit();
    const tools = parsed.value.object.get("tools").?.array.items;
    try std.testing.expectEqual(@as(usize, std.enums.values(Tool).len), tools.len);
    for (tools) |t| {
        try std.testing.expect(std.meta.stringToEnum(Tool, t.object.get("name").?.string) != null);
    }
}

test "id and language_pair rules match the TS validator" {
    try std.testing.expect(isValidId("hsk-1"));
    try std.testing.expect(isValidId("9a"));
    try std.testing.expect(!isValidId("-a"));
    try std.testing.expect(!isValidId("Hsk"));
    try std.testing.expect(!isValidId(""));
    try std.testing.expect(isValidLangPair("zh-de"));
    try std.testing.expect(isValidLangPair("zh"));
    try std.testing.expect(!isValidLangPair("zh_de"));
    try std.testing.expect(!isValidLangPair("ZH-de"));
}

test "validatePackLenient accepts partial packs and names the bad field" {
    const gpa = std.testing.allocator;
    const good =
        \\{"id":"p","name":"P","version":1,"language_pair":"zh-de","lessons":[{"id":"p-l1","sort_order":1,"vocabulary":[{"word":"人"},{"word":"大","translation":"big"}]}]}
    ;
    const g = try std.json.parseFromSlice(std.json.Value, gpa, good, .{});
    defer g.deinit();
    var reason: std.ArrayList(u8) = .empty;
    defer reason.deinit(gpa);
    const summary = try validatePackLenient(gpa, g.value, &reason);
    try std.testing.expectEqual(@as(usize, 2), summary.word_count);
    try std.testing.expectEqual(@as(usize, 1), summary.lessons);

    const bad =
        \\{"id":"p","name":"P","version":1,"language_pair":"zh-de","lessons":[{"id":"p-l1","sort_order":1,"vocabulary":[{"word":"人","extra":1}]}]}
    ;
    const b = try std.json.parseFromSlice(std.json.Value, gpa, bad, .{});
    defer b.deinit();
    try std.testing.expectError(error.Invalid, validatePackLenient(gpa, b.value, &reason));
    try std.testing.expectEqualStrings("lessons[0].vocabulary[0].extra: unknown field", reason.items);
}
