#!/bin/bash
set -euo pipefail

# Build all data binaries (CEDICT + Decomposition + Strokes)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/scripts/build-cedict.sh"
"$ROOT/scripts/build-decomp.sh"
"$ROOT/scripts/build-strokes.sh"
