<div align="center">

# 📈 InvestorPro

**Личный трекер инвестиций для iPhone. Весь портфель — T-Invest и Bybit — в одном нативном приложении.**

*Native iOS investment portfolio tracker (SwiftUI) for Tinkoff Invest & Bybit — assets, analytics, value & return charts, trade history. Stocks & crypto, personal finance, fully local on iPhone.*

![iOS](https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-2396F3?logo=swift&logoColor=white)
![SwiftData](https://img.shields.io/badge/Persistence-SwiftData-blue)
![Swift Charts](https://img.shields.io/badge/Charts-Swift%20Charts-orange)
![No 3rd-party](https://img.shields.io/badge/dependencies-system%20only-success)

</div>

---

## 💡 Зачем

Раньше портфель жил в Telegram-боте на Python: команды, текстовые сводки, поднятый сервер. Неудобно и несовременно. **InvestorPro** переносит и расширяет эту логику в нативное iOS-приложение: красиво, быстро, прямо в руке — и **без сервера**. Все запросы к биржам уходят прямо с телефона, данные хранятся локально.

Бизнес-логика (как тянуть данные T-Invest / Bybit, как считать PnL и доли) выверена в старом боте — он оставлен в репозитории как референс.

## ✨ Возможности

- 🔑 **Аккаунты по API-токенам** — несколько счетов T-Invest + Bybit. Токены только в Keychain.
- 🍩 **Главная** — donut активов, сумма в центре, разбивка по %, переключатель ₽/$.
- 📊 **Аналитика** — четыре среза: **Активы / Компании / Отрасли / Валюта** (donut + легенда), 1:1 со стилем Т-Банка.
- 📈 **Графики** — стоимость портфеля во времени: **колонки ⇄ кривая**, периоды Месяц / Полгода / Год / Всё время, горизонтальный скролл, тап по точке. Сумма постоянна, меняются окно и статистика.
- 💸 **Статистика движения средств** — доходность, дивиденды, купоны, оборот, пополнения за выбранный период.
- 🧾 **История сделок** — операции по датам с типами (покупка, продажа, дивиденды, купоны, комиссии).
- 🌗 **Темы** — светлая / тёмная / системная.
- 🔄 **Обновление** — вручную, авто каждый час или раз в день.

## 🏗 Архитектура

Чистая архитектура, MVVM, зависимости направлены к Domain. Только системные фреймворки — никаких сторонних SDK.

```
InvestorPro/InvestorPro/
├── App/            точка входа, AppSettings (тема/валюта/частота)
├── Domain/         модели + протоколы (без UIKit/сети)
│   ├── Models/     Account, Position, AssetClass, Portfolio, Operation, Snapshot…
│   ├── Providers/  BrokerProvider (OCP: новый брокер = новый класс)
│   └── Services/   PortfolioAggregator, PortfolioStore
├── Data/
│   ├── Network/    TInvestClient, BybitClient, CBRClient
│   ├── Security/   KeychainStore (секреты)
│   └── Persistence (SwiftData: снимки, кэш инструментов, аккаунты)
└── Presentation/   Home, Analytics, Charts, Trades, Settings, Components, Theme
```

**Принципы:** SOLID · DRY · KISS · минимум зависимостей · секреты только в Keychain.

## 🧰 Технологии

`SwiftUI` · `Swift Charts` · `SwiftData` · `URLSession (async/await)` · `CryptoKit (HMAC)` · `Keychain`

## 🔌 Источники данных

| Источник | Что | Авторизация |
|---|---|---|
| **T-Invest** | счета, портфель, инструменты, операции | Bearer-токен (read-only) |
| **Bybit v5** | баланс Unified-аккаунта | API key + secret, HMAC-SHA256 |
| **ЦБ РФ** | курс USD/RUB | публичный XML |

> История стоимости портфеля копится локально (снимок при каждом обновлении) — графики растут со временем работы приложения.

## 🚀 Сборка и запуск

```bash
cd InvestorPro
xcodebuild -scheme InvestorPro -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**На устройство (iPhone):** открыть `InvestorPro/InvestorPro.xcodeproj` в Xcode → выбрать Team (личный Apple ID) → Run. Бесплатная подпись живёт ~7 дней.

**Подключить свои счета:** Настройки → Аккаунты → `+` → токен(ы). Pull-to-refresh подтянет портфель.

## 🗺 Roadmap

- [ ] Заметки с импортом/экспортом в Notion
- [ ] AI-ассистент по портфелю (ProxyAPI: анализ, советы, мультичаты)
- [ ] Настоящее фоновое обновление (BGAppRefreshTask)
- [ ] Виджеты и Face ID на вход

## ⚠️ Дисклеймер

Личный pet-проект, не публикуется в App Store. Не является инвестиционной рекомендацией. API-токены используются только для чтения, хранятся в Keychain устройства и никуда, кроме API бирж, не отправляются.

---

<div align="center">

*Старый Telegram-бот на Python (`legacy_bot.py`) оставлен как референс бизнес-логики.*

</div>

---

<sub><b>Keywords:</b> iOS investment tracker · investment portfolio tracker · stock tracker · crypto portfolio · personal finance app · fintech · money management · Tinkoff Invest API · T-Invest · Bybit API · trading · SwiftUI finance app · SwiftData · Swift Charts · CryptoKit HMAC · MVVM · clean architecture · iPhone portfolio app</sub>
