"""XAUUSD support/resistance prototype: M5, 500 bars, 0.10 lots.
20-bar levels and 1.5 price-unit proximity are reconstruction assumptions.
"""
import MetaTrader5 as mt5
from Python_Bots.common.mt5_common import connect, disconnect, rates, positions, market_order, run_loop

SYMBOL = "XAUUSD"
TIMEFRAME = mt5.TIMEFRAME_M5
BARS = 500
LOT = 0.10
MAGIC = 123456
LEVEL_LOOKBACK = 20
PROXIMITY = 1.5
CHECK_SECONDS = 30

def step():
    df = rates(SYMBOL, TIMEFRAME, BARS)
    candle = df.iloc[-2]
    prior = df.iloc[-(LEVEL_LOOKBACK+2):-2]
    support, resistance = float(prior["low"].min()), float(prior["high"].max())
    close = float(candle["close"])
    bullish = float(candle["low"]) <= support + PROXIMITY and close > support
    bearish = float(candle["high"]) >= resistance - PROXIMITY and close < resistance
    if positions(magic=MAGIC):
        return
    if bullish:
        market_order(SYMBOL, "BUY", LOT, MAGIC, "Gold support rejection")
    elif bearish:
        market_order(SYMBOL, "SELL", LOT, MAGIC, "Gold resistance rejection")
    print(f"[S/R] support={support:.2f} resistance={resistance:.2f} close={close:.2f}")

if __name__ == "__main__":
    connect()
    try:
        run_loop(step, CHECK_SECONDS)
    except KeyboardInterrupt:
        print("Stopping bot.")
    finally:
        disconnect()
