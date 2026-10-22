#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Starting taijobi local dev..."
echo "  Web app:     http://localhost:6173"
echo "  Sync server: http://localhost:8788 ($([[ "${TAIJOBI_NATIVE_SYNC:-}" == 1 ]] && echo native Zig || echo Cloudflare Worker))"
echo ""

# Start the sync server in background. TAIJOBI_NATIVE_SYNC=1 runs the native
# Zig server (taijobi-sync-zig, what the VPS runs) instead of wrangler.
if [[ "${TAIJOBI_NATIVE_SYNC:-}" == 1 ]]; then
    cd "$ROOT/taijobi-sync-zig"
    PORT=8788 TAIJOBI_SYNC_DB="$ROOT/taijobi-sync-zig/dev-sync.db" zig build run &
else
    cd "$ROOT/taijobi-sync"
    bun install --frozen-lockfile 2>/dev/null
    bunx wrangler dev --port 8788 --test-scheduled &
fi
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
