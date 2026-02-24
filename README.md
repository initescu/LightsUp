# LightsUp

A native macOS menu bar app that makes missing meetings impossible.

## What it does

LightsUp sits quietly in your menu bar and syncs with your calendar. The moment a meeting starts,
it takes over your entire screen with an unavoidable full-screen notification. No more missing
meetings because you were deep in focus and dismissed a tiny notification.

**Core features:**
- Menu bar item with live countdown to next meeting (compact/medium/large formats)
- Calendar sync via EventKit (Apple Calendar / Google Calendar)
- Full-screen takeover when a meeting starts — covers all connected displays
- Click-through to join the meeting directly from the takeover screen
- Settings window: calendar selection, menu bar format, launch at login

## The problem it solves

Remote and hybrid professionals miss meetings constantly — not because they don't care, but because
small notification banners are too easy to miss when you're in deep focus. LightsUp makes that
impossible.

## Tech stack

- **Language:** Swift
- **UI:** SwiftUI + AppKit (NSWindow for full-screen takeover)
- **Calendar:** EventKit
- **Platform:** macOS 26 (Tahoe) and above
- **Distribution:** Direct download (notarized, outside App Store)

## Project structure

```
LightsUp/
├── LightsUp/                       # Main app source
│   ├── LightsUpApp.swift           # App entry point, MenuBarExtra, AppDelegate
│   ├── CalendarManager.swift       # @Observable EventKit wrapper, polling, store change observer
│   ├── MenuBarFormat.swift         # Countdown/label format enum + pure format functions
│   ├── MenuBarLabelView.swift      # Live menu bar label, 30 s ticker
│   ├── ContentView.swift           # Dropdown: TODAY/TOMORROW event list
│   ├── SettingsView.swift          # Calendar toggles, format picker, launch at login
│   ├── OnboardingView.swift        # First-launch 4-step flow
│   ├── PopupWindowController.swift # Full-screen overlay window (AppKit)
│   ├── FullScreenPopupView.swift   # Full-screen popup SwiftUI view + Join button
│   └── EKEvent+MeetingURL.swift    # Extracts Zoom/Meet/Teams URL from event
├── LightsUpTests/                  # Unit tests
├── LightsUpUITests/                # UI tests
└── LightsUp.xcodeproj/             # Xcode project
```

## Project configuration

- App Sandbox: **disabled** (required for full-screen takeover and direct distribution)
- Dock icon: **hidden** (`LSUIElement = YES`) — pure menu bar app
- Deployment target: **macOS 26.0**
- Bundle ID: `ohwow.LightsUp`

## Status

- [x] Project scaffolding
- [x] Menu bar item with live countdown (compact / medium / large)
- [x] Dropdown with TODAY/TOMORROW event list
- [x] EventKit calendar integration (full access, instant refresh on edits)
- [x] Meeting detection and full-screen takeover on event start
- [x] Join meeting action from takeover screen (Zoom, Meet, Teams, etc.)
- [x] First-launch onboarding with calendar permission request
- [x] Settings window — calendar selection, menu bar format, launch at login
- [ ] Notarization + distribution setup
