//
//  AIService.swift
//  Flowly
//
//  Created by Gedeon Koh on 8/12/25.
//

import Foundation
import SwiftUI

class AIService {
    static let shared = AIService()
    
    private let calendarManager = CalendarManager.shared
    private let taskManager = TaskManager.shared
    
    // OpenAI API Key
    private let apiKey = ""
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    
    func processUserCommand(_ input: String) async throws -> String {
        let lowercased = input.lowercased()
        
        // Check for mark as done first
        if lowercased.contains("mark") && (lowercased.contains("done") || lowercased.contains("complete")) {
            return try await handleMarkTaskDone(input)
        }
        
        // Try OpenAI first, but fallback to pattern matching if it fails
        do {
            let aiResponse = try await callOpenAI(userInput: input)
            
            // Parse the AI response to extract intent
            if aiResponse.contains("CREATE_EVENT") || aiResponse.contains("SCHEDULE") || lowercased.contains("event") || lowercased.contains("meeting") || lowercased.contains("appointment") {
                return try await handleCalendarCommandWithAI(input, aiResponse: aiResponse)
            } else if aiResponse.contains("CREATE_TASK") || aiResponse.contains("ADD_TASK") || lowercased.contains("task") || lowercased.contains("todo") {
                return try await handleTaskCommandWithAI(input, aiResponse: aiResponse)
            } else if aiResponse.contains("QUESTION") || aiResponse.contains("QUERY") {
                return try await handleQuestionWithAI(input, aiResponse: aiResponse)
            }
        } catch {
            print("OpenAI error: \(error), falling back to pattern matching")
        }
        
        // Fallback to pattern matching
        return try await handleWithPatternMatching(input)
    }
    
    private func handleMarkTaskDone(_ input: String) async throws -> String {
        let tasks = try await taskManager.getIncompleteTasks()
        
        // Try to find the task mentioned
        let lowercased = input.lowercased()
        var taskToComplete: Task? = nil
        
        for task in tasks {
            if lowercased.contains(task.title.lowercased()) {
                taskToComplete = task
                break
            }
        }
        
        // If no specific task found, complete the first one
        if taskToComplete == nil && !tasks.isEmpty {
            taskToComplete = tasks.first
        }
        
        guard let task = taskToComplete else {
            return "I couldn't find any incomplete tasks to mark as done."
        }
        
        var updatedTask = task
        updatedTask.isCompleted = true
        
        try await taskManager.updateTask(updatedTask)
        
        return "Perfect! I've marked '\(task.title)' as completed."
    }
    
    private func callOpenAI(userInput: String) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
        You are a helpful AI assistant for a productivity app. Analyze user input and respond with JSON:
        {
            "intent": "CREATE_EVENT|CREATE_TASK|QUESTION|UNKNOWN",
            "title": "extracted title or null",
            "date": "YYYY-MM-DD or null",
            "time": "HH:MM or null",
            "group": "group name or null",
            "response": "natural language response"
        }
        
        Extract calendar events and tasks from natural language. Be smart about dates (today, tomorrow, day names, etc.)
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userInput]
            ],
            "temperature": 0.3,
            "max_tokens": 200
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.apiError
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        
        throw AIError.invalidResponse
    }
    
    private func handleCalendarCommandWithAI(_ input: String, aiResponse: String) async throws -> String {
        // Parse AI response JSON
        let eventInfo = try parseAIResponse(aiResponse)
        
        // Create calendar event
        let event = CalendarEvent(
            title: eventInfo.title ?? "Event",
            startDate: eventInfo.startDate ?? Date(),
            endDate: eventInfo.endDate ?? (eventInfo.startDate ?? Date()).addingTimeInterval(3600),
            notes: nil,
            color: Color.blue,
            emoji: nil
        )
        
        try await calendarManager.createEvent(event)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return eventInfo.response ?? "Okay, I've scheduled '\(event.title)' for \(formatter.string(from: event.startDate))."
    }
    
    private func handleTaskCommandWithAI(_ input: String, aiResponse: String) async throws -> String {
        let taskInfo = try parseAIResponse(aiResponse)
        
        let task = Task(
            id: UUID().uuidString,
            title: taskInfo.title ?? "New Task",
            group: taskInfo.group ?? "General",
            isCompleted: false,
            dueDate: taskInfo.startDate,
            priority: .medium,
            notes: nil
        )
        
        try await taskManager.addTask(task)
        
        return taskInfo.response ?? "Okay, I've added '\(task.title)' to your \(task.group) group."
    }
    
    private func handleQuestionWithAI(_ input: String, aiResponse: String) async throws -> String {
        let questionInfo = try parseAIResponse(aiResponse)
        
        // If it's about calendar or tasks, get actual data
        if input.lowercased().contains("calendar") || input.lowercased().contains("schedule") {
            let events = try await calendarManager.getUpcomingEvents(count: 5)
            if events.isEmpty {
                return "You have no upcoming events scheduled."
            }
            var response = "Here are your upcoming events:\n"
            for event in events {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                response += "• \(event.title) - \(formatter.string(from: event.startDate))\n"
            }
            return response
        }
        
        if input.lowercased().contains("task") || input.lowercased().contains("todo") {
            let tasks = try await taskManager.getIncompleteTasks()
            if tasks.isEmpty {
                return "You have no incomplete tasks."
            }
            var response = "Here are your incomplete tasks:\n"
            for task in tasks.prefix(5) {
                response += "• \(task.title) (\(task.group))\n"
            }
            return response
        }
        
        return questionInfo.response ?? aiResponse
    }
    
    private func parseAIResponse(_ response: String) throws -> ParsedAIResponse {
        // Try to parse JSON from AI response
        if let jsonData = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            let calendar = Calendar.current
            var startDate: Date? = nil
            
            if let dateStr = json["date"] as? String,
               let timeStr = json["time"] as? String {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
                startDate = dateFormatter.date(from: "\(dateStr) \(timeStr)")
            } else if let dateStr = json["date"] as? String {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: dateStr) {
                    startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)
                }
            }
            
            return ParsedAIResponse(
                title: json["title"] as? String,
                startDate: startDate,
                endDate: startDate?.addingTimeInterval(3600),
                group: json["group"] as? String,
                response: json["response"] as? String
            )
        }
        
        // Fallback: try to extract info from natural language or use DateParser
        let dateParser = DateParser()
        if let eventInfo = dateParser.parseEvent(response) {
            return ParsedAIResponse(
                title: eventInfo.title,
                startDate: eventInfo.startDate,
                endDate: eventInfo.endDate,
                group: nil,
                response: nil
            )
        }
        
        return ParsedAIResponse(title: nil, startDate: nil, endDate: nil, group: nil, response: response)
    }
    
    // Fallback pattern matching for when AI fails
    private func handleWithPatternMatching(_ input: String) async throws -> String {
        let lowercased = input.lowercased()
        
        if lowercased.contains("event") || lowercased.contains("meeting") || lowercased.contains("appointment") {
            return try await handleCalendarCommand(input)
        }
        
        if lowercased.contains("task") || lowercased.contains("todo") || lowercased.contains("remind me") {
            return try await handleTaskCommand(input)
        }
        
        return "I understand you said: '\(input)'. Could you clarify what you'd like me to do?"
    }
    
    private func handleCalendarCommand(_ input: String) async throws -> String {
        let dateParser = DateParser()
        guard let eventInfo = dateParser.parseEvent(input) else {
            return "I'd like to help you schedule that event. Could you tell me the date and time?"
        }
        
        let event = CalendarEvent(
            title: eventInfo.title,
            startDate: eventInfo.startDate,
            endDate: eventInfo.endDate ?? eventInfo.startDate.addingTimeInterval(3600),
            notes: eventInfo.notes,
            color: eventInfo.color,
            emoji: nil
        )
        
        try await calendarManager.createEvent(event)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return "Okay, I've added '\(event.title)' to your calendar for \(formatter.string(from: event.startDate))."
    }
    
    private func handleTaskCommand(_ input: String) async throws -> String {
        let taskParser = TaskParser()
        guard let taskInfo = taskParser.parseTask(input) else {
            return "I'd like to help you create that task. Could you tell me what the task is?"
        }
        
        let task = Task(
            id: UUID().uuidString,
            title: taskInfo.title,
            group: taskInfo.group ?? "General",
            isCompleted: false,
            dueDate: taskInfo.dueDate,
            priority: taskInfo.priority,
            notes: nil
        )
        
        try await taskManager.addTask(task)
        
        return "Okay, I've added '\(task.title)' to your \(task.group) group."
    }
}

struct ParsedAIResponse {
    let title: String?
    let startDate: Date?
    let endDate: Date?
    let group: String?
    let response: String?
}

enum AIError: Error {
    case invalidURL
    case apiError
    case invalidResponse
}

// Date parsing helper
struct DateParser {
    func parseEvent(_ input: String) -> EventInfo? {
        let calendar = Calendar.current
        let now = Date()
        
        var targetDate = now
        if input.lowercased().contains("saturday") || input.lowercased().contains("sat") {
            targetDate = nextOccurrence(of: 7, from: now)
        } else if input.lowercased().contains("sunday") || input.lowercased().contains("sun") {
            targetDate = nextOccurrence(of: 1, from: now)
        } else if input.lowercased().contains("monday") || input.lowercased().contains("mon") {
            targetDate = nextOccurrence(of: 2, from: now)
        } else if input.lowercased().contains("tuesday") || input.lowercased().contains("tue") {
            targetDate = nextOccurrence(of: 3, from: now)
        } else if input.lowercased().contains("wednesday") || input.lowercased().contains("wed") {
            targetDate = nextOccurrence(of: 4, from: now)
        } else if input.lowercased().contains("thursday") || input.lowercased().contains("thu") {
            targetDate = nextOccurrence(of: 5, from: now)
        } else if input.lowercased().contains("friday") || input.lowercased().contains("fri") {
            targetDate = nextOccurrence(of: 6, from: now)
        } else if input.lowercased().contains("today") {
            targetDate = now
        } else if input.lowercased().contains("tomorrow") {
            targetDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        }
        
        var hour = 9
        var minute = 0
        
        if let hourMatch = input.range(of: #"(\d{1,2})\s*(am|pm)"#, options: .regularExpression) {
            let timeString = String(input[hourMatch])
            if let hourValue = Int(timeString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                hour = hourValue
                if timeString.lowercased().contains("pm") && hour != 12 {
                    hour += 12
                } else if timeString.lowercased().contains("am") && hour == 12 {
                    hour = 0
                }
            }
        } else if let hour24Match = input.range(of: #"(\d{1,2}):(\d{2})"#, options: .regularExpression) {
            let timeString = String(input[hour24Match])
            let components = timeString.split(separator: ":")
            if components.count == 2, let h = Int(components[0]), let m = Int(components[1]) {
                hour = h
                minute = m
            }
        }
        
        targetDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDate) ?? targetDate
        
        let title = extractTitle(from: input) ?? "Event"
        
        return EventInfo(
            title: title,
            startDate: targetDate,
            endDate: calendar.date(byAdding: .hour, value: 1, to: targetDate),
            notes: nil,
            color: Color.blue
        )
    }
    
    private func nextOccurrence(of weekday: Int, from date: Date) -> Date {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        var daysUntil = weekday - currentWeekday
        if daysUntil <= 0 {
            daysUntil += 7
        }
        return calendar.date(byAdding: .day, value: daysUntil, to: date) ?? date
    }
    
    private func extractTitle(from input: String) -> String? {
        let words = input.components(separatedBy: " ")
        var titleWords: [String] = []
        var foundEventKeyword = false
        
        for word in words {
            if word.lowercased() == "event" || word.lowercased() == "meeting" {
                foundEventKeyword = true
                continue
            }
            if foundEventKeyword && !word.lowercased().contains("on") && !word.lowercased().contains("at") {
                titleWords.append(word)
            }
        }
        
        return titleWords.isEmpty ? nil : titleWords.joined(separator: " ")
    }
}

struct EventInfo {
    let title: String
    let startDate: Date
    let endDate: Date?
    let notes: String?
    let color: Color
}

// Task parsing helper
struct TaskParser {
    func parseTask(_ input: String) -> TaskInfo? {
        let lowercased = input.lowercased()
        
        var group: String? = nil
        if lowercased.contains("school") {
            group = "School"
        } else if lowercased.contains("work") {
            group = "Work"
        } else if lowercased.contains("personal") {
            group = "Personal"
        }
        
        var title = input
        if let addRange = title.range(of: "add", options: .caseInsensitive) {
            title = String(title[addRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        if let taskRange = title.range(of: "task", options: .caseInsensitive) {
            title = String(title[taskRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        if let toRange = title.range(of: "to", options: .caseInsensitive) {
            title = String(title[toRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        
        var dueDate: Date? = nil
        if lowercased.contains("today") {
            dueDate = Date()
        } else if lowercased.contains("tomorrow") {
            dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        }
        
        return TaskInfo(
            title: title.isEmpty ? "New Task" : title,
            group: group,
            dueDate: dueDate,
            priority: TaskPriority.medium
        )
    }
}

struct TaskInfo {
    let title: String
    let group: String?
    let dueDate: Date?
    let priority: TaskPriority
}
