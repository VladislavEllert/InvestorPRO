import SwiftUI
import SwiftData
import Charts

struct DividendsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PortfolioStore
    @Query private var accounts: [AccountConfig]

    @State private var payouts: [Payout] = []
    @State private var loading = false
    @State private var loaded = false

    private var converter: CurrencyConverter { CurrencyConverter(usdRubRate: store.usdRubRate) }
    private var totalRub: Double { payouts.reduce(0) { $0 + $1.amount } }

    private struct MonthBucket: Identifiable { let id = UUID(); let month: Date; let amount: Double }

    private var monthly: [MonthBucket] {
        let calendar = Calendar.current
        var dict: [Date: Double] = [:]
        for payout in payouts {
            let comps = calendar.dateComponents([.year, .month], from: payout.date)
            let month = calendar.date(from: comps) ?? payout.date
            dict[month, default: 0] += payout.amount
        }
        return dict.map { MonthBucket(month: $0.key, amount: $0.value) }.sorted { $0.month < $1.month }
    }

    private var grouped: [(day: Date, items: [Payout])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: payouts) { calendar.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: <).map { ($0, dict[$0]!.sorted { $0.date < $1.date }) }
    }

    var body: some View {
        Group {
            if loading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загружаем выплаты…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else if payouts.isEmpty {
                ContentUnavailableView(
                    "Нет предстоящих выплат",
                    systemImage: "calendar",
                    description: Text(loaded
                        ? "По вашим бумагам нет объявленных дивидендов и купонов на год вперёд."
                        : "Подключите аккаунт и обновите портфель на главной.")
                )
            } else {
                content
            }
        }
        .navigationTitle("Будущие выплаты")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadIfNeeded() }
    }

    private var content: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(MoneyFormatter.string(converter.display(totalRub, in: settings.baseCurrency),
                                               currency: settings.baseCurrency))
                        .font(.system(size: 30, weight: .bold))
                    Text("за год · в среднем \(MoneyFormatter.string(converter.display(totalRub / 12, in: settings.baseCurrency), currency: settings.baseCurrency)) в месяц")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                Chart(monthly) { bucket in
                    BarMark(
                        x: .value("Месяц", bucket.month, unit: .month),
                        y: .value("Сумма", converter.display(bucket.amount, in: settings.baseCurrency))
                    )
                    .foregroundStyle(Palette.blue)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow)).font(.caption2)
                    }
                }
                .frame(height: 180)
                .padding(.vertical, 8)
            }

            ForEach(grouped, id: \.day) { section in
                Section(section.day.formatted(.dateTime.day().month(.wide).year())) {
                    ForEach(section.items) { payout in
                        HStack(spacing: 12) {
                            Image(systemName: payout.isCoupon ? "doc.text.fill" : "banknote.fill")
                                .foregroundStyle(Palette.positive)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payout.name).font(.body)
                                Text(payout.isCoupon ? "Купоны" : "Дивиденды")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text("+\(MoneyFormatter.string(converter.display(payout.amount, in: settings.baseCurrency), currency: settings.baseCurrency, fractionDigits: 2))")
                                .foregroundStyle(Palette.positive)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var tinvestToken: String? {
        guard let account = accounts.first(where: { $0.kind == .tInvest }) else { return nil }
        return KeychainStore.shared.read(account: account.keychainKey(for: "token"))
    }

    private func loadIfNeeded() async {
        guard !loaded else { return }
        guard let token = tinvestToken, !token.isEmpty,
              let positions = store.portfolio?.positions, !positions.isEmpty else {
            loaded = true
            return
        }
        loading = true
        payouts = await PayoutsService().load(positions: positions, token: token)
        loading = false
        loaded = true
    }
}
