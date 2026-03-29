#!/bin/bash
set -euo pipefail

# Download and compile English Wiktionary dictionary (kaikki.org/wiktextract)
# Downloads per-POS files (noun, verb, adj, adv) and streams through compiler.

DATA_DIR="data"
STATIC_DIR="taijobi-web/static/data"
OUTPUT="$STATIC_DIR/endict.bin"
COMBINED="$DATA_DIR/kaikki-en-core.jsonl"

mkdir -p "$DATA_DIR" "$STATIC_DIR"

BASE="https://kaikki.org/dictionary/English"
POS_FILES=(
    "pos-noun/kaikki.org-dictionary-English-by-pos-noun.jsonl"
    "pos-verb/kaikki.org-dictionary-English-by-pos-verb.jsonl"
    "pos-adj/kaikki.org-dictionary-English-by-pos-adj.jsonl"
    "pos-adv/kaikki.org-dictionary-English-by-pos-adv.jsonl"
)

# Download and concatenate if not present
if [ ! -f "$COMBINED" ]; then
    echo "=== Downloading English Wiktextract (noun + verb + adj + adv) ==="
    > "$COMBINED"
    for pf in "${POS_FILES[@]}"; do
        echo "  Downloading $pf..."
        curl -L --progress-bar "$BASE/$pf" >> "$COMBINED"
    done
    echo "  Downloaded $(wc -l < "$COMBINED") lines"
fi

echo "=== Compiling English dictionary ==="
bun scripts/compile-wiktdict.ts "$COMBINED" "$OUTPUT" WKEN

echo "=== Done ==="
ls -lh "$OUTPUT"
