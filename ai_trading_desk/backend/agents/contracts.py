"""
Agent Contracts and Data Schemas
Defines deterministic interfaces for all 11 agents.
"""

from typing import Dict, List, Optional, Any
from pydantic import BaseModel, Field
import datetime

class AgentSignalPayload(BaseModel):
    agent_id: str
    rule_version: str = "v1.0"
    symbol: str
    direction: str  # BUY, SELL, NEUTRAL
    signal_type: str
    timeframe: str = "1h"
    reference_price: float
    trigger_price: float
    reason: str
    timestamp: datetime.datetime = Field(default_factory=datetime.datetime.utcnow)
    metadata: Dict[str, Any] = Field(default_factory=dict)

class SectorRanking(BaseModel):
    name: str
    symbol: str
    price: float
    change_pct: float
    momentum_score: float
    relative_strength: float # vs Nifty %
    advances: int = 0
    declines: int = 0
    rank: int
    classification: str # BULLISH, BEARISH, NEUTRAL

class NiftyRegimeResult(BaseModel):
    symbol: str = "NSE:NIFTY50-INDEX"
    current_price: float
    prev_close: float
    daily_pivot: float
    open_price: float
    opening_range_high: float
    opening_range_low: float
    bias: str # BULLISH, BEARISH, NEUTRAL
    first_15m_breakout: str # BULLISH_BREAKOUT, BEARISH_BREAKDOWN, INSIDE
    rationale: str
    disagreement: Optional[str] = None

class RiskApproval(BaseModel):
    approved: bool
    rejection_reason: Optional[str] = None
    entry_price: float
    stop_loss: float
    stop_distance: float
    quantity: int
    risk_budget: float
    risk_reward_t2: float
    targets: Dict[str, float] # 1R through 6R

class TradeObserverState(BaseModel):
    plan_id: str
    symbol: str
    direction: str
    entry_price: float
    initial_sl: float
    current_sl: float
    current_price: float
    r_distance: float
    current_r: float
    trailing_milestone: str
    highest_r_touched: float
    status: str # ACTIVE, CLOSED_SL, CLOSED_TARGET
    pnl_inr: float
