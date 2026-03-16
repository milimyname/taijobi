#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Starting taijobi local dev..."
echo "  Web app: http://localhost:5173"
echo ""

cd "$ROOT/taijobi-web"
bun run dev --host
