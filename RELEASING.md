# Releasing LightsUp

## Prerequisites
- Repo cloned locally, on `main` with a clean working tree
- Xcode installed, `xcodebuild` available in PATH

## Release steps

### Option A — Automated via GitHub Actions (requires macOS 26 runner)

1. Update `MARKETING_VERSION` in Xcode if needed
2. Commit and push to `main`
3. Tag and push:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. GitHub Actions triggers, builds the DMG, and creates a GitHub Release automatically.
5. The release asset (`LightsUp-1.0.0.dmg`) appears under **Releases** on GitHub.

> **Note:** The workflow uses `macos-latest`. If GitHub Actions doesn't yet have a macOS 26
> runner, the build will fail. Use Option B as a fallback.

### Option B — Local build + manual upload

```bash
bash scripts/build-release.sh 1.0.0
```

This produces `build/LightsUp-1.0.0.dmg`. Upload it manually via:
```bash
gh release create v1.0.0 build/LightsUp-1.0.0.dmg \
  --title "LightsUp 1.0.0" \
  --notes "See RELEASING.md for install instructions."
```

---

## Installing on another Mac (recipient instructions)

1. Download the DMG from the GitHub Releases page
2. Open the DMG — a window appears with LightsUp and an Applications shortcut
3. Drag **LightsUp** into **Applications**
4. **First launch:** double-clicking will show a Gatekeeper warning ("Apple could not verify…")
   - Right-click (or ctrl-click) the app → **Open** → click **Open** in the dialog
   - This is a one-time step; subsequent launches work normally
5. When prompted, grant **Calendar access** — the app needs it to show your meetings

---

## Future: notarization (paid Apple Developer account)

Once a paid Apple Developer Program membership ($99/year) is active:

1. Obtain a **Developer ID Application** certificate from Apple
2. Export it and store as `APPLE_CERT_BASE64` + `APPLE_CERT_PASSWORD` in GitHub Secrets
3. Add `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` secrets for `notarytool`
4. Update `scripts/build-release.sh` and the workflow to:
   - Sign with the real Developer ID cert instead of `--sign -`
   - Run `xcrun notarytool submit … --wait`
   - Run `xcrun stapler staple …`
5. With notarization, Gatekeeper passes silently — no right-click needed
