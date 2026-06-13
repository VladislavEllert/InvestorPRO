import SwiftUI

/// Donut / chart colour palette tuned to the T-Bank analytics reference.
enum Palette {
    static let blue = Color(red: 0.36, green: 0.71, blue: 0.90)
    static let purple = Color(red: 0.66, green: 0.44, blue: 0.82)
    static let green = Color(red: 0.66, green: 0.82, blue: 0.55)
    static let yellow = Color(red: 0.95, green: 0.78, blue: 0.30)
    static let pink = Color(red: 0.93, green: 0.45, blue: 0.62)
    static let lightBlue = Color(red: 0.45, green: 0.62, blue: 0.86)
    static let orange = Color(red: 0.95, green: 0.66, blue: 0.34)
    static let teal = Color(red: 0.30, green: 0.64, blue: 0.60)
    static let coral = Color(red: 0.93, green: 0.50, blue: 0.40)

    /// Stable colour sequence used to colour breakdown slices by index.
    static let sequence: [Color] = [blue, purple, green, yellow, pink, lightBlue, orange, teal, coral]

    static func color(at index: Int) -> Color {
        sequence[index % sequence.count]
    }

    /// Accent (selection / highlight) — matches the yellow segment border in the reference.
    static let accent = Color(red: 0.95, green: 0.78, blue: 0.20)

    static let positive = Color(red: 0.22, green: 0.72, blue: 0.40)
    static let negative = Color(red: 0.90, green: 0.30, blue: 0.30)
}
