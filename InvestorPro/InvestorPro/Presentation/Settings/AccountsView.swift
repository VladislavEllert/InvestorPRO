import SwiftUI
import SwiftData

struct AccountsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AccountConfig.createdAt) private var accounts: [AccountConfig]
    @State private var showAdd = false

    var body: some View {
        List {
            if accounts.isEmpty {
                ContentUnavailableView(
                    "Нет аккаунтов",
                    systemImage: "person.badge.key",
                    description: Text("Добавьте аккаунт по API-токену (только чтение).")
                )
            } else {
                ForEach(accounts) { account in
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
                .onDelete(perform: delete)
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
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            let account = accounts[index]
            for field in account.kind.credentialFields {
                KeychainStore.shared.delete(account: account.keychainKey(for: field.key))
            }
            context.delete(account)
        }
    }
}

struct AddAccountView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

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
        dismiss()
    }
}

#Preview {
    NavigationStack { AccountsListView() }
        .modelContainer(for: AccountConfig.self, inMemory: true)
}
