import SwiftUI
import Charts

/// Dark, print-ready report rendered to PDF. Mirrors what's in the app.
struct ReportView: View {
    let portfolio: Portfolio
    let snapshots: [PortfolioSnapshot]
    let currency: Currency
    let converter: CurrencyConverter

    private let cardColor = Color(white: 0.12)
    private let pageColor = Color(white: 0.05)

    private func money(_ rub: Double, fraction: Int = 0) -> String {
        MoneyFormatter.string(converter.display(rub, in: currency), currency: currency, fractionDigits: fraction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            assetsCard
            if !snapshots.isEmpty { valueChartCard }
            accountsCard
            if !portfolio.operations.isEmpty { operationsCard }
            footer
        }
        .padding(24)
        .frame(width: 595, alignment: .topLeading)
        .background(pageColor)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("InvestorPro").font(.system(size: 26, weight: .heavy)).foregroundStyle(.white)
                Spacer()
                Text(Date().formatted(date: .long, time: .shortened))
                    .font(.footnote).foregroundStyle(.gray)
            }
            Text("Отчёт по портфелю").font(.subheadline).foregroundStyle(.gray)
            Text(money(portfolio.totalRub)).font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
        }
    }

    // MARK: Assets donut + legend

    private var assetsCard: some View {
        let breakdown = portfolio.breakdown(.assets)
        return card("Активы") {
            HStack(alignment: .center, spacing: 12) {
                DonutChartView(
                    slices: breakdown.donutSlices(),
                    centerTitle: "\(MoneyFormatter.compact(converter.display(portfolio.totalRub, in: currency)))\u{00A0}\(currency.symbol)",
                    centerSubtitle: "\(breakdown.items.count) \(AnalyticsDimension.assets.countWord(breakdown.items.count))"
                )
                .frame(width: 200)

                VStack(spacing: 0) {
                    ForEach(Array(breakdown.sorted.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 8) {
                            Circle().fill(Palette.color(at: index)).frame(width: 9, height: 9)
                            Text(item.name).font(.caption).foregroundStyle(.white).lineLimit(1)
                            Spacer(minLength: 6)
                            Text(MoneyFormatter.percent(breakdown.share(of: item)))
                                .font(.caption)
                                .foregroundStyle(breakdown.share(of: item) < 0 ? Palette.negative : .white)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: Value chart

    private var valueChartCard: some View {
        card("Стоимость портфеля") {
            Chart(snapshots) { snapshot in
                AreaMark(x: .value("Дата", snapshot.date),
                         y: .value("Стоимость", converter.display(snapshot.totalRub, in: currency)))
                    .foregroundStyle(.linearGradient(colors: [Palette.blue.opacity(0.4), .clear],
                                                     startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Дата", snapshot.date),
                         y: .value("Стоимость", converter.display(snapshot.totalRub, in: currency)))
                    .foregroundStyle(Palette.blue)
            }
            .frame(height: 160)
        }
    }

    // MARK: Per-account

    private var accountsCard: some View {
        card("По аккаунтам") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(portfolio.accounts) { account in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(account.label).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Spacer()
                            Text(money(account.totalRub)).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        }
                        ForEach(account.positions.sorted(by: { $0.valueRub > $1.valueRub })) { position in
                            HStack {
                                Text(position.name).font(.caption).foregroundStyle(.gray).lineLimit(1)
                                Spacer(minLength: 8)
                                Text(money(position.valueRub)).font(.caption).foregroundStyle(.white)
                                Text(String(format: " %+.1f%%", position.pnlPercent))
                                    .font(.caption2)
                                    .foregroundStyle(position.expectedYieldRub >= 0 ? Palette.positive : Palette.negative)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Operations

    private var operationsCard: some View {
        card("Последние операции") {
            VStack(spacing: 8) {
                ForEach(portfolio.operations.prefix(25)) { op in
                    HStack {
                        Text(op.date.formatted(date: .numeric, time: .omitted))
                            .font(.caption2).foregroundStyle(.gray).frame(width: 70, alignment: .leading)
                        Text(op.type.title).font(.caption2).foregroundStyle(.gray).frame(width: 80, alignment: .leading)
                        Text(op.name).font(.caption).foregroundStyle(.white).lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(op.payment >= 0 ? "+" : "−")\(MoneyFormatter.string(abs(op.payment), currency: .rub, fractionDigits: 2))")
                            .font(.caption2)
                            .foregroundStyle(op.payment >= 0 ? Palette.positive : .white)
                    }
                }
            }
        }
    }

    private var footer: some View {
        Text("Сформировано приложением InvestorPro · данные T-Invest / Bybit")
            .font(.caption2).foregroundStyle(.gray)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    // MARK: Card container

    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(.white)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
