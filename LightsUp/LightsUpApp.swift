//
//  LightsUpApp.swift
//  LightsUp
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var onboardingWindow: NSWindow?
    let calendarManager = CalendarManager()
    var popupController: PopupWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        popupController = PopupWindowController(calendarManager: calendarManager)
        
        calendarManager.onEventStart = { [weak self] _ in
            self?.popupController?.show()
        }
        
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            NSApp.setActivationPolicy(.regular)
            showOnboarding()
        }
    }
    
    func showOnboarding() {
        let contentView = OnboardingView(calendarManager: calendarManager)
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to LightsUp"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        
        self.onboardingWindow = window
    }
}

@main
struct LightsUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var calendarManager: CalendarManager {
        appDelegate.calendarManager
    }

    var body: some Scene {
        MenuBarExtra("LightsUp", systemImage: "lightbulb") {
            ContentView()
                .environment(calendarManager)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(calendarManager)
        }
    }
}
