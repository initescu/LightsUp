# Milestone 2 Plan — LightsUp

## Context

Milestone 1 delivered a fully-functional calendar menu-bar app. The main friction: you have to click the menu bar icon to see what's coming next. Milestone 2 makes the key information visible at a glance — the menu bar item itself shows the next event — and adds two small-but-useful improvements: instant refresh on calendar edits and a Launch at Login toggle.

---

## Features

### F1 · Dynamic menu bar title (core)

The menu bar item gains a live event summary with a user-selectable format:

| Format | Example |
|--------|---------|
| Compact | `⌛ 4m` |
| Medium | `⌛ 4m · Standup` |
| Large | `⌛ 4m · Daily Standup · 10:00–10:30` |

Rules:
- Countdown: `Xm` when < 60 min; `Xh Ym` / `Xh` when ≥ 60 min
- Only the meeting **title** is truncated if it would overflow; countdown and time are never cut
- Suggested max chars: 15 for Medium, 20 for Large
- When no upcoming event: show `💡 Free` (icon + label)
- Countdown refreshes every 30 s via a local timer in the label view

### F2 · Reduce polling interval

`CalendarManager` timer: `10.0 s → 5.0 s`. Keep the `isJustStarted` detection window at `< 10` (not reducing it — a 5 s timer can fire up to 5 s after start; `< 10` gives safe headroom).

### F3 · EKEventStoreChanged (already done — verify only)

`observeStoreChanges()` in `CalendarManager.swift` (lines 101–113) already subscribes to `.EKEventStoreChanged` and calls `loadCalendars()` + `fetchEvents()`. No code change needed; just verify it works.

### F4 · Launch at Login

Toggle in Settings using `ServiceManagement.SMAppService.mainApp`.

---

## Implementation

### Order of changes (dependencies first)

1. `CalendarManager.swift` — polling interval (2-char change)
2. `MenuBarFormat.swift` (new) — enum + pure formatting functions
3. `MenuBarLabelView.swift` (new) — label view; depends on #2
4. `LightsUpApp.swift` — wire label view; depends on #3
5. `SettingsView.swift` — format picker + Launch at Login

---

### 1 · `CalendarManager.swift` — line 116

```swift
// Before
monitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { ... }

// After
monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { ... }
```

Leave `timeSinceStart < 10` on line 132 unchanged (safe window for 5 s timer).

---

### 2 · New file: `LightsUp/MenuBarFormat.swift`

```swift
import EventKit
import Foundation

enum MenuBarFormat: String, CaseIterable, Identifiable {
    case compact, medium, large
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .compact: return "Compact  — ⌛ 4m"
        case .medium:  return "Medium   — ⌛ 4m · Standup"
        case .large:   return "Large    — ⌛ 4m · Daily Standup · 10:00–10:30"
        }
    }
}

private let mediumMax = 15
private let largeMax  = 20

private func truncated(_ s: String, max: Int) -> String {
    s.count > max ? String(s.prefix(max)) + "…" : s
}

func countdownString(from now: Date, to start: Date) -> String {
    let mins = max(0, Int(start.timeIntervalSince(now) / 60))
    let h = mins / 60; let m = mins % 60
    if h == 0 { return "\(mins)m" }
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

func menuBarLabelString(format: MenuBarFormat, event: EKEvent?, now: Date = Date()) -> String {
    guard let event else { return "Free" }
    let cd = countdownString(from: now, to: event.startDate)
    switch format {
    case .compact: return "⌛ \(cd)"
    case .medium:
        let t = truncated(event.title ?? "No title", max: mediumMax)
        return "⌛ \(cd) · \(t)"
    case .large:
        let t = truncated(event.title ?? "No title", max: largeMax)
        let fmt = Date.FormatStyle(date: .omitted, time: .shortened)
        let range = "\(event.startDate.formatted(fmt))–\(event.endDate.formatted(fmt))"
        return "⌛ \(cd) · \(t) · \(range)"
    }
}
```

---

### 3 · New file: `LightsUp/MenuBarLabelView.swift`

```swift
import Combine
import SwiftUI

struct MenuBarLabelView: View {
    @Environment(CalendarManager.self) private var calendarManager
    @AppStorage("menuBarFormat") private var format: MenuBarFormat = .medium
    @State private var now: Date = Date()

    private let ticker = Timer.publish(every: 30, tolerance: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lightbulb")
            Text(menuBarLabelString(
                format: format,
                event: calendarManager.nearestUpcomingEvent(),
                now: now
            ))
            .lineLimit(1)
        }
        .onReceive(ticker) { date in now = date }
    }
}
```

---

### 4 · `LightsUpApp.swift` — replace static `MenuBarExtra` label

```swift
// Before
MenuBarExtra("LightsUp", systemImage: "lightbulb") {
    ContentView()
        .environment(calendarManager)
}
.menuBarExtraStyle(.window)

// After
MenuBarExtra {
    ContentView()
        .environment(calendarManager)
} label: {
    MenuBarLabelView()
        .environment(calendarManager)   // required — label is a separate view tree
}
.menuBarExtraStyle(.window)
```

---

### 5 · `SettingsView.swift` — two new sections

Add `import ServiceManagement` at the top.

Expand frame from `(width: 320, height: 300)` to `(width: 320, height: 440)` and constrain the calendar `List` to `.frame(height: 180)` so the new sections have room.

Add after the existing Calendars section:

**Menu Bar section** (format picker):
```swift
Divider()
Text("Menu Bar")
    .font(.system(.headline, design: .monospaced))
    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
Divider()
HStack {
    Text("Format")
        .font(.system(.body, design: .monospaced))
    Spacer()
    Picker("", selection: $menuBarFormat) {
        ForEach(MenuBarFormat.allCases) { fmt in
            Text(fmt.displayName).tag(fmt)
        }
    }
    .labelsHidden()
    .frame(width: 220)
}
.padding(.horizontal, 16).padding(.vertical, 8)
```

**General section** (launch at login):
```swift
Divider()
Text("General")
    .font(.system(.headline, design: .monospaced))
    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
Divider()
HStack {
    Text("Launch at Login")
        .font(.system(.body, design: .monospaced))
    Spacer()
    Toggle("", isOn: Binding(
        get: { SMAppService.mainApp.status == .enabled },
        set: { enabled in
            do {
                if enabled { try SMAppService.mainApp.register() }
                else        { try SMAppService.mainApp.unregister() }
            } catch {}
        }
    ))
    .labelsHidden()
}
.padding(.horizontal, 16).padding(.vertical, 8)
```

---

## Critical files

| File | Change |
|------|--------|
| `LightsUp/CalendarManager.swift` | Line 116: `10.0` → `5.0` |
| `LightsUp/MenuBarFormat.swift` | **NEW** — enum + pure format functions |
| `LightsUp/MenuBarLabelView.swift` | **NEW** — label view with 30 s ticker |
| `LightsUp/LightsUpApp.swift` | Replace static `MenuBarExtra` label with label-closure form |
| `LightsUp/SettingsView.swift` | Add `ServiceManagement` import, Menu Bar section, General section, frame resize |

---

## Verification

1. **F1 — Menu bar title**
   - Build & run. Menu bar shows `💡 ⌛ Xm · [title]` (Medium default).
   - No upcoming events → shows `💡 Free`.
   - Wait 30 s → countdown ticks down.
   - Open Settings → change format → menu bar updates on next tick.

2. **F2 — 5 s polling**
   - Create an event starting ~30 s in future; popup fires within 5 s of start time.

3. **F3 — Instant refresh**
   - Edit an event title in Calendar.app; dropdown shows the new title within ~1 s (no need to wait for 5 s timer).

4. **F4 — Launch at Login**
   - Toggle ON in Settings → appears in System Settings > General > Login Items.
   - Log out / in → app launches automatically.
   - Toggle OFF → entry disappears.

5. **Build check**: `./scripts/verify.sh` passes (SwiftLint + xcodebuild).

---

## Status: COMPLETE ✓

All 5 files changed, `./scripts/verify.sh` passes (0 lint violations, build succeeded).
