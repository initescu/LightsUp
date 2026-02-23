//
//  CalendarManager.swift
//  LightsUp
//

import EventKit
import Foundation

@Observable
final class CalendarManager {
    private(set) var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    private(set) var allCalendars: [EKCalendar] = []
    private(set) var todayEvents: [EKEvent] = []
    private(set) var tomorrowEvents: [EKEvent] = []

    // Stored property so @Observable tracks it and SwiftUI re-renders on change.
    var enabledCalendarIDs: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(enabledCalendarIDs), forKey: "enabledCalendarIDs")
            fetchEvents()
        }
    }

    var onEventStart: ((EKEvent) -> Void)?

    private let store = EKEventStore()
    private var monitorTimer: Timer?
    private var lastCheckedEventIDs = Set<String>()

    init() {
        // Load persisted selection. Direct assignment in init does not trigger didSet.
        if let stored = UserDefaults.standard.stringArray(forKey: "enabledCalendarIDs") {
            enabledCalendarIDs = Set(stored)
        }

        if authorizationStatus == .fullAccess {
            loadCalendars()
            fetchEvents()
        }
        observeStoreChanges()
        startMonitoring()
    }

    func requestAccess() async {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {}
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus == .fullAccess {
            loadCalendars()
            fetchEvents()
        }
    }

    func fetchEvents() {
        guard authorizationStatus == .fullAccess else {
            todayEvents = []
            tomorrowEvents = []
            return
        }

        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        guard
            let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday),
            let endOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfTomorrow)
        else { return }

        let targets = allCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }

        guard !targets.isEmpty else {
            todayEvents = []
            tomorrowEvents = []
            return
        }

        let predicate = store.predicateForEvents(withStart: startOfToday, end: endOfTomorrow, calendars: targets)
        let all = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        todayEvents = all.filter { $0.startDate < startOfTomorrow && $0.endDate > now }
        tomorrowEvents = all.filter { $0.startDate >= startOfTomorrow }
    }

    func nearestUpcomingEvent() -> EKEvent? {
        return todayEvents.first ?? tomorrowEvents.first
    }

    private func loadCalendars() {
        allCalendars = store.calendars(for: .event).sorted { $0.title < $1.title }

        // First launch: enable all calendars by default.
        // (didSet fires here since this is a method call, not direct init assignment.)
        if UserDefaults.standard.object(forKey: "enabledCalendarIDs") == nil {
            enabledCalendarIDs = Set(allCalendars.map(\.calendarIdentifier))
        }
    }

    private func observeStoreChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.store.reset()
                self.loadCalendars()
                self.fetchEvents()
            }
        }
    }

    private func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForEventStarts()
            }
        }
    }

    private func checkForEventStarts() {
        guard authorizationStatus == .fullAccess else { return }

        let now = Date()

        for event in todayEvents {
            guard let eventID = event.eventIdentifier else { continue }

            let timeSinceStart = now.timeIntervalSince(event.startDate)
            let isJustStarted = timeSinceStart >= 0 && timeSinceStart < 10

            if isJustStarted && !lastCheckedEventIDs.contains(eventID) {
                onEventStart?(event)
                lastCheckedEventIDs.insert(eventID)
            }
        }
    }
}
