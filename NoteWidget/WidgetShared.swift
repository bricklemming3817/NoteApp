import Foundation

enum WidgetShared {
    static let appGroupID = "group.noteapp.shared"
    private static let contentKey   = "widget.note.content"     // legacy
    private static let updatedAtKey = "widget.note.updatedAt"   // legacy
    private static let notesMapKey  = "widget.notes.map"        // [String: String]

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func read() -> (content: String, updatedAt: Date)? {
        guard let defaults,
              let content = defaults.string(forKey: contentKey)
        else { return nil }

        let t = defaults.double(forKey: updatedAtKey)
        let date = t == 0 ? Date() : Date(timeIntervalSince1970: t)
        return (content, date)
    }

    static func notesList() -> [(id: String, content: String)] {
        let map = (defaults?.dictionary(forKey: notesMapKey) as? [String: String]) ?? [:]
        return map.map { ($0.key, $0.value) }.sorted { $0.id < $1.id }
    }

    static func content(for id: String) -> String? {
        let map = (defaults?.dictionary(forKey: notesMapKey) as? [String: String]) ?? [:]
        return map[id]
    }
}
