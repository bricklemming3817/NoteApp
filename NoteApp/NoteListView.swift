import SwiftUI
import SwiftData

// MARK: – String Extension for Highlighting & Snippet
extension String {
    func highlightedAttributedString(with searchText: String) -> AttributedString {
        var attributed = AttributedString(self)
        guard !searchText.isEmpty else { return attributed }
        let lowerSelf = self.lowercased()
        let lowerSearch = searchText.lowercased()
        var start = lowerSelf.startIndex
        while let range = lowerSelf.range(of: lowerSearch, options: [], range: start..<lowerSelf.endIndex) {
            let nsRange = NSRange(range, in: self)
            if let attrRange = Range(nsRange, in: attributed) {
                attributed[attrRange].backgroundColor = .yellow
            }
            start = range.upperBound
        }
        return attributed
    }

    func snippet(containing searchText: String, maxLength: Int) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else {
            let firstTwo = trimmed.split(whereSeparator: \.isNewline).prefix(2).joined(separator: " ")
            return String(firstTwo.prefix(maxLength))
        }
        guard let match = trimmed.range(of: searchText, options: .caseInsensitive) else {
            let firstTwo = trimmed.split(whereSeparator: \.isNewline).prefix(2).joined(separator: " ")
            return String(firstTwo.prefix(maxLength))
        }
        let startPos = trimmed.distance(from: trimmed.startIndex, to: match.lowerBound)
        let endPos   = trimmed.distance(from: trimmed.startIndex, to: match.upperBound)
        let buffer   = max((maxLength - (endPos - startPos)) / 2, 0)
        let snippetStart = max(0, startPos - buffer)
        let snippetEnd   = min(trimmed.count, endPos + buffer)
        let startIndex = trimmed.index(trimmed.startIndex, offsetBy: snippetStart)
        let endIndex   = trimmed.index(trimmed.startIndex, offsetBy: snippetEnd)
        var result = trimmed[startIndex..<endIndex]
        if snippetStart > 0 { result = "..." + result }
        if snippetEnd < trimmed.count { result += "..." }
        return String(result.prefix(maxLength))
    }
}

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    @State private var showingEditor = false
    @State private var selectedNote: Note?
    @State private var searchText = ""
    @State private var foldersVisible = false

    private var activeNotes: [Note] {
        notes.filter { !$0.isArchived && $0.deletedAt == nil }
             .filter { searchText.isEmpty || $0.content.localizedCaseInsensitiveContains(searchText) }
    }
    private var archivedNotes: [Note] {
        notes.filter { $0.isArchived && $0.deletedAt == nil }
    }
    private var deletedNotes: [Note] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return notes.filter { note in
            if let d = note.deletedAt { return d > cutoff }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Archive Section
                if foldersVisible && !archivedNotes.isEmpty {
                    Section(header: Text("Archive (\(archivedNotes.count))")) {
                        ForEach(archivedNotes) { note in
                            archivedNoteRow(note)
                        }
                    }
                }

                // Deleted Section
                if foldersVisible && !deletedNotes.isEmpty {
                    Section(header: Text("TRASH (\(deletedNotes.count))")) {
                        ForEach(deletedNotes) { note in
                            deletedNoteRow(note)
                        }
                    }
                }

                // Active Notes Section
                Section(header: Text("Notes")) {
                    if activeNotes.isEmpty {
                        Text("No notes yet. Tap + to add one.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(activeNotes) { note in
                            activeNoteRow(note)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText)
            .sheet(isPresented: $showingEditor) {
                NoteEditorView(note: selectedNote)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Principal toolbar item becomes our inline HStack header
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Notes")
                            .font(.title)
                            .bold()
                        Spacer()
                        Button {
                            selectedNote = nil
                            showingEditor = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        withAnimation {
                            if value.translation.height > 50 {
                                foldersVisible = true
                            } else if value.translation.height < -50 {
                                foldersVisible = false
                            }
                        }
                    }
            )
        }
    }

    // MARK: Row Builders

    private func activeNoteRow(_ note: Note) -> some View {
        Button { selectedNote = note; showingEditor = true } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    note.content
                        .snippet(containing: searchText, maxLength: 200)
                        .highlightedAttributedString(with: searchText)
                )
                .foregroundColor(.primary)
                Text(note.createdAt, format: .dateTime.month().day().year().hour().minute())
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                note.isArchived = true
            } label: {
                Label("Archive", systemImage: "archivebox.fill")
            }.tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                note.deletedAt = Date()
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }

    private func archivedNoteRow(_ note: Note) -> some View {
        Button { selectedNote = note; showingEditor = true } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.content.snippet(containing: searchText, maxLength: 200))
                    .foregroundColor(.secondary)
                Text(note.createdAt, format: .dateTime.month().day().year().hour().minute())
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                note.isArchived = false
            } label: {
                Label("Unarchive", systemImage: "arrow.uturn.backward.circle.fill")
            }.tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                note.deletedAt = Date()
                note.isArchived = false
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }

    private func deletedNoteRow(_ note: Note) -> some View {
        Button { selectedNote = note; showingEditor = true } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.content.prefix(200))
                    .foregroundColor(.secondary)
                if let d = note.deletedAt {
                    Text(d, format: .dateTime.month().day().year().hour().minute())
                        .font(.caption).foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                note.deletedAt = nil
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward.circle.fill")
            }.tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(note)
            } label: {
                Label("Delete Now", systemImage: "xmark.bin.fill")
            }
        }
    }
}

