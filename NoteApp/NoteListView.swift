import SwiftUI
import SwiftData

// MARK: – String helpers
extension String {

    /// Highlight search text inside the receiver.
    func highlightedAttributedString(with searchText: String) -> AttributedString {
        var attributed = AttributedString(self)
        guard !searchText.isEmpty else { return attributed }

        let lowerSelf   = lowercased()
        let lowerSearch = searchText.lowercased()
        var start       = lowerSelf.startIndex

        while let r = lowerSelf.range(of: lowerSearch, range: start..<lowerSelf.endIndex) {
            if let attrR = Range(NSRange(r, in: self), in: attributed) {
                attributed[attrR].backgroundColor = .yellow
            }
            start = r.upperBound
        }
        return attributed
    }

    /// Return a short snippet around `search` (max `maxLength` chars).
    func snippet(containing search: String, maxLength: Int) -> String {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)

        guard !search.isEmpty,
              let m = t.range(of: search, options: .caseInsensitive)
        else {
            // first 2 non-empty lines, truncated to maxLength
            return String(
                t.split(whereSeparator: \.isNewline)
                 .prefix(2)
                 .joined(separator: " ")
                 .prefix(maxLength)
            )
        }

        let start  = t.distance(from: t.startIndex, to: m.lowerBound)
        let end    = t.distance(from: t.startIndex, to: m.upperBound)
        let buffer = max((maxLength - (end - start)) / 2, 0)

        let s = max(0, start - buffer)
        let e = min(t.count, end + buffer)

        let sIdx = t.index(t.startIndex, offsetBy: s)
        let eIdx = t.index(t.startIndex, offsetBy: e)

        var result = t[sIdx..<eIdx]
        if s > 0            { result = "…" + result }
        if e < t.count      { result += "…" }
        return String(result)
    }
}

// MARK: – Main view
struct NoteListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    // navigation / edit
    @State private var showingEditor = false
    @State private var selectedNote: Note?

    // search text
    @State private var searchText = ""

    // HUD state
    @State private var foldersVisible   = false
    @State private var isArchiveExpanded = false
    @State private var isTrashExpanded   = false

    // filtered groups
    private var activeNotes: [Note] {
        notes
            .filter { !$0.isArchived && $0.deletedAt == nil }
            .filter {
                searchText.isEmpty ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
    }

    private var archivedNotes: [Note] {
        notes.filter { $0.isArchived && $0.deletedAt == nil }
    }

    private var deletedNotes: [Note] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return notes.filter { ($0.deletedAt ?? .distantPast) > cutoff }
    }

    // MARK: body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // HUD slides from top
                if foldersVisible {
                    folderHud
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // main list
                List {
                    Section(
                        header:
                            HStack {
                                Text("Notes")
                                    .textCase(nil)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .background(Color(.systemBackground))
                    ) {
                        if activeNotes.isEmpty {
                            Text(
                                searchText.isEmpty
                                ? "No notes yet. Tap + to add one."
                                : "No results for ‘\(searchText)’"
                            )
                            .foregroundColor(.gray)
                            .listRowInsets(
                                EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                            )
                        } else {
                            ForEach(activeNotes) { note in
                                activeNoteRow(note)
                                    .listRowInsets(
                                        EdgeInsets(top: 0, leading: 16,
                                                   bottom: 0, trailing: 16)
                                    )
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .global)
                        .onEnded { handleSwipe(translation: $0.translation) }
                )
            }

            // ───── Pinned search bar ─────
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            .navigationBarTitleDisplayMode(.inline)
            // ─────────────────────────────

            .sheet(isPresented: $showingEditor) {
                NoteEditorView(note: selectedNote)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("NoteApp")
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
        }
    }

    // MARK: swipe to show / hide HUD
    private func handleSwipe(translation: CGSize) {
        withAnimation(.spring()) {
            if translation.height > 50  && !foldersVisible {
                foldersVisible = true
            }
            if translation.height < -50 && foldersVisible {
                foldersVisible    = false
                isArchiveExpanded = false
                isTrashExpanded   = false
            }
        }
    }

    // MARK: folder HUD
    private var folderHud: some View {
        VStack(alignment: .leading, spacing: 8) {
            folderCard(
                title:      "Archive",
                icon:       "archivebox.fill",
                countText:  "(\(archivedNotes.count))",
                isExpanded: $isArchiveExpanded,
                notes:      archivedNotes,
                row:        archivedFlatRow(_:),
                onToggle:   { if isArchiveExpanded { isTrashExpanded = false } }
            )

            folderCard(
                title:      "Trash",
                icon:       "trash.fill",
                countText:  "",
                isExpanded: $isTrashExpanded,
                notes:      deletedNotes,
                row:        deletedFlatRow(_:),
                onToggle:   { if isTrashExpanded { isArchiveExpanded = false } }
            )
        }
    }

    // MARK: single folder card
    private func folderCard<Row: View>(
        title: String,
        icon: String,
        countText: String,
        isExpanded: Binding<Bool>,
        notes: [Note],
        @ViewBuilder row: @escaping (Note) -> Row,
        onToggle: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {

            // header
            Button {
                withAnimation(.spring()) {
                    isExpanded.wrappedValue.toggle()
                    onToggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("\(title) \(countText)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
            }

            // rows
            if isExpanded.wrappedValue && !notes.isEmpty {
                List(notes) { note in
                    row(note)
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: 32,
                                       bottom: 0, trailing: 16)
                        )
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(notes.count) * 64) // ≈ row height
                .transition(.opacity)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05),
                radius: 1, x: 0, y: 1)
    }

    // MARK: rows inside Archive / Trash
    private func archivedFlatRow(_ note: Note) -> some View {
        Button {
            selectedNote = note
            showingEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.content)
                    .lineLimit(1)
                Text(note.createdAt,
                     format: .dateTime.month().day().year().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 10)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { note.isArchived = false }
            } label: {
                Label("Unarchive", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    note.deletedAt  = Date()
                    note.isArchived = false
                }
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }

    private func deletedFlatRow(_ note: Note) -> some View {
        Button {
            selectedNote = note
            showingEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.content)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let deleted = note.deletedAt {
                    Text("Deleted: \(deleted.formatted(.dateTime.month().day()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 10)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { note.deletedAt = nil }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { modelContext.delete(note) }
            } label: {
                Label("Delete Now", systemImage: "xmark.bin.fill")
            }
        }
    }

    // MARK: active (main) list row
    private func activeNoteRow(_ note: Note) -> some View {
        Button {
            selectedNote = note
            showingEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    note.content
                        .snippet(containing: searchText, maxLength: 200)
                        .highlightedAttributedString(with: searchText)
                )
                .foregroundColor(.primary)
                Text(note.createdAt,
                     format: .dateTime.month().day().year().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { note.isArchived = true }
            } label: {
                Label("Archive", systemImage: "archivebox.fill")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { note.deletedAt = Date() }
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }
}
