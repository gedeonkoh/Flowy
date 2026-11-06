//
//  CalendarManager.swift
//  Flowly
//
//  Created by Gedeon Koh on 8/12/25.
//

import Foundation
import EventKit
import SwiftUI
import Combine

struct CalendarEvent: Identifiable {
    let id = UUID().uuidString
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String?
    let color: Color
    let emoji: String?
    var ekEvent: EKEvent?
}

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    private var calendar: EKCalendar?
    
    init() {
        requestAccess()
    }
    
    private func requestAccess() {
        eventStore.requestAccess(to: .event) { granted, error in
            if granted {
                self.setupCalendar()
            }
        }
    }
    
    private func setupCalendar() {
        // Find or create Flowly calendar
        let calendars = eventStore.calendars(for: .event)
        calendar = calendars.first { $0.title == "Flowly" }
        
        if calendar == nil {
            calendar = EKCalendar(for: .event, eventStore: eventStore)
            calendar?.title = "Flowly"
            calendar?.cgColor = UIColor.systemBlue.cgColor
            
            // Set source (iCloud, Local, etc.)
            if let source = eventStore.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
                calendar?.source = source
            } else if let source = eventStore.defaultCalendarForNewEvents?.source {
                calendar?.source = source
            }
            
            do {
                try eventStore.saveCalendar(calendar!, commit: true)
            } catch {
                print("Error creating calendar: \(error)")
            }
        }
    }
    
    func createEvent(_ event: CalendarEvent) async throws {
        guard let calendar = calendar else {
            throw CalendarError.calendarNotAvailable
        }
        
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.notes = event.notes
        ekEvent.calendar = calendar
        
        // Set color
        if let color = event.emoji {
            ekEvent.notes = (ekEvent.notes ?? "") + "\n\nEmoji: \(color)"
        }
        
        do {
            try eventStore.save(ekEvent, span: .thisEvent)
        } catch {
            throw CalendarError.saveFailed(error)
        }
    }
    
    func getUpcomingEvents(count: Int) async throws -> [CalendarEvent] {
        guard let calendar = calendar else {
            return []
        }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .year, value: 1, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let ekEvents = eventStore.events(matching: predicate)
        
        return ekEvents.prefix(count).map { ekEvent in
            CalendarEvent(
                title: ekEvent.title,
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                notes: ekEvent.notes,
                color: .blue,
                emoji: extractEmoji(from: ekEvent.notes),
                ekEvent: ekEvent
            )
        }
    }
    
    func getEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        guard let calendar = calendar else {
            return []
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let ekEvents = eventStore.events(matching: predicate)
        
        return ekEvents.map { ekEvent in
            CalendarEvent(
                title: ekEvent.title,
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                notes: ekEvent.notes,
                color: .blue,
                emoji: extractEmoji(from: ekEvent.notes),
                ekEvent: ekEvent
            )
        }
    }
    
    func addReminder(for event: CalendarEvent, minutesBefore: Int) async throws {
        guard let ekEvent = event.ekEvent else {
            throw CalendarError.eventNotFound
        }
        
        let alarm = EKAlarm(relativeOffset: -Double(minutesBefore * 60))
        ekEvent.addAlarm(alarm)
        
        do {
            try eventStore.save(ekEvent, span: .thisEvent)
        } catch {
            throw CalendarError.saveFailed(error)
        }
    }
    
    private func extractEmoji(from notes: String?) -> String? {
        guard let notes = notes,
              let emojiRange = notes.range(of: "Emoji: ") else {
            return nil
        }
        let emojiString = String(notes[emojiRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return emojiString.isEmpty ? nil : emojiString
    }
}

enum CalendarError: Error {
    case calendarNotAvailable
    case saveFailed(Error)
    case eventNotFound
}

