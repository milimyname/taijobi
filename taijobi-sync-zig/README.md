# taijobi-sync-zig

Native Zig replacement for the `taijobi-sync` Cloudflare Worker, ported from
wimg's `wimg-sync-zig/` (the wire protocol is identical, so `store.zig`,
`protocol.zig` and `sqlite.zig` are copied nearly verbatim). Plain HTTP; Caddy
terminates TLS in front.

## Status

| Endpoint | Status |
| --- | --- |
| `GET /health` | ✅ |
| `POST /sync/:key` (push, LWW upsert) | ✅ |
| `GET /sync/:key?since=` (pull) | ✅ |
| `GET /ws/:key` (real-time WebSocket) | ✅ |
| `POST /mcp` (10 tools) | ✅ — `mcp.zig`, links libtaijobi natively (no WASM) |
| `/push/*` + hourly streak cron | ⏳ 501 — port VAPID + RFC 8291 from `push-send.ts` |

Sync is wire-compatible with the Worker, so clients keep talking to
`sync.taijobi.com` unchanged once DNS points here. Cutover has to wait for MCP
and push, or those features break.

## MCP

Same 10 tools, argument names, result shapes and descriptions as
`taijobi-sync/src/mcp-tools.ts`. Stateless: each tool call opens a fresh
in-memory libtaijobi DB, decrypts the caller's rows into it, runs the tool, and
for write tools re-encrypts only the rows newer than the loaded watermark back
into the Store (and broadcasts them over WebSocket). About 125 ms per call with
all six HSK packs (5.2k rows) synced. `install_pack` runs a Zig port of
`packs/validator.ts` `validatePackLenient`.

Dual-era transport: requests carrying
`params._meta["io.modelcontextprotocol/protocolVersion"]` are served as MCP
**2026-07-28** (stateless: no `initialize`, no `Mcp-Session-Id`,
`server/discover`, `resultType` + `_meta` serverInfo on results, `ttlMs` /
`cacheScope` on `tools/list`, `MCP-Protocol-Version` / `Mcp-Method` /
`Mcp-Name` must match the body or 400 + `-32020`, unknown versions 400 +
`-32022`). Everything else gets the 2025-03-26 flow Claude Desktop speaks via
`mcp-remote`. Code Mode is not adopted: it needs a V8 sandbox (Cloudflare's
Dynamic Worker Loader) and only pays off for very large tool surfaces.

## Build & run

```sh
zig build test                     # store + protocol + routing
zig build                          # → zig-out/bin/taijobi-sync
PORT=8787 zig build run            # web dev client's sync URL
```

Env: `PORT` (default 8080), `BIND` (default 0.0.0.0; prod 127.0.0.1),
`TAIJOBI_SYNC_DB` (default `sync.db`). Reuses `../libtaijobi/vendor/sqlite3.c`.

## Differences from the Worker

- One process serves every sync key; rows are partitioned by a `sync_key`
  column instead of one Durable Object per key.
- Push copies the sync key out of the request buffer before reading the body.
  wimg's server doesn't: a push body over 64 KB overwrites the key, so the
  rows are stored under garbage bytes.
- No server-initiated 30 s ping yet (clients reconnect on close).
- Existing data lives in the Worker's Durable Objects and is not migrated.
  Clients hold full local copies, so after cutover one device per sync key
  must push everything (reset its last-sync timestamp) or new devices will
  only see post-cutover rows.
