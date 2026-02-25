# Codebase Review — Post M4

## What the M4 refactor got right

1. **`AppStyle.swift`** — Centralised tokens is the right idea. Font and colour tokens reduce magic values.
2. **`dismissButton` extraction** — Proper deduplication in `FullScreenPopupView`.
3. ~~**`NSHostingController` swap**~~ — **Reverted.** `NSHostingController` drives window sizing from SwiftUI content, which collapses borderless fullscreen windows. `NSHostingView` is correct for the popup. Only use `NSHostingController` for windowed views (onboarding).
4. ~~**`SettingsLink` → manual Button**~~ — **Reverted.** macOS 26 enforces `SettingsLink` for opening Settings scenes. The `NSApp.sendAction(Selector(("showSettingsWindow:")))` workaround now logs `"Please use SettingsLink"` and does nothing.
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

---

## Post-review regressions found & fixed

### NSHostingController broke fullscreen popup
The M4 swap from `NSHostingView` → `NSHostingController` in `PopupWindowController` caused the popup to render only in the bottom-left corner. Root cause: `NSHostingController` defaults to `sizingOptions = .preferredContentSize`, shrinking the borderless window to the SwiftUI content's intrinsic size. Setting `sizingOptions = []` made the window invisible entirely. **Fix:** reverted to `NSHostingView(rootView:)` as `win.contentView`.

**Rule:** Use `NSHostingView` for borderless/fullscreen overlay windows. Use `NSHostingController` only for titled/windowed views where the controller should drive sizing (e.g. onboarding).

### `NSApp.sendAction(showSettingsWindow:)` blocked on macOS 26
The M4 replacement of `SettingsLink` with a manual `Button` + `NSApp.sendAction(Selector(("showSettingsWindow:")))` no longer works on macOS 26 — runtime logs `"Please use SettingsLink for opening the Settings scene"` and the window doesn't open. **Fix:** reverted to `SettingsLink` with styled label content.

### `NSApp.activate()` in SettingsView caused warnings
The `.onAppear { NSApp.activate() }` in `SettingsView` triggered the same `"Please use SettingsLink"` warning on first interaction with the format Picker. Removed — `SettingsLink` handles activation on macOS 26.

**Known limitation:** Settings window sometimes opens behind the active window on LSUIElement apps. No clean workaround found yet — `NSApp.activate()` causes the SettingsLink warning.

---

## Future UX idea: Dropdown persistence

**Request:** Keep the `MenuBarExtra` dropdown open while interacting with the Settings window, so the user can see both simultaneously.

**Assessment:** This is **not feasible** with the current `MenuBarExtra(.window)` API. `MenuBarExtra` dismisses its panel whenever it loses focus — this is hardcoded AppKit behavior that SwiftUI doesn't expose hooks for.

**Possible approaches (all significant rewrites):**
1. Replace `MenuBarExtra` with a custom `NSPanel` managed via `NSStatusItem` — full control over dismissal, but loses all SwiftUI scene integration
2. Use `NSPanel` with `.nonactivating` style mask + `.floatingPanel` level — stays visible when other windows activate, but requires reimplementing the entire dropdown lifecycle
3. Move Settings into the dropdown itself (inline) instead of a separate window — avoids the problem entirely but changes the UX

Recommend deferring to a future milestone if this becomes a priority.
