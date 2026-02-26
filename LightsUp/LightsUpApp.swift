//
//  LightsUpApp.swift
//  LightsUp
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate?
    var onboardingWindow: NSWindow?
    var settingsWindow: NSWindow?
    let calendarManager = CalendarManager()
    var popupController: PopupWindowController?
    var allowTermination = false

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
            self?.calendarManager.setSleeping(true)
            self?.popupController?.dismiss()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil, queue: .main
            
        ) { [weak self] _ in
            self?.calendarManager.setSleeping(true)
            self?.popupController?.dismiss()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.calendarManager.setSleeping(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.calendarManager.refreshAndCheckMissedEvents()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.calendarManager.setSleeping(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.calendarManager.refreshAndCheckMissedEvents()
            }
        }

        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            NSApp.setActivationPolicy(.regular)
            showOnboarding()
        }
    }
    
    func showSettings() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView().environment(calendarManager)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LightsUp Settings"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.settingsWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if allowTermination {
            return .terminateNow
        }
        settingsWindow?.close()
        return .terminateCancel
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        if closingWindow === settingsWindow {
            settingsWindow = nil
            if onboardingWindow == nil {
                NSApp.setActivationPolicy(.accessory)
            }
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
    }
}
