//
//  NoteAppApp.swift
//  NoteApp
//
//  Created by Kevin Varghese on 2025-07-25.
//

import SwiftUI
import SwiftData

@main
struct NoteAppApp: App {
    @AppStorage(AppTheme.storageKey) private var storedTheme = AppTheme.light.rawValue

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
        ])
        let modelConfiguration = ModelConfiguration("NoteAppStoreV2", schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memoryConfig])
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppTheme.load(from: storedTheme).colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
