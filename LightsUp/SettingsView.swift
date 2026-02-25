//
//  SettingsView.swift
//  LightsUp
//

import EventKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(CalendarManager.self) private var calendarManager
    @AppStorage("menuBarFormat") private var menuBarFormat: MenuBarFormat = .medium
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

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
                    .font(.appBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                List(calendarManager.allCalendars, id: \.calendarIdentifier) { calendar in
                    calendarRow(calendar)
                }
                .listStyle(.plain)
                .frame(height: 180)
            }

            Divider()
            Text("Menu Bar")
                .font(.system(.headline, design: .monospaced))
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            Divider()
            HStack {
                Text("Format")
                    .font(.appBody)
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

            Divider()
            Text("General")
                .font(.system(.headline, design: .monospaced))
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            Divider()
            HStack {
                Text("Launch at Login")
                    .font(.appBody)
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .frame(width: 320, height: 440)
    }

    private func calendarRow(_ calendar: EKCalendar) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 10, height: 10)

            Text(calendar.title)
                .font(.appBody)

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
