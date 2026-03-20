#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Starting taijobi local dev..."
echo "  Web app:     http://localhost:6173"
echo "  Sync worker: http://localhost:8788"
echo ""

# Start sync worker in background
cd "$ROOT/taijobi-sync"
bun install --frozen-lockfile 2>/dev/null
bunx wrangler dev --port 8788 &
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
