//
//  SettingsView.swift
//  Flowly
//
//  Created by Gedeon Koh on 8/12/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("syncWithAppleCalendar") private var syncWithAppleCalendar = true
    @AppStorage("aiVoiceEnabled") private var aiVoiceEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("AI Settings") {
                    Toggle("AI Voice Responses", isOn: $aiVoiceEnabled)
                    
                    NavigationLink(destination: AIPreferencesView()) {
                        HStack {
                            Text("AI Preferences")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Calendar") {
                    Toggle("Sync with Apple Calendar", isOn: $syncWithAppleCalendar)
                    
                    NavigationLink(destination: CalendarSettingsView()) {
                        HStack {
                            Text("Calendar Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
                
                Section {
                    Button(action: {
                        // Clear all data
                    }) {
                        Text("Clear All Data")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct AIPreferencesView: View {
    var body: some View {
        Form {
            Section("AI Model") {
                Picker("Model", selection: .constant("Default")) {
                    Text("Default").tag("Default")
                    Text("Fast").tag("Fast")
                    Text("Accurate").tag("Accurate")
                }
            }
            
            Section("Response Style") {
                Toggle("Ask Follow-up Questions", isOn: .constant(true))
                Toggle("Provide Suggestions", isOn: .constant(true))
            }
        }
        .navigationTitle("AI Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CalendarSettingsView: View {
    var body: some View {
        Form {
            Section("Default Calendar") {
                Picker("Calendar", selection: .constant("Default")) {
                    Text("Default").tag("Default")
                }
            }
            
            Section("Event Defaults") {
                Picker("Default Duration", selection: .constant(60)) {
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                }
            }
        }
        .navigationTitle("Calendar Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}

