#!/bin/bash
set -euo pipefail

# Build libtaijobi for WASM
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Ensure data binaries exist (downloads if needed)
"$ROOT/scripts/build-cedict.sh"
"$ROOT/scripts/build-decomp.sh"
"$ROOT/scripts/build-strokes.sh"

cd "$ROOT/libtaijobi"

echo "=== Building libtaijobi.wasm (web) ==="
zig build --release=small
cp zig-out/bin/libtaijobi.wasm "$ROOT/taijobi-web/static/libtaijobi.wasm"
echo "=== Copied to taijobi-web/static/libtaijobi.wasm ==="
ls -lh "$ROOT/taijobi-web/static/libtaijobi.wasm"

# (The compact -Dmcp=true WASM was for the Cloudflare Worker's MCP server; the
# native taijobi-sync-zig links libtaijobi directly.)

# Copy Chinese data files for local dev (vite serves static/data). What ships
# to the VPS comes from data/dist instead — see scripts/deploy-server.sh.
echo "=== Copying Chinese data files to static/data/ ==="
mkdir -p "$ROOT/taijobi-web/static/data"
cp "$ROOT/libtaijobi/src/cedict.bin" "$ROOT/taijobi-web/static/data/"
cp "$ROOT/libtaijobi/src/decomp.bin" "$ROOT/taijobi-web/static/data/"
cp "$ROOT/libtaijobi/src/strokes.bin" "$ROOT/taijobi-web/static/data/"
ls -lh "$ROOT/taijobi-web/static/data/"
