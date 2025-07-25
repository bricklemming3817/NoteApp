
//
//  ContentView.swift
//  NoteApp
//
//  Created by Kevin Varghese on 2025-07-25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NoteListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}
