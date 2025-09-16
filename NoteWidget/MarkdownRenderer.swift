import SwiftUI
import Foundation

enum MarkdownRenderer {
    static func render(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: preprocessUnderline(in: text))) ?? AttributedString(text)
    }

    static func plainText(from text: String) -> String {
        String(render(text).characters)
    }

    private static func preprocessUnderline(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "__([^_]+?)__", options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "<u>$1</u>")
    }
}
