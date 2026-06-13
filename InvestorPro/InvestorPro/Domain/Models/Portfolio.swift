import Foundation

/// The aggregated portfolio across all configured accounts.
struct Portfolio {
    var totalRub: Double
    var accounts: [BrokerAccountPortfolio]
    /// Positions merged by instrument id across accounts.
    var positions: [Position]
    var usdRubRate: Double
    var errors: [String]
    var operations: [Operation] = []

    var isEmpty: Bool { positions.isEmpty && totalRub == 0 }

    /// Cash-flow stats from operations + unrealised PnL (reference: T-Bank).
    var movementStats: MovementStats {
        func sum(_ predicate: (Operation) -> Bool) -> Double {
            operations.filter(predicate).reduce(0) { $0 + $1.payment }
        }
        let dividends = sum { $0.type == .dividend }
        let coupons = sum { $0.type == .coupon }
        let turnover = operations
            .filter { $0.type == .buy || $0.type == .sell }
            .reduce(0) { $0 + abs($1.payment) }
        let deposits = sum { $0.type == .input }
        let profitability = positions.reduce(0) { $0 + $1.expectedYieldRub }
        return MovementStats(profitability: profitability, dividends: dividends,
                             coupons: coupons, turnover: turnover, deposits: deposits)
    }

    /// Build a breakdown along one analytics dimension.
    func breakdown(_ dimension: AnalyticsDimension) -> PortfolioBreakdown {
        let groups: [String: Double]
        switch dimension {
        case .assets:
            groups = group { $0.assetClass.title }
        case .companies:
            groups = group { $0.issuer ?? $0.name }
        case .sectors:
            groups = group { SectorNames.localized($0.sector, assetClass: $0.assetClass) }
        case .currencies:
            groups = group { $0.currency.uppercased() }
        }
        let items = groups.map { BreakdownItem(name: $0.key, amount: $0.value) }
        return PortfolioBreakdown(items: items)
    }

    private func group(by key: (Position) -> String) -> [String: Double] {
        var result: [String: Double] = [:]
        for position in positions where position.valueRub > 0 {
            result[key(position), default: 0] += position.valueRub
        }
        return result
    }
}

/// Maps T-Invest sector codes to Russian labels (reference: T-Bank analytics).
enum SectorNames {
    static func localized(_ sector: String?, assetClass: AssetClass) -> String {
        if assetClass == .crypto { return "Криптовалюта" }
        if assetClass == .bond { return "Государственные бумаги" }
        if assetClass == .currency { return "Валюта и Металлы" }
        switch (sector ?? "").lowercased() {
        case "financial", "banks": return "Финансовый сектор"
        case "it", "telecom", "technology": return "Информационные технологии"
        case "consumer": return "Потребительские товары"
        case "energy", "electrocars": return "Энергетика"
        case "materials": return "Сырьё и материалы"
        case "industrials": return "Промышленность"
        case "health_care": return "Здравоохранение"
        case "utilities": return "Коммунальные услуги"
        case "real_estate": return "Недвижимость"
        case "government": return "Государственные бумаги"
        case "": return "Другое"
        default: return "Другое"
        }
    }
}
