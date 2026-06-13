import SwiftUI
import Charts

struct DonutSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

/// Thin rounded-segment donut with a centred title/subtitle, matching the reference.
struct DonutChartView: View {
    let slices: [DonutSlice]
    let centerTitle: String
    let centerSubtitle: String

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Доля", slice.value),
                innerRadius: .ratio(0.82),
                angularInset: slices.count > 1 ? 1.6 : 0
            )
            .cornerRadius(4)
            .foregroundStyle(slice.color)
        }
        .chartLegend(.hidden)
        .frame(height: 230)
        .overlay {
            VStack(spacing: 4) {
                Text(centerTitle)
                    .font(.system(size: 30, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(centerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 56)
        }
    }
}

/// Legend row: colour dot — name — percentage, like the reference list.
struct LegendRow: View {
    let color: Color
    let name: String
    let percent: String

    private var isNegative: Bool { percent.hasPrefix("-") || percent.hasPrefix("−") }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.body)
            Spacer(minLength: 12)
            Text(percent)
                .font(.body)
                .foregroundStyle(isNegative ? Palette.negative : .primary)
        }
        .padding(.vertical, 8)
    }
}
