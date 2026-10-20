# ⚡ AI Trading Desk: Institutional Multi-Agent Trading System

An institutional-grade, multi-agent algorithmic trading desk built on **Python + FastAPI**, **PostgreSQL** (with transparent local fallback), **FYERS API v3**, and a modern web dashboard.

---

## 🏛️ System Architecture

The trading operation is organized into **11 specialized logical agents** governed by the **Trading Desk Manager**:

```
                       ┌─────────────────────────────────────────┐
                       │          TRADING DESK MANAGER           │
                       │  5-Factor Quantitative Candidate Gate   │
                       │     Reconciliation & Disagreement       │
                       └────────────────────┬────────────────────┘
                                            │
        ┌───────────────────────────────────┼───────────────────────────────────┐
        ▼                                   ▼                                   ▼
 MACRO & SECTORS                     PRICE LEVEL TEAMS                   RISK & RESEARCH
┌───────────────────────────┐       ┌───────────────────────────┐       ┌───────────────────────────┐
│ #1 Sector Radar           │       │ #6 Previous-Day Levels    │       │ #8 Risk Officer           │
│ #2 Sector Leaders         │       │    (PDH Sell, PDL Buy)    │       │    (Size, 1R-6R ladder)   │
│ #3 Nifty Bias             │       │ #7 Previous-Week Levels   │       │ #9 Trade Journal          │
│ #4 Sector Reversal        │       │    (PWH Sell, PWL Buy)    │       │ #10 Trade Observer        │
│ #5 Stock Confirmation     │       │                           │       │ #11 Research Analyst      │
└───────────────────────────┘       └───────────────────────────┘       └───────────────────────────┘
```

### The Anti-Trap Golden Rule: Buy at the Low, Sell on Top
- **At PDH / PWH**: We **ONLY SELL ON TOP**. When retail chases breakouts that fail, we short breakdowns back below the Pivot.
- **At PDL / PWL**: We **ONLY BUY AT THE LOW**. When retail panics on breakdown traps, we buy recoveries back above the Pivot.
- Buying at the highs or selling at the lows is strictly rejected by the Manager.

---

## 🛠️ Technology Stack
- **Backend**: Python 3.11+ / 3.14, FastAPI, SQLAlchemy 2.0 (Async)
- **Database**: PostgreSQL (Production) with SQLite async fallback (`aiosqlite`)
- **Market Data**: FYERS API v3 (Quotes chunked to 50 symbols, streaming DataSocket)
- **Frontend**: Vanilla CSS institutional terminal, responsive WebSocket streaming
- **AI Integration**: Internal MCP (Model Context Protocol) tool provider
- **Containerization**: Docker, Docker Compose, Render Blueprint

---

## 🚀 Running Locally on Windows

1. **Activate virtual environment**:
   ```powershell
   .venv\Scripts\Activate.ps1
   ```

2. **Start the AI Trading Desk**:
   ```powershell
   cd c:\Users\Admin\market_watch\ai_trading_desk
   python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
   ```

3. Open your browser at:
   ```
   http://localhost:8000
   ```

---

## ☁️ Deploying to a Private Cloud Website

### Option 1: Docker Compose (Private VPS / Cloud VM)
```bash
docker compose up -d --build
```
This starts both PostgreSQL 16 and the Trading Desk container.

### Option 2: Render.com (1-Click Deployment)
1. Push repository to private GitHub.
2. Link repository to Render using `render.yaml`.
3. Add your `FYERS_APP_ID`, `FYERS_SECRET_KEY`, and `FYERS_ACCESS_TOKEN`.
4. Render automatically provisions the managed PostgreSQL database and private HTTPS domain.

---

## 🔒 Security
- FYERS credentials kept strictly server-side.
- Zero direct automated broker order placement: confirmed trade reports and real manual trade recording.
- Permanent audit log of all decisions, stop adjustments, and user actions.
