import Foundation
import WidgetKit

/// Shared helper to persist the selected note's content for the widget.
/// Uses an App Group so the widget extension can read it.
enum WidgetShared {
    /// Update to match your App Group ID in Signing & Capabilities
    static let appGroupID = "group.noteapp.shared"

    // Legacy single-note keys (kept for backward compat)
    private static let contentKey   = "widget.note.content"
    private static let updatedAtKey = "widget.note.updatedAt"

    // Multi-note storage for widget configuration (all selectable notes)
    private static let notesMapKey    = "widget.notes.map"      // [String: String]
    private static let pinnedMapKey   = "widget.pinned.map"     // legacy key
    private static let selectedIDKey  = "widget.selected.id"    // legacy key

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: Legacy single note save/read
    static func save(content: String, updatedAt: Date = Date()) {
        defaults?.set(content, forKey: contentKey)
        defaults?.set(updatedAt.timeIntervalSince1970, forKey: updatedAtKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> (content: String, updatedAt: Date)? {
        guard let defaults,
              let content = defaults.string(forKey: contentKey)
        else { return nil }

        let t = defaults.double(forKey: updatedAtKey)
        let date = t == 0 ? Date() : Date(timeIntervalSince1970: t)
        return (content, date)
    }

    static func clear() {
        defaults?.removeObject(forKey: contentKey)
        defaults?.removeObject(forKey: updatedAtKey)
        defaults?.removeObject(forKey: pinnedMapKey)
        defaults?.removeObject(forKey: selectedIDKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Pinned multiple notes helpers
    /// Save or update a pinned note and mark it as the current selection.
    static func savePinned(id: String, content: String, updatedAt: Date = Date()) {
        // Ensure the note exists in the selectable notes map
        upsertNote(id: id, content: content)
        // Keep legacy pinned keys to not break older builds
        var legacy = (defaults?.dictionary(forKey: pinnedMapKey) as? [String: String]) ?? [:]
        legacy[id] = content
        defaults?.set(legacy, forKey: pinnedMapKey)
        defaults?.set(id, forKey: selectedIDKey)
        // Also keep legacy single-note for older widget versions
        defaults?.set(content, forKey: contentKey)
        defaults?.set(updatedAt.timeIntervalSince1970, forKey: updatedAtKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Return the list of all selectable notes as (id, content) pairs.
    static func notesList() -> [(id: String, content: String)] {
        // Prefer new all-notes map; fall back to legacy pinned map if absent
        let map = (defaults?.dictionary(forKey: notesMapKey) as? [String: String])
            ?? (defaults?.dictionary(forKey: pinnedMapKey) as? [String: String])
            ?? [:]
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
        // Update legacy pinned map if present
        if var map = (defaults?.dictionary(forKey: pinnedMapKey) as? [String: String]),
           map.keys.contains(id) {
            map[id] = content
            defaults?.set(map, forKey: pinnedMapKey)
        }
        // Update legacy single selection if matches
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
