#!/usr/bin/env bash
# Combines CLAUDE.md + .claude/rules/*.md into a single markdown file.
# Usage: scripts/combine-docs.sh [output-file]
# Default output: docs/taijobi-full.md

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/docs/taijobi-full.md}"

mkdir -p "$(dirname "$OUT")"

{
  cat "$ROOT/CLAUDE.md"

  for f in "$ROOT/.claude/rules"/*.md; do
    printf '\n---\n\n'
    cat "$f"
  done
} > "$OUT"

echo "Combined docs → $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
