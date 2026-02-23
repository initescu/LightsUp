//
//  FullScreenPopupView.swift
//  LightsUp
//

import EventKit
import SwiftUI

struct FullScreenPopupView: View {
    let event: EKEvent?
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dark scrim
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            if let event = event {
                VStack(spacing: 32) {
                    // Calendar label
                    Text(event.calendar.title.uppercased())
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.orange)
                        .tracking(2)

                    // Event info
                    VStack(spacing: 8) {
                        Text(event.title ?? "(No title)")
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.system(.title2, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // Actions
                    HStack(spacing: 16) {
                        if let url = event.meetingURL {
                            Button("Join Meeting") {
                                NSWorkspace.shared.open(url)
                                onDismiss()
                            }
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .buttonStyle(.plain)
                        }

                        Button("Dismiss") { onDismiss() }
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .buttonStyle(.plain)
                    }
                }
                .padding(48)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("No upcoming events")
                        .font(.system(.title, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                    Button("Dismiss") { onDismiss() }
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .buttonStyle(.plain)
                }
                .padding(48)
            }
        }
    }
}
