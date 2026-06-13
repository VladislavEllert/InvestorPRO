import Foundation
import SwiftData

/// Plain, Sendable instrument metadata (figi → name/ticker/sector/currency).
struct InstrumentMetaValue: Sendable, Hashable {
    let figi: String
    let ticker: String
    let name: String
    let sector: String
    let currency: String
    let logoName: String
}

/// Cached instrument metadata. figi→meta changes rarely, so caching avoids a
/// GetInstrumentBy call per position on every refresh.
@Model
final class InstrumentMeta {
    @Attribute(.unique) var figi: String
    var ticker: String
    var name: String
    var sector: String
    var currency: String
    var logoName: String = ""
    var updatedAt: Date

    init(value: InstrumentMetaValue) {
        self.figi = value.figi
        self.ticker = value.ticker
        self.name = value.name
        self.sector = value.sector
        self.currency = value.currency
        self.logoName = value.logoName
        self.updatedAt = Date()
    }

    var value: InstrumentMetaValue {
        InstrumentMetaValue(figi: figi, ticker: ticker, name: name,
                            sector: sector, currency: currency, logoName: logoName)
    }
}

/// Thread-safe collector for instrument metadata discovered during a refresh,
/// so it can be persisted once on the main actor afterwards.
actor InstrumentMetaCollector {
    private(set) var discovered: [String: InstrumentMetaValue] = [:]
    func add(_ meta: InstrumentMetaValue) { discovered[meta.figi] = meta }
    func all() -> [InstrumentMetaValue] { Array(discovered.values) }
}
