"""
Agent 5 — Stock Confirmation
Checks whether individual stocks confirm their sector's reclaim or breakdown.
"""

from typing import List, Dict, Any
from ..fyers.symbols import SECTOR_CONSTITUENTS, STOCK_TO_SECTOR
from .contracts import AgentSignalPayload, SectorRanking

class Agent5_StockConfirmation:
    name = "Agent 5 — Stock Confirmation"
    version = "v1.0"

    def verify_confirmations(
        self,
        ranked_sectors: List[SectorRanking],
        quotes: Dict[str, Dict[str, Any]]
    ) -> List[AgentSignalPayload]:
        signals = []
        if not ranked_sectors:
            return signals

        # Top 2 bullish sectors and bottom 2 bearish sectors
        bullish_names = [s.name for s in ranked_sectors if s.classification == "BULLISH"][:2]
        bearish_names = [s.name for s in ranked_sectors if s.classification == "BEARISH"][-2:]

        # Check bullish sector constituents
        for sec_name in bullish_names:
            stocks = SECTOR_CONSTITUENTS.get(sec_name, [])
            for sym in stocks:
                q = quotes.get(sym, {})
                price = float(q.get("price", 0.0))
                prev_close = float(q.get("prev_close", price))
                high_p = float(q.get("high", price))
                low_p = float(q.get("low", price))

                if price <= 0:
                    continue

                stock_pivot = round((high_p + low_p + prev_close) / 3.0, 2)
                # Confirmation: stock trading above its own pivot and prev close, aligning with bullish sector
                if price > stock_pivot and price > prev_close:
                    signals.append(AgentSignalPayload(
                        agent_id=self.name,
                        rule_version=self.version,
                        symbol=sym,
                        direction="BUY",
                        signal_type="BULLISH_SECTOR_CONFIRMATION",
                        timeframe="15m",
                        reference_price=stock_pivot,
                        trigger_price=price,
                        reason=f"{sym} confirms bullish {sec_name}: Trading above Daily Pivot (₹{stock_pivot:.2f}) and Prev Close (₹{prev_close:.2f}).",
                        metadata={"sector": sec_name, "stock_pivot": stock_pivot, "prev_close": prev_close}
                    ))

        # Check bearish sector constituents
        for sec_name in bearish_names:
            stocks = SECTOR_CONSTITUENTS.get(sec_name, [])
            for sym in stocks:
                q = quotes.get(sym, {})
                price = float(q.get("price", 0.0))
                prev_close = float(q.get("prev_close", price))
                high_p = float(q.get("high", price))
                low_p = float(q.get("low", price))

                if price <= 0:
                    continue

                stock_pivot = round((high_p + low_p + prev_close) / 3.0, 2)
                # Confirmation: stock trading below its own pivot and prev close, aligning with bearish sector
                if price < stock_pivot and price < prev_close:
                    signals.append(AgentSignalPayload(
                        agent_id=self.name,
                        rule_version=self.version,
                        symbol=sym,
                        direction="SELL",
                        signal_type="BEARISH_SECTOR_CONFIRMATION",
                        timeframe="15m",
                        reference_price=stock_pivot,
                        trigger_price=price,
                        reason=f"{sym} confirms bearish {sec_name}: Trading below Daily Pivot (₹{stock_pivot:.2f}) and Prev Close (₹{prev_close:.2f}).",
                        metadata={"sector": sec_name, "stock_pivot": stock_pivot, "prev_close": prev_close}
                    ))

        return signals

agent5 = Agent5_StockConfirmation()
