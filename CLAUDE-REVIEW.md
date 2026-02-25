# Codebase Review — Post M4

## What the M4 refactor got right

1. **`AppStyle.swift`** — Centralised tokens is the right idea. Font and colour tokens reduce magic values.
2. **`dismissButton` extraction** — Proper deduplication in `FullScreenPopupView`.
3. **`NSHostingController` swap** — More reliable, consistent with `AppDelegate`'s onboarding window.
4. **`SettingsLink` → manual Button** — Correct fix for LSUIElement apps.
5. **Unit tests for pure functions** — Good foundation; `MenuBarFormat` logic is now regression-safe.

## What needs attention

### P0 — Bugs / architectural issues

**1. Duplicate `PopupWindowController` instances**
`AppDelegate` creates one for auto-trigger on event start. `ContentView.onAppear` creates a *second, independent* one for "Test Popup". They don't share state — if the auto-popup is showing, the "Test Popup" one doesn't know about it (the `guard window == nil` only checks its own instance). This is a real bug path.

**2. Debug cruft in `OnboardingView.complete()`**
`OnboardingView.swift:183-200`:
- 3 `print("🔍 ...")` statements
- Redundant `UserDefaults.standard.set(...)` + `.synchronize()` — `@AppStorage` already writes to UserDefaults
- Fragile window lookup by title string `"Welcome to LightsUp"` — `AppDelegate` already holds `onboardingWindow`

**3. Silently swallowed error in `requestAccess()`**
`CalendarManager.swift:46-47`:
```swift
do {
    _ = try await store.requestFullAccessToEvents()
} catch {}
```
No logging, no user feedback. If this fails, the user sees nothing.

### P1 — Incomplete refactor (AppStyle adoption is ~60% done)

**20 inline `.font(.system(...))` calls remain** across 4 files. The refactor only tokenised the common ones (body, caption, captionBold, title2, popupTitle) but left behind:

| Missing token | Used in | Count |
|---|---|---|
| `appBodyBold` (body semibold) | OnboardingView (×2), FullScreenPopupView (×1) | 3 |
| `appHeadline` | SettingsView | 3 |
| `appCallout` | OnboardingView | 3 |
| `appTitle` (.title monospaced) | FullScreenPopupView | 1 |
| `appTitle3` | OnboardingView | 1 |
| `appTitleBold` (.title2 bold) | OnboardingView | 2 |
| `appCaption` (already exists!) | OnboardingView:138 | 1 (missed) |

**Button styles still use inline opacity values** — `MenuRowStyle` and `IconButtonStyle` use `Color.primary.opacity(0.08)` / `0.16` instead of the already-defined `Color.appHoverRow` / `Color.appPressedIcon` tokens.

**`AppStyle.swift` header comment is misleading** — says `.foregroundStyle(.appAccent)` works, but implicit member lookup fails (that's why we had to use `Color.appAccent` everywhere).

### P2 — File organisation

**`ContentView.swift` is 337 lines containing 6 types:**
- `MenuRowStyle` — button style
- `IconButtonStyle` — button style
- `TooltipLabel` — shared component
- `CopyIconButton` — component
- `EventRowView` — major view (shimmer animation, tooltips, meeting actions)
- `ContentView` — the actual dropdown

The button styles and shared components (`TooltipLabel`, `CopyIconButton`) should live in separate files. `EventRowView` is substantial enough (87 lines, its own `@State`, shimmer animation) to be its own file.

**`EKEvent+MeetingURL.swift` has duplicated `NSDataDetector` logic** — the location scan and notes scan are copy-pasted. Should be a `private func extractMeetingURL(from text: String)` helper.

### P3 — Performance / efficiency

**`startMonitoring()` is too aggressive** — every 5 seconds it calls `store.reset()` → `loadCalendars()` (sorts all calendars, writes to array) → `fetchEvents()`. The calendar list rarely changes; `loadCalendars()` should only run on `.EKEventStoreChanged`. The 5s timer should just do `fetchEvents()` + `checkForEventStarts()`.

### P4 — Stale docs

- **`CLAUDE.md:146-148`** — still says F3/F4 are "Pending" — they're done
- **`STYLE-GUIDE.md:162-167`** — "Future Topics" mentions "Formal StyleConstants" — `AppStyle.swift` now partially addresses this
- **`MEMORY.md:32-33`** — same stale status

---

## Recommended cleanup plan

I'd tackle this in priority order:

1. **Fix the duplicate PopupWindowController** — share via environment
2. **Clean OnboardingView** — remove debug prints, redundant UserDefaults, use window reference
3. **Complete AppStyle.swift adoption** — add missing tokens, adopt in button styles, fix all remaining inline fonts
4. **Split ContentView.swift** — extract `EventRowView.swift`, `Components.swift` (styles + tooltips)
5. **DRY the meeting URL extraction**
6. **Reduce timer aggressiveness**
7. **Update docs** (CLAUDE.md, STYLE-GUIDE.md, AppStyle.swift header)
