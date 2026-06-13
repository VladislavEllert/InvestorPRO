import SwiftUI

/// Portfolio split by configured account — tap an account to see its positions.
struct AccountsPortfolioView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PortfolioStore

    private var converter: CurrencyConverter { CurrencyConverter(usdRubRate: store.usdRubRate) }
    private var accounts: [BrokerAccountPortfolio] { store.portfolio?.accounts ?? [] }

    var body: some View {
        List {
            ForEach(accounts) { account in
                if account.error != nil {
                    errorRow(account)
                } else {
                    NavigationLink {
                        PositionsDetailView(positions: account.positions, title: account.label)
                    } label: {
                        row(account)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("По аккаунтам")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if accounts.isEmpty {
                ContentUnavailableView("Нет данных", systemImage: "person.2",
                                       description: Text("Обновите портфель на главной."))
            }
        }
    }

    private func row(_ account: BrokerAccountPortfolio) -> some View {
        HStack(spacing: 12) {
            Image(systemName: account.kind.icon)
                .foregroundStyle(Palette.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.label).font(.body)
                Text("\(account.kind.displayName) · \(account.positions.count) поз.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(MoneyFormatter.string(converter.display(account.totalRub, in: settings.baseCurrency),
                                       currency: settings.baseCurrency))
                .font(.body.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private func errorRow(_ account: BrokerAccountPortfolio) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(account.label, systemImage: "exclamationmark.triangle")
                .foregroundStyle(Palette.negative)
            Text(account.error ?? "").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
