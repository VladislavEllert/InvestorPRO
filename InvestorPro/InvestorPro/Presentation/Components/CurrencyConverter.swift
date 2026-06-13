import Foundation

/// Converts the RUB base amounts to the user's display currency.
/// The USD/RUB rate is a placeholder until CBRClient lands (plan step 3).
struct CurrencyConverter {
    /// RUB per 1 USD.
    var usdRubRate: Double = 79.0

    func display(_ rubAmount: Double, in currency: Currency) -> Double {
        switch currency {
        case .rub: return rubAmount
        case .usd: return usdRubRate > 0 ? rubAmount / usdRubRate : 0
        }
    }
}
