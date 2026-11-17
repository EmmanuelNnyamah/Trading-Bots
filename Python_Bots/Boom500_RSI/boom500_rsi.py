"""Boom 500 RSI example. Original settings: M1, RSI(14), OB70/OS30.
One position at a time. Reconstructed exit: close on return through RSI 50.
"""
import MetaTrader5 as mt5
from Python_Bots.common.mt5_common import connect, disconnect, rates, rsi, positions, market_order, close_position, run_loop

SYMBOL = "Boom 500 Index"
TIMEFRAME = mt5.TIMEFRAME_M1
RSI_PERIOD = 14
OVERBOUGHT = 70
OVERSOLD = 30
MAGIC = 123456
LOT = 0.20
CHECK_SECONDS = 60
EXIT_LEVEL = 50

def step():
    df = rates(SYMBOL, TIMEFRAME, 100)
    values = rsi(df["close"], RSI_PERIOD)
    value = float(values.iloc[-2])
    open_positions = positions(SYMBOL, MAGIC)
    if open_positions:
        p = open_positions[0]
        if p.type == mt5.POSITION_TYPE_BUY and value >= EXIT_LEVEL:
            close_position(p)
        elif p.type == mt5.POSITION_TYPE_SELL and value <= EXIT_LEVEL:
            close_position(p)
        return
    if value <= OVERSOLD:
        market_order(SYMBOL, "BUY", LOT, MAGIC, "Boom RSI buy")
    elif value >= OVERBOUGHT:
        market_order(SYMBOL, "SELL", LOT, MAGIC, "Boom RSI sell")
    print(f"[RSI] {SYMBOL} RSI={value:.2f}")

if __name__ == "__main__":
    connect()
    try:
        run_loop(step, CHECK_SECONDS)
    except KeyboardInterrupt:
        print("Stopping bot.")
    finally:
        disconnect()
