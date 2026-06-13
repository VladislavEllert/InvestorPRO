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
    /// T-Invest brand logo file name (e.g. "yandex.png"), for the CDN logo.
    var logoName: String?

    /// Official instrument logo from the T-Invest brand CDN.
    var logoURL: URL? {
        guard let name = logoName, !name.isEmpty else { return nil }
        let base = name.replacingOccurrences(of: ".png", with: "")
        return URL(string: "https://invest-brands.cdn-tinkoff.ru/\(base)x160.png")
    }
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
