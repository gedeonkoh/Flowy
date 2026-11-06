//
//  TodoListView.swift
//  Flowly
//
//  Created by Gedeon Koh on 8/12/25.
//

import SwiftUI

struct TodoListView: View {
    @StateObject private var taskManager = TaskManager.shared
    @State private var tasks: [Task] = []
    @State private var showingTaskForm = false
    @State private var selectedGroup: String = "All"
    @State private var newGroupName = ""
    @State private var showingNewGroupForm = false
    
    var groups: [String] {
        Array(Set(tasks.map { $0.group })).sorted()
    }
    
    var filteredTasks: [Task] {
        if selectedGroup == "All" {
            return tasks
        }
        return tasks.filter { $0.group == selectedGroup }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Group selector
                    groupSelector
                    
                    // Tasks list
                    if filteredTasks.isEmpty {
                        emptyStateView
                    } else {
                        tasksList
                    }
                }
            }
            .navigationTitle("To-Do")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingNewGroupForm = true
                        }) {
                            Label("New Group", systemImage: "folder.badge.plus")
                        }
                        
                        Button(action: {
                            showingTaskForm = true
                        }) {
                            Label("New Task", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingTaskForm) {
                TaskFormView(selectedGroup: selectedGroup == "All" ? nil : selectedGroup)
            }
            .sheet(isPresented: $showingNewGroupForm) {
                NewGroupFormView()
            }
            .onAppear {
                loadTasks()
            }
        }
    }
    
    private var groupSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                GroupChip(title: "All", isSelected: selectedGroup == "All") {
                    selectedGroup = "All"
                }
                
                ForEach(groups, id: \.self) { group in
                    GroupChip(title: group, isSelected: selectedGroup == group) {
                        selectedGroup = group
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    private var tasksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedTasks.keys.sorted(), id: \.self) { group in
                    TaskGroupSection(
                        group: group,
                        tasks: groupedTasks[group] ?? [],
                        onAddTask: {
                            showingTaskForm = true
                        }
                    )
                }
            }
            .padding(.vertical)
        }
    }
    
    private var groupedTasks: [String: [Task]] {
        Dictionary(grouping: filteredTasks) { $0.group }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No tasks yet")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            
            Text("Tap + to add a task")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadTasks() {
        _Concurrency.Task {
            do {
                let loadedTasks = try await taskManager.getAllTasks()
                await MainActor.run {
                    self.tasks = loadedTasks
                }
            } catch {
                print("Error loading tasks: \(error)")
            }
        }
    }
}

struct GroupChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
        }
    }
}

struct TaskGroupSection: View {
    let group: String
    let tasks: [Task]
    let onAddTask: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(group)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Spacer()
                
                Button(action: onAddTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            ForEach(tasks) { task in
                TaskRowView(task: task)
            }
        }
    }
}

struct TaskRowView: View {
    @StateObject private var taskManager = TaskManager.shared
    let task: Task
    @State private var isCompleted: Bool
    
    init(task: Task) {
        self.task = task
        _isCompleted = State(initialValue: task.isCompleted)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                toggleCompletion()
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isCompleted ? .green : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(formatDate(dueDate))
                            .font(.system(size: 14, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            priorityIndicator
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var priorityIndicator: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 8, height: 8)
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }
    
    private func toggleCompletion() {
        isCompleted.toggle()
        let taskToUpdate = task
        let completed = isCompleted
        let taskManager = TaskManager.shared
        _Concurrency.Task {
            do {
                var updatedTask = taskToUpdate
                updatedTask.isCompleted = completed
                try await taskManager.updateTask(updatedTask)
            } catch {
                print("Error updating task: \(error)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

struct TaskFormView: View {
    @Environment(\.dismiss) var dismiss
    private let taskManager = TaskManager.shared
    
    let selectedGroup: String?
    
    @State private var title = ""
    @State private var group = "General"
    @State private var dueDate: Date? = nil
    @State private var hasDueDate = false
    @State private var priority: TaskPriority = TaskPriority.medium
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task Title", text: $title)
                    
                    Picker("Group", selection: $group) {
                        ForEach(taskManager.getAllGroups(), id: \.self) { groupName in
                            Text(groupName).tag(groupName)
                        }
                    }
                    
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due Date", selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(TaskPriority.low)
                        Text("Medium").tag(TaskPriority.medium)
                        Text("High").tag(TaskPriority.high)
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let selectedGroup = selectedGroup {
                    group = selectedGroup
                }
            }
        }
    }
    
    private func saveTask() {
        let task = Task(
            id: UUID().uuidString,
            title: title,
            group: group,
            isCompleted: false,
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority,
            notes: notes.isEmpty ? nil : notes
        )
        
        let taskToSave = task
        _Concurrency.Task { @MainActor in
            let taskManager = TaskManager.shared
            do {
                try await taskManager.addTask(taskToSave)
                dismiss()
            } catch {
                print("Error saving task: \(error)")
            }
        }
    }
}

struct NewGroupFormView: View {
    @Environment(\.dismiss) var dismiss
    private let taskManager = TaskManager.shared
    @State private var groupName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Group Name") {
                    TextField("Enter group name", text: $groupName)
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(groupName.isEmpty)
                }
            }
        }
    }
    
    private func createGroup() {
        let groupNameToCreate = groupName
        _Concurrency.Task { @MainActor in
            let taskManager = TaskManager.shared
            do {
                try await taskManager.createGroup(groupNameToCreate)
                dismiss()
            } catch {
                print("Error creating group: \(error)")
            }
        }
    }
}

#Preview {
    TodoListView()
}

