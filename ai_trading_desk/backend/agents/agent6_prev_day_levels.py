"""
Agent 6 — Previous-Day Levels
Scans hourly closes and rejection candles around the previous day's high and low.
Strictly implements the Anti-Trap Golden Rule:
- At PDH: SELL ON TOP (Failure to hold breakout, close < Daily Pivot & PDC).
- At PDL: BUY AT THE LOW (Absorption of breakdown, close > Daily Pivot & PDC).
"""

from typing import List, Dict, Any
from .contracts import AgentSignalPayload

class Agent6_PrevDayLevels:
    name = "Agent 6 — Previous-Day Levels"
    version = "v1.0"

    def scan_hourly_rejections(
        self,
        quotes: Dict[str, Dict[str, Any]],
        historical_levels: Dict[str, Dict[str, float]]
    ) -> List[AgentSignalPayload]:
        signals = []

        for sym, q in quotes.items():
            if ":" in sym:
                continue # Skip index symbols

            price = float(q.get("price", 0.0))
            if price <= 0:
                continue

            levels = historical_levels.get(sym, {})
            pdh = float(levels.get("pdh", q.get("high", price * 1.01)))
            pdl = float(levels.get("pdl", q.get("low", price * 0.99)))
            pdc = float(levels.get("pdc", q.get("prev_close", price)))
            daily_pivot = round((pdh + pdl + pdc) / 3.0, 2)

            high_p = float(q.get("high", price))
            low_p = float(q.get("low", price))

            # Condition 1: PDH Failure (SELL ON TOP)
            # Tested PDH (high >= PDH), rejected (closed back below PDH), and broken below Pivot & PDC
            if high_p >= pdh and price < pdh and price < daily_pivot and price < pdc:
                signals.append(AgentSignalPayload(
                    agent_id=self.name,
                    rule_version=self.version,
                    symbol=sym,
                    direction="SELL",
                    signal_type="PDH_FAILURE_SELL_ON_TOP",
                    timeframe="1h",
                    reference_price=pdh,
                    trigger_price=price,
                    reason=f"{sym} rejected at PDH (₹{pdh:.2f}). Closed below Daily Pivot (₹{daily_pivot:.2f}) and PDC (₹{pdc:.2f}). Sell on Top confirmed.",
                    metadata={
                        "pdh": pdh,
                        "pdl": pdl,
                        "pdc": pdc,
                        "daily_pivot": daily_pivot,
                        "tested_high": high_p
                    }
                ))

            # Condition 2: PDL Recovery (BUY AT THE LOW)
            # Tested PDL (low <= PDL), rejected breakdown, and recovered above Pivot & PDC
            elif low_p <= pdl and price > pdl and price > daily_pivot and price > pdc:
                signals.append(AgentSignalPayload(
                    agent_id=self.name,
                    rule_version=self.version,
                    symbol=sym,
                    direction="BUY",
                    signal_type="PDL_RECOVERY_BUY_AT_LOW",
                    timeframe="1h",
                    reference_price=pdl,
                    trigger_price=price,
                    reason=f"{sym} recovered at PDL (₹{pdl:.2f}). Closed above Daily Pivot (₹{daily_pivot:.2f}) and PDC (₹{pdc:.2f}). Buy at the Low confirmed.",
                    metadata={
                        "pdh": pdh,
                        "pdl": pdl,
                        "pdc": pdc,
                        "daily_pivot": daily_pivot,
                        "tested_low": low_p
                    }
                ))

        return signals

agent6 = Agent6_PrevDayLevels()
