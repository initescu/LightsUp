# Distribution Plan — LightsUp

> Moved from PLAN-3.md F2. To be scheduled as a standalone milestone when ready.

## Goal

Make the app installable on other machines. Packaging tooling + GitHub Release workflow.

Notarization requires a **paid Apple Developer Program membership ($99/year)** which the user does not yet have; the scripts are designed to support notarization as an opt-in step added later without code changes.

---

## Notarization reality check

| Scenario | What happens |
|----------|-------------|
| No signing (current) | Works on dev machine only; Gatekeeper blocks on all other Macs |
| Ad-hoc sign (`codesign --sign -`) | Same — Gatekeeper blocks on other Macs; ad-hoc identity is machine-local |
| **Paid Developer account** ($99/yr) | Sign with Developer ID cert + notarize via `notarytool` → Gatekeeper passes silently everywhere |

The notarization step in `scripts/build-release.sh` is gated behind a `NOTARIZE=1` env var — set it to `0` (the default) to produce an unsigned DMG that works on your own machine and can be shared with technical users who know how to right-click > Open. Set it to `1` once you have a Developer account.

---

## New files

**`scripts/build-release.sh`** — archive, export, optional notarize, wrap in DMG

**`scripts/ExportOptions.plist`** — xcodebuild export configuration

**`.github/workflows/release.yml`** — triggers on `v*` tags, builds DMG on macOS runner, uploads as GitHub Release asset

**`RELEASING.md`** — step-by-step release guide including future notarization instructions

---

## Verification

1. Run `bash scripts/build-release.sh 1.0.0` from repo root.
2. Verify `build/LightsUp-1.0.0.dmg` is created.
3. Double-click the DMG → mount → drag LightsUp.app to Applications → launch → app works.
4. (On dev machine) Verify Gatekeeper doesn't block (ad-hoc sign is trusted locally).
5. Push a `v1.0.0` tag → verify GitHub Actions run completes and DMG appears as a release asset.
