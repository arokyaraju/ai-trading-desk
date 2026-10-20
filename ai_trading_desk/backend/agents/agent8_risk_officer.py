"""
Agent 8 — Risk Officer
Enforces institutional risk governance:
- Calculates exact position size: Quantity = floor(Risk Budget / Stop Distance R)
- Computes 1R through 6R target ladder: Tn = E ± n*R
- Rejects invalid stops, negative R, or poor reward/risk (< 1.5 R:R at T2)
"""

from typing import Dict, Any, Optional
from ..config import settings
from .contracts import RiskApproval

class Agent8_RiskOfficer:
    name = "Agent 8 — Risk Officer"
    version = "v1.0"

    def evaluate_risk(
        self,
        symbol: str,
        direction: str,
        entry_price: float,
        stop_loss: float,
        target_2_price: float,
        custom_risk_budget: Optional[float] = None
    ) -> RiskApproval:
        risk_budget = custom_risk_budget or settings.DEFAULT_RISK_PER_TRADE_INR

        if entry_price <= 0:
            return RiskApproval(
                approved=False,
                rejection_reason="Invalid entry price <= 0",
                entry_price=entry_price,
                stop_loss=stop_loss,
                stop_distance=0.0,
                quantity=0,
                risk_budget=risk_budget,
                risk_reward_t2=0.0,
                targets={}
            )

        # Stop distance R calculation
        if direction == "BUY":
            r_distance = round(entry_price - stop_loss, 2)
            if stop_loss >= entry_price:
                return RiskApproval(
                    approved=False,
                    rejection_reason="Invalid Stop Loss: For BUY trades, SL must be strictly below Entry.",
                    entry_price=entry_price,
                    stop_loss=stop_loss,
                    stop_distance=r_distance,
                    quantity=0,
                    risk_budget=risk_budget,
                    risk_reward_t2=0.0,
                    targets={}
                )
        else: # SELL
            r_distance = round(stop_loss - entry_price, 2)
            if stop_loss <= entry_price:
                return RiskApproval(
                    approved=False,
                    rejection_reason="Invalid Stop Loss: For SELL trades, SL must be strictly above Entry.",
                    entry_price=entry_price,
                    stop_loss=stop_loss,
                    stop_distance=r_distance,
                    quantity=0,
                    risk_budget=risk_budget,
                    risk_reward_t2=0.0,
                    targets={}
                )

        if r_distance <= 0.05:
            return RiskApproval(
                approved=False,
                rejection_reason=f"Stop distance R (₹{r_distance:.2f}) is too tight / unexecutable.",
                entry_price=entry_price,
                stop_loss=stop_loss,
                stop_distance=r_distance,
                quantity=0,
                risk_budget=risk_budget,
                risk_reward_t2=0.0,
                targets={}
            )

        # Max stop distance limit (e.g. not more than 8% of stock price)
        if (r_distance / entry_price) > 0.08:
            return RiskApproval(
                approved=False,
                rejection_reason=f"Stop distance R (₹{r_distance:.2f}) exceeds 8% risk tolerance.",
                entry_price=entry_price,
                stop_loss=stop_loss,
                stop_distance=r_distance,
                quantity=0,
                risk_budget=risk_budget,
                risk_reward_t2=0.0,
                targets={}
            )

        # Quantity calculation from Risk Budget
        quantity = int(risk_budget // r_distance)
        if quantity < 1:
            return RiskApproval(
                approved=False,
                rejection_reason=f"Calculated quantity is 0 (Budget ₹{risk_budget} < Stop distance ₹{r_distance:.2f}).",
                entry_price=entry_price,
                stop_loss=stop_loss,
                stop_distance=r_distance,
                quantity=0,
                risk_budget=risk_budget,
                risk_reward_t2=0.0,
                targets={}
            )

        # Build 1R through 6R Target Ladder
        targets: Dict[str, float] = {}
        for n in range(1, 7):
            if direction == "BUY":
                tn = round(entry_price + (n * r_distance), 2)
            else:
                tn = round(entry_price - (n * r_distance), 2)
            targets[f"{n}R"] = tn

        # Risk / Reward check on Target 2
        reward_t2 = abs(target_2_price - entry_price) if target_2_price > 0 else (2 * r_distance)
        rr_t2 = round(reward_t2 / r_distance, 2)

        if rr_t2 < settings.MIN_RISK_REWARD:
            return RiskApproval(
                approved=False,
                rejection_reason=f"Insufficient Risk/Reward ratio: 1:{rr_t2:.2f} (Minimum required: 1:{settings.MIN_RISK_REWARD:.2f}).",
                entry_price=entry_price,
                stop_loss=stop_loss,
                stop_distance=r_distance,
                quantity=quantity,
                risk_budget=risk_budget,
                risk_reward_t2=rr_t2,
                targets=targets
            )

        return RiskApproval(
            approved=True,
            rejection_reason=None,
            entry_price=entry_price,
            stop_loss=stop_loss,
            stop_distance=r_distance,
            quantity=quantity,
            risk_budget=risk_budget,
            risk_reward_t2=rr_t2,
            targets=targets
        )

agent8 = Agent8_RiskOfficer()
