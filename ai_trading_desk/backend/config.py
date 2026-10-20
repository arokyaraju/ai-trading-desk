import os
from pydantic import BaseModel
from dotenv import load_dotenv

# Load environment variables from .env if present
load_dotenv()

class Settings(BaseModel):
    # App Settings
    APP_NAME: str = "AI Trading Desk"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "False").lower() in ("true", "1")
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    SECRET_KEY: str = os.getenv("SECRET_KEY", "institution_grade_ai_desk_secret_token_2026")
    
    # Database Settings: PostgreSQL with fallback to SQLite for local ease
    # e.g., postgresql+asyncpg://user:password@localhost:5432/trading_desk
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL", 
        "postgresql+asyncpg://postgres:postgres@localhost:5432/trading_desk"
    )
    SQLITE_FALLBACK_URL: str = "sqlite+aiosqlite:///./data/trading_desk.db"
    
    # FYERS Settings
    FYERS_APP_ID: str = os.getenv("FYERS_APP_ID", "77WFZ67AWG-200")
    FYERS_SECRET_KEY: str = os.getenv("FYERS_SECRET_KEY", "PGLvsC6gLCFjJjA4")
    FYERS_TOKEN_PATH: str = os.getenv(
        "FYERS_TOKEN_PATH", 
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "bridge", "access_token.txt")
    )
    FYERS_ACCESS_TOKEN: str = os.getenv("FYERS_ACCESS_TOKEN", "")
    
    # Risk Management Defaults
    DEFAULT_RISK_PER_TRADE_INR: float = float(os.getenv("RISK_PER_TRADE_INR", "1000.0"))
    MAX_DAILY_LOSS_INR: float = float(os.getenv("MAX_DAILY_LOSS_INR", "5000.0"))
    MAX_OPEN_POSITIONS: int = int(os.getenv("MAX_OPEN_POSITIONS", "5"))
    MIN_RISK_REWARD: float = float(os.getenv("MIN_RISK_REWARD", "1.5"))

settings = Settings()
