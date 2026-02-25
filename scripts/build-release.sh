#!/usr/bin/env bash
# build-release.sh — Build a release DMG and optionally create a GitHub Release.
# Usage: bash scripts/build-release.sh <version>   e.g.  bash scripts/build-release.sh 1.0.0
#        bash scripts/build-release.sh <version> --publish   (also creates GitHub Release)
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?Usage: $0 <version> [--publish]}"
PUBLISH="${2:-}"
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

if [ "$PUBLISH" = "--publish" ]; then
  echo ""
  echo "==> Creating GitHub Release v${VERSION}..."
  TAG="v$VERSION"
  git tag -f "$TAG"
  git push origin "$TAG" --force

  gh release create "$TAG" "$DMG_PATH" \
    --title "LightsUp $VERSION" \
    --notes "## Install LightsUp $VERSION

**Requirements:** macOS 26 (Tahoe) or later

### Steps
1. Download **LightsUp-${VERSION}.dmg** below
2. Open the DMG and drag **LightsUp** into Applications
3. First launch: double-click will show a Gatekeeper warning — click **Done**
4. Go to **System Settings → Privacy & Security** → click **Open Anyway** for LightsUp
5. Grant calendar access when prompted

> This build is ad-hoc signed (no Apple Developer ID). Gatekeeper will warn on first launch — the System Settings bypass is required once."

  echo "✓ GitHub Release created: $TAG"
fi
