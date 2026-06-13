import SwiftUI

extension PortfolioBreakdown {
    /// Coloured donut slices for the ring. Only positive amounts are drawn (a pie
    /// can't render a negative slice), but the colour index follows the full sorted
    /// list so ring and legend colours stay aligned.
    func donutSlices() -> [DonutSlice] {
        sorted.enumerated().compactMap { index, item in
            item.amount > 0
                ? DonutSlice(label: item.name, value: item.amount, color: Palette.color(at: index))
                : nil
        }
    }
}
