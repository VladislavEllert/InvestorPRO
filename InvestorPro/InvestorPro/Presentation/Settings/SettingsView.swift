import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PortfolioStore
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [AccountConfig]
    @Query(sort: \PortfolioSnapshot.date) private var snapshots: [PortfolioSnapshot]

    @State private var exportFile: ExportFile?

    var body: some View {
        Form {
            Section("Аккаунты") {
                NavigationLink {
                    AccountsListView()
                } label: {
                    Label("Аккаунты и токены", systemImage: "person.badge.key")
                }
            }

            Section("Внешний вид") {
                Picker("Тема", selection: $settings.theme) {
                    ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                }
                Picker("Базовая валюта", selection: $settings.baseCurrency) {
                    ForEach(Currency.allCases) { Text($0.shortName).tag($0) }
                }
            }

            Section("Обновление") {
                Picker("Частота обновления", selection: $settings.refreshInterval) {
                    ForEach(AppSettings.RefreshInterval.allCases) { Text($0.title).tag($0) }
                }
                Button {
                    Task { await store.refresh(accounts: accounts, context: modelContext) }
                } label: {
                    Label("Обновить сейчас", systemImage: "arrow.clockwise")
                }
                .disabled(accounts.isEmpty || store.isLoading)
            }

            Section("Безопасность") {
                Toggle(isOn: $settings.requireBiometrics) {
                    Label("Разблокировка по Face ID", systemImage: "faceid")
                }
            }

            Section("Отчёт") {
                Button {
                    guard let portfolio = store.portfolio else { return }
                    let report = ReportView(
                        portfolio: portfolio,
                        snapshots: snapshots,
                        currency: settings.baseCurrency,
                        converter: CurrencyConverter(usdRubRate: store.usdRubRate)
                    )
                    if let url = PDFReport.render(report) {
                        exportFile = ExportFile(url: url)
                    }
                } label: {
                    Label("Экспорт PDF", systemImage: "square.and.arrow.up")
                }
                .disabled(store.portfolio == nil)
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportFile) { file in
            ActivityView(url: file.url)
        }
    }
}
