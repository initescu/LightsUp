# Milestone 4 Plan — LightsUp

## Context

M3 completed calendar sync reliability. M4 focuses on polish: quick clipboard access to meeting links, a live "in a meeting" pulse on the ongoing event title, improved popup button ergonomics, and targeted maintenance/refactoring.

---

## Features

### F1 · Copy meeting link ✅ DONE

**Dropdown row (`ContentView.swift`):**
- `IconButtonStyle` (new): hover bg `primary.opacity(0.08)`, pressed bg `primary.opacity(0.16)`. Used by both icon buttons.
- `CopyIconButton` (new struct): clipboard icon (`doc.on.clipboard`), orange tint. Holds pressed background for 0.4 s after tap via `justCopied` state + `IconButtonStyle(isActive:)`. Exposes `onHoverChange` callback so parent can manage z-index.
- `TooltipLabel` (new shared struct): monospaced body, orange 0.5 border, system window background, shadow. Used by both title tooltip and button tooltip. **Note:** when overlaid on a tiny view, caller must add `.fixedSize()` to escape the parent's width constraint.
- "copy meeting url" tooltip shown above the clipboard button on hover.

**Popup (`FullScreenPopupView.swift`):**
"Copy Link" button added between "Join Meeting" and "Dismiss". Same outlined style as Dismiss. Copies URL then calls `onDismiss()`.

---

### F2 · Ongoing event title shimmer ✅ DONE

**Goal (revised from plan):** Instead of an opacity pulse, a narrow orange highlight band sweeps left-to-right across the title text continuously — like the Claude Code throbber.

**Implementation:** `eventRow()` extracted to `EventRowView` struct. For ongoing events, title is wrapped in `TimelineView(.animation(minimumInterval: 1/30))` which drives a `LinearGradient` (`.primary → .orange → .primary`) via wall-clock phase. `shimmerGradient(phase:)` slides `startPoint`/`endPoint` across the text width over 2.5 s, looping seamlessly.

**Why TimelineView instead of withAnimation:** `withAnimation` inside `.onAppear` propagates an animation transaction up the full view tree including the `MenuBarExtra` window, causing the popover to physically reposition (jitter). `TimelineView` redraws only its own subtree with no animation transactions.

**Also done:**
- `ForEach` switched to `id: \.calendarItemIdentifier` — `eventIdentifier` is `String!` and can be nil, causing multiple rows to share the same SwiftUI identity and bleed `@State` (hover, tooltips) between them.
- Title hover tooltip using `TooltipLabel` shows full title above the row on hover. `EventRowView` uses `.zIndex(titleHovered || copyHovered ? 1 : 0)` so tooltip floats above sibling rows.

**Bonus fix (not in original plan):** `menuBarLabelString()` now detects ongoing events and returns `● Now [· title]` instead of the stale `⌛ 0m` countdown.

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
3. **Shimmer:** Start the app with an ongoing meeting in today's events → open dropdown → a narrow orange band sweeps left-to-right across the title text continuously. Non-ongoing events are static. Dropdown stays perfectly still (no jitter).
4. **Dismiss [ESC]:** Open popup → button reads "Dismiss [ESC]" → click it → closes. Press ESC → closes.
5. **Button size:** Buttons visually larger; clicking near the edge of the button outline registers the click.
6. **Settings:** Click "Settings..." in dropdown → Settings window comes to front (test after clicking elsewhere first).
7. **Tests:** `./scripts/verify.sh` passes (including new unit tests).
