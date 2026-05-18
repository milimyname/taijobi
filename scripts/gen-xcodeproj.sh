#!/bin/bash
set -euo pipefail

# Regenerate taijobi.xcodeproj from project.yml using XcodeGen.
# Any new Swift files are auto-discovered — no manual pbxproj editing needed.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT/taijobi-ios"

if ! command -v xcodegen &>/dev/null; then
  echo "Error: xcodegen not installed. Run: brew install xcodegen"
  exit 1
fi

xcodegen generate
echo "=== taijobi.xcodeproj regenerated ==="
