//
//  ContentView.swift
//  Flowly
//
//  Created by Gedeon Koh on 8/12/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CallView()
                .tabItem {
                    Label("Call", systemImage: "phone.fill")
                }
                .tag(0)
            
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(1)
            
            TodoListView()
                .tabItem {
                    Label("To-Do", systemImage: "checklist")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView()
}
