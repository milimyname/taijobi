#!/bin/bash
set -euo pipefail

# Build all data binaries (CEDICT + Decomposition + Strokes + EN/DE dictionaries)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/scripts/build-cedict.sh"
"$ROOT/scripts/build-decomp.sh"
"$ROOT/scripts/build-strokes.sh"

# EN/DE dictionaries (optional — large downloads, skip if data not present)
if [ -f "$ROOT/data/kaikki-en-core.jsonl" ]; then
    "$ROOT/scripts/build-endict.sh"
else
    echo "Skipping EN dictionary (run scripts/build-endict.sh to download + compile)"
fi

if [ -f "$ROOT/data/kaikki-de-core.jsonl" ]; then
    "$ROOT/scripts/build-dedict.sh"
else
    echo "Skipping DE dictionary (run scripts/build-dedict.sh to download + compile)"
fi
