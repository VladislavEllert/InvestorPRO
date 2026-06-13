"""
portfolio.py
Собирает единый портфель из T-Bank + Bybit.
"""
import asyncio
from tbank_client import fetch_all_tbank
from bybit_client  import fetch_bybit_data, fetch_usdt_rub_rate
from config import TBANK_ACCOUNTS


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
