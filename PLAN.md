# LightsUp — Milestone 1: Calendar Integration + Today/Tomorrow View

## Context

The project is a pure macOS menu bar app (Swift/SwiftUI, macOS 26 Tahoe+). The scaffold has a placeholder `WindowGroup`/`ContentView`. This milestone replaces the scaffold with a real menu bar app that reads the user's calendars via EventKit and displays today's and tomorrow's events in a compact native-style dropdown, with a separate Settings window for calendar selection.

---

## Decisions

| Topic | Decision |
|---|---|
| UI location | Menu bar dropdown — `.menuBarExtraStyle(.window)` |
| Icon | `lightbulb` SF Symbol |
| Event fields | Calendar color dot · time range · title · "Join" button if meeting URL present |
| Calendar selection | Separate Settings window, opened via "Settings..." button at bottom of dropdown |
| Ongoing events | Visually highlighted (accent background row) |
| Past events today | Hidden — only future and ongoing events shown |
| Dropdown style | Native/compact — section headers TODAY / TOMORROW, plain rows |
| App Sandbox | **Disabled.** Direct-download distribution (no App Store), and future full-screen takeover feature requires it disabled anyway. TCC handles calendar permissions independently of sandbox. |

---

## Styling

Minimal, CLI like. Simple. Dark and orange colours - like the Claude CLI.

## Architecture

### Files to create / modify

| File | Action |
|---|---|
| `LightsUp/LightsUpApp.swift` | Rewrite: `MenuBarExtra` + `Settings` scene, inject `CalendarManager` |
| `LightsUp/ContentView.swift` | Rewrite: today/tomorrow event list + Settings button |
| `LightsUp/CalendarManager.swift` | **New** — `@Observable` EventKit wrapper |
| `LightsUp/SettingsView.swift` | **New** — calendar toggles UI for the Settings window |
| Xcode build settings | Disable `ENABLE_APP_SANDBOX`, add `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription`, set `INFOPLIST_KEY_LSUIElement = YES` |

No entitlements file needed (sandbox disabled).

---

### LightsUpApp

Two scenes:
1. `MenuBarExtra("LightsUp", systemImage: "lightbulb")` with `.menuBarExtraStyle(.window)` — the dropdown
2. `Settings { SettingsView() }` — the calendar selection window

`CalendarManager` lives as `@State` on the app struct and is injected via `.environment()`.

**Known macOS 26 issue:** `@Environment(\.openSettings)` is broken inside `MenuBarExtra` on Tahoe. Use `SettingsLink` (introduced macOS 14, view-based, more reliable in this context) as the "Settings..." button in the dropdown. If `SettingsLink` also fails at runtime, fall back to `NSApp.activate(ignoringOtherApps: true)` + `NSApp.sendAction(#selector(NSApp.showSettingsWindow(_:)), to: nil, from: nil)`.

---

### CalendarManager

- `@Observable final class` with a single `EKEventStore` instance (one per app, as Apple requires)
- Async permission request: `try await store.requestFullAccessToEvents()` (macOS 14+ async variant — not the deprecated callback form)
- Fetch events with `EKEventStore.events(matching:)` predicate covering start-of-today → end-of-tomorrow
- Filter logic:
  - Today: events where `endDate > now` (drop already-finished events)
  - Tomorrow: all events
  - Skip reminders (`calendar.type != .calDAV / .local` — only event calendars)
- Sort by `startDate`
- Filter by `enabledCalendarIDs: Set<String>` — persisted in `UserDefaults`
- Refresh on `EKEventStoreChangedNotification`
- Expose `allCalendars: [EKCalendar]` for the Settings view

**Info.plist key required:** `NSCalendarsFullAccessUsageDescription` (replaces deprecated `NSCalendarsUsageDescription`)

---

### ContentView (dropdown)

```
┌───────────────────────────────────┐
│  TODAY  Sat Feb 22                │  ← small caps header
│  ● 14:00–15:00  Design review     │  ← calendar color dot + time + title
│  ● 16:00–16:30  Standup      [↗]  │  ← [↗] only if meeting URL present
│  ──────────────────────────────   │
│  TOMORROW  Sun Feb 23             │
│  ● 09:00–09:30  1:1 with Ben      │
│  ──────────────────────────────   │
│  Settings...                      │  ← SettingsLink button
└───────────────────────────────────┘
```

States to handle:
- **No permission yet:** prompt with a single "Grant Calendar Access" button
- **Permission denied:** message + link to System Settings > Privacy > Calendar
- **No events in a section:** "No upcoming events" placeholder
- **Ongoing event:** accent-tinted background on that row

---

### SettingsView (Settings window)

Simple list of all available calendars with toggle rows. Each row shows the calendar color swatch and name. Toggle state persisted in `UserDefaults` via `CalendarManager.enabledCalendarIDs`.

---

## API notes (macOS 26 / Tahoe)

- EventKit permission: `try await EKEventStore.requestFullAccessToEvents()` — async variant, current
- Usage description key: `NSCalendarsFullAccessUsageDescription` — `NSCalendarsUsageDescription` is deprecated
- Observable: `@Observable` macro (Swift Observation framework, macOS 14+) — correct pattern, replaces `ObservableObject`
- Bindings into Observable objects: `@Bindable` where needed
- Settings scene opening: `SettingsLink` (macOS 14+) preferred over `@Environment(\.openSettings)` which is broken in `MenuBarExtra` on Tahoe
- No backwards compatibility concerns — macOS 26+ only

---

## Verification

1. Build and run → lightbulb icon appears in menu bar, no Dock icon
2. First launch → macOS TCC calendar permission dialog appears
3. Grant access → dropdown shows today/tomorrow events from real calendar
4. Past events (already ended) are not shown in Today section
5. Ongoing event has an accent-tinted background
6. Event with meeting URL shows a [↗] join button; clicking it opens the URL in the default browser
7. "Settings..." opens a separate window with calendar toggle list
8. Toggling a calendar off → its events disappear from the dropdown immediately
9. Permission denied state shows a helpful message with a link to System Settings

---

## Development Loop

After every implementation step, run before stopping:

```bash
./scripts/verify.sh
```

Must exit with "All checks passed." (0 lint violations, BUILD SUCCEEDED) before handing off for manual validation.

Lint config: `.swiftlint.yml` — catches crashes and dead code only (`force_cast`, `force_try`, `force_unwrapping`, `unused_closure_parameter`, `unused_import`).

---

## Implementation Plan — Milestone 1

### Progress

- [x] **Step 1** — Xcode project setup
- [x] **Step 2** — Menu bar shell *(F1)*
- [x] **Step 3** — Full-screen popup mechanism *(F2)*
- [x] **Step 4** — Onboarding flow *(F3)*
- [x] **Step 5** — CalendarManager + Settings *(F4 + F5)*
- [x] **Step 6** — Wire popup to real data *(F6)*

---

The 6 functional outcomes to deliver:

- **F1** Menu bar widget that can be clicked
- **F2** "Test Popup" button that triggers a mock full-screen overlay
- **F3** First-launch onboarding flow with "Next" steps leading to calendar access
- **F4** Calendar selection (user picks which calendars the app monitors)
- **F5** Visible proof that calendar connection succeeded
- **F6** End-to-end: real calendar data in the dropdown + mock-triggerable popup

---

### Step 1 — Xcode project setup

*Prerequisite for everything else.*

- Set `ENABLE_APP_SANDBOX` → `NO`
- Set `INFOPLIST_KEY_LSUIElement` → `YES`
- Add `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription` with a usage string
- Delete the generated entitlements file if one exists

Deliverable: project builds cleanly with the right Info.plist keys baked in.

---

### Step 2 — Menu bar shell  *(delivers F1)*

- Rewrite `LightsUpApp.swift`: replace `WindowGroup` with `MenuBarExtra("LightsUp", systemImage: "lightbulb")` using `.menuBarExtraStyle(.window)`
- Add a `Settings { SettingsView() }` scene stub (empty view for now)
- Rewrite `ContentView.swift` to a minimal placeholder — a single label "LightsUp" and a "Settings..." `SettingsLink` at the bottom

Deliverable: lightbulb icon in menu bar, clickable dropdown, no Dock icon.

---

### Step 3 — Full-screen popup mechanism  *(delivers F2)*

- Create `FullScreenPopupView.swift` — a SwiftUI view with hardcoded mock content (event title, time, "Join" button, "Dismiss" button)
- Create `PopupWindowController.swift` — a thin AppKit wrapper that creates a borderless `NSWindow` covering `NSScreen.main?.frame` at level `.screenSaver`, hosts the SwiftUI view via `NSHostingView`, and closes itself on dismiss or Escape key
- Add a "Test Popup" button to `ContentView` that calls the controller

Deliverable: clicking "Test Popup" covers the screen with mock data; Dismiss/Escape restores normal state.

---

### Step 4 — Onboarding flow  *(delivers F3)*

- Create `OnboardingView.swift` — a multi-step SwiftUI view with "Next" / "Back" navigation:
  - Step 1: Welcome
  - Step 2: What the app does
  - Step 3: Calendar access explanation + "Grant Access" button (calls `CalendarManager.requestAccess()`)
  - Step 4: Done (sets `UserDefaults` flag `hasCompletedOnboarding = true`, closes window)
- Create `OnboardingWindowController.swift` — AppKit wrapper that shows the onboarding `NSWindow` centered on screen
- In `LightsUpApp`, check the `hasCompletedOnboarding` flag at launch and open the onboarding window if false

Deliverable: fresh launch shows onboarding; macOS TCC dialog fires on Step 3; relaunching after completion skips it.

---

### Step 5 — CalendarManager + Settings + calendar selection  *(delivers F4 + F5)*

- Create `CalendarManager.swift`:
  - `@Observable final class`, single `EKEventStore`
  - `requestAccess()` async method (called from onboarding)
  - Fetch events: start-of-today → end-of-tomorrow, filtered by `enabledCalendarIDs`
  - Refresh on `EKEventStoreChangedNotification`
  - Exposes `allCalendars: [EKCalendar]`, `todayEvents`, `tomorrowEvents`, `authorizationStatus`
- Create `SettingsView.swift`: list of `allCalendars`, each row has color swatch + name + toggle; toggle state persisted via `CalendarManager.enabledCalendarIDs` in `UserDefaults`
- Inject `CalendarManager` via `.environment()` from `LightsUpApp`
- Update `ContentView` to show real events in TODAY / TOMORROW sections (time + title + color dot) and a visible "Connected" status (e.g. calendar names or event count) so the connection is easy to verify

Deliverable: dropdown shows real calendar names and real event counts; toggling a calendar in Settings immediately updates the dropdown.

---

### Step 6 — Wire popup to real data  *(delivers F6)*

- Update `PopupWindowController` to accept an optional `EKEvent`
- In `ContentView`, pass the nearest upcoming real event to "Test Popup"; fall back to mock data with a "(mock)" label if no events exist
- Add "Join" `[↗]` button to event rows in the dropdown where `EKEvent.url` is non-nil

Deliverable: the full user journey works end-to-end — onboard → grant access → select calendars → see real events → trigger popup showing real event data.
