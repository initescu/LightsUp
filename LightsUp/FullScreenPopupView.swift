//
//  FullScreenPopupView.swift
//  LightsUp
//

import EventKit
import SwiftUI

struct FullScreenPopupView: View {
    let event: EKEvent?
    let onDismiss: () -> Void

    private var dismissButton: some View {
        Button { onDismiss() } label: {
            Text("Dismiss [ESC]")
                .font(.appBody)
                .foregroundStyle(.appPopupText)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appPopupStroke, lineWidth: 1)
        )
        .buttonStyle(.plain)
    }

    var body: some View {
        ZStack {
            // Dark scrim
            Color.appPopupScrim
                .ignoresSafeArea()

            if let event = event {
                VStack(spacing: 32) {
                    // Calendar label
                    Text(event.calendar.title.uppercased())
                        .font(.appCaptionBold)
                        .foregroundStyle(.appAccent)
                        .tracking(2)

                    // Event info
                    VStack(spacing: 8) {
                        Text(event.title ?? "(No title)")
                            .font(.appPopupTitle)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.appTitle2)
                            .foregroundStyle(.appPopupText)
                    }

                    // Actions
                    HStack(spacing: 16) {
                        if let url = event.meetingURL {
                            Button {
                                NSWorkspace.shared.open(url)
                                onDismiss()
                            } label: {
                                Text("Join Meeting")
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 14)
                                    .contentShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .background(Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .buttonStyle(.plain)

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(url.absoluteString, forType: .string)
                                onDismiss()
                            } label: {
                                Text("Copy Link")
                                    .font(.appBody)
                                    .foregroundStyle(.appPopupText)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 14)
                                    .contentShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.appPopupStroke, lineWidth: 1)
                            )
                            .buttonStyle(.plain)
                        }

                        dismissButton
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
                        .foregroundStyle(.appPopupText)
                    dismissButton
                }
                .padding(48)
            }
        }
    }
}
