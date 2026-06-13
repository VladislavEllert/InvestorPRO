# InvestorPro

Личный трекер инвестиций — iOS-приложение (SwiftUI, Xcode) в `InvestorPro/`.

Логика тянуть данные T-Invest / Bybit и считать PnL/доли изначально отрабатывалась в
старом Python Telegram-боте (удалён из репо), теперь полностью на Swift.

## Что делает приложение
- Пользователь в настройках добавляет аккаунты по API-токену (T-Invest x N, Bybit).
- Главная: donut активов, сумма в центре, разбивка по %, плитки Аналитика/Графики/История/Заметки.
- Аналитика: срезы Активы / Компании / Отрасли / Валюта (donut + легенда), 1:1 с референсом Т-Банка.
- Графики: стоимость портфеля по времени (Месяц/Полгода/Год, колонки⇄кривая) + статистика движения средств.
- История сделок, Заметки (импорт/экспорт Notion), темы light/dark, RUB/USD, авто/ручное обновление.
- Работает локально на iPhone (sideload, без App Store, без своего сервера).

## Принципы кода (соблюдать строго)
- **SOLID**: брокеры за общим протоколом `BrokerProvider` (OCP — новый брокер = новый класс, без правок существующих). Слои не знают друг о друге сверху вниз.
- **DRY**: общие форматтеры, мапперы, утилиты — один раз. Не дублировать логику долей/PnL.
- **KISS**: простейшее решение, которое работает. Без лишних абстракций «на будущее».
- **Чистая архитектура**: `Domain` (модели + протоколы, без UIKit/сети) ← `Data` (сеть, БД, Keychain) ← `Presentation` (SwiftUI + ViewModels). Зависимости направлены к Domain.
- **Минимум зависимостей**: только системные фреймворки — URLSession, CryptoKit, SwiftData, Swift Charts. Никаких сторонних SDK без явной необходимости.
- Секреты (токены) — только в Keychain, никогда в UserDefaults/файлах/гите.

## Структура iOS
```
InvestorPro/InvestorPro/
  App/           точка входа, AppSettings (тема/валюта/частота)
  Domain/        Models, Providers (протоколы), Services, Sample (временные данные)
  Data/          Network (REST), Persistence (SwiftData), Security (Keychain), Notion
  Presentation/  Home, Analytics, Charts, Trades, Notes, Settings, Components, Theme
```
Xcode-проект использует file-system-synchronized groups: файлы на диске подхватываются
автоматически, перечислять их в `project.pbxproj` не нужно.

## Сборка и запуск
```
cd InvestorPro
xcodebuild -scheme InvestorPro -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Запуск в симуляторе → скриншоты на аппрув UI/UX (светлая + тёмная тема) после каждого крупного шага.
Деплой на устройство: открыть в Xcode, выбрать Team (личный Apple ID), Run. Бесплатная подпись живёт ~7 дней.

## Источники данных (REST, переписано с Python)
- T-Invest: `https://invest-public-api.tinkoff.ru/rest/` (Bearer-токен, read-only).
- Bybit v5: `https://api.bybit.com/v5/...` (HMAC-SHA256, CryptoKit).
- Курс USD/RUB: ЦБ РФ `https://www.cbr.ru/scripts/XML_daily.asp`.

## Память проекта
Текущее состояние, задачи и решения — в `memory-bank/`. Читать при входе в проект.
План реализации: `~/.claude/plans/sprightly-orbiting-quilt.md`.
