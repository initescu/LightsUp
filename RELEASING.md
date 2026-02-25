# Releasing LightsUp

## Prerequisites
- macOS 26 (Tahoe) — must build on the same OS version the app targets
- Xcode installed, `xcodebuild` available in PATH
- `gh` CLI installed and authenticated (for `--publish`)
- `ANTHROPIC_API_KEY` set (for auto-generated changelog) — or provide `--changelog <file>`

## Release steps

### Build only (bump from latest tag)

```bash
bash scripts/build-release.sh --patch              # v1.0.0 → v1.0.1
bash scripts/build-release.sh --minor              # v1.0.0 → v1.1.0
bash scripts/build-release.sh --major              # v1.0.0 → v2.0.0
bash scripts/build-release.sh --version 2.5.0      # explicit version
```

Produces `build/LightsUp-X.Y.Z.dmg`. The script builds, signs (ad-hoc with entitlements), verifies the signature, and packages the DMG. A changelog is auto-generated via the Claude API using commit messages and source diffs since the last release.

### Build + publish to GitHub Releases

```bash
bash scripts/build-release.sh --patch --publish
```

Same as above, plus tags the commit and creates a GitHub Release with the DMG attached and auto-generated release notes.

### Custom changelog

```bash
bash scripts/build-release.sh --patch --changelog CHANGES.md --publish
```

Uses the provided file instead of calling the Claude API.

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
