import SwiftUI
import SwiftData
import WidgetKit

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
                attributed[attrR].backgroundColor = .yellow.opacity(0.25)
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
    @State private var pendingDeepLinkNoteID: String?

    // search text
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    // HUD state
    @State private var foldersVisible   = false
    @State private var isArchiveExpanded = false
    @State private var isTrashExpanded   = false
    @State private var pinBump: Int = 0
    private let folderRowHeight: CGFloat = 64

    // filtered groups
    private var activeNotes: [Note] {
        _ = pinBump // depend on pin changes for re-sorting
        let filtered = notes
            .filter { !$0.isArchived && $0.deletedAt == nil }
            .filter {
                searchText.isEmpty ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        return filtered.sorted { a, b in
            let ap = isPinned(a)
            let bp = isPinned(b)
            if ap != bp { return ap && !bp }
            return a.createdAt > b.createdAt
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

                // Custom title row with compose button
                HStack {
                    Text("NoteApp")
                        .font(.title)
                    Spacer()
                    Button {
                        selectedNote = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.black)
                            .font(.system(size: 22))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Custom minimal search bar
                searchBar
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                // HUD slides below search bar
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
                            HStack(spacing: 8) {
                                Text("Notes")
                                    .textCase(nil)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
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
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(
                                        EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
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

            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)

            .sheet(isPresented: $showingEditor) {
                NoteEditorView(note: selectedNote)
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onChange(of: notes) { _ in
                if let pending = pendingDeepLinkNoteID {
                    if openNote(withID: pending) {
                        pendingDeepLinkNoteID = nil
                    }
                }
            }
            .onAppear {
                purgeOldTrash()
                syncWidgetNotesMap()
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
                count:      archivedNotes.count,
                isExpanded: $isArchiveExpanded,
                notes:      archivedNotes,
                row:        archivedFolderRow(_:),
                onToggle:   { if isArchiveExpanded { isTrashExpanded = false } }
            )

            folderCard(
                title:      "Trash",
                icon:       "trash.fill",
                count:      nil,
                isExpanded: $isTrashExpanded,
                notes:      deletedNotes,
                row:        deletedFolderRow(_:),
                onToggle:   { if isTrashExpanded { isArchiveExpanded = false } }
            )
        }
    }

    // MARK: single folder card
    private func folderCard<Row: View>(
        title: String,
        icon: String,
        count: Int?,
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
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let count {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .tint(.black)

            // rows (use List to preserve swipe actions)
            if isExpanded.wrappedValue && !notes.isEmpty {
                List(notes) { note in
                    row(note)
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 16)
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(notes.count) * folderRowHeight)
                .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: rows inside Archive / Trash
    // Compact archived row used inside the hidden folders HUD (no card background)
    private func archivedFolderRow(_ note: Note) -> some View {
        Button {
            selectedNote = note
            showingEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.content)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(note.createdAt,
                         format: .dateTime.month().day().year().hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if isPinned(note) {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
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
            if isPinned(note) {
                Button {
                    togglePinned(note, makePinned: false)
                } label: {
                    Label("Unpin", systemImage: "pin.slash.fill")
                }
                .tint(.orange)
            } else {
                Button {
                    togglePinned(note, makePinned: true)
                    pinToWidget(note)
                } label: {
                    Label("Pin", systemImage: "pin.fill")
                }
                .tint(.orange)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    note.deletedAt  = Date()
                    note.isArchived = false
                    let id = noteID(for: note)
                    PinnedNotesStore.remove(id: id)
                    WidgetShared.removeNote(id: id)
                }
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }

    // Compact trash row used inside the hidden folders HUD (no card background)
    private func deletedFolderRow(_ note: Note) -> some View {
        Button {
            selectedNote = note
            showingEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.content)
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
                withAnimation {
                    note.deletedAt = nil
                    let id = noteID(for: note)
                    WidgetShared.upsertNote(id: id, content: note.content)
                }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    modelContext.delete(note)
                    let id = noteID(for: note)
                    WidgetShared.removeNote(id: id)
                }
            } label: {
                Label("Delete Now", systemImage: "xmark.bin.fill")
            }
        }
    }
    private func archivedFlatRow(_ note: Note) -> some View {
        Button {
            selectedNote = note
            showingEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(note.content)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(note.createdAt,
                         format: .dateTime.month().day().year().hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if isPinned(note) {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { note.isArchived = false }
            } label: {
                Label("Unarchive", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.green)
            if isPinned(note) {
                Button {
                    togglePinned(note, makePinned: false)
                } label: {
                    Label("Unpin", systemImage: "pin.slash.fill")
                }
                .tint(.orange)
            } else {
                Button {
                    togglePinned(note, makePinned: true)
                    pinToWidget(note)
                } label: {
                    Label("Pin", systemImage: "pin.fill")
                }
                .tint(.orange)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    note.deletedAt  = Date()
                    note.isArchived = false
                    let id = noteID(for: note)
                    PinnedNotesStore.remove(id: id)
                    WidgetShared.removeNote(id: id)
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
            VStack(alignment: .leading, spacing: 6) {
                Text(note.content)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let deleted = note.deletedAt {
                    Text("Deleted: \(deleted.formatted(.dateTime.month().day()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation {
                    note.deletedAt = nil
                    let id = noteID(for: note)
                    WidgetShared.upsertNote(id: id, content: note.content)
                }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    modelContext.delete(note)
                    let id = noteID(for: note)
                    WidgetShared.removeNote(id: id)
                }
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
            VStack(alignment: .leading, spacing: 6) {
                Text(
                    note.content
                        .snippet(containing: searchText, maxLength: 200)
                        .highlightedAttributedString(with: searchText)
                )
                .foregroundColor(.primary)
                HStack(spacing: 6) {
                    Text(note.createdAt,
                         format: .dateTime.month().day().year().hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if isPinned(note) {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { note.isArchived = true }
            } label: {
                Label("Archive", systemImage: "archivebox.fill")
            }
            .tint(.blue)
            if isPinned(note) {
                Button {
                    togglePinned(note, makePinned: false)
                } label: {
                    Label("Unpin", systemImage: "pin.slash.fill")
                }
                .tint(.orange)
            } else {
                Button {
                    togglePinned(note, makePinned: true)
                } label: {
                    Label("Pin", systemImage: "pin.fill")
                }
                .tint(.orange)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    note.deletedAt = Date()
                    let id = noteID(for: note)
                    PinnedNotesStore.remove(id: id)
                    WidgetShared.removeNote(id: id)
                }
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }
}

// MARK: – Widget helpers
extension NoteListView {
    private func noteID(for note: Note) -> String {
        String(Int(note.createdAt.timeIntervalSince1970 * 1000))
    }

    @discardableResult
    private func openNote(withID id: String) -> Bool {
        guard let target = notes.first(where: { noteID(for: $0) == id }) else { return false }
        selectedNote = target
        showingEditor = true
        return true
    }

    private func pinToWidget(_ note: Note) {
        // Use a stable id derived from createdAt (milliseconds since 1970)
        let id = noteID(for: note)
        WidgetShared.savePinned(id: id, content: note.content, updatedAt: note.updatedAt)
    }

    private func togglePinned(_ note: Note, makePinned: Bool) {
        let id = noteID(for: note)
        PinnedNotesStore.setPinned(makePinned, id: id)
        if makePinned {
            // Also ensure widget selection list has the latest content
            WidgetShared.savePinned(id: id, content: note.content, updatedAt: note.updatedAt)
        }
        pinBump &+= 1
    }

    private func isPinned(_ note: Note) -> Bool {
        let id = noteID(for: note)
        return PinnedNotesStore.isPinned(id: id)
    }
}

// MARK: – Purge helpers
extension NoteListView {
    /// Permanently removes notes in Trash older than 30 days.
    private func purgeOldTrash() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        var didDelete = false
        for note in notes {
            if let deleted = note.deletedAt, deleted < cutoff {
                modelContext.delete(note)
                let id = noteID(for: note)
                PinnedNotesStore.remove(id: id)
                WidgetShared.removeNote(id: id)
                didDelete = true
            }
        }
        if didDelete {
            try? modelContext.save()
        }
    }

    /// Keeps the App Group notes map in sync with current (non-deleted) notes
    private func syncWidgetNotesMap() {
        let selectable = notes.filter { $0.deletedAt == nil }
        let items: [(id: String, content: String)] = selectable.map {
            (noteID(for: $0), $0.content)
        }
        WidgetShared.setAllNotes(items)
    }
}

// MARK: – Custom Search Bar
extension NoteListView {
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("", text: $searchText)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(false)
            if searchFocused || !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchFocused = false
                }) {
                    Image(systemName: "xmark")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 18, weight: .regular))
                }
                .tint(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: – Deep link handling
extension NoteListView {
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "noteapp" else { return }

        guard url.host == "note" else { return }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        var candidateID = pathComponents.first
        if candidateID == nil {
            candidateID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "id" })?
                .value
        }

        guard let targetID = candidateID else { return }

        if !openNote(withID: targetID) {
            pendingDeepLinkNoteID = targetID
        }
    }
}
