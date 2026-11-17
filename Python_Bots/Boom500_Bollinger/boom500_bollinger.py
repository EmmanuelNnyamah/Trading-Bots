"""Boom 500 Bollinger breakout. Period 20, deviation 2, M1.
Closed-candle band cross; profitable-only position exit is retained.
"""
import MetaTrader5 as mt5
from Python_Bots.common.mt5_common import connect, disconnect, rates, bollinger, positions, market_order, close_position, run_loop

SYMBOL = "Boom 500 Index"
TIMEFRAME = mt5.TIMEFRAME_M1
PERIOD = 20
DEVIATION = 2.0
LOT = 0.20
MAGIC = 123457
CHECK_SECONDS = 15

def step():
    df = rates(SYMBOL, TIMEFRAME, 100)
    _, upper, lower = bollinger(df["close"], PERIOD, DEVIATION)
    prev_close, last_close = float(df["close"].iloc[-3]), float(df["close"].iloc[-2])
    prev_upper, last_upper = float(upper.iloc[-3]), float(upper.iloc[-2])
    prev_lower, last_lower = float(lower.iloc[-3]), float(lower.iloc[-2])
    pos = positions(SYMBOL, MAGIC)
    if pos:
        if pos[0].profit > 0:
            close_position(pos[0])
        return
    if prev_close <= prev_upper and last_close > last_upper:
        market_order(SYMBOL, "SELL", LOT, MAGIC, "BB upper breakout")
    elif prev_close >= prev_lower and last_close < last_lower:
        market_order(SYMBOL, "BUY", LOT, MAGIC, "BB lower breakout")
    print(f"[BB] close={last_close} upper={last_upper} lower={last_lower}")

if __name__ == "__main__":
    connect()
    try:
        run_loop(step, CHECK_SECONDS)
    except KeyboardInterrupt:
        print("Stopping bot.")
    finally:
        disconnect()
