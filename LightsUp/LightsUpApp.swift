//
//  LightsUpApp.swift
//  LightsUp
//

import SwiftUI

@main
struct LightsUpApp: App {
    var body: some Scene {
        MenuBarExtra("LightsUp", systemImage: "lightbulb") {
            ContentView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
