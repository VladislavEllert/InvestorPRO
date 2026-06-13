import Foundation

/// One broker connection. Each configured account gets a provider built with its
/// credentials. New broker = new conformer, existing code untouched (OCP).
protocol BrokerProvider {
    var kind: BrokerKind { get }

    /// Fetch the account portfolio. Network/credential errors are surfaced inside
    /// `BrokerAccountPortfolio.error` rather than thrown, so one failing account
    /// never blocks the others.
    func fetchPortfolio() async -> BrokerAccountPortfolio

    /// Fetch executed operations for the trade history and cash-flow stats.
    func fetchOperations(monthsBack: Int) async -> [Operation]
}

extension BrokerProvider {
    /// Brokers without an operations feed (e.g. Bybit here) return nothing.
    func fetchOperations(monthsBack: Int) async -> [Operation] { [] }
}
