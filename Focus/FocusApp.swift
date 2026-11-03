//
//  FocusApp.swift
//  Focus
//
//  Created by Emmanuel Vazquez on 31/10/26.
//
import SwiftUI
import SwiftData

@main
struct FocusApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                TodayView()
                    .tabItem { Label("Hoy", systemImage: "checklist") }
                StatsView()
                    .tabItem { Label("Progreso", systemImage: "chart.bar.fill") }
                AchievementsView()
                    .tabItem { Label("Logros", systemImage: "trophy.fill") }
            }
        }
        .modelContainer(for: [Routine.self, CompletionLog.self])
    }
}
