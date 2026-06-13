"""
bybit_client.py
Получает баланс и позиции с Bybit (Unified Trading Account).
"""
import logging
from config import BYBIT_API_KEY, BYBIT_API_SECRET

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