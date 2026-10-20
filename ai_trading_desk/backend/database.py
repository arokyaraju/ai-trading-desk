import os
import logging
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from .config import settings
from .models.schema import Base

logger = logging.getLogger("ai_trading_desk.database")

# Ensure local data directory exists for fallback or local files
os.makedirs("data", exist_ok=True)

# Select engine URL
engine = None
AsyncSessionLocal = None
ACTIVE_DB_TYPE = "UNKNOWN"

async def init_db():
    global engine, AsyncSessionLocal, ACTIVE_DB_TYPE
    
    # 1. Attempt connection using configured DATABASE_URL (PostgreSQL)
    target_url = settings.DATABASE_URL
    if target_url.startswith("postgres://"):
        target_url = target_url.replace("postgres://", "postgresql+asyncpg://", 1)
    elif target_url.startswith("postgresql://") and "+asyncpg" not in target_url:
        target_url = target_url.replace("postgresql://", "postgresql+asyncpg://", 1)
        
    try:
        if "postgres" in target_url:
            logger.info(f"Connecting to PostgreSQL database: {target_url.split('@')[-1] if '@' in target_url else target_url}")
            test_engine = create_async_engine(target_url, echo=False, pool_pre_ping=True)
            async with test_engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            engine = test_engine
            ACTIVE_DB_TYPE = "POSTGRESQL"
            logger.info("Successfully connected to PostgreSQL and initialized tables.")
    except Exception as e:
        logger.warning(f"PostgreSQL connection failed ({e}). Falling back to local SQLite for local runtime: {settings.SQLITE_FALLBACK_URL}")
        ACTIVE_DB_TYPE = "SQLITE_FALLBACK"
        engine = create_async_engine(
            settings.SQLITE_FALLBACK_URL,
            echo=False,
            connect_args={"check_same_thread": False}
        )
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Local database initialized with complete schema.")

    if engine is None:
        ACTIVE_DB_TYPE = "SQLITE_FALLBACK"
        engine = create_async_engine(
            settings.SQLITE_FALLBACK_URL,
            echo=False,
            connect_args={"check_same_thread": False}
        )
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    AsyncSessionLocal = async_sessionmaker(
        bind=engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False
    )

def get_active_db_type() -> str:
    return ACTIVE_DB_TYPE

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI database session dependency."""
    if AsyncSessionLocal is None:
        await init_db()
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
