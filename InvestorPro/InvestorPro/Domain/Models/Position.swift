import Foundation

/// A single holding, normalised to RUB for aggregation.
struct Position: Identifiable, Hashable {
    let id: String          // figi or coin symbol — stable per instrument
    let ticker: String
    let name: String
    let assetClass: AssetClass
    let quantity: Double
    let currentPrice: Double
    let averagePrice: Double
    /// Current market value in RUB.
    let valueRub: Double
    /// Expected yield (PnL) in RUB.
    let expectedYieldRub: Double
    /// PnL percent vs average buy price.
    let pnlPercent: Double
    let currency: String
    /// Optional analytics metadata (filled from instrument cache).
    var sector: String?
    var issuer: String?
}

/// Portfolio of one configured account (may sum several broker sub-accounts).
struct BrokerAccountPortfolio: Identifiable {
    let id: UUID            // AccountConfig.id
    let label: String
    let kind: BrokerKind
    var totalRub: Double
    var positions: [Position]
    var error: String?
}
