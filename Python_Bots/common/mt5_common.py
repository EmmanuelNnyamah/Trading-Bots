"""Shared MT5 helpers. Python examples default to DRY_RUN=True."""
from __future__ import annotations
import time
from datetime import datetime, timezone
import MetaTrader5 as mt5
import pandas as pd

DRY_RUN = True
DEFAULT_DEVIATION = 20

def connect():
    if not mt5.initialize():
        raise RuntimeError(f"MT5 initialize failed: {mt5.last_error()}")
    info = mt5.terminal_info()
    if info is None:
        raise RuntimeError("Could not read MT5 terminal info")
    print(f"Connected to MT5 | terminal={info.name} | dry_run={DRY_RUN}")

def disconnect():
    mt5.shutdown()

def ensure_symbol(symbol):
    info = mt5.symbol_info(symbol)
    if info is None:
        raise RuntimeError(f"Symbol not found: {symbol}")
    if not info.visible and not mt5.symbol_select(symbol, True):
        raise RuntimeError(f"Could not select {symbol}: {mt5.last_error()}")
    return mt5.symbol_info(symbol)

def rates(symbol, timeframe=mt5.TIMEFRAME_M1, count=300):
    ensure_symbol(symbol)
    raw = mt5.copy_rates_from_pos(symbol, timeframe, 0, count)
    if raw is None or len(raw) < 5:
        raise RuntimeError(f"Insufficient rates for {symbol}: {mt5.last_error()}")
    df = pd.DataFrame(raw)
    df["time"] = pd.to_datetime(df["time"], unit="s", utc=True)
    return df

def rsi(series, period=14):
    delta = series.diff()
    gain, loss = delta.clip(lower=0), -delta.clip(upper=0)
    avg_gain = gain.ewm(alpha=1/period, adjust=False, min_periods=period).mean()
    avg_loss = loss.ewm(alpha=1/period, adjust=False, min_periods=period).mean()
    rs = avg_gain / avg_loss.replace(0, float("nan"))
    out = 100 - (100 / (1 + rs))
    out = out.mask((avg_loss == 0) & (avg_gain > 0), 100)
    return out.mask((avg_loss == 0) & (avg_gain == 0), 50)

def bollinger(series, period=20, deviation=2.0):
    mid = series.rolling(period).mean()
    sd = series.rolling(period).std(ddof=0)
    return mid, mid + deviation * sd, mid - deviation * sd

def positions(symbol=None, magic=None):
    found = mt5.positions_get(symbol=symbol) if symbol else mt5.positions_get()
    if found is None:
        return []
    result = list(found)
    return [p for p in result if magic is None or p.magic == magic]

def normalize_volume(symbol, requested):
    info = ensure_symbol(symbol)
    step = info.volume_step or info.volume_min
    volume = round(round(requested / step) * step, 8)
    return max(info.volume_min, min(info.volume_max, volume))

def market_order(symbol, side, volume, magic, comment, deviation=DEFAULT_DEVIATION):
    ensure_symbol(symbol)
    tick = mt5.symbol_info_tick(symbol)
    if tick is None:
        raise RuntimeError(f"No tick for {symbol}")
    order_type = mt5.ORDER_TYPE_BUY if side.upper() == "BUY" else mt5.ORDER_TYPE_SELL
    price = tick.ask if side.upper() == "BUY" else tick.bid
    volume = normalize_volume(symbol, volume)
    request = {
        "action": mt5.TRADE_ACTION_DEAL, "symbol": symbol, "volume": volume,
        "type": order_type, "price": price, "deviation": deviation,
        "magic": magic, "comment": comment[:31], "type_time": mt5.ORDER_TIME_GTC,
    }
    if DRY_RUN:
        print(f"[DRY RUN] {side} {symbol} volume={volume} price≈{price}")
        return None
    last = None
    for mode in (mt5.ORDER_FILLING_IOC, mt5.ORDER_FILLING_FOK, mt5.ORDER_FILLING_RETURN):
        request["type_filling"] = mode
        last = mt5.order_send(request)
        if last and last.retcode == mt5.TRADE_RETCODE_DONE:
            print(f"[ORDER] {side} {symbol} volume={volume} ticket={last.order}")
            return last
        if last and last.retcode != 10030:
            break
    print(f"[ORDER FAILED] {last}")
    return last

def close_position(position, deviation=DEFAULT_DEVIATION):
    tick = mt5.symbol_info_tick(position.symbol)
    if tick is None:
        print(f"No tick to close position {position.ticket}")
        return None
    is_buy = position.type == mt5.POSITION_TYPE_BUY
    request = {
        "action": mt5.TRADE_ACTION_DEAL, "symbol": position.symbol,
        "position": position.ticket, "volume": position.volume,
        "type": mt5.ORDER_TYPE_SELL if is_buy else mt5.ORDER_TYPE_BUY,
        "price": tick.bid if is_buy else tick.ask, "deviation": deviation,
        "magic": position.magic, "comment": "portfolio close",
        "type_time": mt5.ORDER_TIME_GTC,
    }
    if DRY_RUN:
        print(f"[DRY RUN] Close ticket={position.ticket} {position.symbol}")
        return None
    for mode in (mt5.ORDER_FILLING_IOC, mt5.ORDER_FILLING_FOK, mt5.ORDER_FILLING_RETURN):
        request["type_filling"] = mode
        result = mt5.order_send(request)
        if result and result.retcode == mt5.TRADE_RETCODE_DONE:
            return result
        if result and result.retcode != 10030:
            print(f"[CLOSE FAILED] ticket={position.ticket}: {result}")
            return result
    print(f"[CLOSE FAILED] ticket={position.ticket}: {mt5.last_error()}")
    return None

def current_spread_percent(symbol):
    ensure_symbol(symbol)
    tick = mt5.symbol_info_tick(symbol)
    if not tick or tick.ask <= 0:
        return float("inf")
    mid = (tick.ask + tick.bid) / 2
    return ((tick.ask - tick.bid) / mid) * 100

def run_loop(fn, seconds=60):
    while True:
        try:
            fn()
        except KeyboardInterrupt:
            raise
        except Exception as exc:
            print(f"[ERROR] {datetime.now(timezone.utc).isoformat()} {exc}")
        time.sleep(seconds)
