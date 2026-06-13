import Foundation

enum Currency: String, CaseIterable, Identifiable, Codable {
    case rub
    case usd

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .rub: return "₽"
        case .usd: return "$"
        }
    }

    var shortName: String {
        switch self {
        case .rub: return "RUB"
        case .usd: return "USD"
        }
    }
}
