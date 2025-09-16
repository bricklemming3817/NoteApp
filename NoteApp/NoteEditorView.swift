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
                // Custom header with cancel / save actions
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 18, weight: .regular))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    Spacer()

                    Button(action: { saveNote() }) {
                        Image(systemName: "checkmark")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 18, weight: .regular))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .padding(.vertical, 8)

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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func saveNote() {
        let trimmed = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = noteToEdit {
            if trimmed.isEmpty {
                modelContext.delete(existing)
            } else {
                existing.content   = trimmed
                existing.updatedAt = Date()
                // If this note is pinned for the widget, update the pinned content too.
                let id = String(Int(existing.createdAt.timeIntervalSince1970 * 1000))
                WidgetShared.updatePinnedIfPresent(id: id, content: trimmed, updatedAt: existing.updatedAt)
            }
        } else if !trimmed.isEmpty {
            let newNote = Note(content: trimmed, createdAt: Date())
            modelContext.insert(newNote)
            // Add to selectable notes for the widget
            let id = String(Int(newNote.createdAt.timeIntervalSince1970 * 1000))
            WidgetShared.upsertNote(id: id, content: trimmed)
        }
        dismiss()
    }
}

#Preview {
    NoteEditorView()
        .modelContainer(for: [Note.self], inMemory: true)
}
