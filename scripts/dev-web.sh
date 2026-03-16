#!/bin/bash
set -euo pipefail

# Start taijobi-web dev server
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT/taijobi-web"
bun run dev
