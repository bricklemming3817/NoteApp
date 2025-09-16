import Foundation
import WidgetKit

/// Shared helper to persist the selected note's content for the widget.
/// Uses an App Group so the widget extension can read it.
enum WidgetShared {
    /// Update to match your App Group ID in Signing & Capabilities
    static let appGroupID = "group.noteapp.shared"

    private static let contentKey   = "widget.note.content"
    private static let updatedAtKey = "widget.note.updatedAt"
    private static let notesMapKey  = "widget.notes.map"      // [String: String]
    private static let selectedIDKey  = "widget.selected.id"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: Pinned multiple notes helpers
    /// Save or update a pinned note and mark it as the current selection.
    static func savePinned(id: String, content: String, updatedAt: Date = Date()) {
        // Ensure the note exists in the selectable notes map
        upsertNote(id: id, content: content)
        defaults?.set(id, forKey: selectedIDKey)
        defaults?.set(content, forKey: contentKey)
        defaults?.set(updatedAt.timeIntervalSince1970, forKey: updatedAtKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Return the list of all selectable notes as (id, content) pairs.
    static func notesList() -> [(id: String, content: String)] {
        let map = (defaults?.dictionary(forKey: notesMapKey) as? [String: String]) ?? [:]
        return map.map { ($0.key, $0.value) }.sorted { $0.id < $1.id }
    }

    /// Returns the currently selected pinned note id, if any.
    static func selectedPinnedID() -> String? {
        defaults?.string(forKey: selectedIDKey)
    }

    /// Update an existing pinned note's content if present, without changing selection.
    static func updatePinnedIfPresent(id: String, content: String, updatedAt: Date = Date()) {
        // Always keep the all-notes map up to date
        upsertNote(id: id, content: content)
        // Update single selection if matches
        if selectedPinnedID() == id {
            defaults?.set(content, forKey: contentKey)
            defaults?.set(updatedAt.timeIntervalSince1970, forKey: updatedAtKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: All notes map maintenance
    static func upsertNote(id: String, content: String) {
        var map = (defaults?.dictionary(forKey: notesMapKey) as? [String: String]) ?? [:]
        map[id] = content
        defaults?.set(map, forKey: notesMapKey)
    }

    static func removeNote(id: String) {
        guard var map = (defaults?.dictionary(forKey: notesMapKey) as? [String: String]) else { return }
        map.removeValue(forKey: id)
        defaults?.set(map, forKey: notesMapKey)
    }

    static func setAllNotes(_ items: [(id: String, content: String)]) {
        let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.content) })
        defaults?.set(dict, forKey: notesMapKey)
    }
}
