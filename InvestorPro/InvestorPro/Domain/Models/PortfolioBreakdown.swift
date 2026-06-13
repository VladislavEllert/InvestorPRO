import Foundation

/// One slice of a portfolio breakdown (e.g. one asset class, company, sector or currency).
struct BreakdownItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    /// Value in the portfolio base currency (RUB).
    let amount: Double

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: BreakdownItem, rhs: BreakdownItem) -> Bool { lhs.id == rhs.id }
}

/// A full breakdown of the portfolio along one dimension, sorted by amount desc.
struct PortfolioBreakdown {
    let items: [BreakdownItem]

    var total: Double { items.reduce(0) { $0 + $1.amount } }

    /// Percentage share of one item, 0...100.
    func share(of item: BreakdownItem) -> Double {
        total > 0 ? item.amount / total * 100 : 0
    }

    var sorted: [BreakdownItem] {
        items.sorted { $0.amount > $1.amount }
    }
}

/// The four analytics dimensions shown in the segmented control (reference: T-Bank).
enum AnalyticsDimension: String, CaseIterable, Identifiable {
    case assets
    case companies
    case sectors
    case currencies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assets: return "Активы"
        case .companies: return "Компании"
        case .sectors: return "Отрасли"
        case .currencies: return "Валюта"
        }
    }

    /// Russian count word for the donut centre, by item count.
    func countWord(_ n: Int) -> String {
        switch self {
        case .assets: return PluralRu.pick(n, "актив", "актива", "активов")
        case .companies: return PluralRu.pick(n, "компания", "компании", "компаний")
        case .sectors: return PluralRu.pick(n, "отрасль", "отрасли", "отраслей")
        case .currencies: return PluralRu.pick(n, "валюта", "валюты", "валют")
        }
    }
}

enum PluralRu {
    /// Russian plural selection: one / few / many.
    static func pick(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return few }
        return many
    }
}
