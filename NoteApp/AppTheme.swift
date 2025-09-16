import SwiftUI

enum AppTheme: String {
    case light
    case dark

    static let storageKey = "app.theme.preference"

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }

    func toggled() -> AppTheme {
        self == .light ? .dark : .light
    }
}

extension AppTheme {
    static func load(from value: String) -> AppTheme {
        AppTheme(rawValue: value) ?? .light
    }
}
