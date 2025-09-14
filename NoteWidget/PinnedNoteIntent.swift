import AppIntents

// MARK: - PinnedNote entity (from App Group)
struct PinnedNote: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation("Note")
    typealias ID = String

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        .init(title: .init(stringLiteral: title))
    }

    static var defaultQuery = PinnedNoteQuery()
}

struct PinnedNoteQuery: EntityQuery {
    func entities(for identifiers: [PinnedNote.ID]) async throws -> [PinnedNote] {
        let list = WidgetShared.notesList()
        return list
            .filter { identifiers.contains($0.id) }
            .map { PinnedNote(id: $0.id, title: previewTitle($0.content)) }
    }

    func suggestedEntities() async throws -> [PinnedNote] {
        WidgetShared.notesList().map { PinnedNote(id: $0.id, title: previewTitle($0.content)) }
    }

    private func previewTitle(_ content: String) -> String {
        let firstLine = content.split(whereSeparator: \.isNewline).first.map(String.init) ?? content
        return String(firstLine.prefix(40))
    }
}

// MARK: - Widget configuration intent
struct SelectPinnedNoteIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Note"
    static var description = IntentDescription("Choose the note to show in the widget.")

    @Parameter(title: "Note")
    var note: PinnedNote?

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$note)")
    }
}
