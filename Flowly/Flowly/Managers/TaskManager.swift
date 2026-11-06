//
//  TaskManager.swift
//  Flowly
//
//  Created by Gedeon Koh on 8/12/25.
//

import Foundation
import Combine

struct Task: Identifiable, Codable {
    let id: String
    var title: String
    var group: String
    var isCompleted: Bool
    var dueDate: Date?
    var priority: TaskPriority
    var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, group, isCompleted, dueDate, priority, notes
    }
    
    init(id: String, title: String, group: String, isCompleted: Bool, dueDate: Date?, priority: TaskPriority, notes: String?) {
        self.id = id
        self.title = title
        self.group = group
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
        self.notes = notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        group = try container.decode(String.self, forKey: .group)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        priority = try container.decode(TaskPriority.self, forKey: .priority)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(group, forKey: .group)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

enum TaskPriority: String, Codable {
    case low, medium, high
}

class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    private let userDefaults = UserDefaults.standard
    private let tasksKey = "FlowlyTasks"
    private let groupsKey = "FlowlyGroups"
    
    func addTask(_ task: Task) async throws {
        var tasks = getAllTasksSync()
        tasks.append(task)
        saveTasks(tasks)
    }
    
    func updateTask(_ task: Task) async throws {
        var tasks = getAllTasksSync()
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks(tasks)
        }
    }
    
    func deleteTask(_ task: Task) async throws {
        var tasks = getAllTasksSync()
        tasks.removeAll { $0.id == task.id }
        saveTasks(tasks)
    }
    
    func getAllTasks() async throws -> [Task] {
        return getAllTasksSync()
    }
    
    func getIncompleteTasks() async throws -> [Task] {
        return getAllTasksSync().filter { !$0.isCompleted }
    }
    
    func getTasksForGroup(_ group: String) async throws -> [Task] {
        return getAllTasksSync().filter { $0.group == group }
    }
    
    func createGroup(_ name: String) async throws {
        var groups = getAllGroups()
        if !groups.contains(name) {
            groups.append(name)
            saveGroups(groups)
        }
    }
    
    func getAllGroups() -> [String] {
        if let data = userDefaults.data(forKey: groupsKey),
           let groups = try? JSONDecoder().decode([String].self, from: data) {
            return groups
        }
        return ["General", "Work", "School", "Personal"]
    }
    
    private func getAllTasksSync() -> [Task] {
        guard let data = userDefaults.data(forKey: tasksKey),
              let tasks = try? JSONDecoder().decode([Task].self, from: data) else {
            return []
        }
        return tasks
    }
    
    private func saveTasks(_ tasks: [Task]) {
        if let data = try? JSONEncoder().encode(tasks) {
            userDefaults.set(data, forKey: tasksKey)
        }
    }
    
    private func saveGroups(_ groups: [String]) {
        if let data = try? JSONEncoder().encode(groups) {
            userDefaults.set(data, forKey: groupsKey)
        }
    }
}

