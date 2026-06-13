import SwiftUI

struct TradesView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PortfolioStore

    private var operations: [Operation] { store.portfolio?.operations ?? [] }

    private var grouped: [(day: Date, items: [Operation])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: operations) { calendar.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { ($0, dict[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.day) { section in
                Section(section.day.formatted(.dateTime.day().month(.wide).year())) {
                    ForEach(section.items) { operation in
                        NavigationLink {
                            OperationDetailView(operation: operation)
                        } label: {
                            OperationRow(operation: operation)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("История сделок")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if operations.isEmpty {
                ContentUnavailableView(
                    "Нет операций",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Подключите аккаунт и обновите портфель на главной.")
                )
            }
        }
    }
}

private struct OperationRow: View {
    let operation: Operation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: operation.type.icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(operation.name).font(.body)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(amount)
                .font(.callout.weight(.medium))
                .foregroundStyle(operation.payment >= 0 ? Palette.positive : .primary)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        operation.quantity > 0
            ? "\(operation.type.title) · \(operation.quantity.formatted()) шт."
            : operation.type.title
    }

    private var amount: String {
        let sign = operation.payment >= 0 ? "+" : "−"
        let value = MoneyFormatter.string(abs(operation.payment), currency: .rub, fractionDigits: 0)
        return "\(sign)\(value)"
    }

    private var color: Color {
        switch operation.type {
        case .buy: return Palette.negative
        case .sell, .dividend, .coupon, .input: return Palette.positive
        default: return .secondary
        }
    }
}

struct OperationDetailView: View {
    let operation: Operation

    var body: some View {
        List {
            Section {
                detailRow("Тип", operation.type.title)
                detailRow("Инструмент", operation.name)
                detailRow("Аккаунт", operation.accountLabel)
                detailRow("Дата", operation.date.formatted(.dateTime.day().month(.wide).year().hour().minute()))
            }
            Section {
                HStack {
                    Text("Сумма").foregroundStyle(.secondary)
                    Spacer()
                    Text(amountString)
                        .foregroundStyle(operation.payment >= 0 ? Palette.positive : .primary)
                }
                if operation.quantity > 0 {
                    detailRow("Количество", "\(qtyString) шт.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(operation.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    private var amountString: String {
        let sign = operation.payment >= 0 ? "+" : "−"
        return "\(sign)\(MoneyFormatter.string(abs(operation.payment), currency: .rub, fractionDigits: 2))"
    }

    private var qtyString: String {
        operation.quantity == operation.quantity.rounded()
            ? String(Int(operation.quantity))
            : String(format: "%g", operation.quantity)
    }
}

#Preview {
    NavigationStack { TradesView() }
        .environmentObject(AppSettings())
        .environmentObject(PortfolioStore())
}
