import Foundation

enum MoneyFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{00A0}" // non-breaking space, like "180 836"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    /// "180 836 ₽" / "1 980 $"
    static func string(_ amount: Double, currency: Currency, fractionDigits: Int = 0) -> String {
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = fractionDigits
        let number = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "\(number)\u{00A0}\(currency.symbol)"
    }

    /// "80,05%"
    static func percent(_ value: Double) -> String {
        String(format: "%.2f%%", value).replacingOccurrences(of: ".", with: ",")
    }

    /// Compact axis label: "400к", "1,2м". Russian short scale.
    static func compact(_ value: Double) -> String {
        let magnitude = Swift.abs(value)
        if magnitude >= 1_000_000 {
            return String(format: "%.1fм", value / 1_000_000).replacingOccurrences(of: ".", with: ",")
        }
        if magnitude >= 1_000 {
            return String(format: "%.0fк", value / 1_000)
        }
        return String(format: "%.0f", value)
    }
}
