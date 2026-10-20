"""
Agent 9 — Trade Journal
Maintains an immutable, timestamped record of all signals, managerial decisions,
stop adjustments, and trade outcomes. Generates end-of-day narrative reports.
"""

from typing import Dict, List, Any, Optional
import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from ..models.schema import DailyJournal, TradeEvent, TradePlan, RealTrade, AgentSignal

class Agent9_TradeJournal:
    name = "Agent 9 — Trade Journal"
    version = "v1.0"

    async def record_event(
        self,
        session: AsyncSession,
        plan_id: str,
        event_type: str,
        price: float,
        details: str
    ):
        event = TradeEvent(
            plan_id=plan_id,
            event_type=event_type,
            price=price,
            details=details,
            timestamp=datetime.datetime.utcnow()
        )
        session.add(event)
        await session.commit()

    async def generate_daily_summary(
        self,
        session: AsyncSession,
        date_str: str,
        nifty_quote: Dict[str, Any],
        top_sectors: List[str]
    ) -> Dict[str, Any]:
        """
        Compiles the full institutional end-of-day journal narrative.
        """
        # Fetch plans and real trades created today
        query_plans = select(TradePlan).order_by(TradePlan.timestamp.desc())
        res_plans = await session.execute(query_plans)
        plans = res_plans.scalars().all()

        query_real = select(RealTrade).order_by(RealTrade.entry_time.desc())
        res_real = await session.execute(query_real)
        real_trades = res_real.scalars().all()

        total_plans = len(plans)
        wins = sum(1 for p in plans if p.pnl_realized_inr > 0)
        losses = sum(1 for p in plans if p.pnl_realized_inr < 0)
        total_pnl = sum(p.pnl_realized_inr for p in plans)
        real_pnl = sum(r.net_pnl for r in real_trades)

        nifty_p = float(nifty_quote.get("price", 0.0))
        nifty_pc = float(nifty_quote.get("prev_close", 0.0))
        nifty_open = float(nifty_quote.get("open", 0.0))
        nifty_pivot = round((float(nifty_quote.get("high", nifty_p)) + float(nifty_quote.get("low", nifty_p)) + nifty_pc) / 3.0, 2)

        top1 = top_sectors[0] if len(top_sectors) > 0 else "N/A"
        top2 = top_sectors[1] if len(top_sectors) > 1 else "N/A"

        narrative = (
            f"End of Day Session ({date_str}): Nifty opened at ₹{nifty_open:.2f}, "
            f"prev close ₹{nifty_pc:.2f}, pivot at ₹{nifty_pivot:.2f}. "
            f"Leading sectors were {top1} and {top2}. "
            f"The desk evaluated {total_plans} trade plans. "
            f"Paper/Observer P&L: ₹{total_pnl:.2f}. "
            f"Manual Real Executed Trades: {len(real_trades)} logged, Net Realized: ₹{real_pnl:.2f}."
        )

        # Check existing journal record or create new
        q_journal = select(DailyJournal).where(DailyJournal.date_str == date_str)
        res_j = await session.execute(q_journal)
        existing_j = res_j.scalars().first()

        report_payload = {
            "date": date_str,
            "nifty_open": nifty_open,
            "nifty_close": nifty_p,
            "nifty_pivot": nifty_pivot,
            "top_sectors": [top1, top2],
            "total_plans": total_plans,
            "wins": wins,
            "losses": losses,
            "paper_pnl": total_pnl,
            "real_trades_count": len(real_trades),
            "real_pnl": real_pnl,
            "narrative": narrative
        }

        if existing_j:
            existing_j.nifty_opening = nifty_open
            existing_j.nifty_prev_close = nifty_pc
            existing_j.nifty_pivot = nifty_pivot
            existing_j.top_sector_1 = top1
            existing_j.top_sector_2 = top2
            existing_j.total_trades_taken = total_plans
            existing_j.win_count = wins
            existing_j.loss_count = losses
            existing_j.net_pnl_inr = total_pnl + real_pnl
            existing_j.narrative_summary = narrative
            existing_j.report_json = report_payload
        else:
            new_j = DailyJournal(
                date_str=date_str,
                nifty_opening=nifty_open,
                nifty_prev_close=nifty_pc,
                nifty_pivot=nifty_pivot,
                top_sector_1=top1,
                top_sector_2=top2,
                total_candidates_scored=total_plans,
                total_trades_taken=total_plans,
                win_count=wins,
                loss_count=losses,
                net_pnl_inr=total_pnl + real_pnl,
                narrative_summary=narrative,
                report_json=report_payload
            )
            session.add(new_j)

        await session.commit()
        return report_payload

agent9 = Agent9_TradeJournal()
