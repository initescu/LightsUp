//
//  MenuBarFormatTests.swift
//  LightsUpTests
//

import EventKit
import Testing
@testable import LightsUp

// MARK: - countdownString

@Suite("countdownString")
struct CountdownStringTests {

    // Use a fixed reference date so interval arithmetic is deterministic.
    private let base = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func minutesOnly() {
        let start = base.addingTimeInterval(4 * 60)
        #expect(countdownString(from: base, to: start) == "4m")
    }

    @Test func hoursAndMinutes() {
        let start = base.addingTimeInterval(90 * 60)   // 1 h 30 m
        #expect(countdownString(from: base, to: start) == "1h 30m")
    }

    @Test func exactHour() {
        let start = base.addingTimeInterval(2 * 3600)  // 2 h, 0 m
        #expect(countdownString(from: base, to: start) == "2h")
    }

    @Test func negativeClampedToZero() {
        let start = base.addingTimeInterval(-5 * 60)   // 5 min in the past
        #expect(countdownString(from: base, to: start) == "0m")
    }

    @Test func exactlyNow() {
        #expect(countdownString(from: base, to: base) == "0m")
    }
}

// MARK: - menuBarLabelString helpers

private func makeEvent(title: String, startOffset: TimeInterval, duration: TimeInterval = 3600) -> EKEvent {
    let store = EKEventStore()
    let event = EKEvent(eventStore: store)
    event.title = title
    let anchor = Date(timeIntervalSinceReferenceDate: 1_000_000)
    event.startDate = anchor.addingTimeInterval(startOffset)
    event.endDate   = event.startDate.addingTimeInterval(duration)
    return event
}

private let anchor = Date(timeIntervalSinceReferenceDate: 1_000_000)

// MARK: - Free path

@Suite("menuBarLabelString — no event")
struct MenuBarLabelFreeTests {

    @Test func allFormatsReturnFree() {
        for format in MenuBarFormat.allCases {
            #expect(menuBarLabelString(format: format, event: nil, now: anchor) == "Free")
        }
    }
}

// MARK: - Upcoming event

@Suite("menuBarLabelString — upcoming event")
struct MenuBarLabelUpcomingTests {

    @Test func compact() {
        let event = makeEvent(title: "Standup", startOffset: 4 * 60)
        #expect(menuBarLabelString(format: .compact, event: event, now: anchor) == "⌛ 4m")
    }

    @Test func mediumShortTitle() {
        let event = makeEvent(title: "Standup", startOffset: 4 * 60)
        #expect(menuBarLabelString(format: .medium, event: event, now: anchor) == "⌛ 4m · Standup")
    }

    @Test func mediumTruncatesLongTitle() {
        // "A Very Long Title" = 17 chars → truncated to 15 = "A Very Long Tit…"
        let event = makeEvent(title: "A Very Long Title", startOffset: 10 * 60)
        let result = menuBarLabelString(format: .medium, event: event, now: anchor)
        #expect(result.hasPrefix("⌛ 10m ·"))
        #expect(result.hasSuffix("…"))
    }

    @Test func largeContainsTimeRange() {
        let event = makeEvent(title: "Standup", startOffset: 4 * 60)
        let result = menuBarLabelString(format: .large, event: event, now: anchor)
        #expect(result.hasPrefix("⌛ 4m · Standup ·"))
    }
}

// MARK: - Ongoing event

@Suite("menuBarLabelString — ongoing event")
struct MenuBarLabelOngoingTests {

    // Event started 5 min ago, ends in 55 min.
    private let ongoing: EKEvent = makeEvent(title: "Daily Sync", startOffset: -5 * 60, duration: 60 * 60)

    @Test func compact() {
        #expect(menuBarLabelString(format: .compact, event: ongoing, now: anchor) == "● Now")
    }

    @Test func mediumShowsTitle() {
        #expect(menuBarLabelString(format: .medium, event: ongoing, now: anchor) == "● Now · Daily Sync")
    }

    @Test func largeContainsTitleAndRange() {
        let result = menuBarLabelString(format: .large, event: ongoing, now: anchor)
        #expect(result.hasPrefix("● Now · Daily Sync ·"))
    }
}
