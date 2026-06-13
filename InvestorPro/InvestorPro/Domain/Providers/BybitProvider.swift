import Foundation

/// BrokerProvider for Bybit. Coins from the Unified account, converted USD→RUB.
struct BybitProvider: BrokerProvider {
    let kind: BrokerKind = .bybit
    let id: UUID
    let label: String
    let apiKey: String
    let apiSecret: String
    let rate: Double

    func fetchPortfolio() async -> BrokerAccountPortfolio {
        var result = BrokerAccountPortfolio(id: id, label: label, kind: .bybit,
                                            totalRub: 0, positions: [], error: nil)
        do {
            let client = BybitClient(apiKey: apiKey, apiSecret: apiSecret)
            let coins = try await client.fetchWalletBalance()
            var total = 0.0
            var positions: [Position] = []
            for coin in coins {
                let valueRub = coin.usdValue * rate
                total += valueRub
                let unitPrice = coin.equity > 0 ? coin.usdValue / coin.equity : 0
                positions.append(Position(
                    id: coin.coin,
                    ticker: coin.coin,
                    name: coin.coin,
                    assetClass: .crypto,
                    quantity: coin.equity,
                    currentPrice: unitPrice,
                    averagePrice: 0,
                    valueRub: valueRub,
                    expectedYieldRub: 0,
                    pnlPercent: 0,
                    currency: "USDT",
                    sector: "Криптовалюта",
                    issuer: coin.coin
                ))
            }
            result.totalRub = total
            result.positions = positions
        } catch {
            result.error = error.localizedDescription
        }
        return result
    }
}
