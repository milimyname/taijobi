#!/bin/bash
set -euo pipefail

# Full rebuild: WASM (iOS added later)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==============================="
echo "  Build WASM"
echo "==============================="
"$ROOT/scripts/build-wasm.sh"

echo ""
echo "=== All done ==="
