#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/taijobi-web/package.json"
CHANGELOG="$ROOT/CHANGELOG.md"

# ── helpers ──────────────────────────────────────────────────────────────────

die() { echo "error: $1" >&2; exit 1; }

usage() {
  echo "Usage: $0 <patch|minor|major|X.Y.Z> [--push]"
  echo ""
  echo "Examples:"
  echo "  $0 patch         # 0.0.1 → 0.0.2"
  echo "  $0 minor --push  # 0.0.1 → 0.1.0, push immediately"
  echo "  $0 major         # 0.0.1 → 1.0.0"
  echo "  $0 1.0.0         # explicit version"
  exit 1
}

current_version() {
  grep '"version"' "$PKG" | head -1 | sed 's/.*"\([0-9]*\.[0-9]*\.[0-9]*\)".*/\1/'
}

bump_version() {
  local cur="$1" type="$2"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$cur"

  case "$type" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "${major}.$((minor + 1)).0" ;;
    patch) echo "${major}.${minor}.$((patch + 1))" ;;
    *)     die "unknown bump type: $type" ;;
  esac
}

# ── args ─────────────────────────────────────────────────────────────────────

[[ $# -ge 1 ]] || usage

PUSH=false
BUMP_ARG=""

for arg in "$@"; do
  case "$arg" in
    --push) PUSH=true ;;
    *) BUMP_ARG="$arg" ;;
  esac
done

[[ -n "$BUMP_ARG" ]] || usage

OLD=$(current_version)
[[ -n "$OLD" ]] || die "could not read version from $PKG"

case "$BUMP_ARG" in
  patch|minor|major) NEW=$(bump_version "$OLD" "$BUMP_ARG") ;;
  [0-9]*.[0-9]*.[0-9]*) NEW="$BUMP_ARG" ;;
  *) usage ;;
esac

[[ "$OLD" != "$NEW" ]] || die "new version ($NEW) is same as current ($OLD)"

echo "Bumping $OLD → $NEW"

# ── update package.json ──────────────────────────────────────────────────────

sed -i '' "s/\"version\": \"$OLD\"/\"version\": \"$NEW\"/" "$PKG"
echo "  updated $PKG"

# ── generate changelog entry ─────────────────────────────────────────────────

PREV_TAG=$(git tag -l --sort=-v:refname | head -1 2>/dev/null || true)
DATE=$(date +%Y-%m-%d)

if [[ -n "$PREV_TAG" ]]; then
  COMMITS=$(git log --pretty=format:"- %s" --no-merges "$PREV_TAG"..HEAD \
    | grep -vE '^- (release|chore|ci|build): ' || true)
else
  COMMITS=$(git log --pretty=format:"- %s" --no-merges \
    | grep -vE '^- (release|chore|ci|build): ' || true)
fi

if [[ -z "$COMMITS" ]]; then
  COMMITS="- Version bump"
fi

ENTRY="## v${NEW} (${DATE})

${COMMITS}"

if [[ -f "$CHANGELOG" ]]; then
  TMPFILE=$(mktemp)
  head -1 "$CHANGELOG" > "$TMPFILE"
  echo "" >> "$TMPFILE"
  echo "$ENTRY" >> "$TMPFILE"
  tail -n +2 "$CHANGELOG" >> "$TMPFILE"
  mv "$TMPFILE" "$CHANGELOG"
else
  cat > "$CHANGELOG" <<EOF
# Changelog

$ENTRY
EOF
fi

echo "  updated $CHANGELOG"

# ── commit + tag ─────────────────────────────────────────────────────────────

git add "$PKG" "$CHANGELOG"
git commit -m "release: v${NEW}"
git tag "v${NEW}"

echo ""
echo "Done! Created commit and tag v${NEW}."

# ── push ─────────────────────────────────────────────────────────────────────

if [[ "$PUSH" == true ]]; then
  echo ""
  echo "Pushing..."
  git push && git push origin "v${NEW}"
  echo "Pushed! CI will build and deploy."
else
  echo ""
  echo "To publish:"
  echo "  git push && git push origin v${NEW}"
  echo ""
  echo "Or next time, use --push:"
  echo "  $0 $BUMP_ARG --push"
fi
