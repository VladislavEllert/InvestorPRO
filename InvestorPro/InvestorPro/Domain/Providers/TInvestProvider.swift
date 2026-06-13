import Foundation

/// BrokerProvider for T-Invest. One configured account → may hold several broker
/// sub-accounts (счета); they are summed, mirroring the Python bot.
struct TInvestProvider: BrokerProvider {
    let kind: BrokerKind = .tInvest
    let id: UUID
    let label: String
    let token: String
    /// USD/RUB rate for converting USD-priced positions.
    let rate: Double
    /// Pre-loaded instrument metadata (figi→meta) to skip network calls.
    let metaCache: [String: InstrumentMetaValue]
    /// Collects newly fetched metadata for persistence after the refresh.
    let collector: InstrumentMetaCollector

    func fetchPortfolio() async -> BrokerAccountPortfolio {
        var result = BrokerAccountPortfolio(id: id, label: label, kind: .tInvest,
                                            totalRub: 0, positions: [], error: nil)
        do {
            let client = TInvestClient(token: token)
            let accounts = try await client.getAccounts()
            var total = 0.0
            var positions: [Position] = []

            for account in accounts {
                let portfolio = try await client.getPortfolio(accountId: account.id)
                total += portfolio.totalAmountPortfolio?.value ?? 0
                for raw in portfolio.positions ?? [] {
                    if let position = await mapPosition(raw, client: client) {
                        positions.append(position)
                    }
                }
            }
            result.totalRub = total
            result.positions = positions
        } catch {
            result.error = error.localizedDescription
        }
        return result
    }

    func fetchOperations(monthsBack: Int) async -> [Operation] {
        let client = TInvestClient(token: token)
        let to = Date()
        let from = Calendar.current.date(byAdding: .month, value: -monthsBack, to: to) ?? to
        let iso = ISO8601DateFormatter()
        var operations: [Operation] = []
        guard let accounts = try? await client.getAccounts() else { return [] }
        for account in accounts {
            guard let raws = try? await client.getOperations(accountId: account.id, from: from, to: to) else { continue }
            for raw in raws {
                let type = OperationType.from(raw.operationType ?? "")
                let date = raw.date.flatMap { iso.date(from: $0) } ?? Date()
                let name = raw.figi.flatMap { metaCache[$0]?.name } ?? type.title
                operations.append(Operation(
                    id: raw.id ?? UUID().uuidString,
                    date: date,
                    type: type,
                    name: name,
                    payment: raw.payment?.value ?? 0,
                    quantity: Double(raw.quantity ?? "0") ?? 0,
                    accountLabel: label
                ))
            }
        }
        return operations
    }

    private func mapPosition(_ raw: TInvestClient.PortfolioPosition,
                             client: TInvestClient) async -> Position? {
        guard let figi = raw.figi else { return nil }
        let qty = raw.quantity?.value ?? 0
        let price = raw.currentPrice?.value ?? 0
        let priceCurrency = (raw.currentPrice?.currency ?? "rub").lowercased()
        let avg = raw.averagePositionPrice?.value ?? 0
        let expectedYield = raw.expectedYield?.value ?? 0
        let rawValue = price * qty
        let valueRub = priceCurrency == "usd" ? rawValue * rate : rawValue
        let pnlPct = avg > 0 ? (price - avg) / avg * 100 : 0
        let assetClass = AssetClass.fromTInvest(raw.instrumentType ?? "")

        let meta = await resolveMeta(figi: figi, client: client)

        return Position(
            id: figi,
            ticker: meta.ticker,
            name: meta.name,
            assetClass: assetClass,
            quantity: qty,
            currentPrice: price,
            averagePrice: avg,
            valueRub: valueRub,
            expectedYieldRub: expectedYield,
            pnlPercent: pnlPct,
            currency: priceCurrency,
            sector: meta.sector,
            issuer: meta.name
        )
    }

    /// Cache-first instrument metadata lookup; fetches + records only on a miss.
    private func resolveMeta(figi: String, client: TInvestClient) async -> InstrumentMetaValue {
        if let cached = metaCache[figi] { return cached }
        let instrument = try? await client.getInstrument(figi: figi)
        let meta = InstrumentMetaValue(
            figi: figi,
            ticker: instrument?.ticker ?? figi,
            name: instrument?.name ?? figi,
            sector: instrument?.sector ?? "",
            currency: instrument?.currency ?? "rub"
        )
        await collector.add(meta)
        return meta
    }
}
