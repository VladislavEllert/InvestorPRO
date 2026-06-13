import SwiftUI
import SwiftData

/// Observable holder of the latest aggregated portfolio. UI observes this;
/// when no accounts are configured, screens fall back to sample data.
@MainActor
final class PortfolioStore: ObservableObject {
    @Published var portfolio: Portfolio?
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var errorText: String?

    private let aggregator = PortfolioAggregator()

    var hasData: Bool { (portfolio?.isEmpty == false) }

    /// Effective USD/RUB rate (live when loaded, fallback otherwise).
    var usdRubRate: Double { portfolio?.usdRubRate ?? CBRClient.fallbackRate }

    func refresh(accounts: [AccountConfig], context: ModelContext) async {
        let snapshots = accounts.map(\.snapshot)
        guard !snapshots.isEmpty else {
            portfolio = nil
            errorText = nil
            return
        }
        isLoading = true

        // Cache-first instrument metadata: read existing, fetch only misses, persist new.
        let existing = (try? context.fetch(FetchDescriptor<InstrumentMeta>())) ?? []
        let cache = Dictionary(existing.map { ($0.figi, $0.value) }, uniquingKeysWith: { first, _ in first })

        let result = await aggregator.load(accounts: snapshots, metaCache: cache)
        portfolio = result.portfolio

        let existingFigis = Set(existing.map(\.figi))
        var inserted = false
        for meta in result.discoveredMeta where !existingFigis.contains(meta.figi) {
            context.insert(InstrumentMeta(value: meta))
            inserted = true
        }
        if inserted { try? context.save() }

        // Record a portfolio snapshot for the value-over-time chart (one per day).
        if !result.portfolio.isEmpty {
            recordSnapshot(total: result.portfolio.totalRub, context: context)
        }

        errorText = result.portfolio.errors.isEmpty ? nil : result.portfolio.errors.joined(separator: "\n")
        lastUpdated = Date()
        isLoading = false
    }

    private func recordSnapshot(total: Double, context: ModelContext) {
        let descriptor = FetchDescriptor<PortfolioSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let snapshots = (try? context.fetch(descriptor)) ?? []
        if let last = snapshots.first, Calendar.current.isDateInToday(last.date) {
            last.totalRub = total
            last.date = Date()
        } else {
            context.insert(PortfolioSnapshot(date: Date(), totalRub: total))
        }
        try? context.save()
    }
}
