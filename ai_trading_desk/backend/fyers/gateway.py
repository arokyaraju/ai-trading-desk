"""
FYERS Market Data Gateway
Manages authentication, REST API snapshots, WebSocket DataSocket streaming,
and market data caching.
"""

import os
import sys
import json
import time
import logging
import asyncio
from typing import Dict, List, Optional, Any, Callable
from ..config import settings
from .symbols import SECTOR_INDICES, BENCHMARK_NIFTY, SECTOR_CONSTITUENTS, get_fyers_symbol, get_raw_symbol

logger = logging.getLogger("ai_trading_desk.fyers")

class FyersGateway:
    def __init__(self):
        self.app_id = settings.FYERS_APP_ID
        self.secret_key = settings.FYERS_SECRET_KEY
        self.token: Optional[str] = None
        self.fyers_client = None
        self.live_quotes: Dict[str, Dict[str, Any]] = {}
        self.callbacks: List[Callable[[Dict[str, Any]], None]] = []
        self.is_connected = False
        self._load_token()

    def update_token(self, new_token: str) -> bool:
        """Updates and activates a new FYERS access token."""
        self.token = new_token.strip()
        self.fyers_client = None
        token_path = settings.FYERS_TOKEN_PATH
        try:
            os.makedirs(os.path.dirname(token_path), exist_ok=True)
            with open(token_path, "w", encoding="utf-8") as f:
                f.write(self.token)
            logger.info("Saved and activated new FYERS access token.")
        except Exception as e:
            logger.error(f"Error writing FYERS token to file: {e}")
        return self.get_client() is not None

    def _load_token(self) -> Optional[str]:
        """Loads access token from settings or token file."""
        if settings.FYERS_ACCESS_TOKEN:
            self.token = settings.FYERS_ACCESS_TOKEN.strip()
            return self.token
            
        token_path = settings.FYERS_TOKEN_PATH
        if os.path.exists(token_path):
            try:
                with open(token_path, "r", encoding="utf-8") as f:
                    tok = f.read().strip()
                    if tok:
                        self.token = tok
                        logger.info(f"Loaded FYERS access token from {token_path}")
                        return self.token
            except Exception as e:
                logger.error(f"Failed to read FYERS token file: {e}")
        return None

    def get_client(self):
        """Initializes or returns FYERS REST client instance."""
        if self.fyers_client is not None:
            return self.fyers_client
            
        if not self.token:
            self._load_token()
            
        if not self.token:
            logger.warning("FYERS access token not found. Market data will operate in fallback cache mode.")
            return None
            
        try:
            from fyers_apiv3 import fyersModel
            self.fyers_client = fyersModel.FyersModel(
                client_id=self.app_id,
                is_async=False,
                token=self.token,
                log_path=os.getcwd()
            )
            return self.fyers_client
        except Exception as e:
            logger.error(f"Failed to initialize FyersModel: {e}")
            return None

    def fetch_quotes_batch(self, fyers_symbols: List[str]) -> Dict[str, Dict[str, Any]]:
        """
        Fetches quotes in chunks of 50 (FYERS max batch limit per request).
        Returns a dict mapping symbol to parsed quote details.
        """
        client = self.get_client()
        results: Dict[str, Dict[str, Any]] = {}
        
        if not client or not fyers_symbols:
            return self._generate_fallback_quotes(fyers_symbols)
            
        # FYERS standard plan permits max 50 symbols per quotes request
        batch_size = 50
        for i in range(0, len(fyers_symbols), batch_size):
            chunk = fyers_symbols[i:i + batch_size]
            symbols_str = ",".join(chunk)
            try:
                data = {"symbols": symbols_str}
                resp = client.quotes(data=data)
                if resp.get("s") == "ok" and "d" in resp:
                    for item in resp["d"]:
                        val = item.get("v", {})
                        sym = item.get("n", "")
                        raw = get_raw_symbol(sym)
                        
                        lp = float(val.get("lp", 0.0))
                        prev_close = float(val.get("prev_close_price", 0.0))
                        ch = float(val.get("ch", 0.0))
                        chp = float(val.get("chp", 0.0))
                        open_p = float(val.get("open_price", 0.0))
                        high_p = float(val.get("high_price", 0.0))
                        low_p = float(val.get("low_price", 0.0))
                        vol = float(val.get("volume", 0.0))
                        
                        quote_obj = {
                            "symbol": raw,
                            "fyers_symbol": sym,
                            "price": lp,
                            "prev_close": prev_close,
                            "open": open_p,
                            "high": high_p,
                            "low": low_p,
                            "change": ch,
                            "change_pct": chp,
                            "volume": vol,
                            "timestamp": time.time()
                        }
                        results[raw] = quote_obj
                        results[sym] = quote_obj
                        self.live_quotes[raw] = quote_obj
                else:
                    logger.warning(f"FYERS quotes error for chunk {i}: {resp.get('message')}")
                    # If token expired or API failed, use cached or fallback
                    fallback = self._generate_fallback_quotes(chunk)
                    results.update(fallback)
            except Exception as e:
                logger.error(f"Error fetching quotes chunk: {e}")
                results.update(self._generate_fallback_quotes(chunk))
                
        return results

    def _generate_fallback_quotes(self, fyers_symbols: List[str]) -> Dict[str, Dict[str, Any]]:
        """
        Provides deterministic, realistic reference quotes when offline or before market open.
        Ensures the trading desk UI and agents are fully operational for inspection.
        """
        results = {}
        # Predefined realistic anchor prices for major symbols
        anchors = {
            "NIFTY 50": 24850.0,
            "NSE:NIFTY50-INDEX": 24850.0,
            "NIFTY BANK": 52100.0,
            "NSE:NIFTYBANK-INDEX": 52100.0,
            "NIFTY IT": 41800.0,
            "NSE:NIFTYIT-INDEX": 41800.0,
            "NIFTY AUTO": 25400.0,
            "NSE:NIFTYAUTO-INDEX": 25400.0,
            "NIFTY METAL": 9450.0,
            "NSE:NIFTYMETAL-INDEX": 9450.0,
            "RELIANCE": 2980.0,
            "HDFCBANK": 1675.0,
            "ICICIBANK": 1245.0,
            "TCS": 4210.0,
            "INFY": 1890.0,
            "TATASTEEL": 154.0,
            "BHARTIARTL": 1640.0,
            "LT": 3620.0,
            "MARUTI": 12850.0
        }
        
        for sym in fyers_symbols:
            raw = get_raw_symbol(sym)
            base_p = anchors.get(raw, anchors.get(sym, 1000.0))
            # Calculate mock daily levels around base
            change_pct = round(((hash(raw) % 50) - 20) / 10.0, 2) # between -2.0% and +3.0%
            price = round(base_p * (1.0 + change_pct / 100.0), 2)
            prev_close = base_p
            open_p = round(base_p * 1.002, 2)
            high_p = max(price, open_p, round(base_p * 1.015, 2))
            low_p = min(price, open_p, round(base_p * 0.985, 2))
            
            quote = {
                "symbol": raw,
                "fyers_symbol": sym,
                "price": price,
                "prev_close": prev_close,
                "open": open_p,
                "high": high_p,
                "low": low_p,
                "change": round(price - prev_close, 2),
                "change_pct": change_pct,
                "volume": 1250000.0,
                "timestamp": time.time(),
                "is_simulated": True
            }
            results[raw] = quote
            results[sym] = quote
            self.live_quotes[raw] = quote
            
        return results

    def fetch_historical_candles(self, symbol: str, resolution: str = "5", days_back: int = 10) -> List[Dict[str, Any]]:
        """
        Fetches historical candles from FYERS or returns synthetic candles for backtesting.
        """
        client = self.get_client()
        fyers_sym = get_fyers_symbol(symbol)
        
        if client:
            try:
                import datetime
                to_date = datetime.date.today().strftime("%Y-%m-%d")
                from_date = (datetime.date.today() - datetime.timedelta(days=days_back)).strftime("%Y-%m-%d")
                
                data = {
                    "symbol": fyers_sym,
                    "resolution": resolution,
                    "date_format": "1",
                    "range_from": from_date,
                    "range_to": to_date,
                    "cont_flag": "1"
                }
                resp = client.history(data=data)
                if resp.get("s") == "ok" and "candles" in resp:
                    candles = []
                    for c in resp["candles"]:
                        # [epoch_time, open, high, low, close, volume]
                        candles.append({
                            "timestamp": c[0],
                            "open": c[1],
                            "high": c[2],
                            "low": c[3],
                            "close": c[4],
                            "volume": c[5]
                        })
                    return candles
            except Exception as e:
                logger.error(f"Error fetching historical candles from FYERS for {symbol}: {e}")

        # Return structured synthetic historical candles for reliable local execution
        return self._generate_synthetic_candles(symbol, resolution, days_back)

    def _generate_synthetic_candles(self, symbol: str, resolution: str, days: int) -> List[Dict[str, Any]]:
        """Generates realistic candlestick series for offline and paper testing."""
        import datetime
        candles = []
        base_price = 1000.0
        if "NIFTY" in symbol:
            base_price = 24800.0
        elif "BANK" in symbol:
            base_price = 52000.0
            
        now = int(time.time())
        step = 300 if resolution == "5" else 3600
        curr = base_price
        
        # generate 75 bars
        for i in range(75, 0, -1):
            ts = now - (i * step)
            noise = ((hash(f"{symbol}_{i}") % 100) - 48) / 100.0
            o = round(curr, 2)
            c = round(curr * (1.0 + (noise * 0.005)), 2)
            h = max(o, c) + round(abs(noise) * 2.0, 2)
            l = min(o, c) - round(abs(noise) * 2.0, 2)
            v = 15000 + (hash(f"{i}") % 50000)
            candles.append({
                "timestamp": ts,
                "open": o,
                "high": h,
                "low": l,
                "close": c,
                "volume": v
            })
            curr = c
            
        return candles

gateway = FyersGateway()
