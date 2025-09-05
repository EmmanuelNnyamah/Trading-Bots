import MetaTrader5 as mt5
import pandas as pd
import time
from datetime import datetime, timedelta

# Configuration 
symbol = "Boom 500 Index"
lot_size = 0.2
rsi_period = 14
rsi_overbought = 70
rsi_oversold = 30
timeframe = mt5.TIMEFRAME_M30  # Changed to 30-minute candles
magic_number = 123456
deviation = 20
sleep_time = 60  # seconds between checks
close_after_minutes = 60  # Close trade after 1 hour

# Initialize connection
if not mt5.initialize():
    print("❌ Initialize failed:", mt5.last_error())
    quit()

# Get lot size for symbol
def get_valid_lot(symbol):
    info = mt5.symbol_info(symbol)
    return info.volume_min if info else lot_size

# Calculate RSI
def calculate_rsi(data, period=14):
    delta = data["close"].diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_gain = gain.rolling(window=period).mean()
    avg_loss = loss.rolling(window=period).mean()
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

# Place BUY Order
def buy_trade(valid_lot):
    price = mt5.symbol_info_tick(symbol).ask
    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": valid_lot,
        "type": mt5.ORDER_TYPE_BUY,
        "price": price,
        "deviation": deviation,
        "magic": magic_number,
        "comment": "Auto buy Boom 500",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_FOK,
    }
    result = mt5.order_send(request)
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        print(f"❌ BUY order failed: {result.retcode} ({result.comment})")
    else:
        print("✅ BUY order placed successfully!")

# Place SELL Order
def sell_trade(valid_lot):
    price = mt5.symbol_info_tick(symbol).bid
    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": valid_lot,
        "type": mt5.ORDER_TYPE_SELL,
        "price": price,
        "deviation": deviation,
        "magic": magic_number,
        "comment": "Auto sell Boom 500",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_FOK,
    }
    result = mt5.order_send(request)
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        print(f"❌ SELL order failed: {result.retcode} ({result.comment})")
    else:
        print("✅ SELL order placed successfully!")

# Close trades after 1 hour
def close_old_positions():
    now = datetime.now()
    positions = mt5.positions_get(symbol=symbol)
    for pos in positions:
        open_time = datetime.fromtimestamp(pos.time)
        if (now - open_time) >= timedelta(minutes=close_after_minutes):
            price = mt5.symbol_info_tick(symbol).bid if pos.type == mt5.ORDER_TYPE_BUY else mt5.symbol_info_tick(symbol).ask
            close_type = mt5.ORDER_TYPE_SELL if pos.type == mt5.POSITION_TYPE_BUY else mt5.ORDER_TYPE_BUY

            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": pos.volume,
                "type": close_type,
                "position": pos.ticket,
                "price": price,
                "deviation": deviation,
                "magic": magic_number,
                "comment": "Auto close after 1 hour",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_FOK,
            }

            result = mt5.order_send(request)
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                print(f"✅ Position {pos.ticket} closed after 1 hour.")
            else:
                print(f"❌ Failed to close position {pos.ticket}: {result.retcode} ({result.comment})")

# Main Bot Logic
def run_bot():
    print("🚀 Boom500 RSI bot started with 30m candles. Press Ctrl+C to stop.")
    valid_lot = get_valid_lot(symbol)

    while True:
        try:
            rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, 200)
            if rates is None or len(rates) < rsi_period + 1:
                print("⚠️ Not enough candle data. Waiting...")
                time.sleep(sleep_time)
                continue

            df = pd.DataFrame(rates)
            df = df[df["close"] > 0]
            df["time"] = pd.to_datetime(df["time"], unit="s")
            df["rsi"] = calculate_rsi(df, rsi_period)
            df.dropna(subset=["rsi"], inplace=True)

            if df.empty:
                print("⚠️ RSI not ready. Waiting for more data...")
                time.sleep(sleep_time)
                continue

            latest_rsi = df["rsi"].iloc[-1]
            print(f"[{datetime.now().strftime('%H:%M:%S')}] RSI (30m): {latest_rsi:.2f}")

            positions = mt5.positions_get(symbol=symbol)
            has_position = len(positions) > 0

            if not has_position:
                if latest_rsi > rsi_overbought:
                    print("📉 RSI is overbought. Sending SELL order...")
                    sell_trade(valid_lot)
                elif latest_rsi < rsi_oversold:
                    print("📈 RSI is oversold. Sending BUY order...")
                    buy_trade(valid_lot)
                else:
                    print("📊 No trade signal.")
            else:
                print("📊 Position open. Checking age to auto-close if needed.")
                close_old_positions()

            time.sleep(sleep_time)

        except Exception as e:
            print(f"❌ Error: {e}")
            time.sleep(sleep_time)

run_bot()
