//
//  MenuBarFormat.swift
//  LightsUp
//

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
    if event.startDate <= now && event.endDate > now {
        // Ongoing event: show live indicator instead of a stale countdown.
        switch format {
        case .compact: return "● Now"
        case .medium:
            return "● Now · \(truncated(event.title ?? "No title", max: mediumMax))"
        case .large:
            let fmt = Date.FormatStyle(date: .omitted, time: .shortened)
            let range = "\(event.startDate.formatted(fmt))–\(event.endDate.formatted(fmt))"
            return "● Now · \(truncated(event.title ?? "No title", max: largeMax)) · \(range)"
        }
    }
    let cd = countdownString(from: now, to: event.startDate)
    switch format {
    case .compact: return "⌛ \(cd)"
    case .medium:
        return "⌛ \(cd) · \(truncated(event.title ?? "No title", max: mediumMax))"
    case .large:
        let fmt = Date.FormatStyle(date: .omitted, time: .shortened)
        let range = "\(event.startDate.formatted(fmt))–\(event.endDate.formatted(fmt))"
        return "⌛ \(cd) · \(truncated(event.title ?? "No title", max: largeMax)) · \(range)"
    }
}
