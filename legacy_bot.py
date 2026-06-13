"""
legacy_bot.py — архивный Telegram-бот InvestTGBot (объединённый в один файл).

Источник истины по бизнес-логике (T-Invest / Bybit fetch, PnL, доли).
Переписан на Swift в приложении InvestorPro/. Здесь оставлен как референс.

Зависимости: python-telegram-bot>=21.0, pybit>=5.0, python-dotenv>=1.0
Запуск:       python legacy_bot.py   (требует .env с токенами)

Файл собран из модулей: config, tbank_client, bybit_client, portfolio, formatters, main.
Внутренние импорты между модулями удалены — всё в одном пространстве имён.
"""


# ============================================================
# config.py
# ============================================================
import os
from dotenv import load_dotenv

load_dotenv()

TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")

# T-Bank аккаунты: label -> token
_raw_accounts = [
    (os.getenv("TBANK_LABEL_1", "Аккаунт 1"), os.getenv("TBANK_TOKEN_1")),
    (os.getenv("TBANK_LABEL_2", "Аккаунт 2"), os.getenv("TBANK_TOKEN_2")),
    (os.getenv("TBANK_LABEL_3", "Аккаунт 3"), os.getenv("TBANK_TOKEN_3")),
]
TBANK_ACCOUNTS = {label: token for label, token in _raw_accounts if token}

BYBIT_API_KEY    = os.getenv("BYBIT_API_KEY", "")
BYBIT_API_SECRET = os.getenv("BYBIT_API_SECRET", "")

_uid = os.getenv("ALLOWED_USER_ID", "0")
ALLOWED_USER_ID  = int(_uid) if _uid.isdigit() else 0


# ============================================================
# tbank_client.py
# ============================================================
"""
tbank_client.py
Получает данные по всем счетам всех аккаунтов T-Invest.
"""
import asyncio
import logging
from typing import Optional

log = logging.getLogger(__name__)


def _f(money) -> float:
    """MoneyValue / Quotation → float"""
    try:
        return float(money.units) + float(money.nano) / 1_000_000_000
    except Exception:
        return 0.0


INSTRUMENT_ICONS = {
    "share":    "📊",
    "bond":     "📄",
    "etf":      "🗂",
    "currency": "💱",
    "futures":  "📈",
    "option":   "⚙️",
}


async def _get_instrument_name(client, figi: str) -> tuple[str, str]:
    """Возвращает (name, ticker) по figi. При ошибке — figi."""
    try:
        resp = await client.instruments.get_instrument_by(
            id_type=1,   # FIGI
            id=figi
        )
        inst = resp.instrument
        return inst.name, inst.ticker
    except Exception:
        return figi, figi


async def _fetch_account_positions(client, account_id: str, account_name: str) -> dict:
    """Загружает все позиции одного брокерского счёта."""
    result = {
        "id":        account_id,
        "name":      account_name,
        "total_rub": 0.0,
        "positions": [],
        "error":     None,
    }
    try:
        portfolio = await client.operations.get_portfolio(account_id=account_id)
        result["total_rub"] = _f(portfolio.total_amount_portfolio)

        # Кэш имён инструментов — один запрос на figi
        name_tasks = [_get_instrument_name(client, p.figi) for p in portfolio.positions]
        names = await asyncio.gather(*name_tasks, return_exceptions=True)

        for pos, name_result in zip(portfolio.positions, names):
            if isinstance(name_result, Exception):
                inst_name, ticker = pos.figi, pos.figi
            else:
                inst_name, ticker = name_result

            qty         = _f(pos.quantity)
            cur_price   = _f(pos.current_price)
            avg_price   = _f(pos.average_position_price)
            exp_yield   = _f(pos.expected_yield)           # доход в рублях
            cur_value   = cur_price * qty if cur_price and qty else 0.0

            # % изменения от средней цены покупки
            pnl_pct = 0.0
            if avg_price and avg_price > 0:
                pnl_pct = (cur_price - avg_price) / avg_price * 100

            raw_type = str(pos.instrument_type).lower().replace("instrument_type_", "")
            icon     = INSTRUMENT_ICONS.get(raw_type, "•")

            result["positions"].append({
                "figi":            pos.figi,
                "ticker":          ticker,
                "name":            inst_name,
                "type":            raw_type,
                "icon":            icon,
                "qty":             qty,
                "cur_price":       cur_price,
                "avg_price":       avg_price,
                "cur_value":       cur_value,
                "exp_yield_rub":   exp_yield,
                "pnl_pct":         pnl_pct,
                "currency":        getattr(pos.current_price, "currency", "rub"),
            })

    except Exception as e:
        result["error"] = str(e)
        log.warning("Ошибка счёта %s: %s", account_id, e)

    return result


async def fetch_tbank_account(label: str, token: str) -> dict:
    """Загружает все счета одного аккаунта T-Bank."""
    result = {
        "label":     label,
        "total_rub": 0.0,
        "accounts":  [],
        "error":     None,
    }
    try:
        from t_tech.invest import AsyncClient  # noqa
        async with AsyncClient(token) as client:
            accounts_resp = await client.users.get_accounts()

            tasks = []
            for acc in accounts_resp.accounts:
                status = str(getattr(acc, "status", "")).upper()
                if "CLOSED" in status:
                    continue
                name = acc.name if acc.name else f"Счёт …{acc.id[-6:]}"
                tasks.append(_fetch_account_positions(client, acc.id, name))

            fetched = await asyncio.gather(*tasks, return_exceptions=True)
            for acc_data in fetched:
                if isinstance(acc_data, Exception):
                    continue
                result["accounts"].append(acc_data)
                result["total_rub"] += acc_data["total_rub"]

    except Exception as e:
        result["error"] = str(e)
        log.error("Ошибка аккаунта %s: %s", label, e)

    return result


async def fetch_all_tbank(tbank_accounts: dict) -> dict:
    """
    Параллельно загружает все 3 аккаунта.
    Возвращает:
        total_rub       — сумма по всем
        bank_accounts   — список аккаунтов
        merged          — позиции, сгруппированные по инструменту (для сводного экрана)
    """
    tasks = [fetch_tbank_account(label, token)
             for label, token in tbank_accounts.items()]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    out = {
        "total_rub":     0.0,
        "bank_accounts": [],
        "merged":        {},      # figi -> merged_position
    }

    for res in results:
        if isinstance(res, Exception):
            continue
        out["total_rub"] += res["total_rub"]
        out["bank_accounts"].append(res)

        # Сборка merged: суммируем одинаковые инструменты со всех аккаунтов
        for acc in res["accounts"]:
            for pos in acc["positions"]:
                figi = pos["figi"]
                if figi not in out["merged"]:
                    out["merged"][figi] = {
                        "figi":          figi,
                        "ticker":        pos["ticker"],
                        "name":          pos["name"],
                        "type":          pos["type"],
                        "icon":          pos["icon"],
                        "total_qty":     0.0,
                        "total_value":   0.0,
                        "total_yield":   0.0,   # рублей
                        "avg_price":     pos["avg_price"],
                        "cur_price":     pos["cur_price"],
                        "accounts_list": [],    # на каких счетах есть
                    }
                m = out["merged"][figi]
                m["total_qty"]   += pos["qty"]
                m["total_value"] += pos["cur_value"]
                m["total_yield"] += pos["exp_yield_rub"]
                m["accounts_list"].append(
                    f"{res['label']} / {acc['name']}"
                )

    # Считаем итоговый pnl% для merged (взвешенный)
    for m in out["merged"].values():
        invested = m["total_value"] - m["total_yield"]
        m["pnl_pct"] = (m["total_yield"] / invested * 100) if invested > 0 else 0.0

    return out


# ============================================================
# bybit_client.py
# ============================================================
"""
bybit_client.py
Получает баланс и позиции с Bybit (Unified Trading Account).
"""
import logging

log = logging.getLogger(__name__)

FALLBACK_USDT_RATE = 91.0


def fetch_bybit_data() -> dict:
    result = {
        "total_usdt": 0.0,
        "positions":  [],
        "error":      None,
    }

    if not BYBIT_API_KEY or not BYBIT_API_SECRET:
        result["error"] = "Bybit API ключи не настроены"
        return result

    try:
        from pybit.unified_trading import HTTP

        session = HTTP(
            api_key=BYBIT_API_KEY,
            api_secret=BYBIT_API_SECRET,
            recv_window=60000,   # было 20000 — расхождение ~31с, берём с запасом
            timeout=30,          # было не указано (дефолт 10с) — отсюда Read timeout
        )

        balance = session.get_wallet_balance(accountType="UNIFIED")
        coins   = balance["result"]["list"][0]["coin"]

        for coin_data in coins:
            usd_val = float(coin_data.get("usdValue") or 0)
            equity  = float(coin_data.get("equity")   or 0)
            if usd_val < 0.01:
                continue
            result["positions"].append({
                "coin":      coin_data["coin"],
                "equity":    equity,
                "usd_value": usd_val,
            })
            result["total_usdt"] += usd_val

    except Exception as e:
        result["error"] = str(e)
        log.error("Ошибка Bybit: %s", e)

    return result


def fetch_usdt_rub_rate() -> float:
    """Курс USD/RUB с сайта ЦБ РФ (XML API)."""
    try:
        import urllib.request
        import xml.etree.ElementTree as ET
        url = "https://www.cbr.ru/scripts/XML_daily.asp"
        with urllib.request.urlopen(url, timeout=10) as resp:
            tree = ET.parse(resp)
        for valute in tree.findall("Valute"):
            char_code = valute.find("CharCode")
            if char_code is not None and char_code.text == "USD":
                value = valute.find("Value").text.replace(",", ".")
                nominal = valute.find("Nominal").text
                rate = float(value) / float(nominal)
                log.info("Курс USD/RUB по ЦБ РФ: %.2f", rate)
                return rate
        return FALLBACK_USDT_RATE
    except Exception as e:
        log.warning("Не удалось получить курс ЦБ РФ: %s. Используем %.1f", e, FALLBACK_USDT_RATE)
        return FALLBACK_USDT_RATE


# ============================================================
# portfolio.py
# ============================================================
"""
portfolio.py
Собирает единый портфель из T-Bank + Bybit.
"""
import asyncio
from bybit_client  import fetch_bybit_data, fetch_usdt_rub_rate


async def get_full_portfolio() -> dict:
    """Параллельно запрашивает все источники и сводит в один объект."""
    loop = asyncio.get_event_loop()

    tbank_task  = fetch_all_tbank(TBANK_ACCOUNTS)
    bybit_task  = loop.run_in_executor(None, fetch_bybit_data)
    rate_task   = loop.run_in_executor(None, fetch_usdt_rub_rate)

    tbank_data, bybit_data, usdt_rate = await asyncio.gather(
        tbank_task, bybit_task, rate_task
    )

    bybit_rub  = bybit_data["total_usdt"] * usdt_rate
    total_rub  = tbank_data["total_rub"] + bybit_rub

    return {
        "total_rub":   total_rub,
        "tbank":       tbank_data,
        "bybit":       bybit_data,
        "bybit_rub":   bybit_rub,
        "usdt_rate":   usdt_rate,
        "tbank_share": tbank_data["total_rub"] / total_rub * 100 if total_rub else 0,
        "bybit_share": bybit_rub / total_rub * 100 if total_rub else 0,
    }


# ============================================================
# formatters.py
# ============================================================
"""
formatters.py
Все функции форматирования сообщений для Telegram.
Используем простой Markdown (не V2) — не требует экранирования.
"""

MAX_MSG = 3800


def _pnl_str(pct: float) -> str:
    icon = "🟢" if pct >= 0 else "🔴"
    sign = "+" if pct >= 0 else ""
    return f"{icon} {sign}{pct:.1f}%"


def _rub(v: float) -> str:
    return f"{v:,.0f} ₽".replace(",", " ")


def _split(text: str) -> list[str]:
    if len(text) <= MAX_MSG:
        return [text]
    parts, buf = [], ""
    for line in text.split("\n"):
        if len(buf) + len(line) + 1 > MAX_MSG:
            parts.append(buf)
            buf = ""
        buf += line + "\n"
    if buf:
        parts.append(buf)
    return parts


# ─────────────────────────────────────────────────────────────
#  ЭКРАН 1 — СВОДНЫЙ ПОРТФЕЛЬ
# ─────────────────────────────────────────────────────────────

def fmt_summary(data: dict) -> list[str]:
    tbank = data["tbank"]
    bybit = data["bybit"]
    rate  = data["usdt_rate"]
    total = data["total_rub"]

    lines = [
        "💼 Единый портфель — сводные позиции",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        f"💰 Всего: {_rub(total)}",
        f"   📈 T-Invest: {_rub(tbank['total_rub'])} ({data['tbank_share']:.1f}%)",
        f"   ₿  Bybit: {bybit['total_usdt']:,.0f} USDT = {_rub(data['bybit_rub'])} ({data['bybit_share']:.1f}%)",
        f"   💱 Курс USDT: {rate:.2f} ₽",
        "",
        "📊 Позиции T-Invest (все аккаунты)",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    ]

    merged = tbank["merged"]
    if not merged:
        lines.append("  — нет позиций")
    else:
        for m in sorted(merged.values(), key=lambda x: x["total_value"], reverse=True):
            pnl        = _pnl_str(m["pnl_pct"])
            yield_rub  = m["total_yield"]
            yield_sign = "+" if yield_rub >= 0 else ""
            accs       = ", ".join(m["accounts_list"])

            lines.append(f"{m['icon']} {m['name']}")
            lines.append(f"   💵 {_rub(m['total_value'])}  {pnl}  {yield_sign}{_rub(yield_rub)}")
            lines.append(f"   📦 кол-во: {m['total_qty']:.0f}  |  цена: {m['cur_price']:,.2f} ₽")
            lines.append(f"   🗂 {accs}")
            lines.append("")

    if bybit.get("positions"):
        lines += ["₿ Bybit — активы", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"]
        for pos in sorted(bybit["positions"], key=lambda x: x["usd_value"], reverse=True):
            rub_val = pos["usd_value"] * rate
            lines.append(
                f"  • {pos['coin']}: {pos['equity']:.4f}  |  "
                f"${pos['usd_value']:,.2f}  =  {_rub(rub_val)}"
            )

    return _split("\n".join(lines))


# ─────────────────────────────────────────────────────────────
#  ЭКРАН 2 — ПО АККАУНТАМ
# ─────────────────────────────────────────────────────────────

def fmt_by_accounts(data: dict) -> list[str]:
    tbank = data["tbank"]
    lines = [
        "🏦 Портфель по аккаунтам",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        f"📊 T-Invest итого: {_rub(tbank['total_rub'])}",
        "",
    ]

    for bank_acc in tbank["bank_accounts"]:
        lines.append(f"👤 {bank_acc['label']} — {_rub(bank_acc['total_rub'])}")

        if bank_acc.get("error"):
            lines.append(f"  ⚠️ Ошибка: {bank_acc['error']}")
            lines.append("")
            continue

        for acc in bank_acc["accounts"]:
            lines.append(f"  📂 {acc['name']} — {_rub(acc['total_rub'])}")
            if acc.get("error"):
                lines.append(f"    ⚠️ {acc['error']}")
            elif not acc["positions"]:
                lines.append("    — пустой счёт")
            else:
                for pos in sorted(acc["positions"], key=lambda x: x["cur_value"], reverse=True):
                    pnl = _pnl_str(pos["pnl_pct"])
                    y   = pos["exp_yield_rub"]
                    ys  = "+" if y >= 0 else ""
                    lines.append(
                        f"    {pos['icon']} {pos['name']}  |  "
                        f"{_rub(pos['cur_value'])}  |  {pnl}  {ys}{_rub(y)}"
                    )
            lines.append("")

    return _split("\n".join(lines))


# ─────────────────────────────────────────────────────────────
#  ЭКРАН 3 — ОДИН АККАУНТ ДЕТАЛЬНО
# ─────────────────────────────────────────────────────────────

def fmt_account_detail(bank_acc: dict) -> list[str]:
    lines = [
        f"👤 {bank_acc['label']} — {_rub(bank_acc['total_rub'])}",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    ]

    if bank_acc.get("error"):
        lines.append(f"⚠️ Ошибка подключения: {bank_acc['error']}")
        return lines

    for acc in bank_acc["accounts"]:
        lines.append(f"\n📂 {acc['name']} — {_rub(acc['total_rub'])}")
        if acc.get("error"):
            lines.append(f"  ⚠️ {acc['error']}")
        elif not acc["positions"]:
            lines.append("  — пустой счёт")
        else:
            for pos in sorted(acc["positions"], key=lambda x: x["cur_value"], reverse=True):
                pnl = _pnl_str(pos["pnl_pct"])
                y   = pos["exp_yield_rub"]
                ys  = "+" if y >= 0 else ""
                lines += [
                    f"  {pos['icon']} {pos['name']} ({pos['ticker']})",
                    f"     Кол-во: {pos['qty']:.0f}  |  Цена: {pos['cur_price']:,.2f} ₽  |  Ср.покупка: {pos['avg_price']:,.2f} ₽",
                    f"     Итого: {_rub(pos['cur_value'])}  |  {pnl}  {ys}{_rub(y)}",
                ]

    return _split("\n".join(lines))


# ─────────────────────────────────────────────────────────────
#  ЭКРАН 4 — BYBIT ДЕТАЛЬНО
# ─────────────────────────────────────────────────────────────

def fmt_bybit_detail(data: dict) -> list[str]:
    bybit = data["bybit"]
    rate  = data["usdt_rate"]

    lines = [
        "₿ Bybit — детали",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        f"💰 Итого: {bybit['total_usdt']:,.2f} USDT = {_rub(data['bybit_rub'])}",
        f"💱 Курс USDT/RUB: {rate:.2f} ₽",
        "",
    ]

    if bybit.get("error"):
        lines.append(f"⚠️ Ошибка: {bybit['error']}")
    elif bybit.get("positions"):
        for pos in sorted(bybit["positions"], key=lambda x: x["usd_value"], reverse=True):
            rub = pos["usd_value"] * rate
            lines.append(
                f"  • {pos['coin']}\n"
                f"    {pos['equity']:.6f}  |  ${pos['usd_value']:,.2f}  |  {_rub(rub)}"
            )
    else:
        lines.append("  — нет позиций")

    return _split("\n".join(lines))


# ─────────────────────────────────────────────────────────────
#  ЭКРАН 5 — СТРУКТУРА ПОРТФЕЛЯ ПО КЛАССАМ АКТИВОВ
# ─────────────────────────────────────────────────────────────

TYPE_CLASS = {
    "share":    ("📊 Акции",     "share"),
    "bond":     ("📄 Облигации", "bond"),
    "etf":      ("🗂 Фонды",     "etf"),
    "currency": ("💱 Валюта",    "currency"),
    "futures":  ("📈 Фьючерсы",  "futures"),
}


def _bar(pct: float, width: int = 12) -> str:
    filled = round(pct / 100 * width)
    return "█" * filled + "░" * (width - filled)


def fmt_structure(data: dict) -> list[str]:
    total  = data["total_rub"]
    tbank  = data["tbank"]
    bybit  = data["bybit"]
    rate   = data["usdt_rate"]
    merged = tbank["merged"]

    if total <= 0:
        return ["Нет данных для отображения структуры"]

    classes: dict[str, dict] = {}

    for m in merged.values():
        raw_type = m.get("type", "")
        label, key = TYPE_CLASS.get(raw_type, ("Прочее", "other"))
        if key not in classes:
            classes[key] = {"label": label, "total": 0.0, "positions": []}
        classes[key]["total"] += m["total_value"]
        classes[key]["positions"].append({
            "name":  m["name"],
            "value": m["total_value"],
            "pnl":   m["pnl_pct"],
        })

    crypto_total = 0.0
    crypto_positions = []
    for pos in bybit.get("positions", []):
        rub_val = pos["usd_value"] * rate
        crypto_total += rub_val
        crypto_positions.append({"name": pos["coin"], "value": rub_val, "pnl": 0.0})

    if crypto_total > 0:
        classes["crypto"] = {
            "label":     "₿ Крипта",
            "total":     crypto_total,
            "positions": crypto_positions,
        }

    sorted_classes = sorted(classes.values(), key=lambda x: x["total"], reverse=True)

    lines = [
        "📐 Структура портфеля",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        f"Всего: {_rub(total)}",
        "",
    ]

    for cls in sorted_classes:
        pct = cls["total"] / total * 100
        bar = _bar(pct)
        lines.append(f"{cls['label']}")
        lines.append(f"   {bar}  {pct:.1f}%  —  {_rub(cls['total'])}")
        for pos in sorted(cls["positions"], key=lambda x: x["value"], reverse=True):
            pos_pct = pos["value"] / total * 100
            pnl_str = f"  {_pnl_str(pos['pnl'])}" if pos["pnl"] != 0.0 else ""
            name = pos["name"][:28]
            lines.append(f"   • {name:<28} {pos_pct:5.1f}%   {_rub(pos['value'])}{pnl_str}")
        lines.append("")

    return _split("\n".join(lines))


# ============================================================
# main.py
# ============================================================
"""
main.py — Portfolio Bot
"""
import logging

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    CallbackQueryHandler,
    ContextTypes,
)


logging.basicConfig(
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    level=logging.INFO,
)
log = logging.getLogger(__name__)


def kb_main() -> InlineKeyboardMarkup:
    rows = [
        [InlineKeyboardButton("💼 Сводный портфель", callback_data="summary")],
        [InlineKeyboardButton("🏦 По аккаунтам",     callback_data="by_accounts")],
    ]
    for i, label in enumerate(TBANK_ACCOUNTS.keys()):
        rows.append([InlineKeyboardButton(f"👤 {label}", callback_data=f"acc_{i}")])
    rows.append([InlineKeyboardButton("📐 Структура портфеля", callback_data="structure")])
    rows.append([InlineKeyboardButton("₿ Bybit",         callback_data="bybit")])
    rows.append([InlineKeyboardButton("🔄 Обновить всё", callback_data="summary")])
    return InlineKeyboardMarkup(rows)


def kb_back() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([[InlineKeyboardButton("◀️ Назад", callback_data="back_main")]])


def auth(func):
    async def wrapper(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
        uid = update.effective_user.id if update.effective_user else 0
        if uid != ALLOWED_USER_ID:
            if update.message:
                await update.message.reply_text("Доступ запрещён")
            return
        return await func(update, ctx)
    return wrapper


async def send_blocks(target, blocks, reply_markup=None):
    for i, block in enumerate(blocks):
        markup = reply_markup if i == len(blocks) - 1 else None
        await target.reply_text(block, reply_markup=markup, disable_web_page_preview=True)


async def edit_then_send(query, blocks, reply_markup=None):
    await query.edit_message_text(blocks[0], disable_web_page_preview=True)
    for block in blocks[1:]:
        await query.message.reply_text(block, disable_web_page_preview=True)
    if reply_markup:
        await query.message.reply_text("Меню:", reply_markup=reply_markup)


@auth
async def cmd_start(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "Portfolio Bot — единый трекер инвестиций\n\n"
        "/p — сводный портфель\n"
        "/accounts — по аккаунтам\n"
        "/bybit — Bybit\n"
        "/help — справка",
        reply_markup=kb_main()
    )


@auth
async def cmd_portfolio(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("Загружаю данные...")
    data = await get_full_portfolio()
    await msg.delete()
    await send_blocks(update.message, fmt_summary(data), reply_markup=kb_main())


@auth
async def cmd_accounts(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("Загружаю...")
    data = await get_full_portfolio()
    await msg.delete()
    await send_blocks(update.message, fmt_by_accounts(data), reply_markup=kb_main())


@auth
async def cmd_bybit(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("Загружаю...")
    data = await get_full_portfolio()
    await msg.delete()
    await send_blocks(update.message, fmt_bybit_detail(data), reply_markup=kb_back())


@auth
async def cmd_structure(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("Загружаю структуру портфеля...")
    data = await get_full_portfolio()
    await msg.delete()
    await send_blocks(update.message, fmt_structure(data), reply_markup=kb_main())


@auth
async def cmd_help(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "Portfolio Bot — справка\n\n"
        "Сводный портфель — одинаковые инструменты со всех аккаунтов объединены в одну строку\n\n"
        "По аккаунтам — Аккаунт -> Счёт -> Позиции\n\n"
        "PnL считается от средней цены покупки\n"
        "Курс USDT/RUB — с Bybit spot",
        reply_markup=kb_main()
    )


async def btn_handler(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    try:
        await query.answer()
    except Exception:
        pass

    if query.from_user.id != ALLOWED_USER_ID:
        return

    data_key = query.data
    try:
        await query.edit_message_text("Загружаю данные...")
    except Exception:
        pass

    portfolio = await get_full_portfolio()

    if data_key == "summary":
        await edit_then_send(query, fmt_summary(portfolio), reply_markup=kb_main())
    elif data_key == "by_accounts":
        await edit_then_send(query, fmt_by_accounts(portfolio), reply_markup=kb_main())
    elif data_key.startswith("acc_"):
        idx = int(data_key.split("_")[1])
        bank_accs = portfolio["tbank"]["bank_accounts"]
        blocks = fmt_account_detail(bank_accs[idx]) if idx < len(bank_accs) else ["Аккаунт не найден"]
        await edit_then_send(query, blocks, reply_markup=kb_main())
    elif data_key == "structure":
        await edit_then_send(query, fmt_structure(portfolio), reply_markup=kb_main())

    elif data_key == "bybit":
        await edit_then_send(query, fmt_bybit_detail(portfolio), reply_markup=kb_main())
    elif data_key == "back_main":
        try:
            await query.edit_message_text("Выбери раздел:", reply_markup=kb_main())
        except Exception:
            await query.message.reply_text("Выбери раздел:", reply_markup=kb_main())


def main():
    if not TELEGRAM_TOKEN:
        raise SystemExit("TELEGRAM_BOT_TOKEN не задан в .env")
    if not ALLOWED_USER_ID:
        raise SystemExit("ALLOWED_USER_ID не задан в .env")

    from telegram.request import HTTPXRequest
    request = HTTPXRequest(connect_timeout=30, read_timeout=60)
    app = ApplicationBuilder().token(TELEGRAM_TOKEN).request(request).build()

    app.add_handler(CommandHandler("start",     cmd_start))
    app.add_handler(CommandHandler("p",         cmd_portfolio))
    app.add_handler(CommandHandler("portfolio", cmd_portfolio))
    app.add_handler(CommandHandler("accounts",  cmd_accounts))
    app.add_handler(CommandHandler("structure", cmd_structure))
    app.add_handler(CommandHandler("bybit",     cmd_bybit))
    app.add_handler(CommandHandler("help",      cmd_help))
    app.add_handler(CallbackQueryHandler(btn_handler))

    log.info("Portfolio Bot запущен.")
    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()
