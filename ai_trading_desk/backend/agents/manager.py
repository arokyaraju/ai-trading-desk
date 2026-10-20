"""
Trading Desk Manager
Coordinates all 11 agents, reconciles market direction, explains agent disagreements,
scores opportunities across 5 quantitative gates, and produces the finalized Trading Shortlist.
"""

from typing import List, Dict, Any, Optional
import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from .contracts import AgentSignalPayload, SectorRanking, NiftyRegimeResult, RiskApproval
from .agent1_sector_radar import agent1
from .agent2_sector_leaders import agent2
from .agent3_nifty_bias import agent3
from .agent4_sector_reversal import agent4
from .agent5_stock_confirmation import agent5
from .agent6_prev_day_levels import agent6
from .agent7_prev_week_levels import agent7
from .agent8_risk_officer import agent8
from .agent9_trade_journal import agent9
from .agent10_trade_observer import agent10
from .agent11_research_analyst import agent11

from ..models.schema import TradeCandidate, TradePlan, TradeEvent
from ..fyers.symbols import STOCK_TO_SECTOR, BENCHMARK_NIFTY

class TradingDeskManager:
    name = "Trading Desk Manager"
    version = "v1.0"

    def __init__(self):
        self.agent1 = agent1
        self.agent2 = agent2
        self.agent3 = agent3
        self.agent4 = agent4
        self.agent5 = agent5
        self.agent6 = agent6
        self.agent7 = agent7
        self.agent8 = agent8
        self.agent9 = agent9
        self.agent10 = agent10
        self.agent11 = agent11

    def score_candidate(
        self,
        signal: AgentSignalPayload,
        nifty_regime: NiftyRegimeResult,
        ranked_sectors: List[SectorRanking],
        stock_confirmations: List[AgentSignalPayload],
        risk_eval: RiskApproval
    ) -> Dict[str, Any]:
        """
        Calculates the institutional 5-factor scoring model:
        1. Nifty alignment: 25%
        2. Sector strength: 20%
        3. Stock confirmation: 20%
        4. Level setup quality: 20%
        5. Liquidity & R:R: 15%
        Total: 0 to 100 points
        """
        # 1. Nifty direction alignment (25 pts)
        nifty_score = 0.0
        disagreements = []
        if (signal.direction == "BUY" and nifty_regime.bias == "BULLISH") or \
           (signal.direction == "SELL" and nifty_regime.bias == "BEARISH"):
            nifty_score = 25.0
        elif nifty_regime.bias == "NEUTRAL":
            nifty_score = 12.5
            disagreements.append("Caution: Nifty regime is NEUTRAL; macro directional support is absent.")
        else:
            nifty_score = 0.0
            disagreements.append(f"CONTRADICTION: Stock is {signal.direction} but Nifty is {nifty_regime.bias}.")

        # 2. Sector strength and direction (20 pts)
        sector_score = 0.0
        stock_sec = STOCK_TO_SECTOR.get(signal.symbol, "")
        sec_obj = next((s for s in ranked_sectors if s.name == stock_sec), None)

        if sec_obj:
            if (signal.direction == "BUY" and sec_obj.classification == "BULLISH") or \
               (signal.direction == "SELL" and sec_obj.classification == "BEARISH"):
                sector_score = 20.0
            elif sec_obj.classification == "NEUTRAL":
                sector_score = 10.0
            else:
                sector_score = 0.0
                disagreements.append(f"SECTOR CONFLICT: {signal.symbol} is {signal.direction} but sector {stock_sec} is {sec_obj.classification}.")
        else:
            sector_score = 10.0

        # 3. Stock confirmation (20 pts)
        has_confirmation = any(c.symbol == signal.symbol and c.direction == signal.direction for c in stock_confirmations)
        stock_conf_score = 20.0 if has_confirmation else 8.0

        # 4. Quality of Level Setup (20 pts)
        setup_score = 20.0 if "PWH" in signal.signal_type or "PDH" in signal.signal_type or "PWL" in signal.signal_type or "PDL" in signal.signal_type else 12.0

        # 5. Liquidity & Executable R:R (15 pts)
        rr_score = 0.0
        if risk_eval.approved:
            if risk_eval.risk_reward_t2 >= 2.0:
                rr_score = 15.0
            elif risk_eval.risk_reward_t2 >= 1.5:
                rr_score = 12.0
            else:
                rr_score = 5.0
        else:
            rr_score = 0.0
            disagreements.append(f"RISK REJECTION: {risk_eval.rejection_reason}")

        composite = round(nifty_score + sector_score + stock_conf_score + setup_score + rr_score, 1)

        # Status: Approved if >= 65 and Risk Officer approved and no direct contradiction
        status = "CONFIRMED" if (composite >= 65.0 and risk_eval.approved and nifty_score > 0) else "REJECTED"
        rejection_reason = "; ".join(disagreements) if status == "REJECTED" else None

        return {
            "nifty_score": nifty_score,
            "sector_score": sector_score,
            "stock_conf_score": stock_conf_score,
            "level_setup_score": setup_score,
            "risk_reward_score": rr_score,
            "composite_score": composite,
            "status": status,
            "rejection_reason": rejection_reason,
            "disagreement_explanation": " | ".join(disagreements) if disagreements else "All agents aligned in market direction."
        }

    async def run_market_cycle(
        self,
        session: AsyncSession,
        quotes: Dict[str, Dict[str, Any]],
        historical_levels: Dict[str, Dict[str, float]],
        weekly_levels: Dict[str, Dict[str, float]]
    ) -> Dict[str, Any]:
        """
        Executes a complete coordinated analytical sweep across all 11 agents.
        """
        # Step 1: Agent 1 Sector Radar
        ranked_sectors = self.agent1.rank_sectors(quotes)

        # Step 2: Agent 2 Sector Leaders
        leaders = self.agent2.find_leaders_and_laggards(ranked_sectors, quotes)

        # Step 3: Agent 3 Nifty Bias
        nifty_quote = quotes.get(BENCHMARK_NIFTY["name"]) or quotes.get(BENCHMARK_NIFTY["fyers"], {})
        nifty_regime = self.agent3.assess_bias(nifty_quote)

        # Step 4: Agent 4 Sector Reversal
        sector_reversals = self.agent4.scan_reversals(quotes)

        # Step 5: Agent 5 Stock Confirmation
        stock_confirmations = self.agent5.verify_confirmations(ranked_sectors, quotes)

        # Step 6: Agent 6 Previous-Day Levels
        pdl_signals = self.agent6.scan_hourly_rejections(quotes, historical_levels)

        # Step 7: Agent 7 Previous-Week Levels
        pwl_signals = self.agent7.scan_weekly_rejections(quotes, weekly_levels)

        # Combine candidate discovery signals from Level Scanners
        raw_signals: List[AgentSignalPayload] = pdl_signals + pwl_signals

        candidates_out = []
        confirmed_plans = []

        for sig in raw_signals:
            q = quotes.get(sig.symbol, {})
            price = float(q.get("price", sig.trigger_price))
            ref_p = sig.reference_price

            # Define initial stop and structural target
            if sig.direction == "BUY":
                stop_loss = round(min(sig.metadata.get("tested_low", price * 0.99), price * 0.992), 2)
                t2_target = round(price + (2 * (price - stop_loss)), 2)
            else: # SELL
                stop_loss = round(max(sig.metadata.get("tested_high", price * 1.01), price * 1.008), 2)
                t2_target = round(price - (2 * (stop_loss - price)), 2)

            # Step 8: Agent 8 Risk Officer evaluation
            risk_eval = self.agent8.evaluate_risk(
                symbol=sig.symbol,
                direction=sig.direction,
                entry_price=price,
                stop_loss=stop_loss,
                target_2_price=t2_target
            )

            # Manager scoring
            score_data = self.score_candidate(
                signal=sig,
                nifty_regime=nifty_regime,
                ranked_sectors=ranked_sectors,
                stock_confirmations=stock_confirmations,
                risk_eval=risk_eval
            )

            cand = {
                "symbol": sig.symbol,
                "direction": sig.direction,
                "setup_name": sig.signal_type,
                "discovering_agent": sig.agent_id,
                "trigger_price": price,
                "reference_price": ref_p,
                "scores": score_data,
                "risk": risk_eval.dict()
            }
            candidates_out.append(cand)

            # If Manager Confirmed, generate Trade Plan if not already open
            if score_data["status"] == "CONFIRMED":
                import uuid
                # Check if open plan already exists for this symbol and direction
                q_exists = select(TradePlan).where(
                    TradePlan.symbol == sig.symbol,
                    TradePlan.direction == sig.direction,
                    TradePlan.status.in_(["OPEN", "ACTIVE"])
                )
                res_exists = await session.execute(q_exists)
                existing_plan = res_exists.scalars().first()

                if not existing_plan:
                    plan_id = f"PLAN_{sig.symbol}_{sig.direction}_{uuid.uuid4().hex[:8]}"
                    plan = TradePlan(
                        plan_id=plan_id,
                        symbol=sig.symbol,
                        direction=sig.direction,
                        setup_rationale=sig.reason,
                        entry_price=price,
                        initial_stop_loss=risk_eval.stop_loss,
                        current_stop_loss=risk_eval.stop_loss,
                        stop_distance=risk_eval.stop_distance,
                        planned_quantity=risk_eval.quantity,
                        risk_budget_inr=risk_eval.risk_budget,
                        target_1r=risk_eval.targets.get("1R", 0.0),
                        target_2r=risk_eval.targets.get("2R", 0.0),
                        target_3r=risk_eval.targets.get("3R", 0.0),
                        target_4r=risk_eval.targets.get("4R", 0.0),
                        target_5r=risk_eval.targets.get("5R", 0.0),
                        target_6r=risk_eval.targets.get("6R", 0.0),
                        mode="PAPER",
                        status="OPEN",
                        trailing_milestone="0R"
                    )
                    session.add(plan)
                    confirmed_plans.append(plan_id)

        # Step 10: Agent 10 Trade Observer update on active positions
        observer_updates = await self.agent10.update_open_trades(session, quotes)

        # Sort candidates by composite score descending
        candidates_out.sort(key=lambda x: x["scores"]["composite_score"], reverse=True)

        await session.commit()

        return {
            "timestamp": datetime.datetime.utcnow().isoformat(),
            "nifty_regime": nifty_regime.dict(),
            "ranked_sectors": [s.dict() for s in ranked_sectors],
            "sector_leaders": leaders,
            "sector_reversals": [s.dict() for s in sector_reversals],
            "stock_confirmations": [s.dict() for s in stock_confirmations],
            "candidates": candidates_out,
            "confirmed_plans_count": len(confirmed_plans),
            "observer_active_trades": [o.dict() for o in observer_updates]
        }

manager = TradingDeskManager()
