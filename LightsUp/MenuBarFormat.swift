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
