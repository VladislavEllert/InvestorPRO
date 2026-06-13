import Foundation
import SwiftData

/// Persisted account metadata. Secrets (tokens/keys) live in the Keychain,
/// keyed by `\(id).\(field)` — never stored here.
@Model
final class AccountConfig {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var label: String
    var createdAt: Date

    init(kind: BrokerKind, label: String) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.label = label
        self.createdAt = Date()
    }

    var kind: BrokerKind { BrokerKind(rawValue: kindRaw) ?? .tInvest }

    /// Keychain account key for a credential field.
    func keychainKey(for field: String) -> String { "\(id.uuidString).\(field)" }

    /// Plain, Sendable copy for passing off the main actor (SwiftData models are
    /// not thread-safe — never touch them from a background task).
    var snapshot: AccountSnapshot { AccountSnapshot(id: id, kind: kind, label: label) }
}

struct AccountSnapshot: Sendable, Identifiable {
    let id: UUID
    let kind: BrokerKind
    let label: String

    func keychainKey(for field: String) -> String { "\(id.uuidString).\(field)" }
}
