//+------------------------------------------------------------------+
//| V75_AlwaysIn_FlipBot.mq5                                         |
//|                                                                  |
//| Multi-timeframe Volatility 75 (1s) trend/momentum FlipBot        |
//|                                                                  |
//| H4  : Overall trend (EMA 50 / EMA 200)                           |
//| H1  : Trend confirmation (EMA 10 / EMA 50)                       |
//| M15 : Entry timing (Stochastic 5,3,3 + candle confirmation)      |
//|                                                                  |
//| BUY  : H4 bullish + H1 bullish + stochastic recovery + bull bar  |
//| SELL : H4 bearish + H1 bearish + stochastic reversal + bear bar |
//| EXIT : Close on a confirmed opposite signal                      |
//| SL/TP: No broker-side Stop Loss or Take Profit                   |
//|                                                                  |
//| Risk note: The optional floating-loss guard is an EA-side        |
//| emergency close, not a guaranteed loss limit or broker SL.      |
//| Demo-test and validate symbol/volume settings before use.        |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>

CTrade trade;

//+------------------------------------------------------------------+
//| INPUT SETTINGS                                                   |
//+------------------------------------------------------------------+

input group "=== SYMBOL SETTINGS ==="
input string TradeSymbol = "Volatility 75 (1s) Index";

input group "=== TIMEFRAMES ==="
input ENUM_TIMEFRAMES TrendTF = PERIOD_H4;
input ENUM_TIMEFRAMES ConfirmTF = PERIOD_H1;
input ENUM_TIMEFRAMES EntryTF = PERIOD_M15;

input group "=== H4 TREND SETTINGS ==="
input int H4_FastEMA = 50;
input int H4_SlowEMA = 200;

input group "=== H1 CONFIRMATION SETTINGS ==="
input int H1_FastEMA = 10;
input int H1_SlowEMA = 50;

input group "=== STOCHASTIC SETTINGS ==="
input int Stoch_K = 5;
input int Stoch_D = 3;
input int Stoch_Slowing = 3;
input double Stoch_Overbought = 80.0;
input double Stoch_Oversold = 20.0;

input group "=== TRADE SETTINGS ==="
input double LotSize = 0.2;
input ulong MagicNumber = 750075;
input int DeviationPoints = 50;

input group "=== RISK PROTECTION ==="
input bool EnableMaxLossProtection = true;
input double MaxFloatingLossPercent = 2.0;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

string ActiveSymbol = "";

int h4FastHandle = INVALID_HANDLE;
int h4SlowHandle = INVALID_HANDLE;
int h1FastHandle = INVALID_HANDLE;
int h1SlowHandle = INVALID_HANDLE;
int stochHandle = INVALID_HANDLE;

datetime lastEntryBar = 0;
bool TradingHalted = false;

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+

int OnInit()
{
   ActiveSymbol = (TradeSymbol == "") ? _Symbol : TradeSymbol;

   if(!SymbolSelect(ActiveSymbol, true))
   {
      Print("V75 FlipBot: Symbol not available: ", ActiveSymbol);
      return INIT_FAILED;
   }

   h4FastHandle = iMA(ActiveSymbol, TrendTF, H4_FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   h4SlowHandle = iMA(ActiveSymbol, TrendTF, H4_SlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   h1FastHandle = iMA(ActiveSymbol, ConfirmTF, H1_FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   h1SlowHandle = iMA(ActiveSymbol, ConfirmTF, H1_SlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   stochHandle = iStochastic(
      ActiveSymbol, EntryTF, Stoch_K, Stoch_D, Stoch_Slowing,
      MODE_SMA, STO_LOWHIGH
   );

   if(h4FastHandle == INVALID_HANDLE ||
      h4SlowHandle == INVALID_HANDLE ||
      h1FastHandle == INVALID_HANDLE ||
      h1SlowHandle == INVALID_HANDLE ||
      stochHandle == INVALID_HANDLE)
   {
      Print("V75 FlipBot: Indicator initialization failed.");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(DeviationPoints);
   trade.SetTypeFillingBySymbol(ActiveSymbol);
   trade.LogLevel(LOG_LEVEL_ERRORS);

   Print("======================================");
   Print("V75 ALWAYS-IN FLIPBOT INITIALIZED");
   Print("Symbol: ", ActiveSymbol);
   Print("H4 Trend: EMA ", H4_FastEMA, "/", H4_SlowEMA);
   Print("H1 Confirmation: EMA ", H1_FastEMA, "/", H1_SlowEMA);
   Print("Entry: M15 Stochastic + candle confirmation");
   Print("Lot Size: ", LotSize);
   Print("Stop Loss: DISABLED");
   Print("Take Profit: DISABLED");
   Print("======================================");

   // Wait for a confirmed signal; do not force an initial direction.
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
{
   if(h4FastHandle != INVALID_HANDLE) IndicatorRelease(h4FastHandle);
   if(h4SlowHandle != INVALID_HANDLE) IndicatorRelease(h4SlowHandle);
   if(h1FastHandle != INVALID_HANDLE) IndicatorRelease(h1FastHandle);
   if(h1SlowHandle != INVALID_HANDLE) IndicatorRelease(h1SlowHandle);
   if(stochHandle != INVALID_HANDLE) IndicatorRelease(stochHandle);
}

//+------------------------------------------------------------------+
//| READ LAST TWO CLOSED INDICATOR VALUES                            |
//+------------------------------------------------------------------+

bool GetIndicatorValues(
   int handle,
   int buffer,
   double &current,
   double &previous
)
{
   double values[];
   ArraySetAsSeries(values, true);

   if(CopyBuffer(handle, buffer, 1, 2, values) != 2)
      return false;

   current = values[0];
   previous = values[1];
   return true;
}

//+------------------------------------------------------------------+
//| COUNT POSITIONS BELONGING TO THIS EA                             |
//+------------------------------------------------------------------+

int CountPositions()
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != ActiveSymbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)MagicNumber)
         continue;

      count++;
   }

   return count;
}

//+------------------------------------------------------------------+
//| GET CURRENT POSITION TYPE                                        |
//+------------------------------------------------------------------+

ENUM_POSITION_TYPE GetCurrentPositionType()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != ActiveSymbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)MagicNumber)
         continue;

      return (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   }

   return (ENUM_POSITION_TYPE)-1;
}

//+------------------------------------------------------------------+
//| NORMALIZE LOT SIZE TO SYMBOL VOLUME RULES                        |
//+------------------------------------------------------------------+

double NormalizeLotSize()
{
   double minLot = SymbolInfoDouble(ActiveSymbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(ActiveSymbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(ActiveSymbol, SYMBOL_VOLUME_STEP);

   if(step <= 0.0 || minLot <= 0.0 || maxLot < minLot)
      return 0.0;

   double lots = MathMax(minLot, MathMin(maxLot, LotSize));
   lots = MathFloor(lots / step + 0.00000001) * step;

   int digits = 0;
   double temp = step;
   while(temp < 1.0 && digits < 8)
   {
      temp *= 10.0;
      digits++;
   }

   return NormalizeDouble(lots, digits);
}

//+------------------------------------------------------------------+
//| OPEN TRADE - EXPLICITLY NO SL OR TP                              |
//+------------------------------------------------------------------+

bool OpenTrade(ENUM_ORDER_TYPE orderType)
{
   if(TradingHalted || CountPositions() > 0)
      return false;

   double lots = NormalizeLotSize();

   if(lots <= 0.0)
   {
      Print("V75 FlipBot: Invalid symbol lot settings or requested lot size.");
      return false;
   }

   bool result = false;

   if(orderType == ORDER_TYPE_BUY)
   {
      PrintFormat("V75 FlipBot: Opening BUY | Lots: %.8f | NO SL | NO TP", lots);
      result = trade.Buy(lots, ActiveSymbol, 0.0, 0.0, 0.0, "V75 FlipBot BUY");
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      PrintFormat("V75 FlipBot: Opening SELL | Lots: %.8f | NO SL | NO TP", lots);
      result = trade.Sell(lots, ActiveSymbol, 0.0, 0.0, 0.0, "V75 FlipBot SELL");
   }

   uint retcode = trade.ResultRetcode();

   if(result &&
      (retcode == TRADE_RETCODE_DONE ||
       retcode == TRADE_RETCODE_PLACED ||
       retcode == TRADE_RETCODE_DONE_PARTIAL))
   {
      Print("V75 FlipBot: Trade request accepted. Retcode: ", retcode);
      return true;
   }

   Print("V75 FlipBot: Trade failed | ", trade.ResultRetcodeDescription());
   return false;
}

//+------------------------------------------------------------------+
//| CLOSE ALL POSITIONS BELONGING TO THIS EA                         |
//+------------------------------------------------------------------+

bool ClosePositions()
{
   bool allClosed = true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != ActiveSymbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)MagicNumber)
         continue;

      if(!trade.PositionClose(ticket))
      {
         Print("V75 FlipBot: Close failed | ", trade.ResultRetcodeDescription());
         allClosed = false;
         continue;
      }

      uint retcode = trade.ResultRetcode();

      if(retcode != TRADE_RETCODE_DONE &&
         retcode != TRADE_RETCODE_DONE_PARTIAL)
      {
         Print("V75 FlipBot: Close not confirmed | ", trade.ResultRetcodeDescription());
         allClosed = false;
      }
      else
      {
         Print("V75 FlipBot: Close request completed for ticket ", ticket);
      }
   }

   return allClosed && CountPositions() == 0;
}

//+------------------------------------------------------------------+
//| MAXIMUM FLOATING-LOSS PROTECTION                                 |
//+------------------------------------------------------------------+

void CheckMaximumLoss()
{
   if(!EnableMaxLossProtection || TradingHalted)
      return;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return;

   double maxLoss = balance * (MaxFloatingLossPercent / 100.0);
   double floatingLoss = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != ActiveSymbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)MagicNumber)
         continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit < 0.0)
         floatingLoss += MathAbs(profit);
   }

   if(floatingLoss >= maxLoss && CountPositions() > 0)
   {
      Print("V75 FlipBot: Maximum floating loss reached. Loss: ",
            floatingLoss, " | Threshold: ", maxLoss);

      if(ClosePositions())
      {
         TradingHalted = true;
         Print("V75 FlipBot: Trading halted by loss protection.");
      }
      else
      {
         Print("V75 FlipBot: Could not confirm all closes. Retrying on next tick.");
      }
   }
}

//+------------------------------------------------------------------+
//| MAIN TICK                                                        |
//+------------------------------------------------------------------+

void OnTick()
{
   // Emergency check runs on every tick, not just new M15 bars.
   CheckMaximumLoss();

   if(TradingHalted)
      return;

   datetime currentBar = (datetime)SeriesInfoInteger(
      ActiveSymbol, EntryTF, SERIES_LASTBAR_DATE
   );

   if(currentBar == 0 || currentBar == lastEntryBar)
      return;

   // H4 trend values
   double h4Fast, h4FastPrev;
   double h4Slow, h4SlowPrev;

   if(!GetIndicatorValues(h4FastHandle, 0, h4Fast, h4FastPrev))
      return;

   if(!GetIndicatorValues(h4SlowHandle, 0, h4Slow, h4SlowPrev))
      return;

   // H1 confirmation values
   double h1Fast, h1FastPrev;
   double h1Slow, h1SlowPrev;

   if(!GetIndicatorValues(h1FastHandle, 0, h1Fast, h1FastPrev))
      return;

   if(!GetIndicatorValues(h1SlowHandle, 0, h1Slow, h1SlowPrev))
      return;

   // M15 stochastic values
   double kCurrent, kPrevious;
   double dCurrent, dPrevious;

   if(!GetIndicatorValues(stochHandle, 0, kCurrent, kPrevious))
      return;

   if(!GetIndicatorValues(stochHandle, 1, dCurrent, dPrevious))
      return;

   // Last completed M15 candle
   double candleOpen = iOpen(ActiveSymbol, EntryTF, 1);
   double candleClose = iClose(ActiveSymbol, EntryTF, 1);

   if(candleOpen == 0.0 || candleClose == 0.0)
      return;

   // All required data is available; mark this bar as processed.
   lastEntryBar = currentBar;

   // Higher-timeframe direction
   bool h4Bullish = h4Fast > h4Slow;
   bool h4Bearish = h4Fast < h4Slow;

   bool h1Bullish = h1Fast > h1Slow;
   bool h1Bearish = h1Fast < h1Slow;

   // Stochastic crossover on closed bars
   bool bullishCross =
      kCurrent > dCurrent &&
      kPrevious <= dPrevious;

   bool bearishCross =
      kCurrent < dCurrent &&
      kPrevious >= dPrevious;

   // Require the previous K reading to have been in the extreme zone.
   bool bullishRecovery =
      bullishCross &&
      kPrevious <= Stoch_Oversold;

   bool bearishReversal =
      bearishCross &&
      kPrevious >= Stoch_Overbought;

   // Candle direction confirmation
   bool bullishCandle = candleClose > candleOpen;
   bool bearishCandle = candleClose < candleOpen;

   // Complete signals
   bool buySignal =
      h4Bullish &&
      h1Bullish &&
      bullishRecovery &&
      bullishCandle;

   bool sellSignal =
      h4Bearish &&
      h1Bearish &&
      bearishReversal &&
      bearishCandle;

   ENUM_POSITION_TYPE currentDir = GetCurrentPositionType();

   bool inBuy = currentDir == POSITION_TYPE_BUY;
   bool inSell = currentDir == POSITION_TYPE_SELL;
   bool noTrade = CountPositions() == 0;

   string trend =
      (h4Bullish && h1Bullish) ? "BULLISH" :
      (h4Bearish && h1Bearish) ? "BEARISH" :
      "MIXED";

   string signal =
      buySignal ? "BUY" :
      sellSignal ? "SELL" :
      "WAIT";

   string position =
      inBuy ? "BUY" :
      inSell ? "SELL" :
      "NONE";

   PrintFormat(
      "V75 | H4 Fast: %.2f Slow: %.2f | H1 Fast: %.2f Slow: %.2f | "
      "M15 K: %.2f D: %.2f | Trend: %s | Signal: %s | Position: %s",
      h4Fast, h4Slow, h1Fast, h1Slow,
      kCurrent, dCurrent, trend, signal, position
   );

   // SELL -> BUY
   if(inSell && buySignal)
   {
      Print("V75 FlipBot: BUY signal detected. Closing SELL first.");

      if(ClosePositions())
         OpenTrade(ORDER_TYPE_BUY);

      return;
   }

   // BUY -> SELL
   if(inBuy && sellSignal)
   {
      Print("V75 FlipBot: SELL signal detected. Closing BUY first.");

      if(ClosePositions())
         OpenTrade(ORDER_TYPE_SELL);

      return;
   }

   // Flat: wait for a complete signal; no forced startup direction.
   if(noTrade)
   {
      if(buySignal)
      {
         Print("V75 FlipBot: Confirmed BUY entry.");
         OpenTrade(ORDER_TYPE_BUY);
      }
      else if(sellSignal)
      {
         Print("V75 FlipBot: Confirmed SELL entry.");
         OpenTrade(ORDER_TYPE_SELL);
      }
   }
}

//+------------------------------------------------------------------+
