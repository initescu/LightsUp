# LightsUp — Project Context for Claude Code

## What This App Is
macOS 26 (Tahoe) menu bar app that shows upcoming calendar events. LSUIElement background agent with a dropdown panel and a full-screen popup overlay. **No backwards compatibility** — macOS 26 only.

## Current State (as of 2026-02-25)
- **Milestone 1 complete.** All 6 steps validated by user.
- **Milestone 2 complete.** All 4 features validated by user (including Launch at Login verified via reboot).
- **Milestone 3 complete.** F1 (calendar sync speed fix) validated. F2 (distribution tooling) deferred to `DISTRIBUTION-PLAN.md`.
- **Milestone 4 complete.** All features and maintenance tasks done. See `PLAN-5.md` for deferred items.

## Architecture
- **`LightsUpApp.swift`** — `@main` App with `@NSApplicationDelegateAdaptor(AppDelegate.self)`. AppDelegate owns `calendarManager: CalendarManager` and shows onboarding window on first launch. Has `MenuBarExtra` (label-closure form, window style) and `Settings` scene.
- **`AppDelegate`** — `applicationDidFinishLaunching` checks `hasCompletedOnboarding` UserDefault; if false: calls `NSApp.setActivationPolicy(.regular)`, creates `NSWindow` with `NSHostingController(rootView: OnboardingView(...))`, then `NSApp.activate(ignoringOtherApps: true)`.
- **`CalendarManager.swift`** — `@Observable` class. Stored `var enabledCalendarIDs: Set<String>` with `didSet` (NOT computed — `@Observable` only tracks stored properties). Fetches today's and tomorrow's non-allDay events for enabled calendars. Polling timer: 5 s. `observeStoreChanges()` calls `store.reset()` then `loadCalendars()` + `fetchEvents()` on `.EKEventStoreChanged`.
- **`MenuBarFormat.swift`** — `MenuBarFormat` enum (compact/medium/large) + `menuBarLabelString()` and `countdownString()` pure functions. `@AppStorage("menuBarFormat")` key shared between label view and settings.
- **`MenuBarLabelView.swift`** — Menu bar label view. `@AppStorage("menuBarFormat")` drives format. 30 s `Timer.publish` ticker refreshes countdown. Requires `import Combine` for `autoconnect()`. Passed via `label:` closure in `MenuBarExtra` — requires `.environment(calendarManager)` explicitly (label is a separate view tree from the content).
- **`ContentView.swift`** — Menu bar dropdown. Shows events grouped TODAY/TOMORROW. Contains `MenuRowStyle`, `IconButtonStyle`, `CopyIconButton`, `TooltipLabel`, and `EventRowView` (standalone struct — required for `@State`-based animations). Uses `calendarItemIdentifier` (not `eventIdentifier`) as ForEach ID — `eventIdentifier` is `String!` and can be nil, causing view identity collisions. Settings button uses `SettingsLink` — on macOS 26, `NSApp.sendAction(Selector(("showSettingsWindow:")))` is blocked at runtime.
- **`SettingsView.swift`** — Calendar toggle list + Menu Bar format picker + Launch at Login toggle. Launch at Login uses `@State private var launchAtLogin` (NOT a `Binding` with `get/set` — `SMAppService.mainApp.status` is not SwiftUI-tracked, so the toggle won't visually update without `@State`). `onChange` calls `SMAppService.mainApp.register/unregister`. No `.onAppear { NSApp.activate() }` — `SettingsLink` handles activation.
- **`OnboardingView.swift`** — 4-step flow. Takes `onComplete: () -> Void` callback — called by `complete()` which sets `hasCompletedOnboarding = true`, calls `NSApp.setActivationPolicy(.accessory)`, then fires the callback. `AppDelegate.showOnboarding()` passes a closure that closes `onboardingWindow` via the stored reference (NOT title-based lookup).
- **`PopupWindowController.swift`** — Full-screen overlay window. Stores `keyMonitor: Any?`, calls `NSEvent.removeMonitor` on dismiss (leak fix).
- **`FullScreenPopupView.swift`** — Shows real event data from `CalendarManager`. "Join Meeting" + "Copy Link" + "Dismiss [ESC]" buttons. "Copy Link" only shown when `event.meetingURL != nil`.
- **`STYLE-GUIDE.md`** — Visual style guide: colour palette, typography, spacing, button styles, tooltip pattern, animation rules. Keep in sync when new patterns are introduced.

## Critical macOS / SwiftUI Gotchas Learned

### LSUIElement + Window Display
`LSUIElement = YES` sets activation policy to `.accessory`. Any window that must appear in front requires:
```swift
NSApp.setActivationPolicy(.regular)
// ... create and show window ...
NSApp.activate(ignoringOtherApps: true)
```
Use `NSHostingController` for **titled/windowed** views (e.g. onboarding, settings). Use `NSHostingView` for **borderless/fullscreen overlay** windows — `NSHostingController` defaults to `sizingOptions = .preferredContentSize` which collapses a borderless window to its SwiftUI intrinsic size.

### @Observable and Computed Properties
`@Observable` only instruments **stored** properties. If you back a property with UserDefaults, use a stored `var` with `didSet`, not a computed property:
```swift
var enabledCalendarIDs: Set<String> = [] {
    didSet { UserDefaults.standard.set(Array(enabledCalendarIDs), forKey: "enabledCalendarIDs") }
}
```

### Hardened Runtime + Calendar Entitlement
`ENABLE_HARDENED_RUNTIME = YES` requires `com.apple.security.personal-information.calendars` entitlement even with App Sandbox **disabled**. Without it, the TCC dialog never fires (silent failure). File: `LightsUp/LightsUp.entitlements`.

### TCC Cached Denials
If the calendar permission dialog stops firing: `tccutil reset Calendar ohwow.LightsUp`

### EKEventStore Caching
After `.EKEventStoreChanged`, you must call `store.reset()` before fetching — otherwise the store returns stale cached objects:
```swift
self.store.reset()
self.loadCalendars()
self.fetchEvents()
```

### SMAppService Toggle — Use @State, not Binding get/set
`SMAppService.mainApp.status` is not SwiftUI-tracked state. A `Binding(get: { SMAppService.mainApp.status == .enabled }, set: ...)` will fire the action but the toggle won't visually update. Use `@State` instead:
```swift
@State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
// ...
Toggle("", isOn: $launchAtLogin)
    .onChange(of: launchAtLogin) { _, newValue in
        try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
    }
```

### MenuBarExtra Label is a Separate View Tree
When using the `label:` closure form of `MenuBarExtra`, the label view does **not** inherit environment from the content closure. Pass environment explicitly:
```swift
MenuBarExtra {
    ContentView().environment(calendarManager)
} label: {
    MenuBarLabelView().environment(calendarManager)  // required separately
}
```

### Font.system Argument Order
`design:` must come before `weight:`:
```swift
.font(.system(.title2, design: .monospaced, weight: .bold))  // correct
.font(.system(.title2, weight: .bold, design: .monospaced))  // compile error
```

### withAnimation in MenuBarExtra Causes Container Jitter
`withAnimation` inside `.onAppear` (or anywhere during a view render) creates an animation **transaction that propagates up the entire view tree**, including the `MenuBarExtra` window itself — the popover visibly repositions/jitters. Two safe alternatives:
1. **`.animation(_:value:)`** directly on the modifier — scopes animation to that property only, nothing leaks upward.
2. **`TimelineView`** — drives redraws via wall-clock time, no SwiftUI animation transactions at all. Preferred for continuous/looping animations.

### ForEach ID: Use calendarItemIdentifier, Not eventIdentifier
`EKEvent.eventIdentifier` is `String!` and can be nil for some calendar sources. Multiple nil IDs cause SwiftUI to treat different rows as the same view, bleeding `@State` (hover, animation) between them. Always use `calendarItemIdentifier` (`String`, non-optional, from `EKCalendarItem`):
```swift
ForEach(events, id: \.calendarItemIdentifier) { event in ... }
```

### Tooltip Overlays on Tiny Views Need .fixedSize()
When an overlay tooltip is attached to a small view (e.g. an icon button ~24px wide), SwiftUI proposes the parent's narrow width to the overlay content. `fixedSize(horizontal: false, vertical: true)` inside the tooltip respects that proposal and wraps text into a vertical column. Fix: add `.fixedSize()` at the call site to force the tooltip to use its intrinsic (natural content) size:
```swift
.overlay(alignment: .topTrailing) {
    TooltipLabel(text: "copy meeting url")
        .fixedSize()   // escape the parent button's width constraint
        .offset(y: -36)
}
```

## Build Settings (project.pbxproj, both Debug and Release)
- `ENABLE_APP_SANDBOX = NO`
- `ENABLE_HARDENED_RUNTIME = YES`
- `INFOPLIST_KEY_LSUIElement = YES`
- `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription = "LightsUp needs access to your calendars to show upcoming meetings."`
- `CODE_SIGN_ENTITLEMENTS = LightsUp/LightsUp.entitlements`

## Development Loop
```bash
./scripts/verify.sh   # SwiftLint (safety-only rules) + xcodebuild
```
SwiftLint config: `.swiftlint.yml` — only `force_cast`, `force_try`, `force_unwrapping`, `unused_closure_parameter`, `unused_import`.

## Milestone 1 — Completed Features
- F1: Menu bar dropdown (lightbulb icon, no Dock icon)
- F2: Full-screen popup mechanism (triggered manually via "Test Popup" or automatically when event starts)
- F3: First-launch onboarding with calendar permission request
- F4: Calendar selection in Settings window
- F5: Real calendar data in dropdown (TODAY/TOMORROW sections, color dots, time ranges)
- F6: Popup shows real event data; "Join" button opens meeting URL (Zoom, Meet, Teams, etc.); auto-triggers on event start via 5 s timer

## Milestone 2 — Completed Features
- F1: Dynamic menu bar title — live countdown + event name/time in compact/medium/large formats; "Free" when no upcoming event; refreshes every 30 s
- F2: Polling interval reduced from 10 s to 5 s (`isJustStarted` detection window kept at `< 10` for safe headroom)
- F3: `EKEventStoreChanged` instant refresh — verified working; `store.reset()` required before fetch to clear EKEventStore cache
- F4: Launch at Login toggle in Settings using `SMAppService.mainApp`; verified via reboot

## Milestone 3 — Complete
- **F1: Calendar sync speed fix** — complete. `startMonitoring()` now calls `store.reset()` + `loadCalendars()` + `fetchEvents()` every 5 s. `ContentView` also got a 5 s ticker (same pattern as `MenuBarLabelView`) to force re-renders — `@Observable` propagation to `MenuBarExtra` window content is unreliable on macOS 26.
- **F2: Distribution tooling** — deferred to `DISTRIBUTION-PLAN.md`.

## Milestone 4 — Complete

- **F1: Copy meeting link** — clipboard icon button in dropdown + "Copy Link" in popup. `CopyIconButton` with 0.4 s pressed-state feedback. `TooltipLabel` shared component.
- **F2: Ongoing event shimmer** — `EventRowView` struct with `TimelineView`-driven `LinearGradient` shimmer. No `withAnimation` → no container jitter.
- **F3: Popup button improvements** — "Dismiss [ESC]", padding 28/14, `.contentShape` inside label for full hit area.
- **F4: Maintenance** — `AppStyle.swift` style tokens (Color + Font), `dismissButton` dedup, unit tests for pure functions, `OnboardingView` debug cruft removed (callback-based close), incomplete AppStyle adoption finished.
- **Bonus: `● Now` menu bar label** — ongoing events show `● Now` instead of stale `0m` countdown.
- **Bonus: `calendarItemIdentifier`** — ForEach uses non-optional ID, fixes view-identity collisions.

### Known limitations (see PLAN-5.md for fixes)
- Two independent `PopupWindowController` instances (AppDelegate + ContentView).
- `requestAccess()` failure is silently swallowed.
- `ContentView.swift` has 6 types; candidate for splitting in M5.

## Bundle ID
`ohwow.LightsUp`
