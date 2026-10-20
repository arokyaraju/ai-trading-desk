"""
Agent 1 — Sector Radar
Ranks sector-index performance, relative strength vs Nifty, and intraday change.
Displays strongest to weakest sectors, including positive and negative sectors.
"""

from typing import List, Dict, Any
from ..fyers.symbols import SECTOR_INDICES, BENCHMARK_NIFTY
from .contracts import SectorRanking

class Agent1_SectorRadar:
    name = "Agent 1 — Sector Radar"
    version = "v1.0"

    def rank_sectors(self, quotes: Dict[str, Dict[str, Any]]) -> List[SectorRanking]:
        """
        Calculates performance % and relative strength vs Nifty, then ranks sectors.
        """
        nifty_quote = quotes.get(BENCHMARK_NIFTY["name"]) or quotes.get(BENCHMARK_NIFTY["fyers"], {})
        nifty_chp = float(nifty_quote.get("change_pct", 0.0))

        sector_rows = []
        for sec in SECTOR_INDICES:
            q = quotes.get(sec["name"]) or quotes.get(sec["fyers"], {})
            price = float(q.get("price", 0.0))
            chp = float(q.get("change_pct", 0.0))
            open_p = float(q.get("open", price))
            high_p = float(q.get("high", price))
            low_p = float(q.get("low", price))

            # Intraday momentum: where price is relative to daily range
            rng = max(0.01, high_p - low_p)
            momentum_score = round(((price - low_p) / rng) * 100.0, 1) if rng > 0 else 50.0

            # Relative strength vs Nifty 50 benchmark
            rs = round(chp - nifty_chp, 2)

            classification = "NEUTRAL"
            if chp >= 0.3 and rs > 0:
                classification = "BULLISH"
            elif chp <= -0.3 and rs < 0:
                classification = "BEARISH"

            sector_rows.append({
                "name": sec["name"],
                "symbol": sec["fyers"],
                "price": price,
                "change_pct": chp,
                "momentum_score": momentum_score,
                "relative_strength": rs,
                "advances": 0,
                "declines": 0,
                "classification": classification
            })

        # Rank descending by change_pct
        sector_rows.sort(key=lambda s: s["change_pct"], reverse=True)

        ranked: List[SectorRanking] = []
        for idx, s in enumerate(sector_rows, start=1):
            ranked.append(SectorRanking(
                name=s["name"],
                symbol=s["symbol"],
                price=s["price"],
                change_pct=s["change_pct"],
                momentum_score=s["momentum_score"],
                relative_strength=s["relative_strength"],
                advances=s["advances"],
                declines=s["declines"],
                rank=idx,
                classification=s["classification"]
            ))

        return ranked

agent1 = Agent1_SectorRadar()
