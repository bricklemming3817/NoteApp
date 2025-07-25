
//
//  NoteEditorView.swift
//  NoteApp
//
//  Created by Kevin Varghese on 2025-07-25.
//

import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextEditorFocused: Bool
    
    @State private var noteContent: String
    var noteToEdit: Note?
    
    init(note: Note? = nil) {
        _noteContent = State(initialValue: note?.content ?? "")
        self.noteToEdit = note
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) { // Use ZStack for explicit layering
                // TextEditor as the base layer, fills the entire ZStack
                TextEditor(text: $noteContent)
                    .focused($isTextEditorFocused)
                    .onAppear {
                        isTextEditorFocused = true
                    }
                    .padding(.horizontal) // Apply horizontal padding to the text content itself
                    .padding(.top, noteToEdit != nil ? 35 : 0) // IMPORTANT: Add top padding if timestamp is present
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Make it fill available space within ZStack
                    .scrollContentBackground(.hidden) // Hide default TextEditor background
                    .background(Color(.systemBackground)) // Explicit background for the editor area
                
                // Timestamp as an overlay, aligned to the top of the ZStack
                if let noteToEdit = noteToEdit {
                    Text(noteToEdit.createdAt, format: Date.FormatStyle(date: .numeric, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.vertical, 8) // Vertical padding for the timestamp view
                        .frame(maxWidth: .infinity) // Ensure it spans full width
                        .multilineTextAlignment(.center)
                        .background(Color(.systemBackground)) // Solid background so TextEditor content doesn't show through
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 2) // Subtle shadow for visual separation
                        .padding(.top, 0) // No extra top padding needed here, ZStack handles it
                }
            }
            .navigationTitle(noteToEdit == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                        dismiss()
                    }
                }
            }
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height > 50 { // Swipe down threshold
                        isTextEditorFocused = false
                        // Hide keyboard
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            )
            .ignoresSafeArea(.keyboard, edges: .bottom) // Ensures keyboard interaction is smooth
        }
    }
    
    private func saveNote() {
        let trimmedContent = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)

        if let noteToEdit = noteToEdit {
            // We are editing an existing note
            if trimmedContent.isEmpty {
                // If the content is now empty, delete the note
                modelContext.delete(noteToEdit)
            } else {
                // Otherwise, update the note's content
                noteToEdit.content = trimmedContent
                noteToEdit.createdAt = Date() // Update timestamp on edit
            }
        } else {
            // We are creating a new note
            if !trimmedContent.isEmpty {
                // Only create the note if it has content
                let newNote = Note(content: trimmedContent, createdAt: Date())
                modelContext.insert(newNote)
            }
        }
    }
}

#Preview {
    NoteEditorView()
        .modelContainer(for: Note.self, inMemory: true)
}
