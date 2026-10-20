"""
Agent 3 — Nifty Bias
Assesses Nifty versus previous close, daily pivot, opening range,
and first 15-minute breakout. Classifies market into Bullish, Bearish, or Neutral.
"""

from typing import Dict, Any, Optional
from ..fyers.symbols import BENCHMARK_NIFTY
from .contracts import NiftyRegimeResult

class Agent3_NiftyBias:
    name = "Agent 3 — Nifty Bias"
    version = "v1.0"

    def assess_bias(self, quote: Dict[str, Any], opening_candles_15m: Optional[list] = None) -> NiftyRegimeResult:
        """
        Calculates Nifty 50 reference levels and assigns a non-forced market regime.
        """
        price = float(quote.get("price", 24850.0))
        prev_close = float(quote.get("prev_close", price))
        open_p = float(quote.get("open", price))
        high_p = float(quote.get("high", max(price, open_p)))
        low_p = float(quote.get("low", min(price, open_p)))

        # Standard Daily Pivot Calculation: (PDH + PDL + PDC) / 3
        daily_pivot = round((high_p + low_p + prev_close) / 3.0, 2)

        # 15-minute Opening Range
        if opening_candles_15m and len(opening_candles_15m) > 0:
            c1 = opening_candles_15m[0]
            or_high = float(c1.get("high", high_p))
            or_low = float(c1.get("low", low_p))
        else:
            # Approximate OR from early range
            or_high = round(open_p * 1.002, 2)
            or_low = round(open_p * 0.998, 2)

        # Breakout status
        if price > or_high:
            breakout_status = "BULLISH_BREAKOUT"
        elif price < or_low:
            breakout_status = "BEARISH_BREAKDOWN"
        else:
            breakout_status = "INSIDE"

        # Three-state deterministic bias classification
        disagreement = None
        if price > daily_pivot and price > prev_close and price >= or_high:
            bias = "BULLISH"
            rationale = "Nifty trading above Daily Pivot (₹{:.2f}), Previous Close (₹{:.2f}), and 15m Opening Range High.".format(daily_pivot, prev_close)
        elif price < daily_pivot and price < prev_close and price <= or_low:
            bias = "BEARISH"
            rationale = "Nifty trading below Daily Pivot (₹{:.2f}), Previous Close (₹{:.2f}), and 15m Opening Range Low.".format(daily_pivot, prev_close)
        else:
            bias = "NEUTRAL"
            if price > daily_pivot and price < prev_close:
                disagreement = "CONFLICT: Price is above Daily Pivot but below Previous Close."
                rationale = "Conflicting signals: Above Pivot but failing Previous Close. Await confirmation."
            elif price < daily_pivot and price > prev_close:
                disagreement = "CONFLICT: Price is below Daily Pivot but above Previous Close."
                rationale = "Conflicting signals: Below Daily Pivot but above Previous Close. Defensive regime."
            else:
                rationale = "Price oscillating within 15m Opening Range (₹{:.2f} - ₹{:.2f}). No directional edge.".format(or_low, or_high)

        return NiftyRegimeResult(
            symbol=BENCHMARK_NIFTY["fyers"],
            current_price=price,
            prev_close=prev_close,
            daily_pivot=daily_pivot,
            open_price=open_p,
            opening_range_high=or_high,
            opening_range_low=or_low,
            bias=bias,
            first_15m_breakout=breakout_status,
            rationale=rationale,
            disagreement=disagreement
        )

agent3 = Agent3_NiftyBias()
