//
//  ContentView.swift
//  LightsUp
//

import AppKit
import Combine
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

// Compact button style for icon buttons: hover + pressed background, no chrome.
struct IconButtonStyle: ButtonStyle {
    var isActive: Bool = false
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        configuration.isPressed || isActive
                            ? Color.primary.opacity(0.16)
                            : (isHovered ? Color.primary.opacity(0.08) : Color.clear)
                    )
            )
            .onHover { isHovered = $0 }
    }
}

// Shared tooltip card — monospaced body, orange border, system background.
struct TooltipLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: 240, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .allowsHitTesting(false)
    }
}

// Clipboard button: pressed background for ~0.4 s after release; tooltip on hover.
struct CopyIconButton: View {
    let url: URL
    var onHoverChange: ((Bool) -> Void)? = nil
    @State private var justCopied = false
    @State private var isHovered = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
            justCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                justCopied = false
            }
        } label: {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.orange)
        }
        .buttonStyle(IconButtonStyle(isActive: justCopied))
        .onHover {
            isHovered = $0
            onHoverChange?($0)
        }
        .overlay(alignment: .topTrailing) {
            if isHovered {
                TooltipLabel(text: "copy meeting url")
                    .fixedSize()
                    .offset(y: -36)
            }
        }
    }
}

struct EventRowView: View {
    let event: EKEvent
    let isOngoing: Bool
    @State private var titleHovered = false
    @State private var copyHovered = false

    private var timeRange: String {
        "\(event.startDate.formatted(date: .omitted, time: .shortened)) – " +
        "\(event.endDate.formatted(date: .omitted, time: .shortened))"
    }

    // A narrow orange band whose centre sweeps from left to right.
    // phase 0 → band fully left of view; phase 1 → band fully right of view.
    private func shimmerGradient(phase: CGFloat) -> LinearGradient {
        let span: CGFloat = 0.35          // gradient band width relative to text width
        let sx = phase * (1 + span) - span
        let ex = phase * (1 + span)
        return LinearGradient(
            colors: [.primary, .orange, .primary],
            startPoint: UnitPoint(x: sx, y: 0.5),
            endPoint: UnitPoint(x: ex, y: 0.5)
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 8, height: 8)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 1) {
                if isOngoing {
                    // TimelineView drives redraws via system time — no @State mutations,
                    // no animation transactions, container stays perfectly still.
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { ctx in
                        let duration = 2.5
                        let phase = CGFloat(
                            ctx.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: duration) / duration
                        )
                        Text(event.title ?? "(No title)")
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .foregroundStyle(shimmerGradient(phase: phase))
                    }
                } else {
                    Text(event.title ?? "(No title)")
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                }
                Text(timeRange)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .onHover { titleHovered = $0 }
            .overlay(alignment: .topLeading) {
                if titleHovered {
                    TooltipLabel(text: event.title ?? "(No title)")
                        .offset(y: -36)
                }
            }

            Spacer()

            if let url = event.meetingURL {
                HStack(spacing: 4) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(IconButtonStyle())

                    CopyIconButton(url: url, onHoverChange: { copyHovered = $0 })
                }
                .padding(.trailing, 8)
            } else {
                Spacer().frame(width: 12)
            }
        }
        .padding(.vertical, 5)
        .background(isOngoing ? Color.orange.opacity(0.12) : Color.clear)
        .zIndex(titleHovered || copyHovered ? 1 : 0)
    }
}

struct ContentView: View {
    @Environment(CalendarManager.self) private var calendarManager
    @State private var popup: PopupWindowController?
    @State private var now: Date = Date()

    private let ticker = Timer.publish(every: 5, tolerance: 1, on: .main, in: .common).autoconnect()

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
        .onReceive(ticker) { self.now = $0 }
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
                sectionHeader("TODAY", date: now)
                if calendarManager.todayEvents.isEmpty {
                    emptyLabel("No upcoming events today")
                } else {
                    ForEach(calendarManager.todayEvents, id: \.calendarItemIdentifier) { event in
                        EventRowView(event: event, isOngoing: event.startDate <= now && event.endDate > now)
                    }
                }

                Divider()
                    .padding(.vertical, 6)

                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
                sectionHeader("TOMORROW", date: tomorrow)
                if calendarManager.tomorrowEvents.isEmpty {
                    emptyLabel("No events tomorrow")
                } else {
                    ForEach(calendarManager.tomorrowEvents, id: \.calendarItemIdentifier) { event in
                        EventRowView(event: event, isOngoing: event.startDate <= now && event.endDate > now)
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
