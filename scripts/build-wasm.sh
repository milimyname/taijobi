#!/bin/bash
set -euo pipefail

# Build libtaijobi for WASM
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Ensure CEDICT binary exists (downloads if needed)
"$ROOT/scripts/build-cedict.sh"

cd "$ROOT/libtaijobi"

echo "=== Building libtaijobi.wasm ==="
zig build --release=small
cp zig-out/bin/libtaijobi.wasm "$ROOT/taijobi-web/static/libtaijobi.wasm"
echo "=== Copied to taijobi-web/static/libtaijobi.wasm ==="
ls -lh "$ROOT/taijobi-web/static/libtaijobi.wasm"
