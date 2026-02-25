//
//  OnboardingView.swift
//  LightsUp
//

import AppKit
import EventKit
import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var step = 0

    let calendarManager: CalendarManager

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            navigationBar
                .padding(24)
        }
        .frame(width: 480, height: 360)
    }

    // MARK: - Step routing

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeView
        case 1: whatItDoesView
        case 2: calendarAccessView
        default: doneView
        }
    }

    // MARK: - Navigation bar

    private var navigationBar: some View {
        HStack {
            if step > 0 && step < totalSteps - 1 {
                Button("← Back") { step -= 1 }
                    .buttonStyle(.plain)
                    .font(.appBody)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(step == totalSteps - 1 ? "Get Started" : "Next →") {
                if step == totalSteps - 1 {
                    complete()
                } else {
                    step += 1
                }
            }
            .buttonStyle(.plain)
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .foregroundStyle(Color.appAccent)
        }
    }

    // MARK: - Step views

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.appAccent)

            Text("LightsUp")
                .font(.system(size: 32, weight: .bold, design: .monospaced))

            Text("Never miss a meeting again.")
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(48)
    }

    private var whatItDoesView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("How it works")
                .font(.system(.title2, design: .monospaced, weight: .bold))

            VStack(alignment: .leading, spacing: 14) {
                featureRow(icon: "calendar", text: "Reads your Apple Calendar")
                featureRow(icon: "clock.fill", text: "Watches for upcoming meetings")
                featureRow(
                    icon: "rectangle.fill.on.rectangle.fill",
                    text: "Takes over the screen the moment a meeting starts"
                )
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calendarAccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.appAccent)

            Text("Calendar Access")
                .font(.system(.title2, design: .monospaced, weight: .bold))

            Text("LightsUp needs read access to detect upcoming meetings.\nYour data stays on-device.")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            calendarAccessControl
        }
        .padding(48)
    }

    @ViewBuilder
    private var calendarAccessControl: some View {
        switch calendarManager.authorizationStatus {
        case .fullAccess:
            Label("Access granted", systemImage: "checkmark.circle.fill")
                .font(.appBody)
                .foregroundStyle(.green)

        case .denied, .restricted:
            VStack(spacing: 6) {
                Label("Access denied", systemImage: "xmark.circle.fill")
                    .font(.appBody)
                    .foregroundStyle(.red)
                Text("System Settings → Privacy & Security → Calendars")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

        default: // .notDetermined, .writeOnly, future cases
            Button("Grant Calendar Access") {
                Task { await calendarManager.requestAccess() }
            }
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.appAccent)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(.plain)
        }
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)

            Text("You're all set.")
                .font(.system(size: 28, weight: .bold, design: .monospaced))

            Text("LightsUp lives in your menu bar.\nClick the lightbulb any time to see upcoming meetings.")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(48)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.appAccent)
                .frame(width: 20)
            Text(text)
                .font(.appBody)
        }
    }

    private func complete() {
        print("🔍 complete() called")
        print("🔍 Setting hasCompletedOnboarding to true")
        hasCompletedOnboarding = true
        
        // Also set it directly in UserDefaults as a backup
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.synchronize()
        
        print("🔍 UserDefaults value: \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
        
        NSApp.setActivationPolicy(.accessory)
        
        // Close the onboarding window
        if let window = NSApp.windows.first(where: { $0.title == "Welcome to LightsUp" }) {
            window.close()
        }
    }
}
