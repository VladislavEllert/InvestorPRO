import Foundation

/// Builds providers from account configs, fetches them concurrently and merges
/// into a single Portfolio. Adding a broker = a new BrokerProvider, not a change here.
struct AggregationResult {
    let portfolio: Portfolio
    let discoveredMeta: [InstrumentMetaValue]
}

struct PortfolioAggregator {

    func load(accounts: [AccountSnapshot],
              metaCache: [String: InstrumentMetaValue]) async -> AggregationResult {
        let rate = await CBRClient().fetchUsdRub()
        let collector = InstrumentMetaCollector()
        let providers = buildProviders(accounts: accounts, rate: rate,
                                       metaCache: metaCache, collector: collector)

        var results: [BrokerAccountPortfolio] = []
        await withTaskGroup(of: BrokerAccountPortfolio.self) { group in
            for provider in providers {
                group.addTask { await provider.fetchPortfolio() }
            }
            for await result in group { results.append(result) }
        }

        var operations: [Operation] = []
        await withTaskGroup(of: [Operation].self) { group in
            for provider in providers {
                group.addTask { await provider.fetchOperations(monthsBack: 12) }
            }
            for await ops in group { operations.append(contentsOf: ops) }
        }

        var portfolio = merge(results, rate: rate)
        portfolio.operations = operations.sorted { $0.date > $1.date }
        let discovered = await collector.all()
        return AggregationResult(portfolio: portfolio, discoveredMeta: discovered)
    }

    private func buildProviders(accounts: [AccountSnapshot], rate: Double,
                                metaCache: [String: InstrumentMetaValue],
                                collector: InstrumentMetaCollector) -> [BrokerProvider] {
        accounts.compactMap { account in
            switch account.kind {
            case .tInvest:
                guard let token = KeychainStore.shared.read(account: account.keychainKey(for: "token")),
                      !token.isEmpty else { return nil }
                return TInvestProvider(id: account.id, label: account.label, token: token,
                                       rate: rate, metaCache: metaCache, collector: collector)
            case .bybit:
                guard let key = KeychainStore.shared.read(account: account.keychainKey(for: "apiKey")),
                      let secret = KeychainStore.shared.read(account: account.keychainKey(for: "apiSecret")),
                      !key.isEmpty, !secret.isEmpty else { return nil }
                return BybitProvider(id: account.id, label: account.label,
                                     apiKey: key, apiSecret: secret, rate: rate)
            }
        }
    }

    private func merge(_ results: [BrokerAccountPortfolio], rate: Double) -> Portfolio {
        var total = 0.0
        var merged: [String: Position] = [:]
        var errors: [String] = []

        for account in results {
            total += account.totalRub
            if let error = account.error { errors.append("\(account.label): \(error)") }
            for position in account.positions {
                if let existing = merged[position.id] {
                    merged[position.id] = Position(
                        id: existing.id,
                        ticker: existing.ticker,
                        name: existing.name,
                        assetClass: existing.assetClass,
                        quantity: existing.quantity + position.quantity,
                        currentPrice: position.currentPrice,
                        averagePrice: existing.averagePrice,
                        valueRub: existing.valueRub + position.valueRub,
                        expectedYieldRub: existing.expectedYieldRub + position.expectedYieldRub,
                        pnlPercent: existing.pnlPercent,
                        currency: existing.currency,
                        sector: existing.sector,
                        issuer: existing.issuer
                    )
                } else {
                    merged[position.id] = position
                }
            }
        }

        return Portfolio(
            totalRub: total,
            accounts: results,
            positions: Array(merged.values),
            usdRubRate: rate,
            errors: errors
        )
    }
}
