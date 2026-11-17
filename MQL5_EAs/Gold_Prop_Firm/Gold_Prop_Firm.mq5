//+------------------------------------------------------------------+
//| Gold_Prop_Firm.mq5                                               |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

input string TradeSymbol = "XAUUSD";
input ENUM_TIMEFRAMES TF = PERIOD_M15;
input double Lots = 0.01;
input ulong  Magic = 123456;
input int    FastEMA = 50, SlowEMA = 200, TrailStartPoints = 300,
             TrailDistancePoints = 200, TrailStepPoints = 50, Deviation = 20;

int hFast, hSlow;
datetime lastBar = 0;

//+------------------------------------------------------------------+
bool NewBar()
{
   datetime t = iTime(TradeSymbol, TF, 1);
   if(t == 0 || t == lastBar)
      return false;
   lastBar = t;
   return true;
}

//+------------------------------------------------------------------+
void Trail()
{
   double point = SymbolInfoDouble(TradeSymbol, SYMBOL_POINT);
   int stop = (int)SymbolInfoInteger(TradeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   double dist = MathMax(TrailDistancePoints, stop + 1) * point;
   double bid = SymbolInfoDouble(TradeSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 ||
         PositionGetString(POSITION_SYMBOL) != TradeSymbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double old  = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);

      if(type == POSITION_TYPE_BUY && (bid - open) / point >= TrailStartPoints)
      {
         double sl = NormalizeDouble(bid - dist, (int)SymbolInfoInteger(TradeSymbol, SYMBOL_DIGITS));
         if(old == 0 || sl - old >= TrailStepPoints * point)
            trade.PositionModify(t, sl, tp);
      }

      if(type == POSITION_TYPE_SELL && (open - ask) / point >= TrailStartPoints)
      {
         double sl = NormalizeDouble(ask + dist, (int)SymbolInfoInteger(TradeSymbol, SYMBOL_DIGITS));
         if(old == 0 || old - sl >= TrailStepPoints * point)
            trade.PositionModify(t, sl, tp);
      }
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(!SymbolSelect(TradeSymbol, true))
      return INIT_FAILED;

   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(Deviation);

   hFast = iMA(TradeSymbol, TF, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(TradeSymbol, TF, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE)
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int r)
{
   IndicatorRelease(hFast);
   IndicatorRelease(hSlow);
}

//+------------------------------------------------------------------+
void OnTick()
{
   Trail();
   if(!NewBar())
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t > 0 &&
         PositionGetString(POSITION_SYMBOL) == TradeSymbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == Magic)
         return;
   }

   double f[], s[];
   ArraySetAsSeries(f, true);
   ArraySetAsSeries(s, true);
   if(CopyBuffer(hFast, 0, 1, 1, f) < 1 ||
      CopyBuffer(hSlow, 0, 1, 1, s) < 1)
      return;

   double c = iClose(TradeSymbol, TF, 1);

   if(f[0] > s[0] && c > f[0])
      trade.Buy(Lots, TradeSymbol, 0, 0, 0, "Gold trend buy");
   else if(f[0] < s[0] && c < f[0])
      trade.Sell(Lots, TradeSymbol, 0, 0, 0, "Gold trend sell");
}
//+------------------------------------------------------------------+
