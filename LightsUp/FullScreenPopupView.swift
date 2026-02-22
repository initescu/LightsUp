//
//  FullScreenPopupView.swift
//  LightsUp
//

import SwiftUI

struct FullScreenPopupView: View {
    let onDismiss: () -> Void

    // Mock data — will be replaced with real EKEvent in Step 6
    private let eventTitle = "Design Review"
    private let eventTime  = "14:00 – 15:00"
    private let calendarName = "Work"

    var body: some View {
        ZStack {
            // Dark scrim
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Calendar label
                Text(calendarName.uppercased())
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.orange)
                    .tracking(2)

                // Event info
                VStack(spacing: 8) {
                    Text(eventTitle)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(eventTime)
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Actions
                HStack(spacing: 16) {
                    Button("Join Meeting") {}
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)

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
        }
    }
}
