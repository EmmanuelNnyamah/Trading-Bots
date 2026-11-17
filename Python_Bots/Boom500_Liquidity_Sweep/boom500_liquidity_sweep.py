"""Liquidity sweep + Bollinger confirmation prototype.
Reconstruction assumptions: M5, 20-bar swing levels, BB20/2, EMA50 trend
filter, and UTC 12:00-21:00 session approximation. Check DST before use.
"""
import MetaTrader5 as mt5
from datetime import time as dtime
from Python_Bots.common.mt5_common import connect, disconnect, rates, bollinger, positions, market_order, run_loop

SYMBOL = "Boom 500 Index"
TIMEFRAME = mt5.TIMEFRAME_M5
LOT = 0.20
MAGIC = 123458
SWING_LOOKBACK = 20
EMA_PERIOD = 50
BB_PERIOD = 20
BB_DEV = 2.0
CHECK_SECONDS = 30

def in_session(ts):
    return dtime(12, 0) <= ts.time() <= dtime(21, 0)

def step():
    df = rates(SYMBOL, TIMEFRAME, 150)
    candle = df.iloc[-2]
    prior = df.iloc[-(SWING_LOOKBACK+2):-2]
    prior_high, prior_low = float(prior["high"].max()), float(prior["low"].min())
    ema = df["close"].ewm(span=EMA_PERIOD, adjust=False).mean()
    _, upper, lower = bollinger(df["close"], BB_PERIOD, BB_DEV)
    close = float(candle["close"])
    swept_high = float(candle["high"]) > prior_high and close < prior_high
    swept_low = float(candle["low"]) < prior_low and close > prior_low
    trend_up, trend_down = close > float(ema.iloc[-2]), close < float(ema.iloc[-2])
    bb_sell, bb_buy = close < float(upper.iloc[-2]), close > float(lower.iloc[-2])
    if positions(SYMBOL, MAGIC) or not in_session(candle["time"]):
        return
    if swept_low and trend_up and bb_buy:
        market_order(SYMBOL, "BUY", LOT, MAGIC, "Liquidity sweep buy")
    elif swept_high and trend_down and bb_sell:
        market_order(SYMBOL, "SELL", LOT, MAGIC, "Liquidity sweep sell")
    print(f"[SWEEP] high={swept_high} low={swept_low} up={trend_up} down={trend_down}")

if __name__ == "__main__":
    connect()
    try:
        run_loop(step, CHECK_SECONDS)
    except KeyboardInterrupt:
        print("Stopping bot.")
    finally:
        disconnect()
