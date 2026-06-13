import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PortfolioStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var accounts: [AccountConfig]

    private var converter: CurrencyConverter { CurrencyConverter(usdRubRate: store.usdRubRate) }

    /// Live assets breakdown when available, otherwise sample data.
    private var breakdown: PortfolioBreakdown {
        if let portfolio = store.portfolio, !portfolio.isEmpty {
            return portfolio.breakdown(.assets)
        }
        return SampleData.breakdown(for: .assets)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    currencyToggle
                    if !store.hasData { demoBanner }
                    donutCard
                    legend
                    tiles
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Портфель")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.isLoading { ProgressView() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh(accounts: accounts, context: modelContext)}
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
            .task { await store.refresh(accounts: accounts, context: modelContext) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await autoRefreshIfNeeded() } }
            }
        }
    }

    /// Auto-refresh on foreground when the configured interval has elapsed.
    private func autoRefreshIfNeeded() async {
        guard let interval = settings.refreshInterval.seconds, !accounts.isEmpty else { return }
        if let last = store.lastUpdated, Date().timeIntervalSince(last) < interval { return }
        await store.refresh(accounts: accounts, context: modelContext)
    }

    private var currencyToggle: some View {
        Picker("Валюта", selection: $settings.baseCurrency) {
            ForEach(Currency.allCases) { currency in
                Text(currency.shortName).tag(currency)
            }
        }
        .pickerStyle(.segmented)
    }

    private var demoBanner: some View {
        Label("Демо-данные. Добавьте аккаунт в Настройках, чтобы видеть свой портфель.",
              systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var donutCard: some View {
        let total = converter.display(breakdown.total, in: settings.baseCurrency)
        let count = breakdown.items.count
        return DonutChartView(
            slices: breakdown.donutSlices(),
            centerTitle: MoneyFormatter.string(total, currency: settings.baseCurrency),
            centerSubtitle: "\(count) \(AnalyticsDimension.assets.countWord(count))"
        )
        .padding(.vertical, 8)
    }

    private var legend: some View {
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

#Preview {
    HomeView()
        .environmentObject(AppSettings())
        .environmentObject(PortfolioStore())
        .modelContainer(for: AccountConfig.self, inMemory: true)
}
