
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
    @Environment(\.dismiss)     private var dismiss
    @FocusState private var focusedField: FocusField?

    enum FocusField: Hashable {
        case content
    }

    @State private var noteContent: String
    private let noteToEdit: Note?

    init(note: Note? = nil) {
        _noteContent   = State(initialValue: note?.content ?? "")
        self.noteToEdit = note
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Separator under navigation bar
                Divider()
                    .background(Color(.separator))

                // Main editor area
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Text editor
                        TextEditor(text: $noteContent)
                            .focused($focusedField, equals: .content)
                            .onAppear { focusedField = .content }
                            .font(.body)
                            .lineSpacing(5)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 200)

                        // Placeholder
                        if noteContent.isEmpty {
                            Text("Start typing your note…")
                                .foregroundColor(Color(.placeholderText))
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16) // constant bottom padding
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle(noteToEdit == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .padding(.leading, 8)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveNote() }
                        .padding(.trailing, 8)
                }
            }
        }
    }

    private func saveNote() {
        let trimmed = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = noteToEdit {
            if trimmed.isEmpty {
                modelContext.delete(existing)
            } else {
                existing.content   = trimmed
                existing.createdAt = Date()
            }
        } else if !trimmed.isEmpty {
            let newNote = Note(content: trimmed, createdAt: Date())
            modelContext.insert(newNote)
        }

        dismiss()
    }
}

#Preview {
    NoteEditorView()
        .modelContainer(for: [Note.self], inMemory: true)
}













////
////  NoteEditorView.swift
////  NoteApp
////
////  Created by Kevin Varghese on 2025-07-25.
////
//
//import SwiftUI
//import SwiftData
//
//struct NoteEditorView: View {
//    @Environment(\.modelContext) private var modelContext
//    @Environment(\.dismiss) private var dismiss
//    @Environment(\.safeAreaInsets) private var safeAreaInsets
//    @FocusState private var focusedField: FocusField?
//    
//en    enum FocusField: Hashable {
//        case content
//    }
//    
//    @State private var noteContent: String
//    var noteToEdit: Note?
//    
//    init(note: Note? = nil) {
//        _noteContent = State(initialValue: note?.content ?? "")
//        self.noteToEdit = note
//    }
//    
//    var body: some View {
//        NavigationStack {
//            VStack(spacing: 0) {
//                Divider().background(Color(.separator))
//                ScrollView {
//                    ZStack(alignment: .topLeading) {
//                        TextEditor(text: $noteContent)
//                            .focused($focusedField, equals: .content)
//                            .onAppear {
//                                focusedField = .content
//                            }
//                            .font(.body)
//                            .lineSpacing(5)
//                            .padding(.vertical, 20)                   // 20 pt inside top/bottom
//                            .padding(.horizontal, 16)                 // 16 pt inside left/right
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 12)    // From detailed spec
//                                    .stroke(Color(.separator), lineWidth: 1)
//                            )
//                            .cornerRadius(12)                         // From detailed spec
//                            .background(Color(.secondarySystemBackground).opacity(0)) // Transparent background
//                            .frame(maxWidth: .infinity)             // Fill width
//                            .frame(minHeight: 200)                  // Minimum height
//                            .scrollContentBackground(.hidden)       // Keep for custom background
//
//                        if noteContent.isEmpty {
//                            Text("Start typing your note…")
//                                .foregroundColor(Color(.placeholderText))
//                                .padding(.horizontal, 20) // From detailed spec for placeholder
//                                .padding(.top, 24)       // From detailed spec for placeholder
//                        }
//                    }
//                    .padding(.top, 16) // Padding around the ZStack as per example
//                    .padding(.horizontal, 16)
//                    .padding(.bottom, safeAreaInsets.bottom + 16)
//                }
//                .ignoresSafeArea(.keyboard, edges: .bottom) // ONLY HERE
//            }
//            .navigationTitle(noteToEdit == nil ? "New Note" : "Edit Note")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                        .padding(.leading, 8)
//                }
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Save") { saveNote() }
//                        .padding(.trailing, 8)
//                }
//            }
//            .background(Color(.systemBackground)) // Full screen background
//            .gesture(
//                DragGesture().onEnded { value in
//                    if value.translation.height > 50 { // Swipe down threshold
//                        focusedField = nil
//                    }
//                }
//            )
//        }
//    }
//    
//    private func saveNote() {
//        let trimmedContent = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
//
//        if let noteToEdit = noteToEdit {
//            // We are editing an existing note
//            if trimmedContent.isEmpty {
//                // If the content is now empty, delete the note
//                modelContext.delete(noteToEdit)
//            } else {
//                // Otherwise, update the note's content
//                noteToEdit.content = trimmedContent
//                noteToEdit.createdAt = Date() // Update timestamp on edit
//            }
//        } else {
//            // We are creating a new note
//            if !trimmedContent.isEmpty {
//                // Only create the note if it has content
//                let newNote = Note(content: trimmedContent, createdAt: Date())
//                modelContext.insert(newNote)
//            }
//        }
//    }
//}
//
//#Preview {
//    NoteEditorView()
//        .modelContainer(for: Note.self, inMemory: true)
//}
