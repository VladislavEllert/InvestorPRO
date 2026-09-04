import SwiftUI
import SwiftData

struct AccountsListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: PortfolioStore
    @Query(sort: \AccountConfig.createdAt) private var accounts: [AccountConfig]
    @State private var showAdd = false
    @State private var pendingDelete: AccountConfig?

    var body: some View {
        List {
            if accounts.isEmpty {
                ContentUnavailableView(
                    "Нет аккаунтов",
                    systemImage: "person.badge.key",
                    description: Text("Добавьте аккаунт по API-токену (только чтение).")
                )
            } else {
                Section {
                    ForEach(accounts) { account in
                        NavigationLink {
                            AccountDetailView(account: account)
                        } label: {
                            row(for: account)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { pendingDelete = account } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first { pendingDelete = accounts[index] }
                    }
                } footer: {
                    Text("Нажмите на аккаунт, чтобы обновить ключи, или смахните влево, чтобы удалить.")
                }
            }
        }
        .navigationTitle("Аккаунты")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddAccountView() }
        .alert("Удалить аккаунт?", isPresented: deleteAlertBinding, presenting: pendingDelete) { account in
            Button("Удалить", role: .destructive) { delete(account) }
            Button("Отмена", role: .cancel) { pendingDelete = nil }
        } message: { account in
            Text("«\(account.label)» и его ключи будут удалены с устройства. Данные брокера не затрагиваются.")
        }
    }

    private func row(for account: AccountConfig) -> some View {
        HStack(spacing: 12) {
            Image(systemName: account.kind.icon)
                .foregroundStyle(Palette.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.label).font(.body)
                Text(account.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func delete(_ account: AccountConfig) {
        pendingDelete = nil
        AccountCredentials.deleteAll(for: account)
        context.delete(account)
        try? context.save()

        let remaining = (try? context.fetch(
            FetchDescriptor<AccountConfig>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        Task { await store.refresh(accounts: remaining, context: context) }
    }
}

/// Existing account: rename and rotate credentials without losing the account.
struct AccountDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PortfolioStore
    @Query(sort: \AccountConfig.createdAt) private var accounts: [AccountConfig]

    let account: AccountConfig

    @State private var label: String
    @State private var values: [String: String] = [:]

    init(account: AccountConfig) {
        self.account = account
        _label = State(initialValue: account.label)
    }

    var body: some View {
        Form {
            Section("Название") {
                TextField("Название", text: $label)
                    .textInputAutocapitalization(.sentences)
            }

            Section {
                ForEach(account.kind.credentialFields) { field in
                    SecureField(field.title, text: binding(for: field.key))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("Доступ (read-only)")
            } footer: {
                Text(credentialsFooter)
            }

            Section {
                Button("Сохранить") { save() }
                    .disabled(!isValid)
            }
        }
        .navigationTitle(account.kind.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var credentialsFooter: String {
        let missing = account.kind.credentialFields.filter {
            !KeychainStore.shared.hasValue(account: account.keychainKey(for: $0.key))
        }
        if missing.isEmpty {
            return "Ключи сохранены в Keychain. Введите новые, чтобы заменить — пустые поля остаются как есть."
        }
        return "Нет сохранённого значения: \(missing.map(\.title).joined(separator: ", ")). Введите ключ заново."
    }

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func save() {
        account.label = label.trimmingCharacters(in: .whitespaces)
        for field in account.kind.credentialFields {
            let value = (values[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            KeychainStore.shared.save(value, account: account.keychainKey(for: field.key))
        }
        try? context.save()
        values = [:]

        let list = accounts
        Task { await store.refresh(accounts: list, context: context) }
        dismiss()
    }
}

struct AddAccountView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PortfolioStore

    @State private var kind: BrokerKind = .tInvest
    @State private var label = ""
    @State private var values: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section("Брокер") {
                    Picker("Брокер", selection: $kind) {
                        ForEach(BrokerKind.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Название") {
                    TextField("Напр. Основной счёт", text: $label)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Доступ (read-only)") {
                    ForEach(kind.credentialFields) { field in
                        SecureField(field.title, text: binding(for: field.key))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section {
                    Label(
                        "Ключи хранятся в Keychain устройства и уходят только в API брокера.",
                        systemImage: "lock.shield"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Новый аккаунт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return kind.credentialFields.allSatisfy {
            !(values[$0.key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func save() {
        let account = AccountConfig(kind: kind, label: label.trimmingCharacters(in: .whitespaces))
        context.insert(account)
        for field in kind.credentialFields {
            if let value = values[field.key] {
                KeychainStore.shared.save(value, account: account.keychainKey(for: field.key))
            }
        }
        try? context.save()

        let list = (try? context.fetch(
            FetchDescriptor<AccountConfig>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        Task { await store.refresh(accounts: list, context: context) }
        dismiss()
    }
}

/// Keychain lifecycle for an account's credential fields — one place, so a new
/// broker's fields are cleaned up automatically (DRY).
enum AccountCredentials {
    static func deleteAll(for account: AccountConfig) {
        for field in account.kind.credentialFields {
            KeychainStore.shared.delete(account: account.keychainKey(for: field.key))
        }
    }
}

#Preview {
    NavigationStack { AccountsListView() }
        .modelContainer(for: AccountConfig.self, inMemory: true)
        .environmentObject(PortfolioStore())
}
