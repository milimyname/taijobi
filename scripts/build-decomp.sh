#!/bin/bash
# Download Make Me a Hanzi dictionary.txt and compile to binary format.
# Run this before `zig build` if decomp.bin doesn't exist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUT="$ROOT_DIR/libtaijobi/src/decomp.bin"

if [ -f "$OUT" ]; then
    echo "[decomp] $OUT already exists, skipping. Delete it to re-download."
    exit 0
fi

echo "[decomp] Downloading Make Me a Hanzi dictionary.txt..."
TMP=$(mktemp -d)
curl -sL "https://raw.githubusercontent.com/skishore/makemeahanzi/master/dictionary.txt" \
    -o "$TMP/dictionary.txt"

echo "[decomp] Compiling to binary format..."
python3 "$SCRIPT_DIR/compile-decomp.py" "$TMP/dictionary.txt" "$OUT"

rm -rf "$TMP"
echo "[decomp] Done: $OUT"
