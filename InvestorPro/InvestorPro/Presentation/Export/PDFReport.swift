import SwiftUI
import UIKit

/// Renders a SwiftUI report view into a multi-page PDF (A4), preserving the dark look.
enum PDFReport {
    @MainActor
    static func render<Content: View>(_ content: Content) -> URL? {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842

        let renderer = ImageRenderer(content: content.frame(width: pageWidth))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("InvestorPro.pdf")
        let totalHeight = image.size.height
        let pageCount = max(1, Int(ceil(totalHeight / pageHeight)))
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        do {
            try pdf.writePDF(to: url) { ctx in
                for page in 0..<pageCount {
                    ctx.beginPage()
                    UIColor(white: 0.05, alpha: 1).setFill()
                    ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                    let yOffset = -CGFloat(page) * pageHeight
                    image.draw(in: CGRect(x: 0, y: yOffset, width: pageWidth, height: totalHeight))
                }
            }
            return url
        } catch {
            return nil
        }
    }
}

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
