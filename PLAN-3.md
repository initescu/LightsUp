# Milestone 3 Plan — LightsUp

## Context

Milestone 2 shipped a live menu bar label, instant calendar refresh, and launch at login. Milestone 3 has one goal:

1. **Fix calendar sync lag** — users report events take several seconds to reflect after edits in Calendar.app or when new events are added. The `EKEventStoreChanged` notification is the primary refresh path but it can be slow or delayed; the 5 s monitoring timer currently only checks for meeting starts, not data freshness.

> **Distribution (F2) has been moved to `DISTRIBUTION-PLAN.md`.**

---

## Features

### F1 · Calendar sync speed fix ✅ DONE

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

## Critical files

| File | Change |
|------|--------|
| `LightsUp/CalendarManager.swift` | `startMonitoring()` timer body: add `store.reset()` + `loadCalendars()` + `fetchEvents()` before `checkForEventStarts()` |

---

## Verification

### F1 — Calendar sync speed ✅ VALIDATED
1. Build & run.
2. Open Calendar.app → edit an event title for a meeting today.
3. Click the LightsUp menu bar icon → dropdown should show the updated title within ≤ 5 s (no app restart needed).
4. Add a new event for today → appears in dropdown within ≤ 5 s.

**Note:** Required an additional fix beyond the plan — `ContentView` needed a 5 s `Timer.publish` ticker (same pattern as `MenuBarLabelView`) because `@Observable` propagation to `MenuBarExtra` window content is unreliable on macOS 26. The ticker forces re-renders so the dropdown always reflects fresh data.

### Build check
`./scripts/verify.sh` passes (0 SwiftLint violations, xcodebuild succeeds).
