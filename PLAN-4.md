# Milestone 4 Plan — LightsUp

## Context

M3 completed calendar sync reliability. M4 focuses on polish: quick clipboard access to meeting links, a live "in a meeting" pulse on the ongoing event title, improved popup button ergonomics, and targeted maintenance/refactoring.

---

## Features

### F1 · Copy meeting link

**Dropdown row (`ContentView.swift`):**
The existing `eventRow()` function shows a join button (`arrow.up.right.square`) if a meeting URL exists. Add a second icon button (`doc.on.clipboard`) alongside it. On tap: `NSPasteboard.general.clearContents()` + `NSPasteboard.general.setString(url.absoluteString, forType: .string)`. The two icon buttons sit in a small `HStack(spacing: 4)` replacing the single button.

**Popup (`FullScreenPopupView.swift`):**
Add a "Copy Link" button to the actions `HStack`, between "Join Meeting" and "Dismiss". Style: same outlined look as Dismiss (white 0.7 text, white 0.3 stroke, same padding). On tap: copy URL to pasteboard, then call `onDismiss()`. Only shown when `event.meetingURL != nil`.

---

### F2 · Ongoing event title pulse

**Goal:** When an event is ongoing (`startDate ≤ now < endDate`), its title text in the dropdown fades in and out continuously — the Claude Code throbber style: smooth opacity oscillation between ~1.0 and ~0.4, repeating forever with `easeInOut`.

**Implementation:** Extract `eventRow()` into a standalone `EventRowView: View` struct (currently a function in `ContentView`). The struct receives `event: EKEvent` and `isOngoing: Bool`. Add:

```swift
@State private var isPulsing = false

// On title Text:
.opacity(isOngoing ? (isPulsing ? 0.4 : 1.0) : 1.0)
.onAppear {
    if isOngoing {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}
```

The background highlight (`Color.orange.opacity(0.12)`) remains static.

---

### F3 · Popup button improvements

File: `FullScreenPopupView.swift`

1. **Label:** Change `Button("Dismiss")` → `Button("Dismiss [ESC]")` (both instances — the `event != nil` and the `else` branch).
2. **Size:** Increase padding on all buttons: `.padding(.horizontal, 28).padding(.vertical, 14)` (was 24/10).
3. **Hit area:** Add `.contentShape(RoundedRectangle(cornerRadius: 8))` to the Dismiss button so the full outlined area is clickable (currently the `overlay` is visual-only, hit testing works but `.contentShape` makes it explicit and slightly more generous on corners).

---

### F4 · Maintenance

#### Fix SettingsLink (ContentView.swift)
`SettingsLink` does not bring the Settings window to front from an LSUIElement app. Replace the `SettingsLink` in `bottomBar` with a plain `Button`:

```swift
Button("Settings...") {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
}
```

Style matches current: monospaced body, primary color.

#### NSHostingController in popup (PopupWindowController.swift)
Per CLAUDE.md: NSHostingController is more reliable than NSHostingView. Replace:

```swift
// Before
let hostingView = NSHostingView(rootView: popupView)
window.contentView = hostingView

// After
let hostingController = NSHostingController(rootView: popupView)
window.contentViewController = hostingController
```

#### Deduplicate Dismiss button (FullScreenPopupView.swift)
The Dismiss button code is copy-pasted in both branches of `if let event`. Extract a private `dismissButton: some View` computed property and use it in both branches.

#### Unit tests for pure functions (MenuBarFormat.swift)
`menuBarLabelString()` and `countdownString()` are pure functions — no EventKit, no UI. Add a new test target `LightsUpTests` with `MenuBarFormatTests.swift`:
- Test compact/medium/large format strings for events with known start dates
- Test `countdownString` for various time deltas (hours+minutes, minutes only, "Now", negative)
- Test the "Free" / no-event path
- Test the `● Now` path for ongoing events (all three formats)

#### Style tokens — AppStyle.swift (NEW)
Extract all inline magic values into a single `AppStyle.swift` file using `extension Color` and `extension Font` so call-sites read naturally in SwiftUI modifiers (e.g. `.foregroundStyle(.appAccent)`, `.font(.appBody)`).

**`extension Color` tokens to define:**
```swift
static let appAccent          = Color.orange
static let appOngoingRow      = Color.orange.opacity(0.12)
static let appHoverRow        = Color.primary.opacity(0.08)
static let appPressedIcon     = Color.primary.opacity(0.16)
static let appPopupScrim      = Color.black.opacity(0.85)
static let appPopupText       = Color.white.opacity(0.7)
static let appPopupStroke     = Color.white.opacity(0.3)
static let appTooltipStroke   = Color.orange.opacity(0.5)
```

**`extension Font` tokens to define:**
```swift
static let appBody            = Font.system(.body,    design: .monospaced)
static let appCaption         = Font.system(.caption, design: .monospaced)
static let appCaptionBold     = Font.system(.caption, design: .monospaced).weight(.semibold)
static let appTitle2          = Font.system(.title2,  design: .monospaced)
static let appPopupTitle      = Font.system(size: 40, weight: .bold, design: .monospaced)
```

**Approach:** pure additive refactoring — values are identical, only named. Compile-time safe: any missed call-site causes a build error, not a silent visual regression. Touch every file that contains inline style literals; leave `ButtonStyle` internals (`MenuRowStyle`, `IconButtonStyle`) using local references since they already centralise their own opacities.

**Files to update:** `ContentView.swift`, `FullScreenPopupView.swift`, `MenuBarLabelView.swift`, `SettingsView.swift`, `OnboardingView.swift` (if applicable).

---

## Critical files

| File | Change |
|------|--------|
| `LightsUp/AppStyle.swift` | **NEW** — `extension Color` + `extension Font` style tokens |
| `LightsUp/ContentView.swift` | Extract `EventRowView`, add clipboard button, fix SettingsLink, adopt AppStyle tokens |
| `LightsUp/FullScreenPopupView.swift` | Add "Copy Link" button, "Dismiss [ESC]", bigger padding, deduplicate Dismiss, `.contentShape`, adopt AppStyle tokens |
| `LightsUp/PopupWindowController.swift` | NSHostingController swap |
| `LightsUp/MenuBarFormat.swift` | No change — referenced by tests |
| `LightsUpTests/MenuBarFormatTests.swift` | **NEW** — unit tests for pure functions |

---

## Verification

1. **Copy link — dropdown:** Click clipboard icon on any event row with a meeting URL → paste in a text editor → correct URL appears.
2. **Copy link — popup:** Open popup for a meeting event → click "Copy Link" → popup closes → paste → correct URL.
3. **Pulse:** Start the app with an ongoing meeting in today's events → open dropdown → title text gently fades in/out continuously. Non-ongoing events are static.
4. **Dismiss [ESC]:** Open popup → button reads "Dismiss [ESC]" → click it → closes. Press ESC → closes.
5. **Button size:** Buttons visually larger; clicking near the edge of the button outline registers the click.
6. **Settings:** Click "Settings..." in dropdown → Settings window comes to front (test after clicking elsewhere first).
7. **Tests:** `./scripts/verify.sh` passes (including new unit tests).
