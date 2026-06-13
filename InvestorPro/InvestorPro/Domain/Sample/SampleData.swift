import Foundation

/// TEMPORARY scaffolding data so the UI renders before the live REST clients land
/// (plan step 3). Numbers mirror the T-Bank reference screenshots. Delete once
/// PortfolioAggregator feeds real data.
enum SampleData {
    static let total: Double = 180_836

    static func breakdown(for dimension: AnalyticsDimension) -> PortfolioBreakdown {
        switch dimension {
        case .assets:
            return PortfolioBreakdown(items: [
                BreakdownItem(name: "Акции", amount: 144_759),
                BreakdownItem(name: "Облигации", amount: 26_492),
                BreakdownItem(name: "Фонды", amount: 9_385),
                BreakdownItem(name: "Валюта и Металлы", amount: 217),
            ])
        case .companies:
            return PortfolioBreakdown(items: [
                BreakdownItem(name: "Яндекс", amount: 32_008),
                BreakdownItem(name: "ОФЗ", amount: 26_492),
                BreakdownItem(name: "X5 Retail Group", amount: 26_438),
                BreakdownItem(name: "Т-Технологии", amount: 23_617),
                BreakdownItem(name: "СберБанк", amount: 22_948),
                BreakdownItem(name: "Московская биржа", amount: 20_977),
                BreakdownItem(name: "Ренессанс Страхование", amount: 18_770),
                BreakdownItem(name: "Т-Капитал", amount: 9_385),
                BreakdownItem(name: "Валюта и Металлы", amount: 217),
            ])
        case .sectors:
            return PortfolioBreakdown(items: [
                BreakdownItem(name: "Финансовый сектор", amount: 86_313),
                BreakdownItem(name: "Информационные технологии", amount: 32_008),
                BreakdownItem(name: "Государственные бумаги", amount: 26_492),
                BreakdownItem(name: "Потребительские товары", amount: 26_438),
                BreakdownItem(name: "Другое", amount: 9_385),
                BreakdownItem(name: "Валюта и Металлы", amount: 217),
            ])
        case .currencies:
            return PortfolioBreakdown(items: [
                BreakdownItem(name: "RUB", amount: 180_836),
            ])
        }
    }

    /// One long deterministic value series. The charts screen windows into it per
    /// period — the latest value is the same regardless of the selected range.
    static func fullHistory(days: Int = 730) -> [PortfolioValuePoint] {
        let calendar = Calendar.current
        let today = Date()
        var points: [PortfolioValuePoint] = []
        var value = 90_000.0
        for offset in stride(from: days, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let step = days - offset
            let noise = Double((step &* 2_654_435_761) % 10_000) / 10_000.0
            value += (noise - 0.42) * 5_200            // mild upward drift
            points.append(PortfolioValuePoint(date: date, value: max(value, 10_000)))
        }
        return points
    }

    /// Sample operations for the trade-history screen before live data lands.
    static var operations: [Operation] {
        let calendar = Calendar.current
        let now = Date()
        func daysAgo(_ i: Int) -> Date { calendar.date(byAdding: .day, value: -i, to: now) ?? now }
        return [
            Operation(id: "1", date: daysAgo(1), type: .buy, name: "Яндекс", payment: -15_000, quantity: 3, accountLabel: "Демо"),
            Operation(id: "2", date: daysAgo(3), type: .dividend, name: "СберБанк", payment: 1_200, quantity: 0, accountLabel: "Демо"),
            Operation(id: "3", date: daysAgo(5), type: .sell, name: "X5 Retail Group", payment: 8_400, quantity: 2, accountLabel: "Демо"),
            Operation(id: "4", date: daysAgo(9), type: .coupon, name: "ОФЗ 26240", payment: 549, quantity: 0, accountLabel: "Демо"),
            Operation(id: "5", date: daysAgo(12), type: .input, name: "Пополнение счёта", payment: 50_000, quantity: 0, accountLabel: "Демо"),
            Operation(id: "6", date: daysAgo(15), type: .fee, name: "Комиссия брокера", payment: -45, quantity: 0, accountLabel: "Демо"),
            Operation(id: "7", date: daysAgo(20), type: .buy, name: "Т-Технологии", payment: -22_000, quantity: 8, accountLabel: "Демо"),
        ]
    }
}

struct PortfolioValuePoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
