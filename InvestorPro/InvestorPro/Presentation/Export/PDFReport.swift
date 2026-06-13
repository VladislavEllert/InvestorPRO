import UIKit

/// Builds a simple PDF report (portfolio summary + holdings + recent trades) from
/// real portfolio data. Returns a temp-file URL to share.
enum PDFReport {
    static func build(portfolio: Portfolio, currency: Currency, converter: CurrencyConverter) -> URL? {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 in points
        let margin: CGFloat = 40
        let maxY: CGFloat = 800
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("InvestorPro.pdf")

        let title = UIFont.boldSystemFont(ofSize: 24)
        let h2 = UIFont.boldSystemFont(ofSize: 15)
        let body = UIFont.systemFont(ofSize: 11)

        func money(_ rub: Double) -> String {
            MoneyFormatter.string(converter.display(rub, in: currency), currency: currency)
        }

        do {
            try renderer.writePDF(to: url) { ctx in
                var y = margin
                ctx.beginPage()

                func draw(_ text: String, font: UIFont, color: UIColor = .label) {
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                    let width = bounds.width - 2 * margin
                    let height = (text as NSString).boundingRect(
                        with: CGSize(width: width, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin], attributes: attrs, context: nil).height
                    if y + height + 4 > maxY { ctx.beginPage(); y = margin }
                    (text as NSString).draw(in: CGRect(x: margin, y: y, width: width, height: height),
                                            withAttributes: attrs)
                    y += height + 4
                }
                func spacer(_ h: CGFloat = 10) { y += h }

                draw("InvestorPro", font: title)
                draw("Отчёт от \(Date().formatted(date: .long, time: .shortened))", font: body, color: .secondaryLabel)
                spacer()
                draw("Стоимость портфеля: \(money(portfolio.totalRub))", font: h2)
                spacer()

                let breakdown = portfolio.breakdown(.assets)
                draw("Срез по активам", font: h2)
                for item in breakdown.sorted {
                    draw("• \(item.name): \(money(item.amount))  (\(MoneyFormatter.percent(breakdown.share(of: item))))", font: body)
                }
                spacer()

                draw("Позиции", font: h2)
                for position in portfolio.positions.sorted(by: { $0.valueRub > $1.valueRub }) {
                    let pnl = String(format: "%+.1f%%", position.pnlPercent)
                    draw("• \(position.name) (\(position.ticker)): \(money(position.valueRub))  \(pnl)", font: body)
                }
                spacer()

                if !portfolio.operations.isEmpty {
                    draw("Последние операции", font: h2)
                    for op in portfolio.operations.prefix(40) {
                        let sign = op.payment >= 0 ? "+" : "−"
                        let amount = MoneyFormatter.string(abs(op.payment), currency: .rub, fractionDigits: 2)
                        draw("\(op.date.formatted(date: .numeric, time: .omitted))   \(op.type.title)   \(op.name)   \(sign)\(amount)", font: body)
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }
}

import SwiftUI

struct ActivityView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}
