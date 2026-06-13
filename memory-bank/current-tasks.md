# Current Tasks

План целиком: `~/.claude/plans/sprightly-orbiting-quilt.md` (9 шагов).

## Сделано
- [x] Шаг 1: Каркас Xcode-проекта + репо-артефакты. Сборка зелёная, BUILD SUCCEEDED.
      Скриншоты приняты: Home (свет+тьма), Аналитика (Активы/Компании), Графики (колонки/кривая).

## Фидбэк юзера (обработан)
- [x] Charts Y-ось резалась о левый край → компактные подписи + отступ. Фикс внесён, подтверждён.
- [+] Новая фича: AI-ассистент (ProxyAPI чат, контекст портфеля, вердикт, мультичаты, выбор
      модели, редакт. системный промпт, опц. Notion). Порт из репо AgentChat. → шаг 9.

- [x] Шаг 2: Domain (BrokerKind, AccountConfig@Model, AssetClass, Position, BrokerAccountPortfolio),
      BrokerProvider, KeychainStore, SwiftData (AppSchema.models), экран Аккаунты (CRUD), форма
      динамична по credentialFields (T-Инвест=токен, Bybit=key+secret). Проверено.

- [x] Шаг 3: CBRClient (XML курс), TInvestClient (REST Bearer), BybitClient (HMAC CryptoKit),
      TInvestProvider/BybitProvider, PortfolioAggregator (параллель, мерж по figi, срезы),
      PortfolioStore (@MainActor, live-курс), Home+Analytics на реальных данных или демо.
      AccountSnapshot для thread-safe передачи. Сборка зелёная. Live-тест ждёт токенов юзера.

- [x] Шаг 4: InstrumentMeta@Model + InstrumentMetaCollector (actor), cache-first резолв имён/секторов,
      персист новых figi. SectorNames маппинг. Срезы Аналитики на store.
- [x] Шаг 5: PortfolioSnapshot@Model, запись при refresh (дедуп по дню), ChartsView читает снимки
      (@Query) с fallback на демо. Статистика движения пока демо (ждёт операций, шаг 6).

- [x] Шаг 6: Operation модель + OperationType, TInvestClient.getOperations, BrokerProvider.fetchOperations
      (дефолт [] для Bybit), TInvestProvider операции, агрегатор тянет операции (12 мес), Portfolio.operations
      + movementStats, экран История сделок (секции по датам, цветные типы), Charts статистика из store.

- [x] Шаг 8: Авто-обновление foreground по интервалу (settings.refreshInterval.seconds, scenePhase
      .active → refresh если прошло время). Плитки Заметки/Ассистент убраны с главной (отложены).
      Светлая+тёмная темы проверены на всех экранах.

## Отложено в backlog (решение юзера)
- Заметки + Notion sync (не раздуваем; юзер ведёт в Notion).
- AI-ассистент ProxyAPI (порт из AgentChat) — «ласточка», сделаем если понадобится.
- BGAppRefreshTask настоящий фон — нужен кастомный Info.plist + платный аккаунт.

## Charts концепция (фидбэк юзера, готово)
Сумма портфеля ПОСТОЯННА по всем периодам (= currentTotalRub = totalRub/SampleData.total).
Один непрерывный ряд (fullSeriesRub: снимки или sample, заякорен на текущую сумму), период = окно.
Δ и статистика движения считаются по выбранному окну (фильтр операций по cutoff).
Доходность = ОДНА величина profitabilityRub = (изменение стоимости − чистые пополнения),
включает рост/дивиденды/купоны. Шапка под суммой и строка «Доходность» в статистике
показывают ОДНО И ТО ЖЕ число (фидбэк юзера). Добавлен период «Всё время».

## Фичи после MVP (готово, на реальных данных)
- [x] Home: изменение за сегодня (− чистые пополнения, честно) + «обновлено в HH:mm».
- [x] По аккаунтам: плитка → аккаунт → позиции (PositionsDetailView с title).
- [x] Фильтр истории: по аккаунту и типу (toolbar Menu Picker).
- [x] Face ID/код на вход: RootView + LocalAuthentication, тоггл Настройки→Безопасность,
      INFOPLIST_KEY_NSFaceIDUsageDescription в pbxproj.
- [x] Будущие выплаты: GetDividends + GetBondCoupons (per-unit × qty, год вперёд),
      бар по месяцам + список по датам. PayoutsService, DividendsView, плитка.
- [x] PDF-экспорт: PDFReport (UIGraphicsPDFRenderer) + ActivityView, Настройки→Отчёт.
      Заодно: починена мёртвая кнопка «Обновить сейчас», убрана Notion-заглушка.

## Заблокировано (бесплатный Apple ID / нужен ввод)
- iCloud-синк (#15): CloudKit = платный Developer + запрещает @Attribute(.unique)
  (AccountConfig/InstrumentMeta). Не делаем до платного аккаунта.
- Виджет (#16): новый target + App Group (платный аккаунт), риск сломать ручной pbxproj.
- Bybit фьючерсы/фандинг (#18): нужны /v5/position/list и т.п.; уточнить, торгует ли юзер
  фьючерсами (для спота будет пусто). Спот-монеты уже видны в «По аккаунтам».

## MVP готов
Шаги 1-6, 8 + переделанный график. Работает на демо-данных; реальные — после ввода токенов.
Главная (donut+плитки), Аналитика (4 среза), Графики (бар/кривая/скролл/скраббинг/Δ),
История сделок, Настройки (аккаунты+Keychain, тема, валюта, частота). Обе темы.
- [ ] Шаг 4: Аналитика — 4 среза + кэш метаданных инструментов (SwiftData).
- [ ] Шаг 5: Snapshots + Графики (колонки⇄кривая) + статистика движения + backfill-реконструкция.
- [ ] Шаг 6: История сделок.
- [ ] Шаг 7: Заметки + Notion sync.
- [ ] Шаг 8: Авто-обновление (BGAppRefreshTask) + RUB/USD везде + полировка тем.

## Текущее состояние кода
Шаг 1 в процессе. Экраны на временных данных `SampleData` (помечено, удалить на шаге 3).
UI: Home (donut+плитки), Analytics (4 среза), Charts (бар/кривая+статистика), Settings
(тема/валюта/частота работают), Trades/Notes — заглушки.

Charts переделан (фидбэк юзера, готово): недельные бакеты (Месяц=день, Полгода/Год=неделя),
headroom по Y ×1.15, горизонтальный скролл (chartScrollableAxes + chartXVisibleDomain +
chartScrollPosition), стартует с конца, заголовок сумма+Δ за период, area-градиент,
скраббинг (chartXSelection → RuleMark+PointMark), чистые X-метки (месячный stride).
Демо-данные детерминированы (не мерцают). Юзер дотестит на реальном API позже.
