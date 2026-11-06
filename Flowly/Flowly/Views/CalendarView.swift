//
//  CalendarView.swift
//  Flowly
//
//  Created by Gedeon Koh on 8/12/25.
//

import SwiftUI
import EventKit

struct CalendarView: View {
    @StateObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()
    @State private var showingEventForm = false
    @State private var events: [CalendarEvent] = []
    @State private var currentMonth: Date = Date()
    @State private var isLoading = false
    @State private var eventsCache: [Date: [CalendarEvent]] = [:]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Month header
                    monthHeader
                    
                    // Weekday headers
                    weekdayHeaders
                    
                    // Calendar grid
                    calendarGrid
                    
                    // Events list for selected date
                    eventsList
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingEventForm = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingEventForm) {
                EventFormView(selectedDate: selectedDate)
            }
            .onAppear {
                loadEvents()
            }
            .onChange(of: currentMonth) { _ in
                loadEvents()
            }
        }
    }
    
    private var monthHeader: some View {
        HStack {
            Button(action: {
                currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text(monthYearString(from: currentMonth))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var weekdayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var calendarGrid: some View {
        let days = computeCalendarDays()
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days) { calendarDay in
                CalendarDayView(
                    day: calendarDay,
                    isSelected: Calendar.current.isDate(calendarDay.date, inSameDayAs: selectedDate),
                    events: eventsForDate(calendarDay.date)
                ) {
                    selectedDate = calendarDay.date
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private func computeCalendarDays() -> [CalendarDay] {
        let calendar = Calendar.current
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!.count
        let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: calendar.date(byAdding: .month, value: -1, to: currentMonth)!)!.count
        
        let totalCells = 42
        var days: [CalendarDay] = []
        
        // Previous month days - need to add (firstWeekday - 1) days
        let daysToAddFromPreviousMonth = firstWeekday - 1
        if daysToAddFromPreviousMonth > 0 {
            for i in 0..<daysToAddFromPreviousMonth {
                let day = daysInPreviousMonth - daysToAddFromPreviousMonth + i + 1
                let date = calendar.date(byAdding: .day, value: -(daysToAddFromPreviousMonth - i), to: firstDayOfMonth)!
                days.append(CalendarDay(day: day, date: date, isCurrentMonth: false))
            }
        }
        
        // Current month days
        for day in 1...daysInMonth {
            let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth)!
            days.append(CalendarDay(day: day, date: date, isCurrentMonth: true))
        }
        
        // Next month days
        let remainingDays = totalCells - days.count
        if remainingDays > 0 {
            for day in 1...remainingDays {
                let date = calendar.date(byAdding: .day, value: day - 1, to: calendar.date(byAdding: .month, value: 1, to: firstDayOfMonth)!)!
                days.append(CalendarDay(day: day, date: date, isCurrentMonth: false))
            }
        }
        
        return days
    }
    
    private var eventsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(selectedDateString)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                let dayEvents = eventsForDate(selectedDate)
                if dayEvents.isEmpty {
                    Text("No events scheduled")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 20)
                } else {
                    ForEach(dayEvents) { event in
                        EventRowView(event: event)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        
        // Check cache first
        if let cached = eventsCache[dateKey] {
            return cached
        }
        
        // Filter from main events array
        let dayEvents = events.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
        eventsCache[dateKey] = dayEvents
        return dayEvents
    }
    
    private func loadEvents() {
        guard !isLoading else { return }
        isLoading = true
        
        _Concurrency.Task {
            do {
                // Only load events for current month + buffer
                let calendar = Calendar.current
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
                
                // Get events for the month range
                let loadedEvents = try await calendarManager.getEvents(from: startOfMonth, to: endOfMonth)
                
                await MainActor.run {
                    self.events = loadedEvents
                    self.eventsCache.removeAll() // Clear cache
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Error loading events: \(error)")
                }
            }
        }
    }
}

struct CalendarDay: Identifiable {
    let id = UUID()
    let day: Int
    let date: Date
    let isCurrentMonth: Bool
}

struct CalendarDayView: View {
    let day: CalendarDay
    let isSelected: Bool
    let events: [CalendarEvent]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(day.day)")
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular, design: .rounded))
                    .foregroundColor(day.isCurrentMonth ? (isSelected ? .white : .primary) : .secondary)
                
                if !events.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(events.prefix(3)) { event in
                            Circle()
                                .fill(event.color)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EventRowView: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(event.color)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                
                Text(timeString(from: event.startDate))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let emoji = event.emoji {
                Text(emoji)
                    .font(.system(size: 20))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EventFormView: View {
    @Environment(\.dismiss) var dismiss
    private let calendarManager = CalendarManager.shared
    
    let selectedDate: Date
    
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var notes = ""
    @State private var selectedColor: Color = .blue
    @State private var emoji = ""
    @State private var hasReminder = false
    @State private var reminderMinutes: Int = 15
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                    
                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Emoji (optional)", text: $emoji)
                        .autocapitalization(.none)
                    
                    ColorPicker("Color", selection: $selectedColor)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section("Reminder") {
                    Toggle("Set Reminder", isOn: $hasReminder)
                    
                    if hasReminder {
                        Picker("Remind me", selection: $reminderMinutes) {
                            Text("5 minutes before").tag(5)
                            Text("15 minutes before").tag(15)
                            Text("30 minutes before").tag(30)
                            Text("1 hour before").tag(60)
                        }
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                startDate = selectedDate
                endDate = selectedDate.addingTimeInterval(3600)
            }
        }
    }
    
    private func saveEvent() {
        let event = CalendarEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: notes.isEmpty ? nil : notes,
            color: selectedColor,
            emoji: emoji.isEmpty ? nil : emoji
        )
        
        _Concurrency.Task {
            let calendarManager = CalendarManager.shared
            do {
                try await calendarManager.createEvent(event)
                if hasReminder {
                    try await calendarManager.addReminder(for: event, minutesBefore: reminderMinutes)
                }
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving event: \(error)")
            }
        }
    }
}

#Preview {
    CalendarView()
}

