import SwiftUI

extension PortfolioBreakdown {
    /// Map breakdown items to coloured donut slices (palette by sorted index).
    func donutSlices() -> [DonutSlice] {
        sorted.enumerated().map { index, item in
            DonutSlice(label: item.name, value: item.amount, color: Palette.color(at: index))
        }
    }
}
