import SwiftUI
import SwiftData

// MARK: – String Extension for Highlighting & Snippet
extension String {
    func highlightedAttributedString(with searchText: String) -> AttributedString {
        var attributed = AttributedString(self)
        guard !searchText.isEmpty else { return attributed }

        let lowerSelf   = self.lowercased()
        let lowerSearch = searchText.lowercased()
        var searchStart = lowerSelf.startIndex

        while let stringRange = lowerSelf.range(of: lowerSearch,
                                                options: [],
                                                range: searchStart..<lowerSelf.endIndex) {
            // Convert String range → NSRange → AttributedString.Range
            let nsRange = NSRange(stringRange, in: self)
            if let attrRange = Range(nsRange, in: attributed) {
                attributed[attrRange].backgroundColor = .yellow
            }
            searchStart = stringRange.upperBound
        }

        return attributed
    }

    func snippet(containing searchText: String, maxLength: Int) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)

        guard !searchText.isEmpty else {
            let firstTwo = trimmed
                .split(whereSeparator: \.isNewline)
                .prefix(2)
                .joined(separator: "\n")
            return String(firstTwo.prefix(maxLength))
        }

        if let match = trimmed.range(of: searchText, options: .caseInsensitive) {
            let startPos = trimmed.distance(from: trimmed.startIndex, to: match.lowerBound)
            let endPos   = trimmed.distance(from: trimmed.startIndex, to: match.upperBound)
            let buffer   = max((maxLength - (endPos - startPos)) / 2, 0)

            let snippetStart = max(0, startPos - buffer)
            let snippetEnd   = min(trimmed.count, endPos + buffer)

            let startIndex = trimmed.index(trimmed.startIndex, offsetBy: snippetStart)
            let endIndex   = trimmed.index(trimmed.startIndex, offsetBy: snippetEnd)

            var result = trimmed[startIndex..<endIndex]
            if snippetStart > 0 { result = "..." + result }
            if snippetEnd   < trimmed.count { result += "..." }

            return String(result.prefix(maxLength))
        } else {
            let firstTwo = trimmed
                .split(whereSeparator: \.isNewline)
                .prefix(2)
                .joined(separator: "\n")
            return String(firstTwo.prefix(maxLength))
        }
    }
}

// MARK: – NoteListView with Bottom Search Bar
struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    @State private var showingEditor = false
    @State private var selectedNote: Note?
    @AppStorage("hasShownOnboarding") private var hasShownOnboarding = false
    @State private var searchText = ""

    private var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.content.range(of: searchText, options: .caseInsensitive) != nil
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                List {
                    ForEach(filteredNotes) { note in
                        Button {
                            selectedNote = note
                            showingEditor = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                let snippet = note.content
                                    .snippet(containing: searchText, maxLength: 200)
                                Text(snippet.highlightedAttributedString(with: searchText))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(note.createdAt, format: .dateTime.year().month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { offsets in
                        withAnimation {
                            for offset in offsets {
                                let toDelete = filteredNotes[offset]
                                modelContext.delete(toDelete)
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        TextField("Search notes…", text: $searchText)
                            .padding(.vertical, 8)
                            .padding(.leading, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .overlay {
                                HStack {
                                    Spacer()
                                    if !searchText.isEmpty {
                                        Button {
                                            withAnimation { searchText = "" }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.trailing, 12)
                                    }
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
                .navigationTitle("Notes")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            selectedNote = nil
                            showingEditor = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                        }
                    }
                }
                .sheet(isPresented: $showingEditor) {
                    NoteEditorView(note: selectedNote)
                }
            }

            if !hasShownOnboarding {
                VStack {
                    Spacer()
                    VStack {
                        Text("Tap + to add a note")
                        Button("Got it!") {
                            withAnimation { hasShownOnboarding = true }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 5)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .transition(.move(edge: .bottom))
                    .padding(.bottom, 100)
                }
            }
        }
    }
}
