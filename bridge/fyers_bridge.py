import asyncio
import json
import os
import websockets
from fyers_apiv3.FyersWebsocket import data_ws

# ---- CONFIG ----
APP_ID = "77WFZ67AWG-200"


def load_access_token():
    # Reads the token written by the Flutter app after login, instead of
    # a hardcoded string that goes stale every few days.
    token_path = os.path.join(os.path.dirname(__file__), "access_token.txt")
    with open(token_path, "r") as f:
        return f.read().strip()


ACCESS_TOKEN = load_access_token()

SYMBOLS = [
    "NSE:NIFTY50-INDEX",
    "NSE:NIFTYBANK-INDEX",
    "NSE:FINNIFTY-INDEX",
    "NSE:MIDCPNIFTY-INDEX",
    "NSE:RELIANCE-EQ",
    "NSE:TCS-EQ",
    "NSE:INFY-EQ",
    "NSE:SBIN-EQ",
    "NSE:HDFCBANK-EQ",
    "NSE:ICICIBANK-EQ",
    "NSE:LT-EQ",
]
LOCAL_WS_PORT = 9000
# ----------------

connected_clients = set()
loop = None  # set once the asyncio loop starts


async def register(websocket):
    connected_clients.add(websocket)
    try:
        await websocket.wait_closed()
    finally:
        connected_clients.discard(websocket)


async def broadcast(message: dict):
    if not connected_clients:
        return
    data = json.dumps(message)
    await asyncio.gather(
        *(client.send(data) for client in connected_clients),
        return_exceptions=True,
    )


def on_message(message):
    print("TICK:", message)
    if loop is not None:
        asyncio.run_coroutine_threadsafe(broadcast(message), loop)


def on_error(message):
    print("Fyers WS Error:", message)


def on_close(message):
    print("Fyers WS Closed:", message)


def on_connect():
    print("Fyers WS Connected — subscribing...")
    fyers_ws.subscribe(symbols=SYMBOLS, data_type="SymbolUpdate")
    fyers_ws.keep_running()


access_token = f"{APP_ID}:{ACCESS_TOKEN}"
fyers_ws = data_ws.FyersDataSocket(
    access_token=access_token,
    log_path="",
    litemode=False,
    write_to_file=False,
    reconnect=True,
    on_connect=on_connect,
    on_close=on_close,
    on_error=on_error,
    on_message=on_message,
)


async def main():
    global loop
    loop = asyncio.get_running_loop()
    # Run Fyers' blocking SDK connection in a background thread
    await loop.run_in_executor(None, fyers_ws.connect)
    async with websockets.serve(register, "127.0.0.1", LOCAL_WS_PORT):
        print(f"Local bridge WebSocket running at ws://127.0.0.1:{LOCAL_WS_PORT}")
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    asyncio.run(main())