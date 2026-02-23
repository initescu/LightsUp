//
//  MenuBarLabelView.swift
//  LightsUp
//

import Combine
import SwiftUI

struct MenuBarLabelView: View {
    @Environment(CalendarManager.self) private var calendarManager
    @AppStorage("menuBarFormat") private var format: MenuBarFormat = .medium
    @State private var now: Date = Date()

    private let ticker = Timer.publish(every: 30, tolerance: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
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
