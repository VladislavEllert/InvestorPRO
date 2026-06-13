import SwiftUI

/// Per-instrument detail: price, average, value and PnL — like the Telegram bot's
/// account breakdown. Grouped by asset class.
struct PositionsDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PortfolioStore

    let positions: [Position]
    var title: String = "Подробнее"

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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PositionRow: View {
    let position: Position
    let converter: CurrencyConverter
    let currency: Currency

    var body: some View {
        HStack(spacing: 12) {
            InstrumentLogo(url: position.logoURL,
                           fallbackText: position.ticker.isEmpty ? position.name : position.ticker)
            VStack(alignment: .leading, spacing: 2) {
                Text(position.name).font(.body.weight(.medium)).lineLimit(1)
                Text("\(qtyString) шт · \(price(position.averagePrice))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFormatter.string(converter.display(position.valueRub, in: currency), currency: currency))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(position.valueRub >= 0 ? .primary : Palette.negative)
                if position.pnlPercent != 0 || position.expectedYieldRub != 0 {
                    Text(pnlString)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(position.expectedYieldRub >= 0 ? Palette.positive : Palette.negative)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var qtyString: String {
        position.quantity == position.quantity.rounded()
            ? String(Int(position.quantity))
            : String(format: "%g", position.quantity)
    }

    private var pnlString: String {
        let yieldSign = position.expectedYieldRub >= 0 ? "+" : "−"
        let yield = MoneyFormatter.string(abs(position.expectedYieldRub), currency: .rub)
        let pct = String(format: "%.1f%%", abs(position.pnlPercent)).replacingOccurrences(of: ".", with: ",")
        return "\(yieldSign)\(yield) · \(pct)"
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
