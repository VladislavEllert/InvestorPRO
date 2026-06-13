import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

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
                    // Manual refresh wired in plan step 3.
                } label: {
                    Label("Обновить сейчас", systemImage: "arrow.clockwise")
                }
            }

            Section("Заметки") {
                // Notion token entry lands in plan step 7.
                Label("Notion-интеграция", systemImage: "link")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView().environmentObject(AppSettings()) }
}
