#!/usr/bin/env bash
# build-release.sh — Build a release DMG. Run from repo root.
# Usage: bash scripts/build-release.sh <version>   e.g.  bash scripts/build-release.sh 1.0.0
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?Usage: $0 <version>  (e.g. 1.0.0)}"
APP_NAME="LightsUp"
DERIVED="build/DerivedData"
APP_PATH="$DERIVED/Build/Products/Release/$APP_NAME.app"
DMG_PATH="build/$APP_NAME-$VERSION.dmg"

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
