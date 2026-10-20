"""
Internal MCP Server Module
Exposes approved read-only and risk-validated tools for AI assistants and MCP clients.
"""

from typing import Dict, List, Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..agents.manager import manager
from ..models.schema import MarketRegime, SectorSnapshot, TradeCandidate, TradePlan, DailyJournal, ResearchReport, RealTrade

class TradingDeskMCPServer:
    """Internal Model Context Protocol tool executor."""

    @staticmethod
    async def get_market_regime(session: AsyncSession) -> Dict[str, Any]:
        """Retrieve the latest Nifty classification, pivots, and bias reasons."""
        q = select(MarketRegime).order_by(MarketRegime.timestamp.desc()).limit(1)
        res = await session.execute(q)
        regime = res.scalars().first()
        if regime:
            return {
                "symbol": regime.index_symbol,
                "current_price": regime.current_price,
                "daily_pivot": regime.daily_pivot,
                "prev_close": regime.prev_close,
                "bias": regime.bias,
                "breakout": regime.first_15m_breakout,
                "rationale": regime.rationale
            }
        return {"bias": "NEUTRAL", "rationale": "No market regime record stored yet."}

    @staticmethod
    async def get_sector_rankings(session: AsyncSession) -> List[Dict[str, Any]]:
        """Retrieve ranked sector snapshots from Sector Radar (Agent #1)."""
        q = select(SectorSnapshot).order_by(SectorSnapshot.rank.asc()).limit(10)
        res = await session.execute(q)
        snapshots = res.scalars().all()
        return [
            {
                "rank": s.rank,
                "name": s.sector_name,
                "change_pct": s.change_pct,
                "relative_strength": s.momentum_score,
                "classification": s.status
            }
            for s in snapshots
        ]

    @staticmethod
    async def get_trade_candidates(session: AsyncSession) -> List[Dict[str, Any]]:
        """Retrieve manager-ranked trading shortlist."""
        q = select(TradeCandidate).order_by(TradeCandidate.composite_score.desc()).limit(15)
        res = await session.execute(q)
        candidates = res.scalars().all()
        return [
            {
                "symbol": c.symbol,
                "direction": c.direction,
                "setup_name": c.setup_name,
                "composite_score": c.composite_score,
                "status": c.status,
                "disagreement": c.disagreement_explanation
            }
            for c in candidates
        ]

    @staticmethod
    async def get_open_trade_status(session: AsyncSession) -> List[Dict[str, Any]]:
        """Retrieve open paper plans and live observer status."""
        q = select(TradePlan).where(TradePlan.status.in_(["OPEN", "ACTIVE"]))
        res = await session.execute(q)
        plans = res.scalars().all()
        return [
            {
                "plan_id": p.plan_id,
                "symbol": p.symbol,
                "direction": p.direction,
                "entry_price": p.entry_price,
                "initial_stop": p.initial_stop_loss,
                "current_stop": p.current_stop_loss,
                "target_1r": p.target_1r,
                "target_2r": p.target_2r,
                "trailing_milestone": p.trailing_milestone,
                "mode": p.mode
            }
            for p in plans
        ]

    @staticmethod
    async def get_journal_summary(session: AsyncSession, date_str: Optional[str] = None) -> Dict[str, Any]:
        """Retrieve daily journal and trading outcomes."""
        q = select(DailyJournal).order_by(DailyJournal.timestamp.desc()).limit(1)
        res = await session.execute(q)
        journal = res.scalars().first()
        if journal:
            return {
                "date": journal.date_str,
                "narrative": journal.narrative_summary,
                "win_count": journal.win_count,
                "loss_count": journal.loss_count,
                "net_pnl_inr": journal.net_pnl_inr
            }
        return {"message": "No journal entry recorded for current session."}

    @staticmethod
    async def get_research_findings(session: AsyncSession) -> Dict[str, Any]:
        """Retrieve latest validated research recommendations from Agent #11."""
        q = select(ResearchReport).order_by(ResearchReport.created_at.desc()).limit(1)
        res = await session.execute(q)
        rep = res.scalars().first()
        if rep:
            return {
                "report_id": rep.report_id,
                "sample_size": rep.sample_size,
                "win_rate_pct": rep.win_rate_pct,
                "expectancy_per_trade": rep.expectancy_per_trade,
                "findings": rep.findings,
                "recommendations": rep.recommendations,
                "status": rep.approval_status
            }
        return {"message": "No research report generated yet."}

    @staticmethod
    async def record_manual_trade(
        session: AsyncSession,
        symbol: str,
        direction: str,
        entry_price: float,
        quantity: int,
        initial_sl: float,
        broker_order_id: Optional[str] = None,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """Records an actual manual real trade executed at the broker."""
        import datetime
        trade_id = f"REAL_{symbol}_{int(datetime.datetime.utcnow().timestamp())}"
        real_trade = RealTrade(
            trade_id=trade_id,
            symbol=symbol,
            direction=direction,
            entry_price=entry_price,
            quantity=quantity,
            initial_sl=initial_sl,
            current_sl=initial_sl,
            broker_order_id=broker_order_id or "MANUAL_FILL",
            status="OPEN",
            notes=notes
        )
        session.add(real_trade)
        await session.commit()
        return {
            "status": "success",
            "trade_id": trade_id,
            "message": f"Real trade recorded for {symbol} {direction} @ ₹{entry_price:.2f}"
        }

mcp_server = TradingDeskMCPServer()
