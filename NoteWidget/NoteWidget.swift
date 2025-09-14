//
//  NoteWidget.swift
//  NoteWidget
//
//  Created by Kevin Varghese on 2025-09-14.
//

import WidgetKit
import SwiftUI

struct NoteEntry: TimelineEntry {
    let date: Date
    let content: String
}

struct Provider: AppIntentTimelineProvider {
    typealias Entry = NoteEntry
    typealias Intent = SelectPinnedNoteIntent

    func placeholder(in context: Context) -> NoteEntry {
        NoteEntry(date: Date(), content: "Pin a note from the app")
    }

    func snapshot(for configuration: SelectPinnedNoteIntent, in context: Context) async -> NoteEntry {
        if let note = configuration.note, let content = WidgetShared.content(for: note.id) {
            return NoteEntry(date: Date(), content: content)
        }
        if let data = WidgetShared.read() { // legacy fallback
            return NoteEntry(date: Date(), content: data.content)
        }
        return placeholder(in: context)
    }

    func timeline(for configuration: SelectPinnedNoteIntent, in context: Context) async -> Timeline<NoteEntry> {
        let content: String
        if let note = configuration.note, let c = WidgetShared.content(for: note.id) {
            content = c
        } else if let data = WidgetShared.read() {
            content = data.content
        } else {
            content = "Pin a note from the app"
        }
        let entry = NoteEntry(date: Date(), content: content)
        return Timeline(entries: [entry], policy: .never)
    }
}

struct NoteWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family
    // Choose how to normalize letter casing for a consistent "thoughts" style
    private let caseStyle: CaseStyle = .lowercase

    var body: some View {
        let parts = split(entry.content)
        let titleText = normalize(parts.title)
        let bodyText  = parts.body.map(normalize)
        VStack(alignment: .leading, spacing: vSpacing) {
            // Accent rule
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: accentWidth, height: 3)

            // Title (first line)
            Text(titleText)
                .font(titleFont)
                .foregroundStyle(.primary)
                // Show the first line fully (wrap as needed),
                // and give it priority over the body text.
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)

            // Body (rest)
            if let body = bodyText, !body.isEmpty {
                Text(body)
                    .font(bodyFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(bodyLineLimit)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(bodyLineSpacing)
                    .minimumScaleFactor(0.9)
                    .layoutPriority(0)
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: vPadding, leading: hPadding, bottom: vPadding, trailing: hPadding))
    }

    // MARK: – Layout helpers
    private var hPadding: CGFloat {
        switch family {
        case .systemSmall: return 6
        case .systemMedium: return 10
        case .systemLarge: return 12
        default: return 8
        }
    }

    private var vPadding: CGFloat {
        switch family {
        case .systemSmall: return 6
        case .systemMedium: return 12
        case .systemLarge: return 14
        default: return 10
        }
    }

    private var titleFont: Font {
        switch family {
        case .systemSmall: return .system(size: 18, weight: .semibold)
        case .systemMedium: return .system(size: 20, weight: .semibold)
        case .systemLarge: return .system(size: 22, weight: .semibold)
        default: return .headline
        }
    }

    private var bodyFont: Font {
        switch family {
        case .systemSmall: return .system(size: 14)
        case .systemMedium: return .system(size: 15)
        case .systemLarge: return .system(size: 17)
        default: return .body
        }
    }

    private var bodyLineLimit: Int {
        switch family {
        case .systemSmall: return 4
        case .systemMedium: return 6
        case .systemLarge: return 10
        default: return 6
        }
    }

    private var bodyLineSpacing: CGFloat {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 1.5
        case .systemLarge: return 2
        default: return 1.5
        }
    }

    private var vSpacing: CGFloat {
        switch family {
        case .systemSmall: return 6
        case .systemMedium: return 8
        case .systemLarge: return 10
        default: return 8
        }
    }

    private var accentWidth: CGFloat {
        switch family {
        case .systemSmall: return 26
        case .systemMedium: return 34
        case .systemLarge: return 42
        default: return 30
        }
    }

    private func split(_ text: String) -> (title: String, body: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("Empty Note", nil) }
        if let idx = trimmed.firstIndex(of: "\n") {
            let title = String(trimmed[..<idx]).trimmingCharacters(in: .whitespaces)
            let body = String(trimmed[idx...].dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            return (title.isEmpty ? "Untitled" : title, body)
        } else {
            return (trimmed, nil)
        }
    }

    // MARK: – Case normalization
    private enum CaseStyle { case lowercase, uppercase, none }
    private func normalize(_ text: String) -> String {
        switch caseStyle {
        case .lowercase: return text.lowercased()
        case .uppercase: return text.uppercased()
        case .none: return text
        }
    }
}

struct NoteWidget: Widget {
    let kind: String = "NoteWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectPinnedNoteIntent.self, provider: Provider()) { entry in
            NoteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Note")
        .description("Displays your selected note.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
