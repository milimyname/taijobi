//! taijobi-sync server (native Zig) — the self-hosted replacement for the
//! Cloudflare Worker in `taijobi-sync/`. Ported from wimg's `wimg-sync-zig/`.
//!
//! Listens on plain HTTP (Caddy terminates TLS in front). Endpoints are
//! wire-compatible with the Worker so clients need no changes:
//!
//!   GET  /health           → "ok"
//!   POST /sync/:key        → {"merged": N}     (LWW upsert of {"rows":[...]})
//!   GET  /sync/:key?since= → {"rows":[...]}    (rows newer than `since`)
//!   GET  /ws/:key          → real-time sync    (broadcasts `changes` frames)
//!   POST /mcp              → MCP JSON-RPC       (10 tools, see mcp.zig)
//!   /push/*                → 501 until ported (still served by the Worker)
//!
//! One OS thread per connection. The Worker gave each sync key its own Durable
//! Object; here a mutex-guarded `Registry` tracks the live WebSocket connections
//! per key so an HTTP push (or a WS push) can fan changes out to the others.

const std = @import("std");
const store_mod = @import("store.zig");
const Store = store_mod.Store;
const protocol = @import("protocol.zig");
const mcp = @import("mcp.zig");

const Server = std.http.Server;

extern fn arc4random_buf(buf: [*]u8, len: usize) void;
extern fn getenv(name: [*:0]const u8) ?[*:0]const u8;

const json_headers = [_]std.http.Header{
    .{ .name = "content-type", .value = "application/json" },
    .{ .name = "access-control-allow-origin", .value = "*" },
};
const MAX_BODY = 16 * 1024 * 1024; // 16 MB — generous for a full-sync push

/// Tiny spinlock (same rationale as store.zig — avoid the std.Io async mutex).
const SpinLock = struct {
    locked: std.atomic.Value(bool) = .init(false),
    fn lock(self: *SpinLock) void {
        while (self.locked.cmpxchgWeak(false, true, .acquire, .monotonic) != null) std.atomic.spinLoopHint();
    }
    fn unlock(self: *SpinLock) void {
        self.locked.store(false, .release);
    }
};

/// One live WebSocket connection. Lives on its connection thread's stack; the
/// registry only holds a pointer, removed before that stack unwinds.
const Conn = struct {
    ws: *Server.WebSocket,
    key: []const u8,
    write_lock: SpinLock = .{},

    fn sendOp(self: *Conn, payload: []const u8, op: Server.WebSocket.Opcode) void {
        self.write_lock.lock();
        defer self.write_lock.unlock();
        self.ws.writeMessage(payload, op) catch {};
    }
    fn send(self: *Conn, payload: []const u8) void {
        self.sendOp(payload, .text);
    }
};

const Registry = struct {
    lock: SpinLock = .{},
    conns: std.ArrayList(*Conn) = .empty,
    gpa: std.mem.Allocator,

    fn register(self: *Registry, conn: *Conn) !void {
        self.lock.lock();
        defer self.lock.unlock();
        try self.conns.append(self.gpa, conn);
    }
    fn unregister(self: *Registry, conn: *Conn) void {
        self.lock.lock();
        defer self.lock.unlock();
        for (self.conns.items, 0..) |c, i| {
            if (c == conn) {
                _ = self.conns.swapRemove(i);
                return;
            }
        }
    }
    /// Send `payload` to every live connection of `key` except `exclude`. Holds
    /// the lock across the writes so connections can't be freed mid-broadcast;
    /// fine at one-user / few-device scale.
    fn broadcast(self: *Registry, key: []const u8, payload: []const u8, exclude: ?*Conn) void {
        self.lock.lock();
        defer self.lock.unlock();
        for (self.conns.items) |c| {
            if (c == exclude) continue;
            if (std.mem.eql(u8, c.key, key)) c.send(payload);
        }
    }
};

const Context = struct {
    io: std.Io,
    store: *Store,
    registry: *Registry,
};

pub fn main() !void {
    const gpa = std.heap.smp_allocator;

    // Defaults match the Caddyfile (reverse_proxy → :8080) and the systemd unit
    // (WorkingDirectory=/var/lib/taijobi, so "sync.db" lands there). Override with
    // PORT / TAIJOBI_SYNC_DB env vars (local dev points the web client at :8787).
    const port: u16 = if (getenv("PORT")) |p|
        std.fmt.parseInt(u16, std.mem.span(p), 10) catch 8080
    else
        8080;
    const db_path: [*:0]const u8 = getenv("TAIJOBI_SYNC_DB") orelse "sync.db";
    // Bind address. Default 0.0.0.0 (LAN-reachable for phone dev); prod sets
    // BIND=127.0.0.1 so only Caddy (same host) can reach it.
    const host: []const u8 = if (getenv("BIND")) |h| std.mem.span(h) else "0.0.0.0";

    var store = try Store.open(db_path);
    defer store.close();

    var registry = Registry{ .gpa = gpa };

    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var ctx = Context{ .io = io, .store = &store, .registry = &registry };

    const addr = try std.Io.net.IpAddress.parseIp4(host, port);
    var server = try addr.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);

    std.debug.print("taijobi-sync listening on {s}:{d} (db: {s})\n", .{ host, port, db_path });

    while (true) {
        const stream = server.accept(io) catch continue;
        const thread = std.Thread.spawn(.{}, connThread, .{ &ctx, stream }) catch {
            stream.close(io);
            continue;
        };
        thread.detach();
    }
}

fn connThread(ctx: *Context, stream: std.Io.net.Stream) void {
    defer stream.close(ctx.io);

    var read_buf: [64 * 1024]u8 = undefined;
    var write_buf: [64 * 1024]u8 = undefined;
    var sr = stream.reader(ctx.io, &read_buf);
    var sw = stream.writer(ctx.io, &write_buf);
    var http_server = Server.init(&sr.interface, &sw.interface);

    // Keep-alive: serve requests until the client goes away — unless a request
    // upgrades to WebSocket, which then owns the connection for its lifetime.
    while (true) {
        var request = http_server.receiveHead() catch return;
        const path = pathOf(request.head.target);

        if (std.mem.startsWith(u8, path, "/ws/")) {
            switch (request.upgradeRequested()) {
                .websocket => |maybe_key| {
                    handleWebSocket(ctx, &request, maybe_key orelse return, path["/ws/".len..]);
                    return; // connection consumed
                },
                else => {
                    request.respond("expected websocket upgrade", .{ .status = .upgrade_required }) catch return;
                    continue;
                },
            }
        }

        routeRequest(ctx, &request) catch return;
    }
}

fn routeRequest(ctx: *Context, request: *Server.Request) !void {
    const method = request.head.method;
    const target = request.head.target;
    const path = pathOf(target);

    if (method == .OPTIONS) {
        return request.respond("", .{
            .status = .no_content,
            .extra_headers = &.{
                .{ .name = "access-control-allow-origin", .value = "*" },
                .{ .name = "access-control-allow-methods", .value = "GET, POST, DELETE, OPTIONS" },
                .{ .name = "access-control-allow-headers", .value = "Content-Type, Authorization, Mcp-Session-Id" },
            },
        });
    }

    if (std.mem.eql(u8, path, "/health")) {
        return request.respond("ok", .{ .status = .ok });
    }

    if (std.mem.startsWith(u8, path, "/sync/")) {
        const key = path["/sync/".len..];
        if (key.len == 0) return request.respond("missing key", .{ .status = .bad_request });
        return switch (method) {
            .POST => handlePush(ctx, request, key),
            .GET => handlePull(ctx, request, key, target),
            else => request.respond("method not allowed", .{ .status = .method_not_allowed }),
        };
    }

    if (std.mem.eql(u8, path, "/mcp")) {
        return switch (method) {
            .POST => handleMcp(ctx, request),
            .GET => request.respond(": connected\n\n", .{ // no-op SSE stream (Streamable HTTP)
                .status = .ok,
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "text/event-stream" },
                    .{ .name = "access-control-allow-origin", .value = "*" },
                },
            }),
            .DELETE => request.respond("OK", .{ .status = .ok, .extra_headers = &json_headers }),
            else => request.respond("method not allowed", .{ .status = .method_not_allowed }),
        };
    }

    // Not ported yet — the Cloudflare Worker keeps serving these until cutover.
    if (std.mem.startsWith(u8, path, "/push/")) {
        return request.respond("{\"error\":\"not implemented\"}", .{ .status = .not_implemented, .extra_headers = &json_headers });
    }

    return request.respond("not found", .{ .status = .not_found });
}

fn handlePush(ctx: *Context, request: *Server.Request, key_path: []const u8) !void {
    const gpa = ctx.registry.gpa;

    // `key_path` points into the connection's read buffer, which the body
    // reader overwrites once the body outgrows it (a full-sync push easily
    // does) — copy it out first or the rows land under garbage bytes.
    var key_buf: [256]u8 = undefined;
    if (key_path.len > key_buf.len) return request.respond("key too long", .{ .status = .bad_request });
    @memcpy(key_buf[0..key_path.len], key_path);
    const key = key_buf[0..key_path.len];

    var body_buf: [16 * 1024]u8 = undefined;
    const reader = request.readerExpectContinue(&body_buf) catch
        return request.respond("bad request", .{ .status = .bad_request });
    const body = reader.allocRemaining(gpa, .limited(MAX_BODY)) catch
        return request.respond("body too large", .{ .status = .payload_too_large });
    defer gpa.free(body);

    var push = protocol.parsePush(gpa, body) catch
        return request.respond("{\"error\":\"invalid body\"}", .{ .status = .bad_request, .extra_headers = &json_headers });
    defer push.deinit();

    const merged = ctx.store.merge(key, push.rows) catch
        return request.respond("{\"error\":\"merge failed\"}", .{ .status = .internal_server_error, .extra_headers = &json_headers });

    logReq("push", key, @intCast(push.rows.len));

    // Fan out to this key's WebSocket listeners. No exclude — the HTTP pusher
    // isn't a socket; clients suppress their own echo via a 2s window.
    broadcastChanges(ctx, gpa, key, push.rows, null);

    var out: [64]u8 = undefined;
    const reply = std.fmt.bufPrint(&out, "{{\"merged\":{d}}}", .{merged}) catch unreachable;
    return request.respond(reply, .{ .status = .ok, .extra_headers = &json_headers });
}

fn handleMcp(ctx: *Context, request: *Server.Request) !void {
    const gpa = ctx.registry.gpa;

    // Bearer token == sync key. Capture before reading the body (the header
    // strings are invalidated once the body reader initializes).
    var key_buf: [256]u8 = undefined;
    var key_len: usize = 0;
    var session_buf: [128]u8 = undefined;
    var session_len: usize = 0;
    // MCP 2026-07-28 mirrored headers, copied for the same reason.
    var version_buf: [32]u8 = undefined;
    var method_buf: [64]u8 = undefined;
    var name_buf: [256]u8 = undefined;
    var mcp_headers: mcp.Headers = .{};
    var it = request.iterateHeaders();
    while (it.next()) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, "authorization")) {
            if (std.ascii.startsWithIgnoreCase(h.value, "bearer ")) {
                const tok = std.mem.trim(u8, h.value["bearer ".len..], " ");
                if (tok.len <= key_buf.len) {
                    @memcpy(key_buf[0..tok.len], tok);
                    key_len = tok.len;
                }
            }
        } else if (std.ascii.eqlIgnoreCase(h.name, "mcp-protocol-version")) {
            mcp_headers.protocol_version = copyHeader(&version_buf, h.value);
        } else if (std.ascii.eqlIgnoreCase(h.name, "mcp-method")) {
            mcp_headers.method = copyHeader(&method_buf, h.value);
        } else if (std.ascii.eqlIgnoreCase(h.name, "mcp-name")) {
            mcp_headers.name = copyHeader(&name_buf, h.value);
        } else if (std.ascii.eqlIgnoreCase(h.name, "mcp-session-id")) {
            if (h.value.len <= session_buf.len) {
                @memcpy(session_buf[0..h.value.len], h.value);
                session_len = h.value.len;
            }
        }
    }
    if (key_len == 0) {
        return request.respond(
            "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32600,\"message\":\"Missing Authorization: Bearer <sync-key>\"}}",
            .{ .status = .unauthorized, .extra_headers = &json_headers },
        );
    }
    const key = key_buf[0..key_len];

    var body_buf: [16 * 1024]u8 = undefined;
    const reader = request.readerExpectContinue(&body_buf) catch
        return request.respond("bad request", .{ .status = .bad_request });
    const body = reader.allocRemaining(gpa, .limited(MAX_BODY)) catch
        return request.respond("body too large", .{ .status = .payload_too_large });
    defer gpa.free(body);

    const rpc = mcp.handleRpc(gpa, ctx.store, key, body, mcp_headers) catch
        return request.respond("{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32603,\"message\":\"Internal error\"}}", .{ .status = .internal_server_error, .extra_headers = &json_headers });
    defer gpa.free(rpc.body);
    defer if (rpc.broadcast) |b| gpa.free(b);

    // A write tool fanned out changes — push them to this key's WS listeners.
    if (rpc.broadcast) |b| ctx.registry.broadcast(key, b, null);

    // Notifications produce no body.
    if (rpc.body.len == 0) {
        return request.respond("", .{ .status = .accepted, .extra_headers = &json_headers });
    }

    // 2026-07-28 has no sessions: never mint or echo one for modern requests.
    if (!rpc.session) {
        return request.respond(rpc.body, .{ .status = rpc.status, .extra_headers = &json_headers });
    }

    // Legacy: echo an incoming Mcp-Session-Id, or mint one on initialize so
    // clients that track sessions are satisfied (we're stateless, so the value
    // is opaque).
    var minted: [32]u8 = undefined;
    const session: []const u8 = if (session_len > 0) session_buf[0..session_len] else blk: {
        var raw: [16]u8 = undefined;
        arc4random_buf(&raw, raw.len);
        _ = std.fmt.bufPrint(&minted, "{x}", .{&raw}) catch unreachable;
        break :blk minted[0..32];
    };

    return request.respond(rpc.body, .{
        .status = .ok,
        .extra_headers = &.{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "access-control-allow-origin", .value = "*" },
            .{ .name = "mcp-session-id", .value = session },
        },
    });
}

fn handlePull(ctx: *Context, request: *Server.Request, key: []const u8, target: []const u8) !void {
    const gpa = ctx.registry.gpa;
    const since = sinceOf(target);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    ctx.store.rowsSinceJson(gpa, key, since, &out) catch
        return request.respond("{\"error\":\"query failed\"}", .{ .status = .internal_server_error, .extra_headers = &json_headers });
    logReq("pull", key, since);
    return request.respond(out.items, .{ .status = .ok, .extra_headers = &json_headers });
}

// --- WebSocket ---

fn handleWebSocket(ctx: *Context, request: *Server.Request, sec_key: []const u8, key_path: []const u8) void {
    var ws = request.respondWebSocket(.{ .key = sec_key }) catch return;
    ws.flush() catch return;

    // Own copy of the sync key (the request target buffer is not guaranteed to
    // survive the connection).
    var key_buf: [128]u8 = undefined;
    if (key_path.len > key_buf.len) return;
    @memcpy(key_buf[0..key_path.len], key_path);
    const key = key_buf[0..key_path.len];

    var conn = Conn{ .ws = &ws, .key = key };
    ctx.registry.register(&conn) catch return;
    logReq("ws connect", key, 0);
    defer {
        ctx.registry.unregister(&conn);
        logReq("ws disconnect", key, 0);
    }

    while (true) {
        const msg = ws.readSmallMessage() catch return; // ConnectionClose / error → done
        switch (msg.opcode) {
            .ping => conn.sendOp(msg.data, .pong),
            .pong => {},
            .text => handleWsText(ctx, &conn, key, msg.data),
            else => {}, // ignore binary / continuation
        }
    }
}

fn handleWsText(ctx: *Context, conn: *Conn, key: []const u8, text: []const u8) void {
    const gpa = ctx.registry.gpa;
    const parsed = std.json.parseFromSlice(std.json.Value, gpa, text, .{}) catch return;
    defer parsed.deinit();
    if (parsed.value != .object) return;
    const obj = parsed.value.object;
    const msg_type = (obj.get("type") orelse return);
    if (msg_type != .string) return;
    const t = msg_type.string;

    if (std.mem.eql(u8, t, "push")) {
        var push = protocol.parsePush(gpa, text) catch return;
        defer push.deinit();
        const merged = ctx.store.merge(key, push.rows) catch return;
        // Exclude the sender; it already applied the change locally.
        broadcastChanges(ctx, gpa, key, push.rows, conn);
        var out: [64]u8 = undefined;
        const ack = std.fmt.bufPrint(&out, "{{\"type\":\"push_ack\",\"merged\":{d}}}", .{merged}) catch return;
        conn.send(ack);
    } else if (std.mem.eql(u8, t, "pull")) {
        const since: i64 = if (obj.get("since")) |v| switch (v) {
            .integer => |i| i,
            else => 0,
        } else 0;
        // rowsSinceJson writes `{"rows":[...]}`; splice in the type field by
        // dropping its leading '{'.
        var rows_json: std.ArrayList(u8) = .empty;
        defer rows_json.deinit(gpa);
        ctx.store.rowsSinceJson(gpa, key, since, &rows_json) catch return;
        if (rows_json.items.len == 0) return;
        var result: std.ArrayList(u8) = .empty;
        defer result.deinit(gpa);
        result.appendSlice(gpa, "{\"type\":\"pull_result\",") catch return;
        result.appendSlice(gpa, rows_json.items[1..]) catch return;
        conn.send(result.items);
    }
    // "pong" and unknown types: ignore.
}

/// Build `{"type":"changes","rows":[...]}` and broadcast it to `key`'s sockets.
fn broadcastChanges(ctx: *Context, gpa: std.mem.Allocator, key: []const u8, rows: []const store_mod.Row, exclude: ?*Conn) void {
    if (rows.len == 0) return;
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(gpa);
    payload.appendSlice(gpa, "{\"type\":\"changes\",\"rows\":") catch return;
    store_mod.appendRowsArrayJson(gpa, &payload, rows) catch return;
    payload.append(gpa, '}') catch return;
    ctx.registry.broadcast(key, payload.items, exclude);
}

/// One-line request log to stderr (the dev terminal). The sync key is a secret,
/// so only its first 8 chars are shown — enough to correlate, not to leak.
fn logReq(tag: []const u8, key: []const u8, n: i64) void {
    const kp = key[0..@min(key.len, 8)];
    std.debug.print("[taijobi-sync] {s} key={s}… n={d}\n", .{ tag, kp, n });
}

/// Copy a header value into `buf`; empty when it doesn't fit (treated as missing).
fn copyHeader(buf: []u8, value: []const u8) []const u8 {
    if (value.len > buf.len) return "";
    @memcpy(buf[0..value.len], value);
    return buf[0..value.len];
}

/// Path portion of a request target (everything before `?`).
fn pathOf(target: []const u8) []const u8 {
    const q = std.mem.indexOfScalar(u8, target, '?') orelse return target;
    return target[0..q];
}

/// Parse the `since` query parameter (defaults to 0).
fn sinceOf(target: []const u8) i64 {
    const q = std.mem.indexOfScalar(u8, target, '?') orelse return 0;
    var it = std.mem.splitScalar(u8, target[q + 1 ..], '&');
    while (it.next()) |pair| {
        if (std.mem.startsWith(u8, pair, "since=")) {
            return std.fmt.parseInt(i64, pair["since=".len..], 10) catch 0;
        }
    }
    return 0;
}

test "pathOf and sinceOf" {
    try std.testing.expectEqualStrings("/sync/abc", pathOf("/sync/abc?since=100"));
    try std.testing.expectEqualStrings("/sync/abc", pathOf("/sync/abc"));
    try std.testing.expectEqual(@as(i64, 100), sinceOf("/sync/abc?since=100"));
    try std.testing.expectEqual(@as(i64, 0), sinceOf("/sync/abc"));
    try std.testing.expectEqual(@as(i64, 42), sinceOf("/sync/abc?foo=1&since=42"));
}
