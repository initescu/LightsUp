# Issue: Grant Calendar Access button does nothing on distributed binary

> **Branch:** `claude/fix-calendar-permissions-jjD8q`
> **Status:** Ready to file — code change (diagnostic logging) already committed to this branch

---

## Bug report

**Affects:** distributed binary (DMG / release asset), not dev builds
**macOS:** 26 (Tahoe)
**Reproduced on:** fresh machine that did not build the app

### Steps to reproduce

1. Download and install the LightsUp binary from the DMG
2. Gatekeeper blocks the app (it is not notarized) — bypass via System Settings → Security
3. Open the app — onboarding screen appears correctly
4. Click **"Grant Calendar Access"** on the onboarding screen

### Expected

macOS TCC dialog appears asking for calendar permission.

### Actual

Nothing happens. No system dialog appears. Calendar access is never granted.
Status remains `.notDetermined` indefinitely. The "Grant Calendar Access" button
stays visible but appears non-functional.

---

## Root cause analysis

### 1. `--deep` flag invalidates the code signature (primary cause)

Both `scripts/build-release.sh` and `.github/workflows/release.yml` use:

```bash
codesign --force --deep --sign - \
  --entitlements LightsUp/LightsUp.entitlements \
  --options runtime \
  "$APP_PATH"
```

`--deep` is deprecated by Apple (see [TN3124](https://developer.apple.com/documentation/technotes/tn3124-inside-code-signing-provisioning-profiles)).
For Swift apps, it signs embedded frameworks in the **wrong order** — each
framework must be individually signed *before* the main bundle. The resulting
signature is structurally invalid at the framework/binary chain level.

macOS TCC validates entitlements through the full code-signature chain before
showing a permission dialog. An invalid chain → TCC silently skips the dialog.
The `com.apple.security.personal-information.calendars` entitlement IS present
in `LightsUp/LightsUp.entitlements`, but TCC cannot verify it through the broken
signature.

This matches the exact silent-failure pattern already documented in `CLAUDE.md`:
> "Without it, the TCC dialog never fires (silent failure)."

Here the entitlement exists, but the broken signature makes it invisible to TCC.

**Relevant commits:**
- `7b565cf` — added the entitlement and fixed the dialog in dev builds ✓
- `3d384ad` — introduced distribution tooling with the broken `--deep` signing ✗

**Fix:** Remove `--deep`. Sign each embedded framework individually first, then
sign the main `.app`:

```bash
# Sign any embedded frameworks/dylibs first
find "$APP_PATH/Contents/Frameworks" \
  \( -name "*.framework" -o -name "*.dylib" \) 2>/dev/null | \
  while read fw; do
    codesign --force --sign - "$fw"
  done

# Then sign the main bundle with entitlements
codesign --force --sign - \
  --entitlements LightsUp/LightsUp.entitlements \
  --options runtime \
  "$APP_PATH"
```

Apply the same fix to both `scripts/build-release.sh` and
`.github/workflows/release.yml`.

---

### 2. Silent `catch {}` makes the failure undiagnosable (contributing factor)

`CalendarManager.swift` (before the fix on this branch):

```swift
func requestAccess() async {
    do {
        _ = try await store.requestFullAccessToEvents()
    } catch {}   // ← all errors silently discarded
    authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    ...
}
```

When TCC refuses to show the dialog, `requestFullAccessToEvents()` throws. Because
the error is discarded silently and `authorizationStatus` stays `.notDetermined`,
the button just re-renders with no visible feedback — impossible to debug without
reading source.

**Fix on this branch:** errors and the resulting auth status are now printed to
`stdout` (visible in Console.app filtered by process name `LightsUp`).

---

### 3. GitHub Actions runner is not macOS 26 (secondary risk)

`MACOSX_DEPLOYMENT_TARGET = 26.2` in the project, but `macos-latest` on GitHub
Actions is macOS 14 or 15. Building a macOS 26.2 app on an older runner without
the macOS 26 SDK may affect how entitlements are compiled into the binary and how
TCC handles them at runtime.

---

### 4. Gatekeeper bypass method affects TCC (user-side factor)

The release notes instruct: *"right-click → Open → click Open in the dialog"*.
The user went via **System Settings → Security** instead (because Gatekeeper moved
the app to the Bin on macOS 26). These two bypass flows have different effects on
TCC's willingness to honor entitlements for the bypassed app.

The release notes should explicitly warn that the System Settings path may not
work and that right-click → Open is required.

---

## Proposed fixes (checklist)

- [ ] Remove `--deep` from `scripts/build-release.sh` codesign call
- [ ] Remove `--deep` from `.github/workflows/release.yml` codesign step
- [ ] Add per-framework signing before signing the `.app` in both files
- [ ] Update Gatekeeper bypass instructions in `RELEASING.md` / release notes:
      warn that System Settings bypass may break TCC; require right-click → Open
- [ ] Investigate using a macOS 26 GitHub Actions runner for releases
- [ ] (Done on this branch) Add error logging in `CalendarManager.requestAccess()`

---

## How to verify the fix

After applying the codesign fix, confirm the signature is valid on the
**target machine** (not the build machine):

```bash
# Should print the entitlement
codesign -d --entitlements :- /Applications/LightsUp.app

# Should exit 0 with no errors
codesign --verify --deep --strict --verbose=2 /Applications/LightsUp.app

# Check Console.app for LightsUp process after clicking Grant Calendar Access
# With the logging fix on this branch you should see:
#   [LightsUp] authorizationStatus after request: <N>
# If N stays 0 (notDetermined) and no TCC dialog appeared, the signature is bad.
```

---

## Files changed on this branch

| File | Change |
|------|--------|
| `LightsUp/CalendarManager.swift` | Added error logging in `requestAccess()` |

## Files that need changes (not yet done)

| File | Required change |
|------|----------------|
| `scripts/build-release.sh` | Replace `--deep` with per-framework signing |
| `.github/workflows/release.yml` | Same codesign fix |
| `RELEASING.md` | Update Gatekeeper bypass instructions |
