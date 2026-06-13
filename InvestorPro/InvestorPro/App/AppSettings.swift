import SwiftUI

/// User-facing app preferences, persisted in UserDefaults.
/// Tokens are NOT stored here — they live in the Keychain.
final class AppSettings: ObservableObject {

    enum RefreshInterval: String, CaseIterable, Identifiable, Codable {
        case off
        case hourly
        case daily

        var id: String { rawValue }
        var title: String {
            switch self {
            case .off: return "Только вручную"
            case .hourly: return "Каждый час"
            case .daily: return "Раз в день"
            }
        }
        /// Auto-refresh interval in seconds; nil means manual only.
        var seconds: TimeInterval? {
            switch self {
            case .off: return nil
            case .hourly: return 3_600
            case .daily: return 86_400
            }
        }
    }

    @Published var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    @Published var baseCurrency: Currency {
        didSet { defaults.set(baseCurrency.rawValue, forKey: Keys.currency) }
    }

    @Published var refreshInterval: RefreshInterval {
        didSet { defaults.set(refreshInterval.rawValue, forKey: Keys.refresh) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        self.baseCurrency = Currency(rawValue: defaults.string(forKey: Keys.currency) ?? "") ?? .rub
        self.refreshInterval = RefreshInterval(rawValue: defaults.string(forKey: Keys.refresh) ?? "") ?? .off
    }

    private enum Keys {
        static let theme = "settings.theme"
        static let currency = "settings.baseCurrency"
        static let refresh = "settings.refreshInterval"
    }
}
