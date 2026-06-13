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
