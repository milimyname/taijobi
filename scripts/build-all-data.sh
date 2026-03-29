#!/bin/bash
set -euo pipefail

# Build all data binaries (CEDICT + Decomposition + Strokes + EN/DE dictionaries)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/scripts/build-cedict.sh"
"$ROOT/scripts/build-decomp.sh"
"$ROOT/scripts/build-strokes.sh"

# EN/DE dictionaries (optional — large downloads, skip if data not present)
if [ -f "$ROOT/data/kaikki-en.jsonl" ]; then
    "$ROOT/scripts/build-endict.sh"
else
    echo "Skipping EN dictionary (data/kaikki-en.jsonl not found — run scripts/build-endict.sh manually)"
fi

if [ -f "$ROOT/data/kaikki-de.jsonl" ]; then
    "$ROOT/scripts/build-dedict.sh"
else
    echo "Skipping DE dictionary (data/kaikki-de.jsonl not found — run scripts/build-dedict.sh manually)"
fi
