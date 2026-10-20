"""
AI Trading Desk - Application Entry Point
FastAPI app with database initialization, background periodic market cycles,
and static frontend hosting.
"""

import os
import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import settings
from .database import init_db, AsyncSessionLocal
from .api.routes import router, ws_manager
from .agents.manager import manager
from .fyers.gateway import gateway
from .fyers.symbols import BENCHMARK_NIFTY, SECTOR_INDICES, SECTOR_CONSTITUENTS, get_fyers_symbol

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("ai_trading_desk")

# Background ticker loop
async def background_market_scanner():
    """Periodically triggers market sweeps and pushes live updates to WebSocket clients."""
    logger.info("Starting background market scanner loop...")
    symbols_to_fetch = [BENCHMARK_NIFTY["fyers"]] + [s["fyers"] for s in SECTOR_INDICES]
    for constituents in SECTOR_CONSTITUENTS.values():
        for s in constituents:
            symbols_to_fetch.append(get_fyers_symbol(s))

    while True:
        try:
            await asyncio.sleep(15) # Sweep every 15 seconds
            quotes = gateway.fetch_quotes_batch(symbols_to_fetch)

            hist_levels = {}
            weekly_levels = {}
            for sym, q in quotes.items():
                p = q.get("price", 1000.0)
                hist_levels[sym] = {
                    "pdh": round(p * 1.015, 2),
                    "pdl": round(p * 0.985, 2),
                    "pdc": round(p * 0.998, 2)
                }
                weekly_levels[sym] = {
                    "pwh": round(p * 1.03, 2),
                    "pwl": round(p * 0.97, 2),
                    "pwc": round(p * 0.995, 2)
                }

            if AsyncSessionLocal:
                async with AsyncSessionLocal() as session:
                    res = await manager.run_market_cycle(session, quotes, hist_levels, weekly_levels)
                    await ws_manager.broadcast({"type": "MARKET_CYCLE_UPDATE", "data": res})
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error(f"Error in background market scanner: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing AI Trading Desk database...")
    await init_db()
    scanner_task = asyncio.create_task(background_market_scanner())
    yield
    scanner_task.cancel()
    try:
        await scanner_task
    except asyncio.CancelledError:
        pass
    logger.info("AI Trading Desk shutdown complete.")

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    lifespan=lifespan
)

# CORS configuration for secure web access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(router)

# Mount frontend directory for browser dashboard
frontend_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "frontend")
if os.path.exists(frontend_dir):
    app.mount("/", StaticFiles(directory=frontend_dir, html=True), name="frontend")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("ai_trading_desk.backend.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
