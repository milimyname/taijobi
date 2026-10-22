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
| `POST /mcp` (10 tools) | ⏳ 501 — port from `taijobi-sync/src/mcp-*.ts`, link libtaijobi natively |
| `/push/*` + hourly streak cron | ⏳ 501 — port VAPID + RFC 8291 from `push-send.ts` |

Sync is wire-compatible with the Worker, so clients keep talking to
`sync.taijobi.com` unchanged once DNS points here. Cutover has to wait for MCP
and push, or those features break.

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
- No server-initiated 30 s ping yet (clients reconnect on close).
- Existing data lives in the Worker's Durable Objects and is not migrated.
  Clients hold full local copies, so after cutover one device per sync key
  must push everything (reset its last-sync timestamp) or new devices will
  only see post-cutover rows.
