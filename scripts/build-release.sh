#!/usr/bin/env bash
# build-release.sh — Build a release DMG and optionally create a GitHub Release.
#
# Usage:
#   bash scripts/build-release.sh --patch [--publish]                # 1.0.0 → 1.0.1
#   bash scripts/build-release.sh --minor [--publish]                # 1.0.0 → 1.1.0
#   bash scripts/build-release.sh --major [--publish]                # 1.0.0 → 2.0.0
#   bash scripts/build-release.sh --version 1.2.3 [--publish]
#   bash scripts/build-release.sh --patch --changelog CHANGES.md [--publish]
#
# Changelog:
#   By default, generates a changelog via the Claude API (requires ANTHROPIC_API_KEY).
#   Use --changelog <file> to provide a pre-written changelog instead.
set -euo pipefail

cd "$(dirname "$0")/.."

# ── Load .env if present ─────────────────────────────────────────────

if [[ -f .env ]]; then
  # shellcheck source=/dev/null
  source .env
fi

# ── Parse arguments ──────────────────────────────────────────────────

VERSION=""
BUMP=""
PUBLISH=false
CHANGELOG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --patch|--minor|--major) BUMP="${1#--}"; shift ;;
    --publish) PUBLISH=true; shift ;;
    --changelog) CHANGELOG_FILE="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 (--patch | --minor | --major | --version X.Y.Z) [--changelog FILE] [--publish]" >&2
      exit 1
      ;;
  esac
done

# ── Resolve version ─────────────────────────────────────────────────

get_latest_tag() {
  git tag -l 'v*' --sort=-v:refname | head -1 | sed 's/^v//'
}

bump_version() {
  local ver="$1" part="$2"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$ver"
  case "$part" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "${major}.$((minor + 1)).0" ;;
    patch) echo "${major}.${minor}.$((patch + 1))" ;;
  esac
}

LATEST_TAG=""
if [[ -n "$BUMP" ]]; then
  LATEST_TAG=$(get_latest_tag)
  if [[ -z "$LATEST_TAG" ]]; then
    echo "Error: no existing v* tags found — use --version to set the first release." >&2
    exit 1
  fi
  VERSION=$(bump_version "$LATEST_TAG" "$BUMP")
  echo "==> Latest tag: v${LATEST_TAG} → bumping ${BUMP} → v${VERSION}"
elif [[ -n "$VERSION" ]]; then
  LATEST_TAG=$(get_latest_tag)
else
  echo "Usage: $0 (--patch | --minor | --major | --version X.Y.Z) [--changelog FILE] [--publish]" >&2
  exit 1
fi

# ── Generate changelog ───────────────────────────────────────────────

generate_changelog() {
  if [[ -n "$CHANGELOG_FILE" ]]; then
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
      echo "Error: changelog file not found: $CHANGELOG_FILE" >&2
      exit 1
    fi
    cat "$CHANGELOG_FILE"
    return
  fi

  # Auto-generate via Claude API
  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "Error: ANTHROPIC_API_KEY is not set and no --changelog file provided." >&2
    echo "Either set ANTHROPIC_API_KEY or pass --changelog <file>." >&2
    exit 1
  fi

  local commit_range
  if [[ -n "$LATEST_TAG" ]]; then
    commit_range="v${LATEST_TAG}..HEAD"
  else
    commit_range="HEAD~20..HEAD"
  fi

  local commits
  commits=$(git log "$commit_range" --pretty=format:"--- %h ---%n%s%n%b" 2>/dev/null || echo "")

  if [[ -z "$commits" ]]; then
    echo "No changes since last release."
    return
  fi

  local diffstat
  diffstat=$(git diff "$commit_range" --stat 2>/dev/null || echo "")

  local diff
  diff=$(git diff "$commit_range" -- '*.swift' 2>/dev/null | head -c 10000 || echo "")

  echo "==> Generating changelog via Claude API…" >&2

  local prompt
  prompt="You are writing release notes for LightsUp v${VERSION}, a macOS menu bar app that shows upcoming calendar events.

Below is the full context of changes since v${LATEST_TAG:-0.0.0}.

COMMIT MESSAGES:
${commits}

FILES CHANGED:
${diffstat}

SOURCE DIFF (Swift files):
${diff}

Write a concise \"What's New\" section in markdown. Use bullet points. Group related changes. Focus on user-facing changes — skip internal refactors, doc updates, and build changes unless they affect the user. Do not include a heading — just the bullet points."

  local escaped_prompt
  escaped_prompt=$(printf '%s' "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

  local response
  response=$(curl -s https://api.anthropic.com/v1/messages \
    -H "content-type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "{
      \"model\": \"claude-haiku-4-5-20251001\",
      \"max_tokens\": 1024,
      \"messages\": [{\"role\": \"user\", \"content\": ${escaped_prompt}}]
    }")

  local changelog
  changelog=$(printf '%s' "$response" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data["content"][0]["text"])' 2>/dev/null)

  if [[ -z "$changelog" ]]; then
    echo "Error: failed to generate changelog from Claude API." >&2
    echo "Response: $response" >&2
    exit 1
  fi

  echo "$changelog"
}

CHANGELOG=$(generate_changelog)
echo "==> Changelog:"
echo "$CHANGELOG"
echo ""

# ── Build ────────────────────────────────────────────────────────────

APP_NAME="LightsUp"
DERIVED="build/DerivedData"
APP_PATH="$DERIVED/Build/Products/Release/$APP_NAME.app"
DMG_PATH="build/$APP_NAME-$VERSION.dmg"

rm -rf build
mkdir -p build

echo "==> Building $APP_NAME $VERSION (Release)…"
xcodebuild \
  -project LightsUp.xcodeproj \
  -scheme LightsUp \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" \
  | grep -v appintentsmetadata

echo "==> Signing (ad-hoc)…"
# Sign embedded frameworks/dylibs first (--deep is deprecated and breaks the
# code-signature chain, causing TCC to silently reject entitlements).
if [ -d "$APP_PATH/Contents/Frameworks" ]; then
  find "$APP_PATH/Contents/Frameworks" \
    \( -name "*.framework" -o -name "*.dylib" \) | \
    while read -r fw; do
      echo "    signing $fw"
      codesign --force --sign - "$fw"
    done
fi

# Then sign the main bundle with entitlements
codesign --force --sign - \
  --entitlements LightsUp/LightsUp.entitlements \
  --options runtime \
  "$APP_PATH"

echo "==> Verifying signature…"
codesign --verify --deep --strict "$APP_PATH"
echo "    signature valid"

echo "==> Packaging DMG…"
STAGE=$(mktemp -d)
cp -r "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG_PATH"
rm -rf "$STAGE"

echo ""
echo "✓ $DMG_PATH"

if $PUBLISH; then
  echo ""
  echo "==> Creating GitHub Release v${VERSION}..."
  TAG="v$VERSION"
  git tag -f "$TAG"
  git push origin "$TAG" --force

  NOTES="## What's New in $VERSION

$CHANGELOG

---

## Install

**Requirements:** macOS 26 (Tahoe) or later

1. Download **LightsUp-${VERSION}.dmg** below
2. Open the DMG and drag **LightsUp** into Applications
3. First launch: double-click will show a Gatekeeper warning — click **Done**
4. Go to **System Settings → Privacy & Security** → click **Open Anyway** for LightsUp
5. Grant calendar access when prompted

> This build is ad-hoc signed (no Apple Developer ID). Gatekeeper will warn on first launch — the System Settings bypass is required once."

  gh release create "$TAG" "$DMG_PATH" \
    --title "LightsUp $VERSION" \
    --notes "$NOTES"

  echo "✓ GitHub Release created: $TAG"
fi
