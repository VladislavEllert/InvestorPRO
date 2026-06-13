import Foundation

/// Asset class buckets, matching the Python bot's TYPE_CLASS plus crypto.
enum AssetClass: String, Codable, CaseIterable, Identifiable {
    case share
    case bond
    case etf
    case currency
    case futures
    case crypto
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .share: return "Акции"
        case .bond: return "Облигации"
        case .etf: return "Фонды"
        case .currency: return "Валюта и Металлы"
        case .futures: return "Фьючерсы"
        case .crypto: return "Крипта"
        case .other: return "Другое"
        }
    }

    /// Map a T-Invest instrument_type string to an asset class.
    static func fromTInvest(_ raw: String) -> AssetClass {
        switch raw.lowercased() {
        case "share": return .share
        case "bond": return .bond
        case "etf": return .etf
        case "currency": return .currency
        case "futures": return .futures
        default: return .other
        }
    }
}
