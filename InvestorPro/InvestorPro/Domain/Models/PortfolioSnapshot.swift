import Foundation
import SwiftData

/// A point-in-time portfolio value, written on each successful refresh. The charts
/// screen builds the value-over-time series from these (exact, forward-looking).
@Model
final class PortfolioSnapshot {
    var date: Date
    var totalRub: Double

    init(date: Date, totalRub: Double) {
        self.date = date
        self.totalRub = totalRub
    }
}
