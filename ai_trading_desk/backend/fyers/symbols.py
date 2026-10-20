"""
Verified NSE Instrument and Sector Master
Maps sector indices to constituents and defines F&O universe.
"""

from typing import Dict, List, Any

# Primary NSE Sector Indices monitored by Sector Radar (Agent #1)
SECTOR_INDICES = [
    {"name": "NIFTY BANK", "fyers": "NSE:NIFTYBANK-INDEX", "short": "BANK"},
    {"name": "NIFTY IT", "fyers": "NSE:NIFTYIT-INDEX", "short": "IT"},
    {"name": "NIFTY AUTO", "fyers": "NSE:NIFTYAUTO-INDEX", "short": "AUTO"},
    {"name": "NIFTY METAL", "fyers": "NSE:NIFTYMETAL-INDEX", "short": "METAL"},
    {"name": "NIFTY PHARMA", "fyers": "NSE:NIFTYPHARMA-INDEX", "short": "PHARMA"},
    {"name": "NIFTY FMCG", "fyers": "NSE:NIFTYFMCG-INDEX", "short": "FMCG"},
    {"name": "NIFTY ENERGY", "fyers": "NSE:NIFTYENERGY-INDEX", "short": "ENERGY"},
    {"name": "NIFTY REALTY", "fyers": "NSE:NIFTYREALTY-INDEX", "short": "REALTY"},
    {"name": "NIFTY INFRA", "fyers": "NSE:NIFTYINFRA-INDEX", "short": "INFRA"},
    {"name": "NIFTY FINANCIAL SERVICES", "fyers": "NSE:FINNIFTY-INDEX", "short": "FINANCE"},
]

# Benchmark index for Market Regime (Agent #3)
BENCHMARK_NIFTY = {
    "name": "NIFTY 50",
    "fyers": "NSE:NIFTY50-INDEX",
    "short": "NIFTY"
}

# Key high-volume liquid F&O constituents by sector
SECTOR_CONSTITUENTS: Dict[str, List[str]] = {
    "NIFTY BANK": [
        "HDFCBANK", "ICICIBANK", "SBIN", "KOTAKBANK", "AXISBANK", 
        "INDUSINDBK", "BANKBARODA", "PNB", "AUBANK", "FEDERALBNK"
    ],
    "NIFTY IT": [
        "TCS", "INFY", "HCLTECH", "WIPRO", "TECHM", 
        "LTIM", "PERSISTENT", "COFORGE", "MPHASIS"
    ],
    "NIFTY AUTO": [
        "MARUTI", "M&M", "TATAMOTORS", "BAJAJ-AUTO", "EICHERMOT", 
        "HEROMOTOCO", "TVSMOTOR", "BHARATFORG", "ASHOKLEY"
    ],
    "NIFTY METAL": [
        "TATASTEEL", "JSWSTEEL", "HINDALCO", "VEDL", "JINDALSTEL", 
        "NMDC", "NATIONALUM", "SAIL"
    ],
    "NIFTY PHARMA": [
        "SUNPHARMA", "CIPLA", "DRREDDY", "DIVISLAB", "LUPIN", 
        "AUROPHARMA", "TORNTPHARM", "ALKEM", "BIOCON"
    ],
    "NIFTY FMCG": [
        "ITC", "HINDUNILVR", "NESTLEIND", "BRITANNIA", "TATACONSUM", 
        "GODREJCP", "DABUR", "MARICO", "COLPAL"
    ],
    "NIFTY ENERGY": [
        "RELIANCE", "NTPC", "POWERGRID", "ONGC", "BPCL", 
        "IOC", "COALINDIA", "GAIL", "TATAPOWER"
    ],
    "NIFTY REALTY": [
        "DLF", "GODREJPROP", "OBEROIRLTY", "PHOENIXLTD", "BRIGADE"
    ],
    "NIFTY INFRA": [
        "LT", "BHARTIARTL", "ADANIPORTS", "ULTRACEMCO", "GRASIM"
    ],
    "NIFTY FINANCIAL SERVICES": [
        "BAJFINANCE", "BAJAJFINSV", "CHOLAFIN", "SHRIRAMFIN", "MUTHOOTFIN", "HDFCLIFE", "SBILIFE"
    ]
}

# Reverse lookup: Stock -> Sector
STOCK_TO_SECTOR: Dict[str, str] = {}
for sector, stocks in SECTOR_CONSTITUENTS.items():
    for stock in stocks:
        STOCK_TO_SECTOR[stock] = sector

def get_fyers_symbol(symbol: str) -> str:
    """Formats standard NSE equity symbol into FYERS symbol format (e.g. NSE:RELIANCE-EQ)."""
    if symbol.startswith("NSE:"):
        return symbol
    if "-INDEX" in symbol:
        return f"NSE:{symbol}"
    return f"NSE:{symbol}-EQ"

def get_raw_symbol(fyers_symbol: str) -> str:
    """Strips exchange prefix and suffix to yield clean ticker symbol."""
    sym = fyers_symbol.replace("NSE:", "").replace("-EQ", "").replace("-INDEX", "")
    return sym
