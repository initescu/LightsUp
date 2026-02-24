# Milestone 3 Plan — LightsUp

## Context

Milestone 2 shipped a live menu bar label, instant calendar refresh, and launch at login. Milestone 3 has two goals:

1. **Fix calendar sync lag** — users report events take several seconds to reflect after edits in Calendar.app or when new events are added. The `EKEventStoreChanged` notification is the primary refresh path but it can be slow or delayed; the 5 s monitoring timer currently only checks for meeting starts, not data freshness.

2. **Distribution** — make the app installable on other machines. Packaging tooling + GitHub Release workflow. Notarization requires a **paid Apple Developer Program membership ($99/year)** which the user does not yet have; the scripts are designed to support notarization as an opt-in step added later without code changes.

---

## Features

### F1 · Calendar sync speed fix

**Root cause:** `fetchEvents()` is called in three places: `init`, `enabledCalendarIDs.didSet`, and the `EKEventStoreChanged` notification handler. The 5 s monitoring timer (`startMonitoring`) only calls `checkForEventStarts()` — it never refreshes event data. If the `EKEventStoreChanged` notification arrives late (which happens — Apple Calendar's local change propagation can take several seconds), stale data can persist much longer than 5 s.

**Fix:** In `startMonitoring()`, expand the timer body to call `store.reset()` + `loadCalendars()` + `fetchEvents()` before `checkForEventStarts()`. This guarantees event data is never more than 5 s stale, independent of notification timing.

`store.reset()` must precede `fetchEvents()` in the timer (same as in the notification handler) — otherwise the in-memory cache may return stale objects even though the database has changed.

**Performance:** `store.reset()` + `store.events(matching:)` are local database reads via `CalendarAgent` XPC. For a typical user (a few calendars, ~50 events today + tomorrow) this completes in < 5 ms and is not perceptible.

**Exact change in `CalendarManager.swift`:**

```swift
// Before
private func startMonitoring() {
    monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        Task { @MainActor [weak self] in
            self?.checkForEventStarts()
        }
    }
}

// After
private func startMonitoring() {
    monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.store.reset()
            self.loadCalendars()
            self.fetchEvents()
            self.checkForEventStarts()
        }
    }
}
```

Note: `checkForEventStarts()` continues to run last — it reads from the freshly-updated `todayEvents` array, so popups fire with accurate data.

---

### F2 · Distribution tooling

#### Notarization reality check

| Scenario | What happens |
|----------|-------------|
| No signing (current) | Works on dev machine only; Gatekeeper blocks on all other Macs |
| Ad-hoc sign (`codesign --sign -`) | Same — Gatekeeper blocks on other Macs; ad-hoc identity is machine-local |
| **Paid Developer account** ($99/yr) | Sign with Developer ID cert + notarize via `notarytool` → Gatekeeper passes silently everywhere |

**M3 delivers:** build script + GitHub Actions workflow + `ExportOptions.plist`. The notarization step in `scripts/build-release.sh` is gated behind a `NOTARIZE=1` env var — set it to `0` (the default) to produce an unsigned DMG that works on your own machine and can be shared with technical users who know how to right-click > Open. Set it to `1` once you have a Developer account.

#### New files

**`scripts/build-release.sh`** — archive, export, optional notarize, wrap in DMG

**`scripts/ExportOptions.plist`** — xcodebuild export configuration

**`.github/workflows/release.yml`** — triggers on `v*` tags, builds DMG on macOS runner, uploads as GitHub Release asset

**`RELEASING.md`** — step-by-step release guide including future notarization instructions

---

## Critical files

| File | Change |
|------|--------|
| `LightsUp/CalendarManager.swift` | `startMonitoring()` timer body: add `store.reset()` + `loadCalendars()` + `fetchEvents()` before `checkForEventStarts()` |
| `scripts/build-release.sh` | **NEW** — archive, export, optional notarize, DMG |
| `scripts/ExportOptions.plist` | **NEW** — xcodebuild export config |
| `.github/workflows/release.yml` | **NEW** — CI release workflow |
| `RELEASING.md` | **NEW** — step-by-step release guide |

---

## Verification

### F1 — Calendar sync speed
1. Build & run.
2. Open Calendar.app → edit an event title for a meeting today.
3. Click the LightsUp menu bar icon → dropdown should show the updated title within ≤ 5 s (no app restart needed).
4. Add a new event for today → appears in dropdown within ≤ 5 s.

### F2 — Distribution build
1. Run `bash scripts/build-release.sh 1.0.0` from repo root.
2. Verify `build/LightsUp-1.0.0.dmg` is created.
3. Double-click the DMG → mount → drag LightsUp.app to Applications → launch → app works.
4. (On dev machine) Verify Gatekeeper doesn't block (ad-hoc sign is trusted locally).
5. Push a `v1.0.0` tag → verify GitHub Actions run completes and DMG appears as a release asset.

### Build check
`./scripts/verify.sh` passes (0 SwiftLint violations, xcodebuild succeeds).
