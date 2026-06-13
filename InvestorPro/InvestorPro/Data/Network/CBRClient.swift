import Foundation

/// USD/RUB rate from the Russian Central Bank XML feed (same source as the Python bot).
struct CBRClient {
    private let url = URL(string: "https://www.cbr.ru/scripts/XML_daily.asp")!
    static let fallbackRate = 80.0

    func fetchUsdRub() async -> Double {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parser = USDRateParser()
            return parser.parse(data) ?? Self.fallbackRate
        } catch {
            return Self.fallbackRate
        }
    }
}

/// Pulls the USD <Value>/<Nominal> out of the CBR XML (windows-1251, comma decimals).
private final class USDRateParser: NSObject, XMLParserDelegate {
    private var inUSD = false
    private var currentElement = ""
    private var charCode = ""
    private var valueText = ""
    private var nominalText = ""
    private var result: Double?

    func parse(_ data: Data) -> Double? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return result
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        currentElement = elementName
        if elementName == "Valute" {
            charCode = ""; valueText = ""; nominalText = ""; inUSD = false
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "CharCode": charCode += string
        case "Value": valueText += string
        case "Nominal": nominalText += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "CharCode", charCode.trimmingCharacters(in: .whitespacesAndNewlines) == "USD" {
            inUSD = true
        }
        if elementName == "Valute", inUSD {
            let value = Double(valueText.replacingOccurrences(of: ",", with: ".")) ?? 0
            let nominal = Double(nominalText.replacingOccurrences(of: ",", with: ".")) ?? 1
            if value > 0, nominal > 0 { result = value / nominal }
        }
    }
}
