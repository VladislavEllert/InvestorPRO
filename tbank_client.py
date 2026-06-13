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