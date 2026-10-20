"""
Agent 4 — Sector Reversal
Tracks sector transitions across previous close and daily pivot in both directions.
"""

from typing import List, Dict, Any
from ..fyers.symbols import SECTOR_INDICES
from .contracts import AgentSignalPayload
import datetime

class Agent4_SectorReversal:
    name = "Agent 4 — Sector Reversal"
    version = "v1.0"

    def scan_reversals(self, quotes: Dict[str, Dict[str, Any]]) -> List[AgentSignalPayload]:
        signals = []

        for sec in SECTOR_INDICES:
            q = quotes.get(sec["name"]) or quotes.get(sec["fyers"], {})
            price = float(q.get("price", 0.0))
            prev_close = float(q.get("prev_close", price))
            open_p = float(q.get("open", price))
            high_p = float(q.get("high", price))
            low_p = float(q.get("low", price))

            if price <= 0:
                continue

            daily_pivot = round((high_p + low_p + prev_close) / 3.0, 2)

            # Bullish Pivot Reclaim: Opened below pivot, currently trading above both pivot and previous close
            if open_p < daily_pivot and price > daily_pivot and price > prev_close:
                signals.append(AgentSignalPayload(
                    agent_id=self.name,
                    rule_version=self.version,
                    symbol=sec["name"],
                    direction="BUY",
                    signal_type="SECTOR_PIVOT_RECLAIM",
                    timeframe="15m",
                    reference_price=daily_pivot,
                    trigger_price=price,
                    reason=f"{sec['name']} reclaimed Daily Pivot (₹{daily_pivot:.2f}) and Prev Close (₹{prev_close:.2f}) after opening lower.",
                    metadata={"pivot": daily_pivot, "prev_close": prev_close, "open": open_p}
                ))

            # Bearish Pivot Breakdown: Opened above pivot, currently falling below both pivot and previous close
            elif open_p > daily_pivot and price < daily_pivot and price < prev_close:
                signals.append(AgentSignalPayload(
                    agent_id=self.name,
                    rule_version=self.version,
                    symbol=sec["name"],
                    direction="SELL",
                    signal_type="SECTOR_PIVOT_BREAKDOWN",
                    timeframe="15m",
                    reference_price=daily_pivot,
                    trigger_price=price,
                    reason=f"{sec['name']} broke down below Daily Pivot (₹{daily_pivot:.2f}) and Prev Close (₹{prev_close:.2f}) after opening higher.",
                    metadata={"pivot": daily_pivot, "prev_close": prev_close, "open": open_p}
                ))

        return signals

agent4 = Agent4_SectorReversal()
