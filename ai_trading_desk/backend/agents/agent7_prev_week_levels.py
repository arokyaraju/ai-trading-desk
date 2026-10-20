"""
Agent 7 — Previous-Week Levels
Scans hourly rejection at previous week's high (PWH) and low (PWL).
- PWH Failure (SELL ON TOP): Close < Weekly Pivot & PWC after testing PWH.
- PWL Recovery (BUY AT THE LOW): Close > Weekly Pivot & PWC after testing PWL.
"""

from typing import List, Dict, Any
from .contracts import AgentSignalPayload

class Agent7_PrevWeekLevels:
    name = "Agent 7 — Previous-Week Levels"
    version = "v1.0"

    def scan_weekly_rejections(
        self,
        quotes: Dict[str, Dict[str, Any]],
        weekly_levels: Dict[str, Dict[str, float]]
    ) -> List[AgentSignalPayload]:
        signals = []

        for sym, q in quotes.items():
            if ":" in sym:
                continue

            price = float(q.get("price", 0.0))
            if price <= 0:
                continue

            levels = weekly_levels.get(sym, {})
            pwh = float(levels.get("pwh", q.get("high", price * 1.02)))
            pwl = float(levels.get("pwl", q.get("low", price * 0.98)))
            pwc = float(levels.get("pwc", q.get("prev_close", price)))
            weekly_pivot = round((pwh + pwl + pwc) / 3.0, 2)

            high_p = float(q.get("high", price))
            low_p = float(q.get("low", price))

            # Weekly High Failure (SELL ON TOP)
            if high_p >= pwh and price < pwh and price < weekly_pivot and price < pwc:
                signals.append(AgentSignalPayload(
                    agent_id=self.name,
                    rule_version=self.version,
                    symbol=sym,
                    direction="SELL",
                    signal_type="PWH_FAILURE_SELL_ON_TOP",
                    timeframe="1h",
                    reference_price=pwh,
                    trigger_price=price,
                    reason=f"{sym} rejected at Previous Week High (₹{pwh:.2f}). Closed below Weekly Pivot (₹{weekly_pivot:.2f}) and PWC (₹{pwc:.2f}).",
                    metadata={
                        "pwh": pwh,
                        "pwl": pwl,
                        "pwc": pwc,
                        "weekly_pivot": weekly_pivot,
                        "tested_high": high_p
                    }
                ))

            # Weekly Low Recovery (BUY AT THE LOW)
            elif low_p <= pwl and price > pwl and price > weekly_pivot and price > pwc:
                signals.append(AgentSignalPayload(
                    agent_id=self.name,
                    rule_version=self.version,
                    symbol=sym,
                    direction="BUY",
                    signal_type="PWL_RECOVERY_BUY_AT_LOW",
                    timeframe="1h",
                    reference_price=pwl,
                    trigger_price=price,
                    reason=f"{sym} supported at Previous Week Low (₹{pwl:.2f}). Closed above Weekly Pivot (₹{weekly_pivot:.2f}) and PWC (₹{pwc:.2f}).",
                    metadata={
                        "pwh": pwh,
                        "pwl": pwl,
                        "pwc": pwc,
                        "weekly_pivot": weekly_pivot,
                        "tested_low": low_p
                    }
                ))

        return signals

agent7 = Agent7_PrevWeekLevels()
