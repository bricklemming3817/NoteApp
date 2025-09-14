import Foundation

/// Lightweight persistence for a set of pinned notes used by the app UI.
/// Uses stable note ids derived from `createdAt` (milliseconds since 1970).
enum PinnedNotesStore {
    private static let key = "pinned.note.ids"
    private static var defaults: UserDefaults { .standard }

    private static func load() -> Set<String> {
        if let arr = defaults.array(forKey: key) as? [String] {
            return Set(arr)
        }
        return []
    }

    private static func save(_ set: Set<String>) {
        defaults.set(Array(set), forKey: key)
    }

    static func isPinned(id: String) -> Bool { load().contains(id) }

    static func setPinned(_ pinned: Bool, id: String) {
        var set = load()
        if pinned { set.insert(id) } else { set.remove(id) }
        save(set)
    }

    static func remove(id: String) { setPinned(false, id: id) }
}

