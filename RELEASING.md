# Releasing LightsUp

## Prerequisites
- macOS 26 (Tahoe) — must build on the same OS version the app targets
- Xcode installed, `xcodebuild` available in PATH
- `gh` CLI installed and authenticated (for `--publish`)

## Release steps

### Build only

```bash
bash scripts/build-release.sh 1.0.0
```

Produces `build/LightsUp-1.0.0.dmg`. The script builds, signs (ad-hoc with entitlements), verifies the signature, and packages the DMG.

### Build + publish to GitHub Releases

```bash
bash scripts/build-release.sh 1.0.0 --publish
```

Same as above, plus tags the commit `v1.0.0` and creates a GitHub Release with the DMG attached.

---

## Installing on another Mac (recipient instructions)

1. Download the DMG from the GitHub Releases page
2. Open the DMG — a window appears with LightsUp and an Applications shortcut
3. Drag **LightsUp** into **Applications**
4. **First launch:** double-clicking will show a Gatekeeper warning ("Apple could not verify…")
   - Click **Done** (do not move to Bin)
   - Go to **System Settings → Privacy & Security**, scroll down to find the "LightsUp was blocked" message
   - Click **Open Anyway** and authenticate
   - This is a one-time step; subsequent launches work normally
5. When prompted, grant **Calendar access** — the app needs it to show your meetings

---

## Future: notarization (paid Apple Developer account)

Once a paid Apple Developer Program membership ($99/year) is active:

1. Obtain a **Developer ID Application** certificate from Apple
2. Update `scripts/build-release.sh` to:
   - Sign with the real Developer ID cert instead of `--sign -`
   - Run `xcrun notarytool submit … --wait`
   - Run `xcrun stapler staple …`
3. With notarization, Gatekeeper passes silently — no bypass needed
