<div align="center">

# 📈 InvestorPro

**A personal investment tracker for iPhone. Your whole portfolio — Tinkoff Invest (T-Invest) and Bybit — in one native app.**

*Native iOS investment portfolio tracker (SwiftUI) for Tinkoff Invest & Bybit — assets, analytics, value & return charts, trade history. Stocks & crypto, personal finance, fully local on iPhone.*

![iOS](https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-2396F3?logo=swift&logoColor=white)
![SwiftData](https://img.shields.io/badge/Persistence-SwiftData-blue)
![Swift Charts](https://img.shields.io/badge/Charts-Swift%20Charts-orange)
![No 3rd-party](https://img.shields.io/badge/dependencies-system%20only-success)

</div>

---

## 💡 Why

The portfolio used to live in a Python Telegram bot: commands, plain-text summaries, a server to keep alive. Clunky and dated. **InvestorPro** moves and extends that logic into a native iOS app: fast, good-looking, in your hand — and **serverless**. All exchange requests go straight from the phone; data stays on the device.

## ✨ Features

- 🔑 **Accounts via API tokens** — multiple T-Invest accounts + Bybit. Tokens live only in the Keychain.
- 🍩 **Home** — assets donut with the total in the centre, % breakdown, ₽/$ toggle, **today's change** and last-updated time.
- 📊 **Analytics** — four breakdowns: **Assets / Companies / Sectors / Currency** (donut + legend), 1:1 with the Tinkoff style. Margin debt is shown as its own line.
- 🏷 **Positions with logos** — official company logos from T-Invest, name, quantity · average price, value, PnL ₽·%. "Details" drill-down.
- 👥 **By account** — each account separately → its positions.
- 📈 **Charts** — portfolio value over time from real snapshots: **columns ⇄ curve**, ranges Month / 6M / Year / All time, scroll, scrubbing. Nothing is fabricated.
- 💸 **Cash-flow stats** — return, dividends, coupons, turnover, deposits, withdrawals for the selected period.
- 🗓 **Upcoming payouts** — declared dividends and coupons a year ahead: total, monthly bar chart, list by date.
- 🧾 **Trade history** — operations by date, filter by account/type, tap → details (account, date, amount).
- 🔐 **Face ID / passcode** lock (optional).
- 📄 **PDF export** — a dark report of the portfolio and operations.
- 🌗 **Themes** light / dark / system · 🔄 **refresh** manual / hourly / daily.

## 📸 Screenshots

> Demo GIF and screenshots — coming soon.

## 🏗 Architecture

Clean architecture, MVVM, dependencies pointing toward Domain. System frameworks only — no third-party SDKs.

```
InvestorPro/InvestorPro/
├── App/            entry point, AppSettings (theme/currency/refresh)
├── Domain/         models + protocols (no UIKit/networking)
│   ├── Models/     Account, Position, AssetClass, Portfolio, Operation, Snapshot…
│   ├── Providers/  BrokerProvider (OCP: new broker = new class)
│   └── Services/   PortfolioAggregator, PortfolioStore
├── Data/
│   ├── Network/    TInvestClient, BybitClient, CBRClient
│   ├── Security/   KeychainStore (secrets)
│   └── Persistence (SwiftData: snapshots, instrument cache, accounts)
└── Presentation/   Home, Analytics, Accounts, Charts, Trades, Dividends, Export, Settings, Components, Theme
```

**Principles:** SOLID · DRY · KISS · minimal dependencies · secrets only in the Keychain.

## 🧰 Tech

`SwiftUI` · `Swift Charts` · `SwiftData` · `URLSession (async/await)` · `CryptoKit (HMAC)` · `Keychain` · `LocalAuthentication (Face ID)` · `PDFKit`

## 🔌 Data sources

| Source | What | Auth |
|---|---|---|
| **T-Invest** | accounts, portfolio, instruments, operations, dividends, coupons, logos | Bearer token (read-only) |
| **Bybit v5** | Unified account balance | API key + secret, HMAC-SHA256 |
| **Bank of Russia** | USD/RUB rate | public XML |

> Portfolio value history is accumulated locally (a snapshot on every refresh) — the charts grow over time as the app is used. The exchanges don't expose a ready-made value time series, so nothing is invented: history starts from first launch.

## 🚀 Build & run

```bash
cd InvestorPro
xcodebuild -scheme InvestorPro -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**On a device (iPhone):** open `InvestorPro/InvestorPro.xcodeproj` in Xcode → pick a Team (personal Apple ID) → Run. Free signing lasts ~7 days.

**Connect your accounts:** Settings → Accounts → `+` → token(s). Pull-to-refresh loads the portfolio.

## 🗺 Roadmap

Require a paid Apple Developer account (free signing doesn't support CloudKit / App Groups):

- [ ] iCloud snapshot sync (chart history across devices)
- [ ] Home-screen widget (total + sparkline)
- [ ] Real background refresh (`BGAppRefreshTask`)

Other:

- [ ] AI portfolio assistant (ProxyAPI: analysis, advice, multi-chat)
- [ ] Notes with Notion import/export
- [ ] Bybit detail (futures, funding)

## ⚠️ Disclaimer

A personal pet project, not published on the App Store. Not investment advice. API tokens are read-only, stored in the device Keychain, and never sent anywhere except the exchange APIs.

---

<sub><b>Keywords:</b> iOS investment tracker · investment portfolio tracker · stock tracker · crypto portfolio · personal finance app · fintech · money management · Tinkoff Invest API · T-Invest · Bybit API · trading · SwiftUI finance app · SwiftData · Swift Charts · CryptoKit HMAC · MVVM · clean architecture · iPhone portfolio app</sub>
