import Foundation

/// Supported brokers. Adding a new broker = new case + a new BrokerProvider (OCP).
enum BrokerKind: String, CaseIterable, Identifiable, Codable {
    case tInvest
    case bybit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tInvest: return "Т-Инвест"
        case .bybit: return "Bybit"
        }
    }

    var icon: String {
        switch self {
        case .tInvest: return "building.columns"
        case .bybit: return "bitcoinsign.circle"
        }
    }

    /// Credential fields the user must provide for this broker.
    var credentialFields: [CredentialField] {
        switch self {
        case .tInvest:
            return [CredentialField(key: "token", title: "API-токен", isSecret: true)]
        case .bybit:
            return [
                CredentialField(key: "apiKey", title: "API Key", isSecret: true),
                CredentialField(key: "apiSecret", title: "API Secret", isSecret: true)
            ]
        }
    }
}

struct CredentialField: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let title: String
    let isSecret: Bool
}
