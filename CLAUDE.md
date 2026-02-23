# LightsUp — Project Context for Claude Code

## What This App Is
macOS 26 (Tahoe) menu bar app that shows upcoming calendar events. LSUIElement background agent with a dropdown panel and a full-screen popup overlay. **No backwards compatibility** — macOS 26 only.

## Current State (as of 2026-02-23)
- **Milestone 1 complete.** All 6 steps validated by user.
- Ready to plan Milestone 2.

## Architecture
- **`LightsUpApp.swift`** — `@main` App with `@NSApplicationDelegateAdaptor(AppDelegate.self)`. AppDelegate owns `calendarManager: CalendarManager` and shows onboarding window on first launch. Has `MenuBarExtra` (window style) and `Settings` scene.
- **`AppDelegate`** — `applicationDidFinishLaunching` checks `hasCompletedOnboarding` UserDefault; if false: calls `NSApp.setActivationPolicy(.regular)`, creates `NSWindow` with `NSHostingController(rootView: OnboardingView(...))`, then `NSApp.activate(ignoringOtherApps: true)`.
- **`CalendarManager.swift`** — `@Observable` class. Stored `var enabledCalendarIDs: Set<String>` with `didSet` (NOT computed — `@Observable` only tracks stored properties). Fetches today's and tomorrow's non-allDay events for enabled calendars.
- **`ContentView.swift`** — Menu bar dropdown. Shows events grouped TODAY/TOMORROW. Settings button uses `NSApp.activate()` + `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` (NOT `SettingsLink` — SettingsLink doesn't bring window to front from LSUIElement app).
- **`SettingsView.swift`** — Calendar toggle list. Has `.onAppear { NSApp.activate() }` to ensure window comes to front.
- **`OnboardingView.swift`** — 4-step flow. Closes via title-lookup: `NSApp.windows.first(where: { $0.title == "Welcome to LightsUp" })?.close()`. Sets `NSApp.setActivationPolicy(.accessory)` on complete.
- **`PopupWindowController.swift`** — Full-screen overlay window. Stores `keyMonitor: Any?`, calls `NSEvent.removeMonitor` on dismiss (leak fix).
- **`FullScreenPopupView.swift`** — Currently hardcoded mock data; Step 6 will wire it to `CalendarManager`.

## Critical macOS / SwiftUI Gotchas Learned

### LSUIElement + Window Display
`LSUIElement = YES` sets activation policy to `.accessory`. Any window that must appear in front requires:
```swift
NSApp.setActivationPolicy(.regular)
// ... create and show window ...
NSApp.activate(ignoringOtherApps: true)
```
Use `NSHostingController` (not `NSHostingView`) when hosting SwiftUI in AppKit windows — more reliable.

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

### Font.system Argument Order
`design:` must come before `weight:`:
```swift
.font(.system(.title2, design: .monospaced, weight: .bold))  // correct
.font(.system(.title2, weight: .bold, design: .monospaced))  // compile error
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
- F6: Popup shows real event data; "Join" button opens meeting URL (Zoom, Meet, Teams, etc.); auto-triggers on event start via 10s timer

## Up Next — Milestone 2
TBD. Discuss with user.

## Bundle ID
`ohwow.LightsUp`
