import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)     private var dismiss
    @FocusState private var focusedField: Bool

    @State private var noteContent: String
    private let noteToEdit: Note?

    init(note: Note? = nil) {
        _noteContent   = State(initialValue: note?.content ?? "")
        self.noteToEdit = note
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Divider()

                // Timestamp at top, centered
                Text(
                    (noteToEdit?.createdAt ?? Date()),
                    format: .dateTime.month().day().year().hour().minute().second()
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                // Editor
                TextEditor(text: $noteContent)
                    .focused($focusedField)
                    .onAppear { focusedField = true }
                    .font(.body)
                    .padding(.horizontal,0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            }
            .padding(.horizontal, 16)
            .ignoresSafeArea(.keyboard, edges: .bottom)
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
