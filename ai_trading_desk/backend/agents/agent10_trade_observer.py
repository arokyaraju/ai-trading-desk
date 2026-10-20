"""
Agent 10 — Trade Observer
Tracks open positions (simulated paper trades and manually recorded real trades).
Monitors milestones (1R to 6R), manages trailing-stop movements:
- At +2R: move stop to Entry price (breakeven).
- At +3R: move stop to +1R.
- At +4R: move stop to +2R.
- At +5R: move stop to +3R.
- At +6R: move stop to +4R.
- Strictly never loosens a stop once moved.
"""

from typing import Dict, List, Any, Optional
import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..models.schema import TradePlan, TradeEvent
from .contracts import TradeObserverState

class Agent10_TradeObserver:
    name = "Agent 10 — Trade Observer"
    version = "v1.0"

    async def update_open_trades(
        self,
        session: AsyncSession,
        quotes: Dict[str, Dict[str, Any]]
    ) -> List[TradeObserverState]:
        """
        Scans all ACTIVE / OPEN plans, checks SL, targets, updates trailing stops.
        """
        query = select(TradePlan).where(TradePlan.status.in_(["OPEN", "ACTIVE"]))
        result = await session.execute(query)
        open_plans = result.scalars().all()

        observed_states: List[TradeObserverState] = []

        for plan in open_plans:
            q = quotes.get(plan.symbol, {})
            current_price = float(q.get("price", plan.entry_price))
            if current_price <= 0:
                continue

            direction = plan.direction
            entry = plan.entry_price
            current_sl = plan.current_stop_loss
            r = plan.stop_distance

            # Current gain/loss in R multiples and INR
            if direction == "BUY":
                points = current_price - entry
                curr_r = round(points / r, 2)
            else: # SELL
                points = entry - current_price
                curr_r = round(points / r, 2)

            unrealized_pnl = round(points * plan.planned_quantity, 2)

            # Check Stop Loss Breach
            sl_breached = False
            if direction == "BUY" and current_price <= current_sl:
                sl_breached = True
            elif direction == "SELL" and current_price >= current_sl:
                sl_breached = True

            if sl_breached:
                plan.status = "CLOSED"
                plan.pnl_realized_inr = round((current_sl - entry if direction == "BUY" else entry - current_sl) * plan.planned_quantity, 2)
                plan.pnl_r_multiple = round((current_sl - entry if direction == "BUY" else entry - current_sl) / r, 2)
                
                # Log event
                event = TradeEvent(
                    plan_id=plan.plan_id,
                    event_type="EXIT_SL_HIT",
                    price=current_sl,
                    details=f"Stop loss triggered at ₹{current_sl:.2f}. P&L: ₹{plan.pnl_realized_inr:.2f} ({plan.pnl_r_multiple}R)",
                    timestamp=datetime.datetime.utcnow()
                )
                session.add(event)
                observed_states.append(TradeObserverState(
                    plan_id=plan.plan_id,
                    symbol=plan.symbol,
                    direction=plan.direction,
                    entry_price=entry,
                    initial_sl=plan.initial_stop_loss,
                    current_sl=current_sl,
                    current_price=current_price,
                    r_distance=r,
                    current_r=curr_r,
                    trailing_milestone=plan.trailing_milestone,
                    highest_r_touched=curr_r,
                    status="CLOSED_SL",
                    pnl_inr=plan.pnl_realized_inr
                ))
                continue

            # Trailing Stop Rules
            new_sl = current_sl
            new_milestone = plan.trailing_milestone

            if curr_r >= 6.0:
                # Stop at +4R
                calc_sl = round(entry + (4 * r) if direction == "BUY" else entry - (4 * r), 2)
                if (direction == "BUY" and calc_sl > current_sl) or (direction == "SELL" and calc_sl < current_sl):
                    new_sl = calc_sl
                    new_milestone = "+6R (Stop @ +4R)"
            elif curr_r >= 5.0:
                # Stop at +3R
                calc_sl = round(entry + (3 * r) if direction == "BUY" else entry - (3 * r), 2)
                if (direction == "BUY" and calc_sl > current_sl) or (direction == "SELL" and calc_sl < current_sl):
                    new_sl = calc_sl
                    new_milestone = "+5R (Stop @ +3R)"
            elif curr_r >= 4.0:
                # Stop at +2R
                calc_sl = round(entry + (2 * r) if direction == "BUY" else entry - (2 * r), 2)
                if (direction == "BUY" and calc_sl > current_sl) or (direction == "SELL" and calc_sl < current_sl):
                    new_sl = calc_sl
                    new_milestone = "+4R (Stop @ +2R)"
            elif curr_r >= 3.0:
                # Stop at +1R
                calc_sl = round(entry + (1 * r) if direction == "BUY" else entry - (1 * r), 2)
                if (direction == "BUY" and calc_sl > current_sl) or (direction == "SELL" and calc_sl < current_sl):
                    new_sl = calc_sl
                    new_milestone = "+3R (Stop @ +1R)"
            elif curr_r >= 2.0:
                # Move stop to Entry price (breakeven)
                calc_sl = entry
                if (direction == "BUY" and calc_sl > current_sl) or (direction == "SELL" and calc_sl < current_sl):
                    new_sl = calc_sl
                    new_milestone = "+2R (Stop @ Breakeven)"

            # Persist stop adjustment if moved
            if new_sl != current_sl:
                plan.current_stop_loss = new_sl
                plan.trailing_milestone = new_milestone
                event = TradeEvent(
                    plan_id=plan.plan_id,
                    event_type="STOP_TRAILED",
                    price=new_sl,
                    details=f"Trailing stop updated to ₹{new_sl:.2f} based on milestone {new_milestone}.",
                    timestamp=datetime.datetime.utcnow()
                )
                session.add(event)

            observed_states.append(TradeObserverState(
                plan_id=plan.plan_id,
                symbol=plan.symbol,
                direction=plan.direction,
                entry_price=entry,
                initial_sl=plan.initial_stop_loss,
                current_sl=new_sl,
                current_price=current_price,
                r_distance=r,
                current_r=curr_r,
                trailing_milestone=new_milestone,
                highest_r_touched=curr_r,
                status="ACTIVE",
                pnl_inr=unrealized_pnl
            ))

        await session.commit()
        return observed_states

agent10 = Agent10_TradeObserver()
