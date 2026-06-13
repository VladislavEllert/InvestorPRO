import SwiftUI
import SwiftData
import Charts

private struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ChartsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PortfolioStore
    @Query(sort: \PortfolioSnapshot.date) private var snapshots: [PortfolioSnapshot]

    enum Period: String, CaseIterable, Identifiable {
        case month, halfYear, year, allTime
        var id: String { rawValue }
        var title: String {
            switch self {
            case .month: return "Месяц"
            case .halfYear: return "Полгода"
            case .year: return "Год"
            case .allTime: return "Всё время"
            }
        }
        /// Start of the window; nil = the whole series.
        var cutoff: Date? {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .month: return calendar.date(byAdding: .day, value: -30, to: now)
            case .halfYear: return calendar.date(byAdding: .day, value: -182, to: now)
            case .year: return calendar.date(byAdding: .day, value: -365, to: now)
            case .allTime: return nil
            }
        }
        /// Visible window before scrolling (seconds).
        var visibleSeconds: TimeInterval {
            switch self {
            case .month: return 31 * 86_400
            case .halfYear: return 75 * 86_400
            case .year: return 140 * 86_400
            case .allTime: return 420 * 86_400
            }
        }
        var bucket: Calendar.Component {
            switch self {
            case .month: return .day
            case .halfYear, .year: return .weekOfYear
            case .allTime: return .month
            }
        }
    }

    enum ChartStyle: String, CaseIterable, Identifiable {
        case columns, curve
        var id: String { rawValue }
        var systemImage: String { self == .columns ? "chart.bar.fill" : "waveform.path.ecg" }
    }

    @State private var period: Period = .halfYear
    @State private var style: ChartStyle = .curve
    @State private var scrollX: Date = .now
    @State private var selectedDate: Date?

    private var converter: CurrencyConverter { CurrencyConverter(usdRubRate: store.usdRubRate) }

    var body: some View {
        Group {
            if hasPortfolio {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        periodPicker
                        styleAndChart
                        movementStats
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            } else {
                ContentUnavailableView(
                    "Нет данных",
                    systemImage: "chart.bar",
                    description: Text("Подключите аккаунт и обновите портфель на главной.")
                )
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Графики")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Data

    private var hasPortfolio: Bool {
        if let portfolio = store.portfolio { return !portfolio.isEmpty }
        return false
    }

    /// Current portfolio total — the same for every period.
    private var currentTotalRub: Double { store.portfolio?.totalRub ?? 0 }

    /// Value series in RUB — ONLY recorded snapshots (even a single one). Never fabricated.
    private var fullSeriesRub: [PortfolioValuePoint] {
        snapshots.map { PortfolioValuePoint(date: $0.date, value: $0.totalRub) }
    }

    /// At least one snapshot → we can draw (a single column). Builds up over time.
    private var hasChartData: Bool { buckets.count >= 1 }
    /// Two+ points needed to compute a change/return.
    private var hasReturn: Bool { buckets.count >= 2 }
    /// A line needs two points; with a single point fall back to a column.
    private var effectiveStyle: ChartStyle { buckets.count < 2 ? .columns : style }
    /// Only enable horizontal scrolling when there are enough points to overflow;
    /// otherwise let the chart auto-fit so the axis dates sit under the bars.
    private var isScrollable: Bool { buckets.count > 10 }
    /// Narrow fixed bar(s) when there are only a few points, so a single snapshot
    /// doesn't stretch into a full-width block.
    private var barWidth: MarkDimension { buckets.count <= 3 ? .fixed(40) : .automatic }

    private var windowedRub: [PortfolioValuePoint] {
        guard let cutoff = period.cutoff else { return fullSeriesRub }
        let filtered = fullSeriesRub.filter { $0.date >= cutoff }
        return filtered.count >= 2 ? filtered : fullSeriesRub
    }

    private var windowStartRub: Double { windowedRub.first?.value ?? currentTotalRub }

    // MARK: Period profitability (one value, shared by header + stats)

    private var operations: [Operation] { store.portfolio?.operations ?? [] }

    private var windowOps: [Operation] {
        let cutoff = period.cutoff ?? .distantPast
        return operations.filter { $0.date >= cutoff }
    }

    private var windowDeposits: Double {
        windowOps.filter { $0.type == .input }.reduce(0) { $0 + $1.payment }
    }

    private var windowWithdrawals: Double {
        windowOps.filter { $0.type == .output }.reduce(0) { $0 + abs($1.payment) }
    }

    /// Доходность за период = изменение стоимости − чистые пополнения.
    /// Включает рост цены, дивиденды и купоны (они увеличивают стоимость и не являются пополнениями).
    private var profitabilityRub: Double {
        (currentTotalRub - windowStartRub) - (windowDeposits - windowWithdrawals)
    }

    private var buckets: [ChartPoint] {
        let converted = windowedRub.map {
            ChartPoint(date: $0.date, value: converter.display($0.value, in: settings.baseCurrency))
        }
        guard period.bucket != .day else { return converted }

        let calendar = Calendar.current
        let components: Set<Calendar.Component> = period.bucket == .month
            ? [.year, .month]
            : [.yearForWeekOfYear, .weekOfYear]

        var byBucket: [Date: ChartPoint] = [:]
        for point in converted {
            let comps = calendar.dateComponents(components, from: point.date)
            let bucketStart = calendar.date(from: comps) ?? point.date
            if let existing = byBucket[bucketStart], point.date < existing.date { continue }
            byBucket[bucketStart] = ChartPoint(date: bucketStart, value: point.value)
        }
        return byBucket.values.sorted { $0.date < $1.date }
    }

    private var selectedBucket: ChartPoint? {
        guard let date = selectedDate else { return nil }
        return buckets.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    // MARK: Header (constant total + period change)

    private var header: some View {
        let current = converter.display(currentTotalRub, in: settings.baseCurrency)
        let profit = converter.display(profitabilityRub, in: settings.baseCurrency)
        let pct = windowStartRub > 0 ? profitabilityRub / windowStartRub * 100 : 0
        let color: Color = profitabilityRub >= 0 ? Palette.positive : Palette.negative
        let sign = profitabilityRub >= 0 ? "+" : "−"
        let headline = selectedBucket?.value ?? current

        return VStack(alignment: .leading, spacing: 4) {
            Text("Стоимость портфеля")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(MoneyFormatter.string(headline, currency: settings.baseCurrency))
                .font(.system(size: 32, weight: .bold))
                .contentTransition(.numericText())
            HStack(spacing: 6) {
                if let sel = selectedBucket {
                    Text(sel.date.formatted(.dateTime.day().month().year()))
                        .foregroundStyle(.secondary)
                } else if hasReturn {
                    Text("\(sign)\(MoneyFormatter.string(abs(profit), currency: settings.baseCurrency))")
                        .foregroundStyle(color)
                    Text("(\(MoneyFormatter.percent(abs(pct))))")
                        .foregroundStyle(color)
                    Text("· за \(period.title.lowercased())").foregroundStyle(.secondary)
                } else {
                    Text("История копится с каждым обновлением")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var periodPicker: some View {
        Picker("Период", selection: $period) {
            ForEach(Period.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var styleAndChart: some View {
        if hasChartData {
            VStack(spacing: 8) {
                if hasReturn {
                    HStack {
                        Spacer()
                        Picker("Вид", selection: $style) {
                            ForEach(ChartStyle.allCases) { Image(systemName: $0.systemImage).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 96)
                    }
                }
                chartCard
            }
        } else {
            emptyChart
        }
    }

    private var emptyChart: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("Недостаточно истории")
                .font(.headline)
            Text("График стоимости строится по реальным снимкам портфеля. Они копятся при каждом обновлении — вернись позже.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Chart

    private var chartCard: some View {
        let maxValue = buckets.map(\.value).max() ?? 1
        let yDomain = 0...(maxValue * 1.15)

        return Chart {
            ForEach(buckets) { point in
                switch effectiveStyle {
                case .columns:
                    BarMark(
                        x: .value("Дата", point.date, unit: period.bucket),
                        y: .value("Стоимость", point.value),
                        width: barWidth
                    )
                    .foregroundStyle(
                        .linearGradient(colors: [Palette.blue, Palette.blue.opacity(0.45)],
                                        startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(2)
                case .curve:
                    AreaMark(x: .value("Дата", point.date), y: .value("Стоимость", point.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            .linearGradient(colors: [Palette.blue.opacity(0.35), Palette.blue.opacity(0.02)],
                                            startPoint: .top, endPoint: .bottom)
                        )
                    LineMark(x: .value("Дата", point.date), y: .value("Стоимость", point.value))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(Palette.blue)
                }
            }

            if let sel = selectedBucket {
                RuleMark(x: .value("Дата", sel.date))
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                PointMark(x: .value("Дата", sel.date), y: .value("Стоимость", sel.value))
                    .foregroundStyle(Palette.blue)
                    .symbolSize(80)
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(MoneyFormatter.compact(v)).font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: buckets.count == 1 ? 1 : 5)) { _ in
                AxisGridLine()
                AxisValueLabel(
                    format: period == .month
                        ? .dateTime.day().month(.abbreviated)
                        : .dateTime.month(.abbreviated).year(.twoDigits)
                )
                .font(.caption2)
            }
        }
        .chartXSelection(value: $selectedDate)
        .applyIf(isScrollable) {
            $0.chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: period.visibleSeconds)
                .chartScrollPosition(x: $scrollX)
        }
        .frame(height: 260)
        .padding(.init(top: 12, leading: 8, bottom: 8, trailing: 12))
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onChange(of: period, initial: true) { _, _ in resetScroll() }
        .onChange(of: settings.baseCurrency) { _, _ in resetScroll() }
    }

    private func resetScroll() {
        selectedDate = nil
        if let last = buckets.last?.date {
            scrollX = last.addingTimeInterval(-period.visibleSeconds)
        }
    }

    // MARK: Movement stats (per selected period)

    private var stats: MovementStats {
        func sum(_ predicate: (Operation) -> Bool) -> Double {
            windowOps.filter(predicate).reduce(0) { $0 + $1.payment }
        }
        let dividends = sum { $0.type == .dividend }
        let coupons = sum { $0.type == .coupon }
        let turnover = windowOps.filter { $0.type == .buy || $0.type == .sell }
            .reduce(0) { $0 + abs($1.payment) }
        // Доходность — та же величина, что и под суммой в шапке.
        return MovementStats(profitability: profitabilityRub, dividends: dividends,
                             coupons: coupons, turnover: turnover,
                             deposits: windowDeposits, withdrawals: windowWithdrawals)
    }

    private var movementStats: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Статистика движения средств").font(.title3.bold())
                Spacer()
                Text("за \(period.title.lowercased())").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            if hasReturn {
                statRow("Доходность", value: stats.profitability, signed: true)
            } else {
                dashRow("Доходность")
            }
            Divider()
            statRow("Дивиденды", value: stats.dividends)
            Divider()
            statRow("Купоны", value: stats.coupons)
            Divider()
            statRow("Оборот", value: stats.turnover)
            Divider()
            statRow("Пополнения", value: stats.deposits)
            Divider()
            statRow("Вывод", value: stats.withdrawals)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dashRow(_ title: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text("—").foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private func statRow(_ title: String, value: Double, signed: Bool = false) -> some View {
        let display = converter.display(value, in: settings.baseCurrency)
        let color: Color = signed ? (value >= 0 ? Palette.positive : Palette.negative) : .primary
        let text = MoneyFormatter.string(display, currency: settings.baseCurrency, fractionDigits: 2)
        return HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(signed && value >= 0 ? "+\(text)" : text).foregroundStyle(color)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        ChartsView()
            .environmentObject(AppSettings())
            .environmentObject(PortfolioStore())
    }
    .modelContainer(for: PortfolioSnapshot.self, inMemory: true)
}

private extension View {
    @ViewBuilder
    func applyIf<T: View>(_ condition: Bool, _ transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
