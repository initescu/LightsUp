//
//  SettingsView.swift
//  LightsUp
//

import EventKit
import SwiftUI

struct SettingsView: View {
    @Environment(CalendarManager.self) private var calendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Calendars")
                .font(.system(.headline, design: .monospaced))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            if calendarManager.allCalendars.isEmpty {
                Text("No calendars found.\nGrant calendar access first.")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                List(calendarManager.allCalendars, id: \.calendarIdentifier) { calendar in
                    calendarRow(calendar)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 320, height: 300)
        .onAppear {
            NSApp.activate()
        }
    }

    private func calendarRow(_ calendar: EKCalendar) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 10, height: 10)

            Text(calendar.title)
                .font(.system(.body, design: .monospaced))

            Spacer()

            Toggle("", isOn: Binding(
                get: { calendarManager.enabledCalendarIDs.contains(calendar.calendarIdentifier) },
                set: { enabled in
                    var ids = calendarManager.enabledCalendarIDs
                    if enabled {
                        ids.insert(calendar.calendarIdentifier)
                    } else {
                        ids.remove(calendar.calendarIdentifier)
                    }
                    calendarManager.enabledCalendarIDs = ids
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}
