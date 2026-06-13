import Foundation
import CryptoKit

/// Bybit v5 REST. Reads the Unified Trading Account wallet balance.
/// Mirrors the Python `bybit_client.py` logic. HMAC-SHA256 signing via CryptoKit.
struct BybitClient {
    private let apiKey: String
    private let apiSecret: String
    private let base = URL(string: "https://api.bybit.com")!
    private let recvWindow = "60000"

    init(apiKey: String, apiSecret: String) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
    }

    struct Coin {
        let coin: String
        let equity: Double
        let usdValue: Double
    }

    private struct WalletResponse: Decodable {
        let retCode: Int
        let retMsg: String
        let result: ResultBox?
        struct ResultBox: Decodable { let list: [Account]? }
        struct Account: Decodable { let coin: [CoinDTO]? }
        struct CoinDTO: Decodable {
            let coin: String
            let equity: String?
            let usdValue: String?
        }
    }

    func fetchWalletBalance() async throws -> [Coin] {
        let query = "accountType=UNIFIED"
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let payload = timestamp + apiKey + recvWindow + query
        let signature = sign(payload)

        var components = URLComponents(url: base.appending(path: "/v5/account/wallet-balance"),
                                       resolvingAgainstBaseURL: false)!
        components.query = query
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-BAPI-API-KEY")
        request.setValue(timestamp, forHTTPHeaderField: "X-BAPI-TIMESTAMP")
        request.setValue(recvWindow, forHTTPHeaderField: "X-BAPI-RECV-WINDOW")
        request.setValue(signature, forHTTPHeaderField: "X-BAPI-SIGN")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.http(status: http.statusCode,
                                    body: String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(WalletResponse.self, from: data)
        guard decoded.retCode == 0 else {
            throw NetworkError.http(status: decoded.retCode, body: decoded.retMsg)
        }

        let coins = decoded.result?.list?.first?.coin ?? []
        return coins.compactMap { dto in
            let usd = Double(dto.usdValue ?? "0") ?? 0
            guard usd >= 0.01 else { return nil }
            return Coin(coin: dto.coin, equity: Double(dto.equity ?? "0") ?? 0, usdValue: usd)
        }
    }

    private func sign(_ payload: String) -> String {
        let key = SymmetricKey(data: Data(apiSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }
}
