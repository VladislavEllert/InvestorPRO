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