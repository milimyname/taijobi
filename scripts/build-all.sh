#!/bin/bash
set -euo pipefail

# Full rebuild: CEDICT + Decomposition + Strokes + WASM (iOS added later)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==============================="
echo "  Build CEDICT"
echo "==============================="
"$ROOT/scripts/build-cedict.sh"

echo ""
echo "==============================="
echo "  Build Decomposition Data"
echo "==============================="
"$ROOT/scripts/build-decomp.sh"

echo ""
echo "==============================="
echo "  Build Stroke Data"
echo "==============================="
"$ROOT/scripts/build-strokes.sh"

echo ""
echo "==============================="
echo "  Build WASM"
echo "==============================="
"$ROOT/scripts/build-wasm.sh"

echo ""
echo "=== All done ==="
