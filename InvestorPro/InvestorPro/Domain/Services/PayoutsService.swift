import Foundation

/// Fetches declared future dividends (shares) and coupons (bonds) for held positions.
/// All data is real, from the T-Invest Instruments API — nothing is projected/invented.
struct PayoutsService {
    func load(positions: [Position], token: String, monthsAhead: Int = 12) async -> [Payout] {
        let client = TInvestClient(token: token)
        let now = Date()
        let to = Calendar.current.date(byAdding: .month, value: monthsAhead, to: now) ?? now

        var result: [Payout] = []
        await withTaskGroup(of: [Payout].self) { group in
            for position in positions where position.quantity > 0 {
                group.addTask { await fetch(position, client: client, from: now, to: to) }
            }
            for await payouts in group { result.append(contentsOf: payouts) }
        }
        return result.sorted { $0.date < $1.date }
    }

    private func fetch(_ position: Position, client: TInvestClient,
                       from: Date, to: Date) async -> [Payout] {
        switch position.assetClass {
        case .share:
            guard let dividends = try? await client.getDividends(figi: position.id, from: from, to: to) else { return [] }
            return dividends.compactMap { dto in
                guard let raw = dto.paymentDate,
                      let date = TInvestProvider.parseDate(raw), date >= from else { return nil }
                let perShare = dto.dividendNet?.value ?? 0
                guard perShare > 0 else { return nil }
                return Payout(date: date, name: position.name,
                              amount: perShare * position.quantity, isCoupon: false)
            }
        case .bond:
            guard let coupons = try? await client.getBondCoupons(figi: position.id, from: from, to: to) else { return [] }
            return coupons.compactMap { dto in
                guard let raw = dto.couponDate,
                      let date = TInvestProvider.parseDate(raw), date >= from else { return nil }
                let perBond = dto.payOneBond?.value ?? 0
                guard perBond > 0 else { return nil }
                return Payout(date: date, name: position.name,
                              amount: perBond * position.quantity, isCoupon: true)
            }
        default:
            return []
        }
    }
}
