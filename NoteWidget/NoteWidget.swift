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
    let noteID: String?
}

struct Provider: AppIntentTimelineProvider {
    typealias Entry = NoteEntry
    typealias Intent = SelectPinnedNoteIntent

    func placeholder(in context: Context) -> NoteEntry {
        NoteEntry(date: Date(), content: "Pin a note from the app", noteID: nil)
    }

    func snapshot(for configuration: SelectPinnedNoteIntent, in context: Context) async -> NoteEntry {
        if let note = configuration.note, let content = WidgetShared.content(for: note.id) {
            return NoteEntry(date: Date(), content: content, noteID: note.id)
        }
        if let selected = WidgetShared.selectedPinnedID(),
           let content = WidgetShared.content(for: selected) {
            return NoteEntry(date: Date(), content: content, noteID: selected)
        }
        return placeholder(in: context)
    }

    func timeline(for configuration: SelectPinnedNoteIntent, in context: Context) async -> Timeline<NoteEntry> {
        let content: String
        let noteID: String?
        if let note = configuration.note, let c = WidgetShared.content(for: note.id) {
            content = c
            noteID = note.id
        } else if let selected = WidgetShared.selectedPinnedID(),
                  let stored = WidgetShared.content(for: selected) {
            content = stored
            noteID = selected
        } else {
            content = "Pin a note from the app"
            noteID = nil
        }
        let entry = NoteEntry(date: Date(), content: content, noteID: noteID)
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
        widgetBody(titleText: titleText, bodyText: bodyText)
    }

    @ViewBuilder
    private func widgetBody(titleText: String, bodyText: String?) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content(titleText: titleText, bodyText: bodyText)
                .containerBackground(widgetBackgroundColor, for: .widget)
        } else {
            content(titleText: titleText, bodyText: bodyText)
                .background(widgetBackgroundColor)
        }
    }

    private func content(titleText: String, bodyText: String?) -> some View {
        let bodyLines = formattedBodyLines(from: bodyText)
        return VStack(alignment: .leading, spacing: dynamicSpacing) {
            // Title (first line)
            Text(MarkdownRenderer.render(titleText))
                .font(titleFont)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)

            if !bodyLines.isEmpty {
                VStack(alignment: .leading, spacing: bodyLineSpacing) {
                    ForEach(Array(bodyLines.enumerated()), id: \.offset) { item in
                        bodyLineView(item.element)
                    }
                }
                .layoutPriority(1)
            }

            Spacer(minLength: 0)
        }
        .padding(dynamicPadding)
        .widgetURL(deepLinkURL(for: entry.noteID))
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private func bodyLineView(_ line: BodyLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let prefix = line.prefix {
                Text(prefix)
                    .font(prefixFont)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: prefixMinWidth, alignment: .trailing)
            }
            Text(line.content)
                .font(bodyFont)
                .foregroundStyle(.primary)
                .lineLimit(bodyLineLimit)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.9)
        }
        .padding(.leading, CGFloat(line.indentLevel) * indentStep)
    }

    private var widgetBackgroundColor: Color {
        // Matches the asset catalog color configured for widget backgrounds.
        Color("WidgetBackground")
    }

    // MARK: – Layout helpers
    private var baseHorizontalPadding: CGFloat {
        switch family {
        case .systemSmall: return 14
        case .systemMedium: return 20
        case .systemLarge: return 24
        default: return 16
        }
    }

    private var baseVerticalPadding: CGFloat {
        switch family {
        case .systemSmall: return 12
        case .systemMedium: return 18
        case .systemLarge: return 22
        default: return 14
        }
    }

    private var titleFont: Font {
        switch family {
        case .systemSmall: return .system(size: 18, weight: .regular)
        case .systemMedium: return .system(size: 20, weight: .regular)
        case .systemLarge: return .system(size: 22, weight: .regular)
        default: return .system(size: 18, weight: .regular)
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
        case .systemSmall: return 2
        case .systemMedium: return 3
        case .systemLarge: return 4
        default: return 2
        }
    }

    private var prefixFont: Font {
        switch family {
        case .systemSmall: return .system(size: 12, weight: .semibold)
        case .systemMedium: return .system(size: 13, weight: .semibold)
        case .systemLarge: return .system(size: 15, weight: .semibold)
        default: return .caption
        }
    }

    private var prefixMinWidth: CGFloat {
        switch family {
        case .systemSmall: return 16
        case .systemMedium: return 18
        case .systemLarge: return 20
        default: return 16
        }
    }

    private var indentStep: CGFloat {
        switch family {
        case .systemSmall: return 6
        case .systemMedium: return 8
        case .systemLarge: return 10
        default: return 6
        }
    }

    private var baseSpacing: CGFloat {
        switch family {
        case .systemSmall: return 10
        case .systemMedium: return 12
        case .systemLarge: return 14
        default: return 10
        }
    }

    private func split(_ text: String) -> (title: String, body: String?) {
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("Empty Note", nil) }
        if let idx = trimmed.firstIndex(of: "\n") {
            let title = String(trimmed[..<idx]).trimmingCharacters(in: CharacterSet.whitespaces)
            let body = String(trimmed[idx...].dropFirst()).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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

    private func deepLinkURL(for noteID: String?) -> URL? {
        guard let noteID else { return URL(string: "noteapp://") }
        return URL(string: "noteapp://note/\(noteID)")
    }

    // MARK: – Dynamic layout metrics
    private var dynamicPadding: EdgeInsets {
        let horizontal = adjustedPadding(base: baseHorizontalPadding, minimumFactor: 0.7)
        let vertical = adjustedPadding(base: baseVerticalPadding, minimumFactor: 0.65)
        return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    private var dynamicSpacing: CGFloat {
        let base = baseSpacing
        let reduction = base * 0.25 * contentDensity
        return max(base - reduction, base * 0.7)
    }

    private func adjustedPadding(base: CGFloat, minimumFactor: CGFloat) -> CGFloat {
        let reduction = base * 0.35 * contentDensity
        return max(base - reduction, base * minimumFactor)
    }

    private var contentDensity: CGFloat {
        let trimmed = MarkdownRenderer.plainText(from: entry.content).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }

        let characters = trimmed.count
        let lines = max(1, trimmed.split(whereSeparator: \.isNewline).count)

        let charComponent = min(max(CGFloat(characters - 60) / 240, 0), 1)
        let lineComponent = min(CGFloat(max(lines - 2, 0)) / 6, 1)

        return min(1, charComponent * 0.6 + lineComponent * 0.4)
    }
}

// MARK: – Body formatting helpers
extension NoteWidgetEntryView {
    private struct BodyLine {
        let prefix: String?
        let content: AttributedString
        let indentLevel: Int
    }

    private func formattedBodyLines(from body: String?) -> [BodyLine] {
        guard let body, !body.isEmpty else { return [] }
        let rawLines = body.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
        var result: [BodyLine] = []

        for raw in rawLines {
            let line = String(raw)
            if line.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty { continue }
            if let ordered = parseOrdered(line) {
                result.append(ordered)
            } else if let unordered = parseUnordered(line) {
                result.append(unordered)
            } else {
                result.append(BodyLine(prefix: nil,
                                       content: MarkdownRenderer.render(line.trimmingCharacters(in: CharacterSet.whitespaces)),
                                               indentLevel: 0))
            }
        }
        return result
    }

    private func parseOrdered(_ line: String) -> BodyLine? {
        guard let regex = try? NSRegularExpression(pattern: "^([\\t ]*)(\\d+)\\.\\s+(.+)$", options: []) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }
        guard let indentRange = Range(match.range(at: 1), in: line),
              let numberRange = Range(match.range(at: 2), in: line),
              let contentRange = Range(match.range(at: 3), in: line) else { return nil }

        let indentLevel = indentLevel(for: String(line[indentRange]))
        let prefixNumber = String(line[numberRange])
        let prefix = "\(prefixNumber)."
        let content = String(line[contentRange]).trimmingCharacters(in: CharacterSet.whitespaces)
        return BodyLine(prefix: prefix,
                        content: MarkdownRenderer.render(content),
                        indentLevel: indentLevel)
    }

    private func parseUnordered(_ line: String) -> BodyLine? {
        guard let regex = try? NSRegularExpression(pattern: "^([\\t ]*)([-\\*+])\\s+(.+)$", options: []) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }
        guard let indentRange = Range(match.range(at: 1), in: line),
              let contentRange = Range(match.range(at: 3), in: line) else { return nil }

        let indentLevel = indentLevel(for: String(line[indentRange]))
        let content = String(line[contentRange]).trimmingCharacters(in: CharacterSet.whitespaces)
        return BodyLine(prefix: "•",
                        content: MarkdownRenderer.render(content),
                        indentLevel: indentLevel)
    }

    private func indentLevel(for indent: String) -> Int {
        guard !indent.isEmpty else { return 0 }
        let spaces = indent.reduce(0) { partial, character -> Int in
            if character == "\t" { return partial + 4 }
            return partial + 1
        }
        return max(0, spaces / 2)
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
