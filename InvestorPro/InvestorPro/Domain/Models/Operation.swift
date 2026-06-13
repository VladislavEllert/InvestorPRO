import Foundation

enum OperationType: String, Sendable {
    case buy, sell, dividend, coupon, fee, input, output, tax, other

    var title: String {
        switch self {
        case .buy: return "Покупка"
        case .sell: return "Продажа"
        case .dividend: return "Дивиденды"
        case .coupon: return "Купоны"
        case .fee: return "Комиссия"
        case .input: return "Пополнение"
        case .output: return "Вывод"
        case .tax: return "Налог"
        case .other: return "Операция"
        }
    }

    var icon: String {
        switch self {
        case .buy: return "arrow.down.circle.fill"
        case .sell: return "arrow.up.circle.fill"
        case .dividend, .coupon: return "banknote.fill"
        case .fee, .tax: return "minus.circle.fill"
        case .input: return "plus.circle.fill"
        case .output: return "arrow.up.right.circle.fill"
        case .other: return "circle.fill"
        }
    }

    static func from(_ raw: String) -> OperationType {
        let s = raw.uppercased()
        if s.contains("BUY") { return .buy }
        if s.contains("SELL") { return .sell }
        if s.contains("DIVIDEND") { return .dividend }
        if s.contains("COUPON") { return .coupon }
        if s.contains("FEE") || s.contains("COMMISSION") { return .fee }
        if s.contains("TAX") { return .tax }
        if s.contains("INPUT") { return .input }
        if s.contains("OUTPUT") { return .output }
        return .other
    }
}

struct Operation: Identifiable, Sendable {
    let id: String
    let date: Date
    let type: OperationType
    let name: String
    /// Signed payment in RUB.
    let payment: Double
    let quantity: Double
    let accountLabel: String
}

/// Cash-flow statistics for the charts screen (reference: T-Bank).
struct MovementStats {
    let profitability: Double
    let dividends: Double
    let coupons: Double
    let turnover: Double
    let deposits: Double
}
