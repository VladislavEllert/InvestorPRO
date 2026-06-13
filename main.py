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

from config import TELEGRAM_TOKEN, ALLOWED_USER_ID, TBANK_ACCOUNTS
from portfolio import get_full_portfolio
from formatters import fmt_summary, fmt_by_accounts, fmt_account_detail, fmt_bybit_detail, fmt_structure

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