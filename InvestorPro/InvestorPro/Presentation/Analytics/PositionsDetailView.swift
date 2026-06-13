import SwiftUI

/// Per-instrument detail: price, average, value and PnL — like the Telegram bot's
/// account breakdown. Grouped by asset class.
struct PositionsDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PortfolioStore

    let positions: [Position]

    private var converter: CurrencyConverter { CurrencyConverter(usdRubRate: store.usdRubRate) }

    private var grouped: [(assetClass: AssetClass, total: Double, items: [Position])] {
        let dict = Dictionary(grouping: positions) { $0.assetClass }
        return dict.map { (key, value) in
            (key, value.reduce(0) { $0 + $1.valueRub }, value.sorted { $0.valueRub > $1.valueRub })
        }
        .sorted { $0.total > $1.total }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.assetClass) { section in
                Section {
                    ForEach(section.items) { position in
                        PositionRow(position: position, converter: converter,
                                    currency: settings.baseCurrency)
                    }
                } header: {
                    HStack {
                        Text(section.assetClass.title)
                        Spacer()
                        Text(MoneyFormatter.string(converter.display(section.total, in: settings.baseCurrency),
                                                   currency: settings.baseCurrency))
                            .foregroundStyle(section.total >= 0 ? .secondary : Palette.negative)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Подробнее")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PositionRow: View {
    let position: Position
    let converter: CurrencyConverter
    let currency: Currency

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(position.name).font(.body.weight(.medium))
                Spacer(minLength: 8)
                Text(MoneyFormatter.string(converter.display(position.valueRub, in: currency), currency: currency))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(position.valueRub >= 0 ? .primary : Palette.negative)
            }
            HStack {
                Text("\(position.ticker) · \(qtyString) шт.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if position.pnlPercent != 0 || position.expectedYieldRub != 0 {
                    Text(pnlString)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(position.expectedYieldRub >= 0 ? Palette.positive : Palette.negative)
                }
            }
            Text("Цена \(price(position.currentPrice)) · средняя \(price(position.averagePrice))")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var qtyString: String {
        position.quantity == position.quantity.rounded()
            ? String(Int(position.quantity))
            : String(format: "%g", position.quantity)
    }

    private var pnlString: String {
        let pctSign = position.pnlPercent >= 0 ? "+" : "−"
        let pct = String(format: "%.1f%%", abs(position.pnlPercent)).replacingOccurrences(of: ".", with: ",")
        let yieldSign = position.expectedYieldRub >= 0 ? "+" : "−"
        let yield = MoneyFormatter.string(abs(position.expectedYieldRub), currency: .rub)
        return "\(pctSign)\(pct)  \(yieldSign)\(yield)"
    }

    private func price(_ value: Double) -> String {
        let symbol = position.currency.lowercased() == "rub" ? "₽" : "$"
        return "\(String(format: "%.2f", value).replacingOccurrences(of: ".", with: ","))\u{00A0}\(symbol)"
    }
}

#Preview {
    NavigationStack { PositionsDetailView(positions: []) }
        .environmentObject(AppSettings())
        .environmentObject(PortfolioStore())
}
