//
//  CalendarManager.swift
//  LightsUp
//
//  Minimal stub for Step 4 (onboarding / permission request).
//  Expanded with full event fetching in Step 5.
//

import EventKit
import Foundation

@Observable
final class CalendarManager {
    private(set) var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let store = EKEventStore()

    func requestAccess() async {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {}
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
}
