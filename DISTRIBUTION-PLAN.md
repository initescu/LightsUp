# Distribution Plan — LightsUp

> Moved from PLAN-3.md F2. To be scheduled as a standalone milestone when ready.
> **Status:** Detailed implementation researched and ready — see section below.

## Goal

Make the app installable on other machines. Packaging tooling + GitHub Release workflow.

Notarization requires a **paid Apple Developer Program membership ($99/year)** which the user does not yet have; the scripts are designed to support notarization as an opt-in step added later without code changes.

---

## Notarization reality check

| Scenario | What happens |
|----------|-------------|
| No signing (current) | Works on dev machine only; Gatekeeper blocks on all other Macs |
| Ad-hoc sign (`codesign --sign -`) | Gatekeeper warns on other Macs — but **right-click → Open bypasses it permanently** |
| **Paid Developer account** ($99/yr) | Sign with Developer ID cert + notarize via `notarytool` → Gatekeeper passes silently everywhere |

**Correction from original plan:** ad-hoc signing is NOT machine-local in terms of the signature format — it's a valid signature on any Mac. Gatekeeper will warn, but the recipient can right-click → Open once to permanently allow the app. This makes ad-hoc signed DMGs usable for sharing with real users, not just technical ones.

---

## New files

**`.gitignore`** — excludes `build/`, `*.xcuserstate`, `DerivedData/`, `.DS_Store`

**`scripts/build-release.sh`** — build Release .app, ad-hoc sign, wrap in DMG with /Applications symlink

**`.github/workflows/release.yml`** — triggers on `v*` tags, builds DMG on macOS runner, creates GitHub Release with install instructions

**`RELEASING.md`** — step-by-step release guide (Option A: tag+push; Option B: local build+manual upload) + future notarization path

> **Note:** `scripts/ExportOptions.plist` is not needed. The simpler `xcodebuild build` approach
> (vs archive+export) avoids signing complications and is more transparent.

---

## Verification

1. Run `bash scripts/build-release.sh 1.0.0` from repo root.
2. Verify `build/LightsUp-1.0.0.dmg` is created.
3. Double-click the DMG → mounts with LightsUp + Applications symlink → drag to Applications → launch → app works, calendar permission dialog fires.
4. Push a `v1.0.0` tag → verify GitHub Actions run completes and DMG appears as a release asset.
5. On another Mac running macOS 26: download DMG, right-click → Open → confirm Gatekeeper bypass works and calendar permission fires.

---

## Detailed Implementation (up-to-date approach)

### `.gitignore`

```
# Build artifacts
build/

# Xcode
*.xcuserstate
xcuserdata/
DerivedData/

# macOS
.DS_Store
```

---

### `scripts/build-release.sh`

```bash
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
codesign --force --deep --sign - \
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
```

Key decisions:
- `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` — prevents xcodebuild from failing when it can't use the dev team cert (required on CI; harmless locally)
- `codesign --sign - --options runtime --entitlements …` — ad-hoc sign with Hardened Runtime + calendars entitlement embedded, so TCC shows the permission dialog on the recipient's machine
- `--options runtime` is required because `ENABLE_HARDENED_RUNTIME=YES` is set at build time

---

### `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v4

      - name: Extract version
        run: echo "VERSION=${GITHUB_REF_NAME#v}" >> "$GITHUB_ENV"

      - name: Build
        run: |
          xcodebuild \
            -project LightsUp.xcodeproj \
            -scheme LightsUp \
            -configuration Release \
            -destination "platform=macOS" \
            -derivedDataPath build/DerivedData \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            build

      - name: Sign (ad-hoc)
        run: |
          codesign --force --deep --sign - \
            --entitlements LightsUp/LightsUp.entitlements \
            --options runtime \
            build/DerivedData/Build/Products/Release/LightsUp.app

      - name: Package DMG
        run: |
          STAGE=$(mktemp -d)
          cp -r build/DerivedData/Build/Products/Release/LightsUp.app "$STAGE/"
          ln -s /Applications "$STAGE/Applications"
          hdiutil create \
            -volname "LightsUp ${{ env.VERSION }}" \
            -srcfolder "$STAGE" \
            -ov -format UDZO \
            "build/LightsUp-${{ env.VERSION }}.dmg"
          rm -rf "$STAGE"

      - name: Create GitHub Release
        run: |
          gh release create "${{ github.ref_name }}" \
            "build/LightsUp-${{ env.VERSION }}.dmg" \
            --title "LightsUp ${{ env.VERSION }}" \
            --notes "## Install LightsUp ${{ env.VERSION }}

          **Requirements:** macOS 26 (Tahoe) or later

          ### Steps
          1. Download **LightsUp-${{ env.VERSION }}.dmg** below
          2. Open the DMG and drag **LightsUp** into Applications
          3. First launch: right-click the app → **Open** → click **Open** in the dialog
             *(Gatekeeper requires this one-time step for apps not from the Mac App Store)*
          4. Grant calendar access when prompted

          > This build is ad-hoc signed (no Apple Developer ID). Gatekeeper will warn on first
          > launch — right-click → Open bypasses this permanently."
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

No extra GitHub Secrets required — `GITHUB_TOKEN` is provided automatically by GitHub Actions.

> **macOS 26 runner caveat:** The workflow uses `macos-latest`. If GitHub Actions doesn't yet
> have a macOS 26 runner (deployment target 26.2 requires the macOS 26 SDK), the build will
> fail. Use `bash scripts/build-release.sh` locally + `gh release create` as a fallback.

---

### `RELEASING.md` (content)

See the Verification section above for the full recipient instructions. The file covers:
- Option A: `git tag v1.0.0 && git push origin v1.0.0` → automated CI build
- Option B: `bash scripts/build-release.sh 1.0.0` + manual `gh release create`
- Recipient steps: download DMG, drag to Applications, right-click → Open, grant calendar access
- Future notarization path once a paid Developer account is available
