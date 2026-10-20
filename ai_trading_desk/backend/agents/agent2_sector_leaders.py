"""
Agent 2 — Sector Leaders
Finds the strongest stocks in the top two bullish sectors and
the weakest stocks in the top two bearish sectors.
"""

from typing import List, Dict, Any
from ..fyers.symbols import SECTOR_CONSTITUENTS
from .contracts import SectorRanking

class Agent2_SectorLeaders:
    name = "Agent 2 — Sector Leaders"
    version = "v1.0"

    def find_leaders_and_laggards(
        self,
        ranked_sectors: List[SectorRanking],
        quotes: Dict[str, Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Takes top 2 sectors and bottom 2 sectors, ranks their constituents.
        """
        if not ranked_sectors:
            return {"top_bullish_stocks": [], "top_bearish_stocks": []}

        bullish_sectors = ranked_sectors[:2]
        bearish_sectors = ranked_sectors[-2:]

        bullish_stocks = []
        for sec in bullish_sectors:
            constituents = SECTOR_CONSTITUENTS.get(sec.name, [])
            for sym in constituents:
                q = quotes.get(sym, {})
                price = float(q.get("price", 0.0))
                chp = float(q.get("change_pct", 0.0))
                vol = float(q.get("volume", 0.0))
                bullish_stocks.append({
                    "symbol": sym,
                    "sector": sec.name,
                    "price": price,
                    "change_pct": chp,
                    "volume": vol,
                    "relative_strength": round(chp - sec.change_pct, 2)
                })

        # Sort bullish stocks by change_pct descending
        bullish_stocks.sort(key=lambda x: x["change_pct"], reverse=True)

        bearish_stocks = []
        for sec in bearish_sectors:
            constituents = SECTOR_CONSTITUENTS.get(sec.name, [])
            for sym in constituents:
                q = quotes.get(sym, {})
                price = float(q.get("price", 0.0))
                chp = float(q.get("change_pct", 0.0))
                vol = float(q.get("volume", 0.0))
                bearish_stocks.append({
                    "symbol": sym,
                    "sector": sec.name,
                    "price": price,
                    "change_pct": chp,
                    "volume": vol,
                    "relative_weakness": round(chp - sec.change_pct, 2)
                })

        # Sort bearish stocks by change_pct ascending
        bearish_stocks.sort(key=lambda x: x["change_pct"])

        return {
            "top_bullish_stocks": bullish_stocks[:6],
            "top_bearish_stocks": bearish_stocks[:6]
        }

agent2 = Agent2_SectorLeaders()
