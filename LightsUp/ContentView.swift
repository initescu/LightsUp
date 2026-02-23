//
//  ContentView.swift
//  LightsUp
//

import AppKit
import EventKit
import SwiftUI

// Reusable button style for all menu rows: hover highlight, no default chrome.
struct MenuRowStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .onHover { isHovered = $0 }
    }
}

struct ContentView: View {
    @Environment(CalendarManager.self) private var calendarManager
    @State private var popup: PopupWindowController?

    var body: some View {
        VStack(spacing: 0) {
            mainContent
            Divider()
            bottomBar
        }
        .frame(width: 280)
        .onAppear {
            calendarManager.fetchEvents()
            popup = PopupWindowController(calendarManager: calendarManager)
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        switch calendarManager.authorizationStatus {
        case .fullAccess:
            eventsView
        case .denied, .restricted:
            accessDeniedView
        default:
            accessPromptView
        }
    }

    // MARK: - Events

    private var eventsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("TODAY", date: .now)
                if calendarManager.todayEvents.isEmpty {
                    emptyLabel("No upcoming events today")
                } else {
                    ForEach(calendarManager.todayEvents, id: \.eventIdentifier) {
                        eventRow($0)
                    }
                }

                Divider()
                    .padding(.vertical, 6)

                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
                sectionHeader("TOMORROW", date: tomorrow)
                if calendarManager.tomorrowEvents.isEmpty {
                    emptyLabel("No events tomorrow")
                } else {
                    ForEach(calendarManager.tomorrowEvents, id: \.eventIdentifier) {
                        eventRow($0)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxHeight: 320)
    }

    private func sectionHeader(_ label: String, date: Date) -> some View {
        let datePart = date
            .formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            .uppercased()
        return Text("\(label)  \(datePart)")
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }

    private func eventRow(_ event: EKEvent) -> some View {
        let now = Date()
        let isOngoing = event.startDate <= now && event.endDate > now
        let timeRange = "\(event.startDate.formatted(date: .omitted, time: .shortened)) – " +
                        "\(event.endDate.formatted(date: .omitted, time: .shortened))"

        return HStack(spacing: 8) {
            Circle()
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 8, height: 8)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "(No title)")
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                Text(timeRange)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let url = event.meetingURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            } else {
                Spacer().frame(width: 12)
            }
        }
        .padding(.vertical, 5)
        .background(isOngoing ? Color.orange.opacity(0.12) : Color.clear)
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }

    // MARK: - Permission states

    private var accessDeniedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Calendar access denied.")
                .font(.system(.body, design: .monospaced))
            Button("Open System Settings") {
                NSWorkspace.shared.open(
                    // swiftlint:disable:next force_unwrapping
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
                )
            }
            .buttonStyle(.plain)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var accessPromptView: some View {
        Text("Open the menu bar icon\nand grant calendar access.")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding()
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Button("Test Popup") { popup?.show() }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .buttonStyle(MenuRowStyle())

            Divider().frame(height: 20)

            SettingsLink {
                Text("Settings...")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(MenuRowStyle())
        }
    }
}
