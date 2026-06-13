import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PortfolioStore
    @State private var dimension: AnalyticsDimension = .assets

    private var converter: CurrencyConverter { CurrencyConverter(usdRubRate: store.usdRubRate) }

    private var breakdown: PortfolioBreakdown {
        if let portfolio = store.portfolio, !portfolio.isEmpty {
            return portfolio.breakdown(dimension)
        }
        return SampleData.breakdown(for: dimension)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                dimensionPicker
                donut
                legend
                detailButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Аналитика")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dimensionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsDimension.allCases) { dim in
                    SegmentPill(title: dim.title, isSelected: dim == dimension) {
                        withAnimation(.easeInOut(duration: 0.2)) { dimension = dim }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var donut: some View {
        let total = converter.display(breakdown.total, in: settings.baseCurrency)
        let count = breakdown.items.count
        return DonutChartView(
            slices: breakdown.donutSlices(),
            centerTitle: MoneyFormatter.string(total, currency: settings.baseCurrency),
            centerSubtitle: "\(count) \(dimension.countWord(count))"
        )
    }

    private var detailPositions: [Position] {
        if let portfolio = store.portfolio, !portfolio.positions.isEmpty { return portfolio.positions }
        return SampleData.positions
    }

    private var detailButton: some View {
        NavigationLink {
            PositionsDetailView(positions: detailPositions)
        } label: {
            HStack {
                Label("Подробнее по активам", systemImage: "list.bullet.indent")
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        VStack(spacing: 0) {
            ForEach(Array(breakdown.sorted.enumerated()), id: \.element.id) { index, item in
                LegendRow(
                    color: Palette.color(at: index),
                    name: item.name,
                    percent: MoneyFormatter.percent(breakdown.share(of: item))
                )
                if index < breakdown.items.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SegmentPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Palette.accent : Color.clear, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
            .environmentObject(AppSettings())
            .environmentObject(PortfolioStore())
    }
}
