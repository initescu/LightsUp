# Milestone 5 — Maintenance & Architecture

Deferred from M4 review (CLAUDE-REVIEW.md). All items are non-breaking improvements.

---

## P0 · Bugs / architectural issues

### F1 · Deduplicate PopupWindowController

**Problem:** `AppDelegate` owns one `PopupWindowController` (for auto-trigger on event start). `ContentView.onAppear` creates a *second, independent* one (for the "Test Popup" button). They don't share state — both have their own `guard window == nil` check, so both could show simultaneously.

**Fix:** Remove `ContentView`'s local `@State private var popup`. Instead, surface `AppDelegate.popupController` through the environment or pass it down explicitly so both trigger paths share the same instance.

**Risk:** Medium — requires threading the controller through the environment. Test: trigger "Test Popup" while auto-popup is also showing (needs a real event starting) and confirm only one popup appears.

---

### F2 · Silent `requestAccess()` failure in CalendarManager

**File:** `CalendarManager.swift:46-47`

```swift
do {
    _ = try await store.requestFullAccessToEvents()
} catch {}  // swallowed
```

**Fix:** At minimum, log the error. Better: set an `authorizationError: String?` published property that `OnboardingView`'s calendarAccessControl can surface to the user.

---

## P2 · Code organisation

### F3 · Split ContentView.swift

**Problem:** 337-line file contains 6 types: `MenuRowStyle`, `IconButtonStyle`, `TooltipLabel`, `CopyIconButton`, `EventRowView`, `ContentView`.

**Fix:**
- `Styles.swift` — `MenuRowStyle`, `IconButtonStyle`
- `Components.swift` — `TooltipLabel`, `CopyIconButton`
- `EventRowView.swift` — `EventRowView` (87 lines, has its own shimmer animation + @State)
- `ContentView.swift` — just `ContentView` (~80 lines)

### F4 · DRY EKEvent+MeetingURL.swift

Duplicated `NSDataDetector` pattern for scanning location vs notes. Extract a `private func firstMeetingURL(in text: String?) -> URL?` helper and call it for both fields.

---

## P3 · Performance

### F5 · Reduce timer aggressiveness in CalendarManager

**Problem:** `startMonitoring()` calls `store.reset()` → `loadCalendars()` → `fetchEvents()` every 5 s. `loadCalendars()` sorts all calendars and writes them to the array — unnecessary since the calendar list rarely changes.

**Fix:** Timer callback should only do `fetchEvents()` + `checkForEventStarts()`. Move `loadCalendars()` to only run on `.EKEventStoreChanged`.

**Risk:** Low — `loadCalendars()` is fast, but removing it from the hot path is cleaner.

---

## Verification (per feature)

| Feature | How to test |
|---------|-------------|
| F1 (dedup popup) | Start a test event, let auto-popup trigger, then also click "Test Popup" — should not stack two overlays |
| F2 (requestAccess error) | Revoke calendar permission, relaunch, tap "Grant Calendar Access" — error should surface visibly |
| F3 (file split) | Build succeeds, all types still accessible |
| F4 (DRY URL) | Zoom/Meet/Teams links still extracted correctly from both location and notes fields |
| F5 (timer) | Calendar list still updates after adding/removing a calendar in System Settings → Calendar |
