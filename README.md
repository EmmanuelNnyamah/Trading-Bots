# Trading Bots Portfolio

A collection of nine MetaTrader 5 automation projects (4 Python examples and 5 MQL5 Expert Advisors), reconstructed from the strategy specifications in the developer's project history.

> **Important:** These projects are educational prototypes, not investment advice or proven profitable systems. Synthetic indices, CFDs, leverage, spreads, slippage and execution failures can cause rapid losses. Test in MetaTrader 5 Strategy Tester and on a demo account. Do not assume backtests predict future performance.

## Projects

| Project | Language | Strategy | Main settings |
|---|---|---|---|
| Boom 500 RSI | Python | RSI extremes | M1, RSI 14, OB 70 / OS 30, one position |
| Boom 500 Bollinger | Python | Bollinger breakout | Period 20, deviation 2 |
| Boom 500 Liquidity Sweep | Python | Swing sweep + Bollinger + trend | M5, EMA50, BB20/2, 20-bar swing |
| Gold Support/Resistance | Python | Support/resistance rejection | XAUUSD, M5, 500 bars, 0.10 lots |
| AlwaysIn FlipBot | MQL5 | EMA + Stochastic flips | H1, EMA10/50, Stoch 5/3/3, 0.20 lots, magic 600600, no fixed SL/TP |
| Boom 500 Price Action | MQL5 | EMA trend + candle breakout | EMA50/200, 200-point trail |
| Gold Prop Firm | MQL5 | EMA trend + trailing runner | XAUUSD, M15, EMA50/200 |
| VIX FlipBot | MQL5 | EMA/Stochastic flip | M1, EMA10/50, Stoch 5/3/3, percentage spread filter, volume normalization |
| ELITE Adaptive Bot | MQL5 | EMA/Stochastic + spike filter | M1, magic 150001, requested lot 1.0, 30s cooldown, trailing only |

## Repository layout

```text
Python_Bots/
  common/mt5_common.py
  Boom500_RSI/boom500_rsi.py
  Boom500_Bollinger/boom500_bollinger.py
  Boom500_Liquidity_Sweep/boom500_liquidity_sweep.py
  Gold_Support_Resistance/gold_sr.py
MQL5_EAs/
  AlwaysIn_FlipBot/AlwaysIn_FlipBot.mq5
  Boom500_Price_Action/Boom500_Price_Action.mq5
  Gold_Prop_Firm/Gold_Prop_Firm.mq5
  VIX_FlipBot/VIX_FlipBot.mq5
  ELITE_Adaptive_Bot/ELITE_Adaptive_Bot.mq5
requirements.txt
```

## Python setup

1. Install MetaTrader 5 desktop terminal and Python 3.10+.
2. From the repository root:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

3. Start MT5 and use a demo account. The portfolio's Python helper defaults to `DRY_RUN=True`, so it logs intended orders rather than sending them.
4. Run one bot at a time from the repository root, for example:

```powershell
python Python_Bots/Boom500_RSI/boom500_rsi.py
```

Broker symbol names vary. Update symbol constants if your broker uses a suffix or different label.

## MQL5 setup

Copy each `.mq5` file into the MT5 data folder under `MQL5/Experts/`. Open in MetaEditor, compile, and test in Strategy Tester before attaching to a demo chart.

## Reconstruction notes

Not every original source-code block or parameter was retained in the available prior-chat history. These are complete reconstructed implementations, not verified byte-for-byte copies of all earlier versions. In particular, exit rules and some indicator/session/trailing parameters are explicitly documented as reconstruction assumptions in the accompanying portfolio README. Validate each strategy against the intended historical behavior before use.

## Safety checklist

- Verify symbol, tick size/value, digits, volume min/max/step, stop level and filling mode.
- Check account mode (netting vs hedging).
- Verify spread filters using your broker's quote scale.
- Test rejected orders, terminal restarts and connection loss.
- Include spread, commission and slippage in backtests.
- Keep the Python dry-run default until the code has been reviewed and demo-tested.

## License

MIT. See `LICENSE`.
