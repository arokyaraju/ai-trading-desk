"""
FastAPI REST Routes and WebSocket Dispatcher
Provides web dashboard endpoints, agent monitoring, real trade manual recording,
journal management, and live WebSocket streaming.
"""

import json
import logging
from typing import Dict, List, Any, Optional
from pydantic import BaseModel
from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..database import get_db, get_active_db_type
from ..fyers.gateway import gateway
from ..fyers.symbols import SECTOR_INDICES, BENCHMARK_NIFTY, SECTOR_CONSTITUENTS, get_fyers_symbol
from ..agents.manager import manager
from ..models.schema import RealTrade, TradePlan, TradeCandidate, DailyJournal, ResearchReport, AuditLog
from ..mcp.mcp_server import mcp_server

router = APIRouter()
logger = logging.getLogger("ai_trading_desk.routes")

# Active WebSocket dashboard connections
active_connections: List[WebSocket] = []

class ConnectionManager:
    @staticmethod
    async def connect(websocket: WebSocket):
        await websocket.accept()
        active_connections.append(websocket)

    @staticmethod
    def disconnect(websocket: WebSocket):
        if websocket in active_connections:
            active_connections.remove(websocket)

    @staticmethod
    async def broadcast(message: Dict[str, Any]):
        for connection in list(active_connections):
            try:
                await connection.send_text(json.dumps(message))
            except Exception:
                pass

ws_manager = ConnectionManager()

class TokenUpdateRequest(BaseModel):
    token: str

class RealTradeCreateRequest(BaseModel):
    symbol: str
    direction: str  # BUY, SELL
    entry_price: float
    quantity: int
    initial_sl: float
    broker_order_id: Optional[str] = None
    notes: Optional[str] = None

class MCPToolCallRequest(BaseModel):
    tool_name: str
    arguments: Dict[str, Any] = {}

# --- Routes ---

@router.post("/api/update-token")
async def update_fyers_token(payload: TokenUpdateRequest):
    """Updates FYERS access token in memory and persists to disk."""
    success = gateway.update_token(payload.token)
    await ws_manager.broadcast({
        "type": "TOKEN_UPDATED",
        "message": "Fresh FYERS token activated successfully!"
    })
    return {"status": "success" if success else "error", "message": "Token updated"}

@router.get("/api/auth/login-url")
async def get_fyers_login_url():
    """Returns direct FYERS OAuth login URL."""
    client_id = gateway.app_id
    redirect_uri = "http://127.0.0.1:8080/auth"
    url = f"https://api-t1.fyers.in/api/v3/generate-authcode?client_id={client_id}&redirect_uri={redirect_uri}&response_type=code&state=market_watch"
    return {"login_url": url, "app_id": client_id, "redirect_uri": redirect_uri}

@router.get("/api/status")
async def get_system_status():
    """Returns engine health, database status, and FYERS connection mode."""
    token_loaded = gateway.token is not None and len(gateway.token) > 20
    return {
        "status": "ONLINE",
        "app_name": "AI Trading Desk",
        "version": "1.0.0",
        "active_database": get_active_db_type(),
        "fyers_gateway": {
            "token_loaded": token_loaded,
            "cached_quotes_count": len(gateway.live_quotes),
            "simulated_mode": not token_loaded
        },
        "connected_clients": len(active_connections)
    }

@router.post("/api/cycle/run")
async def run_full_scan_cycle(db: AsyncSession = Depends(get_db)):
    """Triggers an instantaneous coordinated scan across all 11 agents."""
    # Gather all watched symbols: Nifty, Sectors, and F&O Constituents
    symbols_to_fetch = [BENCHMARK_NIFTY["fyers"]] + [s["fyers"] for s in SECTOR_INDICES]
    for constituents in SECTOR_CONSTITUENTS.values():
        for s in constituents:
            symbols_to_fetch.append(get_fyers_symbol(s))

    quotes = gateway.fetch_quotes_batch(symbols_to_fetch)

    # Reference levels for level scanners
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

    results = await manager.run_market_cycle(db, quotes, hist_levels, weekly_levels)
    await ws_manager.broadcast({"type": "MARKET_CYCLE_UPDATE", "data": results})
    return results

@router.get("/api/sectors")
async def get_sector_radar():
    """Agent #1 Sector Radar rankings."""
    symbols = [BENCHMARK_NIFTY["fyers"]] + [s["fyers"] for s in SECTOR_INDICES]
    quotes = gateway.fetch_quotes_batch(symbols)
    ranked = manager.agent1.rank_sectors(quotes)
    return {"sectors": [s.dict() for s in ranked]}

@router.get("/api/leaders")
async def get_sector_leaders():
    """Agent #2 Sector Leaders in top bullish and bearish sectors."""
    symbols = [BENCHMARK_NIFTY["fyers"]] + [s["fyers"] for s in SECTOR_INDICES]
    for constituents in SECTOR_CONSTITUENTS.values():
        for s in constituents:
            symbols.append(get_fyers_symbol(s))
    quotes = gateway.fetch_quotes_batch(symbols)
    ranked = manager.agent1.rank_sectors(quotes)
    leaders = manager.agent2.find_leaders_and_laggards(ranked, quotes)
    return leaders

@router.get("/api/nifty")
async def get_nifty_regime():
    """Agent #3 Nifty Bias and Regime."""
    quotes = gateway.fetch_quotes_batch([BENCHMARK_NIFTY["fyers"]])
    q = quotes.get(BENCHMARK_NIFTY["name"]) or quotes.get(BENCHMARK_NIFTY["fyers"], {})
    regime = manager.agent3.assess_bias(q)
    return regime.dict()

@router.get("/api/candidates")
async def get_trade_candidates(db: AsyncSession = Depends(get_db)):
    """Manager's ranked trading shortlist and gate review."""
    q = select(TradeCandidate).order_by(TradeCandidate.composite_score.desc()).limit(20)
    res = await db.execute(q)
    cands = res.scalars().all()
    return {"candidates": cands}

@router.get("/api/plans")
async def get_active_plans(db: AsyncSession = Depends(get_db)):
    """Trade plans and observer trailing stop states."""
    q = select(TradePlan).order_by(TradePlan.timestamp.desc()).limit(25)
    res = await db.execute(q)
    plans = res.scalars().all()
    return {"plans": plans}

@router.get("/api/real-trades")
async def get_real_trades(db: AsyncSession = Depends(get_db)):
    """User's manually recorded real trades."""
    q = select(RealTrade).order_by(RealTrade.entry_time.desc()).limit(50)
    res = await db.execute(q)
    trades = res.scalars().all()
    return {"real_trades": trades}

@router.post("/api/real-trades")
async def record_real_trade(payload: RealTradeCreateRequest, db: AsyncSession = Depends(get_db)):
    """Records an executed manual real trade."""
    res = await mcp_server.record_manual_trade(
        session=db,
        symbol=payload.symbol.upper(),
        direction=payload.direction.upper(),
        entry_price=payload.entry_price,
        quantity=payload.quantity,
        initial_sl=payload.initial_sl,
        broker_order_id=payload.broker_order_id,
        notes=payload.notes
    )
    await ws_manager.broadcast({"type": "REAL_TRADE_RECORDED", "data": res})
    return res

@router.get("/api/journal")
async def get_journal_summary(db: AsyncSession = Depends(get_db)):
    """End-of-day journal and narrative history."""
    q = select(DailyJournal).order_by(DailyJournal.timestamp.desc()).limit(10)
    res = await db.execute(q)
    entries = res.scalars().all()
    return {"journal": entries}

@router.get("/api/research")
async def get_research_reports(db: AsyncSession = Depends(get_db)):
    """Agent #11 historical research recommendations."""
    rep = await manager.agent11.generate_research_report(db)
    return {"latest_report": rep}

@router.post("/api/mcp/call")
async def handle_mcp_tool(call: MCPToolCallRequest, db: AsyncSession = Depends(get_db)):
    """Dispatcher for internal MCP tools."""
    tool = call.tool_name
    args = call.arguments
    if tool == "get_market_regime":
        return await mcp_server.get_market_regime(db)
    elif tool == "get_sector_rankings":
        return await mcp_server.get_sector_rankings(db)
    elif tool == "get_trade_candidates":
        return await mcp_server.get_trade_candidates(db)
    elif tool == "get_open_trade_status":
        return await mcp_server.get_open_trade_status(db)
    elif tool == "get_journal_summary":
        return await mcp_server.get_journal_summary(db, args.get("date"))
    elif tool == "get_research_findings":
        return await mcp_server.get_research_findings(db)
    elif tool == "record_manual_trade":
        return await mcp_server.record_manual_trade(
            db,
            args.get("symbol", ""),
            args.get("direction", "BUY"),
            float(args.get("entry_price", 0.0)),
            int(args.get("quantity", 1)),
            float(args.get("initial_sl", 0.0)),
            args.get("broker_order_id"),
            args.get("notes")
        )
    else:
        raise HTTPException(status_code=404, detail=f"Unknown MCP tool: {tool}")

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """Real-time live push feed for browser dashboard."""
    await ws_manager.connect(websocket)
    try:
        # Send initial connection handshake
        await websocket.send_text(json.dumps({
            "type": "CONNECTION_ESTABLISHED",
            "message": "Connected to AI Trading Desk Live Feed"
        }))
        while True:
            # Keep alive and receive any client ping
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)
