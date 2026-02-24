# LightsUp — Visual Style Guide

> Living document. Update when new patterns are introduced or existing ones are revised.

---

## Design Philosophy

Monospaced, information-dense, "developer terminal" aesthetic. Orange is the sole accent colour against neutral system backgrounds. No decorative chrome — every visible element earns its space.

---

## Colour Palette

| Role | SwiftUI Value | Usage |
|------|---------------|-------|
| Accent | `.orange` (system) | Section headers, join button fill, icon tints, shimmer highlight, tooltip/button borders |
| Primary | `.primary` | Main body text (adaptive: near-white in dark mode, near-black in light) |
| Secondary | `.secondary` | Timestamps, subtitles, disabled states |
| Ongoing row bg | `Color.orange.opacity(0.12)` | Subtle highlight behind a currently active event row |
| Hover (row) | `Color.primary.opacity(0.08)` | `MenuRowStyle` hover state |
| Hover (icon) | `Color.primary.opacity(0.08)` | `IconButtonStyle` hover state |
| Pressed (icon) | `Color.primary.opacity(0.16)` | `IconButtonStyle` pressed/active state |
| Popup scrim | `Color.black.opacity(0.85)` | Full-screen popup overlay |
| Popup text | `.white` / `.white.opacity(0.7)` | Primary / secondary text on the popup |
| Popup border | `Color.white.opacity(0.3)` | Outlined button stroke on popup |

---

## Typography

All text uses **system monospaced** — no serif or proportional fonts anywhere.

```swift
.font(.system(textStyle, design: .monospaced))
.font(.system(size: N, weight: W, design: .monospaced))
```

| Role | Style |
|------|-------|
| Popup event title | `.system(size: 40, weight: .bold, design: .monospaced)` |
| Popup time range | `.system(.title2, design: .monospaced)` |
| Dropdown body text (event title, buttons) | `.system(.body, design: .monospaced)` |
| Dropdown captions (time ranges, empty labels) | `.system(.caption, design: .monospaced)` |
| Section headers | `.system(.caption, design: .monospaced).weight(.semibold)` + `.tracking(2)` (via `sectionHeader()`) |
| Menu bar label | default (set by system via `Text` in `MenuBarExtra` label) |

> **Argument order reminder:** `.font(.system(.title2, design: .monospaced, weight: .bold))` — `design:` must come before `weight:` or it won't compile.

---

## Layout & Spacing

| Element | Value |
|---------|-------|
| Dropdown panel width | `280pt` (`.frame(width: 280)`) |
| Events scroll area max height | `320pt` |
| Row vertical padding | `.padding(.vertical, 5)` |
| Section header padding | `.padding(.horizontal, 12).padding(.vertical, 4)` |
| Bottom bar padding | `.padding(.horizontal, 12).padding(.vertical, 8)` |
| Calendar colour dot | `Circle().frame(width: 8, height: 8).padding(.leading, 12)` |
| Icon button trailing padding | `.padding(.trailing, 8)` |
| Icon button internal padding | `4pt` all sides (inside `IconButtonStyle`) |

---

## Corner Radii

| Element | Radius |
|---------|--------|
| Row hover background (`MenuRowStyle`) | `6` |
| Icon button hover background (`IconButtonStyle`) | `5` |
| Tooltip background | `6` |
| Popup action buttons | `8` |

---

## Button Styles

### `MenuRowStyle`
Full-width menu row button. No default chrome. Background transitions from clear → `primary.opacity(0.08)` on hover.

```swift
Button("Label") { action() }
    .buttonStyle(MenuRowStyle())
```

### `IconButtonStyle`
Compact icon-only button (join, copy). Adds `4pt` padding around the icon image. Three background states:

| State | Opacity |
|-------|---------|
| Default | `0` (clear) |
| Hover | `primary.opacity(0.08)` |
| Pressed / active | `primary.opacity(0.16)` |

Accepts an optional `isActive: Bool` parameter to hold the pressed appearance (used by `CopyIconButton` for post-tap feedback).

```swift
Button { ... } label: { Image(systemName: "...") }
    .buttonStyle(IconButtonStyle())

Button { ... } label: { Image(systemName: "...") }
    .buttonStyle(IconButtonStyle(isActive: someState))
```

---

## Popup (FullScreenPopupView)

- Full-screen `Color.black.opacity(0.85)` scrim via `.ignoresSafeArea()`
- Calendar name: `.caption` monospaced semibold, `.orange`, `.tracking(2)`, uppercased
- Event title: `size: 40, weight: .bold, design: .monospaced`, `.white`
- Time range: `.title2` monospaced, `.white.opacity(0.7)`
- **Join Meeting**: orange fill, black text, `RoundedRectangle(cornerRadius: 8)`, `.padding(.horizontal, 28).padding(.vertical, 14)`
- **Copy Link / Dismiss**: outlined — `white.opacity(0.7)` text, `white.opacity(0.3)` stroke, same padding, `.contentShape(RoundedRectangle(cornerRadius: 8))`

---

## Tooltip Pattern

Shown on hover of any truncated event title row in the dropdown.

- Font: `.system(.body, design: .monospaced)`, `.primary` colour
- Max width: `240pt`, multi-line allowed
- Background: `Color(NSColor.windowBackgroundColor)` (system-adaptive)
- Border: `Color.orange.opacity(0.5)` stroke, `1pt`, `cornerRadius: 6`
- Shadow: `black.opacity(0.2)`, radius `4`, offset `(0, 2)`
- Positioned: `36pt` above the title text via `.offset(y: -36)`
- Non-interactive: `.allowsHitTesting(false)`
- Z-ordering: parent `EventRowView` uses `.zIndex(titleHovered ? 1 : 0)` to float above sibling rows

---

## Animations

### Shimmer (ongoing event title)
`TimelineView(.animation(minimumInterval: 1/30))` drives redraws at ~30 fps using wall-clock time — **no `@State` mutations, no SwiftUI animation transactions** (critical: prevents `MenuBarExtra` container jitter).

A `LinearGradient` (`primary → orange → primary`) slides its `startPoint`/`endPoint` across the text from left to right over 2.5 s, looping seamlessly.

### Copy confirmation
`CopyIconButton` sets `justCopied = true` on tap, which passes `isActive: true` to `IconButtonStyle`, holding the pressed background for 0.4 s before reverting.

### `withAnimation` warning
**Do not use `withAnimation` inside `.onAppear` on views inside a `MenuBarExtra` dropdown.** The animation transaction propagates up the view tree and causes the entire popover window to reposition. Use `.animation(_:value:)` (scoped) or `TimelineView` instead.

---

## Menu Bar Label Formats

| State | Compact | Medium | Large |
|-------|---------|--------|-------|
| No events | `Free` | `Free` | `Free` |
| Upcoming | `⌛ 4m` | `⌛ 4m · Title` | `⌛ 4m · Title · 10:00–10:30` |
| Ongoing | `● Now` | `● Now · Title` | `● Now · Title · 10:00–10:30` |

Title truncation: medium `15` chars, large `20` chars (defined in `MenuBarFormat.swift`).

---

## Future Topics (to revisit)

- Formal `StyleConstants` or `Theme` enum for colour/spacing tokens
- Whether to extract shared button styles into a dedicated `Styles.swift` file
- Dark-mode–specific colour overrides (currently relies on system adaptive colours)
- Tooltip: detect actual truncation vs always-showing (requires `GeometryReader` text measurement)
