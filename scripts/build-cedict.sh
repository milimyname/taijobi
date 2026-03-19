#!/bin/bash
# Download CC-CEDICT and compile to binary format for Zig @embedFile.
# Run this before `zig build` if cedict.bin doesn't exist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUT="$ROOT_DIR/libtaijobi/src/cedict.bin"

if [ -f "$OUT" ]; then
    echo "[cedict] $OUT already exists, skipping. Delete it to re-download."
    exit 0
fi

echo "[cedict] Downloading CC-CEDICT from mdbg.net..."
TMP=$(mktemp -d)
curl -sL "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz" \
    -o "$TMP/cedict.txt.gz"
gunzip "$TMP/cedict.txt.gz"

echo "[cedict] Compiling to binary format..."
bun "$SCRIPT_DIR/compile-cedict.ts" "$TMP/cedict.txt" "$OUT"

rm -rf "$TMP"
echo "[cedict] Done: $OUT"
