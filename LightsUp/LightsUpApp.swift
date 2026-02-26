//
//  LightsUpApp.swift
//  LightsUp
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?
    var onboardingWindow: NSWindow?
    let calendarManager = CalendarManager()
    var popupController: PopupWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        popupController = PopupWindowController(calendarManager: calendarManager)
        
        calendarManager.onEventStart = { [weak self] _ in
            self?.popupController?.show()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.popupController?.dismiss()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.popupController?.dismiss()
        }

        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            NSApp.setActivationPolicy(.regular)
            showOnboarding()
        }
    }
    
    func showOnboarding() {
        let contentView = OnboardingView(calendarManager: calendarManager) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }
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
        MenuBarExtra {
            ContentView()
                .environment(calendarManager)
        } label: {
            MenuBarLabelView()
                .environment(calendarManager)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(calendarManager)
        }
    }
}
