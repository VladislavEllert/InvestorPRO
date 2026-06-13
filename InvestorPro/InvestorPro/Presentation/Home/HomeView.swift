import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PortfolioStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var accounts: [AccountConfig]
    @Query(sort: \PortfolioSnapshot.date) private var snapshots: [PortfolioSnapshot]

    private var converter: CurrencyConverter { CurrencyConverter(usdRubRate: store.usdRubRate) }

    /// Most recent snapshot recorded before today — yesterday's close.
    private var previousClose: Double? {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return snapshots.last(where: { $0.date < startOfToday })?.totalRub
    }

    /// Real change since the previous day's close, EXCLUDING today's deposits/withdrawals
    /// (so adding money isn't shown as a gain). Nil until we have a prior snapshot.
    private var todayChange: Double? {
        guard let portfolio = store.portfolio, !portfolio.isEmpty,
              let prev = previousClose else { return nil }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let todayOps = portfolio.operations.filter { $0.date >= startOfToday }
        let deposits = todayOps.filter { $0.type == .input }.reduce(0) { $0 + $1.payment }
        let withdrawals = todayOps.filter { $0.type == .output }.reduce(0) { $0 + abs($1.payment) }
        return (portfolio.totalRub - prev) - (deposits - withdrawals)
    }

    private var hasData: Bool {
        if let portfolio = store.portfolio { return !portfolio.isEmpty }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if hasData {
                        currencyToggle
                        let breakdown = store.portfolio!.breakdown(.assets)
                        donutCard(breakdown)
                        statusRow
                        legend(breakdown)
                        tiles
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Портфель")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.isLoading { ProgressView() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh(accounts: accounts, context: modelContext) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(accounts.isEmpty || store.isLoading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                }
            }
            .refreshable { await store.refresh(accounts: accounts, context: modelContext) }
            .task { await autoRefreshIfNeeded() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await autoRefreshIfNeeded() } }
            }
        }
    }

    /// Refresh once on first load, then only on the configured interval — NOT on every
    /// screen change. Manual button and pull-to-refresh always force a refresh.
    private func autoRefreshIfNeeded() async {
        guard !accounts.isEmpty else { return }
        // First load — always fetch once.
        if store.portfolio == nil {
            await store.refresh(accounts: accounts, context: modelContext)
            return
        }
        // Otherwise respect the chosen interval (manual → never auto).
        guard let interval = settings.refreshInterval.seconds else { return }
        if let last = store.lastUpdated, Date().timeIntervalSince(last) < interval { return }
        await store.refresh(accounts: accounts, context: modelContext)
    }

    // MARK: Empty states (no fabricated data — show nothing until real data is pulled)

    @ViewBuilder
    private var emptyState: some View {
        if accounts.isEmpty {
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "Нет аккаунтов",
                    systemImage: "person.badge.key",
                    description: Text("Добавьте аккаунт по API-токену в настройках, чтобы увидеть свой портфель.")
                )
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Открыть настройки", systemImage: "gearshape")
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Palette.accent.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, minHeight: 420)
        } else if store.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Загружаем портфель…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 420)
        } else {
            ContentUnavailableView {
                Label("Нет данных", systemImage: "arrow.clockwise")
            } description: {
                Text(store.errorText ?? "Потяните вниз, чтобы обновить портфель.")
            }
            .frame(maxWidth: .infinity, minHeight: 420)
        }
    }

    // MARK: Content

    private var currencyToggle: some View {
        Picker("Валюта", selection: $settings.baseCurrency) {
            ForEach(Currency.allCases) { currency in
                Text(currency.shortName).tag(currency)
            }
        }
        .pickerStyle(.segmented)
    }

    private var statusRow: some View {
        HStack {
            if let change = todayChange, let prev = previousClose {
                let display = converter.display(change, in: settings.baseCurrency)
                let pct = prev > 0 ? change / prev * 100 : 0
                let color: Color = change >= 0 ? Palette.positive : Palette.negative
                let sign = change >= 0 ? "+" : "−"
                HStack(spacing: 6) {
                    Text("Сегодня").foregroundStyle(.secondary)
                    Text("\(sign)\(MoneyFormatter.string(abs(display), currency: settings.baseCurrency)) (\(MoneyFormatter.percent(abs(pct))))")
                        .foregroundStyle(color)
                }
                .font(.subheadline)
            }
            Spacer()
            if let last = store.lastUpdated {
                Text("обновлено \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func donutCard(_ breakdown: PortfolioBreakdown) -> some View {
        let total = converter.display(breakdown.total, in: settings.baseCurrency)
        let count = breakdown.items.count
        return DonutChartView(
            slices: breakdown.donutSlices(),
            centerTitle: MoneyFormatter.string(total, currency: settings.baseCurrency),
            centerSubtitle: "\(count) \(AnalyticsDimension.assets.countWord(count))"
        )
        .padding(.vertical, 8)
    }

    private func legend(_ breakdown: PortfolioBreakdown) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(breakdown.sorted.enumerated()), id: \.element.id) { index, item in
                LegendRow(
                    color: Palette.color(at: index),
                    name: item.name,
                    percent: MoneyFormatter.percent(breakdown.share(of: item))
                )
                if index < breakdown.items.count - 1 { Divider() }
            }
        }
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            NavigationTile(title: "Аналитика", systemImage: "chart.pie.fill", color: Palette.blue) {
                AnalyticsView()
            }
            NavigationTile(title: "Графики", systemImage: "chart.bar.fill", color: Palette.green) {
                ChartsView()
            }
            NavigationTile(title: "История сделок", systemImage: "list.bullet.rectangle.fill", color: Palette.purple) {
                TradesView()
            }
            NavigationTile(title: "По аккаунтам", systemImage: "person.2.fill", color: Palette.orange) {
                AccountsPortfolioView()
            }
            NavigationTile(title: "Будущие выплаты", systemImage: "calendar.badge.clock", color: Palette.positive) {
                DividendsView()
            }
        }
    }
}

private struct NavigationTile<Destination: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
