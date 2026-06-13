import Foundation

/// T-Invest REST (gRPC-JSON transcoding). Read-only Bearer token.
/// Mirrors the Python `tbank_client.py` logic.
struct TInvestClient {
    private let token: String
    private let base = URL(string: "https://invest-public-api.tinkoff.ru/rest/")!
    private let service = "tinkoff.public.invest.api.contract.v1."

    init(token: String) { self.token = token }

    // MARK: Money helpers

    struct MoneyValue: Decodable {
        let units: String?
        let nano: Int?
        let currency: String?
        var value: Double { (Double(units ?? "0") ?? 0) + Double(nano ?? 0) / 1_000_000_000 }
    }

    // MARK: Responses

    struct Account: Decodable {
        let id: String
        let name: String?
        let status: String?
    }
    private struct AccountsResponse: Decodable { let accounts: [Account]? }

    struct PortfolioPosition: Decodable {
        let figi: String?
        let instrumentType: String?
        let quantity: MoneyValue?
        let currentPrice: MoneyValue?
        let averagePositionPrice: MoneyValue?
        let expectedYield: MoneyValue?
    }
    struct PortfolioResponse: Decodable {
        let totalAmountPortfolio: MoneyValue?
        let positions: [PortfolioPosition]?
    }

    struct Brand: Decodable { let logoName: String? }
    struct Instrument: Decodable {
        let ticker: String?
        let name: String?
        let sector: String?
        let currency: String?
        let brand: Brand?
    }
    private struct InstrumentResponse: Decodable { let instrument: Instrument? }

    // MARK: Calls

    func getAccounts() async throws -> [Account] {
        let data = try await post("UsersService/GetAccounts", body: [:])
        let decoded = try JSONDecoder().decode(AccountsResponse.self, from: data)
        return (decoded.accounts ?? []).filter { !($0.status ?? "").uppercased().contains("CLOSED") }
    }

    func getPortfolio(accountId: String) async throws -> PortfolioResponse {
        let data = try await post("OperationsService/GetPortfolio", body: ["accountId": accountId])
        return try JSONDecoder().decode(PortfolioResponse.self, from: data)
    }

    func getInstrument(figi: String) async throws -> Instrument? {
        let data = try await post("InstrumentsService/GetInstrumentBy",
                                  body: ["idType": "INSTRUMENT_ID_TYPE_FIGI", "id": figi])
        return try JSONDecoder().decode(InstrumentResponse.self, from: data).instrument
    }

    struct OperationDTO: Decodable {
        let id: String?
        let date: String?
        let figi: String?
        let operationType: String?
        let payment: MoneyValue?
        let quantity: String?
    }
    private struct OperationsResponse: Decodable { let operations: [OperationDTO]? }

    func getOperations(accountId: String, from: Date, to: Date) async throws -> [OperationDTO] {
        let iso = ISO8601DateFormatter()
        let data = try await post("OperationsService/GetOperations", body: [
            "accountId": accountId,
            "from": iso.string(from: from),
            "to": iso.string(from: to),
            "state": "OPERATION_STATE_EXECUTED"
        ])
        return try JSONDecoder().decode(OperationsResponse.self, from: data).operations ?? []
    }

    // MARK: Dividends & coupons (future payouts)

    struct DividendDTO: Decodable {
        let paymentDate: String?
        let dividendNet: MoneyValue?
    }
    private struct DividendsResponse: Decodable { let dividends: [DividendDTO]? }

    func getDividends(figi: String, from: Date, to: Date) async throws -> [DividendDTO] {
        let iso = ISO8601DateFormatter()
        let data = try await post("InstrumentsService/GetDividends", body: [
            "figi": figi,
            "from": iso.string(from: from),
            "to": iso.string(from: to)
        ])
        return try JSONDecoder().decode(DividendsResponse.self, from: data).dividends ?? []
    }

    struct CouponDTO: Decodable {
        let couponDate: String?
        let payOneBond: MoneyValue?
    }
    private struct CouponsResponse: Decodable { let events: [CouponDTO]? }

    func getBondCoupons(figi: String, from: Date, to: Date) async throws -> [CouponDTO] {
        let iso = ISO8601DateFormatter()
        let data = try await post("InstrumentsService/GetBondCoupons", body: [
            "figi": figi,
            "from": iso.string(from: from),
            "to": iso.string(from: to)
        ])
        return try JSONDecoder().decode(CouponsResponse.self, from: data).events ?? []
    }

    // MARK: Transport

    private func post(_ method: String, body: [String: Any]) async throws -> Data {
        let url = base.appending(path: service + method)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.http(status: http.statusCode,
                                    body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}

enum NetworkError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Некорректный ответ сервера."
        case .http(let status, let body):
            let short = body.count > 200 ? String(body.prefix(200)) + "…" : body
            return "Ошибка \(status): \(short)"
        }
    }
}
