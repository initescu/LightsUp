//
//  LightsUpApp.swift
//  LightsUp
//

import AppKit
import SwiftUI

@main
struct LightsUpApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var calendarManager = CalendarManager()

    init() {
        // LSUIElement=YES sets activation policy to .accessory before any code runs,
        // which blocks all window display at launch. Temporarily elevate to .regular
        // so the onboarding Window scene can appear. Restored to .accessory on completion.
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            NSApp.setActivationPolicy(.regular)
        }
    }

    var body: some Scene {
        MenuBarExtra("LightsUp", systemImage: "lightbulb") {
            ContentView()
                .environment(calendarManager)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to LightsUp", id: "onboarding") {
            OnboardingView(calendarManager: calendarManager)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(hasCompletedOnboarding ? .suppressed : .presented)

        Settings {
            SettingsView()
                .environment(calendarManager)
        }
    }
}
