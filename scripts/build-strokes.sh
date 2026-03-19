#!/bin/bash
# Download Make Me a Hanzi graphics.txt and compile to binary format.
# Run this before `zig build` if strokes.bin doesn't exist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUT="$ROOT_DIR/libtaijobi/src/strokes.bin"

if [ -f "$OUT" ]; then
    echo "[strokes] $OUT already exists, skipping. Delete it to re-download."
    exit 0
fi

echo "[strokes] Downloading Make Me a Hanzi graphics.txt..."
TMP=$(mktemp -d)
curl -sL "https://raw.githubusercontent.com/skishore/makemeahanzi/master/graphics.txt" \
    -o "$TMP/graphics.txt"

echo "[strokes] Compiling to binary format..."
bun "$SCRIPT_DIR/compile-strokes.ts" "$TMP/graphics.txt" "$OUT"

rm -rf "$TMP"
echo "[strokes] Done: $OUT"
