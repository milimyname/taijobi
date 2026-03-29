#!/bin/bash
set -euo pipefail

# Download and compile German Wiktionary dictionary (kaikki.org/wiktextract)
# Downloads per-POS files (noun, verb, adj, adv) and streams through compiler.

DATA_DIR="data"
STATIC_DIR="taijobi-web/static/data"
OUTPUT="$STATIC_DIR/dedict.bin"
COMBINED="$DATA_DIR/kaikki-de-core.jsonl"

mkdir -p "$DATA_DIR" "$STATIC_DIR"

BASE="https://kaikki.org/dictionary/German"
POS_FILES=(
    "pos-noun/kaikki.org-dictionary-German-by-pos-noun.jsonl"
    "pos-verb/kaikki.org-dictionary-German-by-pos-verb.jsonl"
    "pos-adj/kaikki.org-dictionary-German-by-pos-adj.jsonl"
    "pos-adv/kaikki.org-dictionary-German-by-pos-adv.jsonl"
)

# Download and concatenate if not present
if [ ! -f "$COMBINED" ]; then
    echo "=== Downloading German Wiktextract (noun + verb + adj + adv) ==="
    > "$COMBINED"
    for pf in "${POS_FILES[@]}"; do
        echo "  Downloading $pf..."
        curl -L --progress-bar "$BASE/$pf" >> "$COMBINED"
    done
    echo "  Downloaded $(wc -l < "$COMBINED") lines"
fi

echo "=== Compiling German dictionary ==="
bun scripts/compile-wiktdict.ts "$COMBINED" "$OUTPUT" WKDE

echo "=== Done ==="
ls -lh "$OUTPUT"
