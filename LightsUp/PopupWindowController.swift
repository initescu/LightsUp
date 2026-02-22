//
//  PopupWindowController.swift
//  LightsUp
//

import AppKit
import SwiftUI

final class PopupWindowController: NSObject {

    private var window: NSWindow?

    func show() {
        guard window == nil else { return }

        guard let screen = NSScreen.main else { return }

        let popupView = FullScreenPopupView { [weak self] in
            self?.dismiss()
        }

        let hostingView = NSHostingView(rootView: popupView)

        let win = NSWindow(
            contentRect: screen.frame,
            styleMask:   .borderless,
            backing:     .buffered,
            defer:       false,
            screen:      screen
        )
        win.level                = .screenSaver
        win.isOpaque             = false
        win.backgroundColor      = .clear
        win.collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.contentView          = hostingView
        win.makeKeyAndOrderFront(nil)

        // Dismiss on Escape
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                return nil
            }
            return event
        }

        self.window = win
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}
