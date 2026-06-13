import Foundation

/// A future dividend or coupon payment (declared, from the broker API).
struct Payout: Identifiable {
    let id = UUID()
    let date: Date
    let name: String
    /// Amount in RUB (per-unit × quantity held).
    let amount: Double
    let isCoupon: Bool
}
