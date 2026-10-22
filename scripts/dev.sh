#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Starting taijobi local dev..."
echo "  Web app:     http://localhost:6173"
echo "  Sync server: http://localhost:8788 (taijobi-sync-zig)"
echo ""

# Start the native sync server in background (same binary the VPS runs).
# PUSH_CRON_RUN_ON_START=1 + VAPID_PRIVATE_KEY in the env fires one push tick.
cd "$ROOT/taijobi-sync-zig"
PORT=8788 TAIJOBI_SYNC_DB="$ROOT/taijobi-sync-zig/dev-sync.db" zig build run &
SYNC_PID=$!

# Start web app
cd "$ROOT/taijobi-web"
bun run dev --host --port 6173 &
WEB_PID=$!

# Cleanup on exit
cleanup() {
    echo ""
    echo "Shutting down..."
    kill $SYNC_PID $WEB_PID 2>/dev/null || true
    wait $SYNC_PID $WEB_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

wait
