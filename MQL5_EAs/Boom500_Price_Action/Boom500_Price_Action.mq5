//+------------------------------------------------------------------+
//| Boom500_Price_Action.mq5                                         |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;
input double Lots=0.20;
input ulong Magic=777;
input ENUM_TIMEFRAMES TF=PERIOD_M5;
input int FastEMA=50,SlowEMA=200,MinCandleSizePoints=50,ConsolidationBars=5,TrailStopPoints=200,Deviation=20;
int hFast,hSlow;datetime lastBar=0;
bool NewBar(){datetime t=iTime(_Symbol,TF,1);if(t==0||t==lastBar)return false;lastBar=t;return true;}
bool HasPosition(){for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==Magic)return true;}return false;}
void ManageTrailing()
{
 double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);int stops=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
 double distance=MathMax(TrailStopPoints,stops+1)*point;
 for(int i=PositionsTotal()-1;i>=0;i--)
 {
  ulong t=PositionGetTicket(i);if(t==0||PositionGetString(POSITION_SYMBOL)!=_Symbol||(ulong)PositionGetInteger(POSITION_MAGIC)!=Magic)continue;
  long type=PositionGetInteger(POSITION_TYPE);double old=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
  double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
  if(type==POSITION_TYPE_BUY){double sl=NormalizeDouble(bid-distance,_Digits);if((old==0||sl>old)&&sl<bid)trade.PositionModify(t,sl,tp);}
  else{double sl=NormalizeDouble(ask+distance,_Digits);if((old==0||sl<old)&&sl>ask)trade.PositionModify(t,sl,tp);}
 }
}
int OnInit(){trade.SetExpertMagicNumber(Magic);trade.SetDeviationInPoints(Deviation);hFast=iMA(_Symbol,TF,FastEMA,0,MODE_EMA,PRICE_CLOSE);hSlow=iMA(_Symbol,TF,SlowEMA,0,MODE_EMA,PRICE_CLOSE);if(hFast==INVALID_HANDLE||hSlow==INVALID_HANDLE)return INIT_FAILED;return INIT_SUCCEEDED;}
void OnDeinit(const int r){IndicatorRelease(hFast);IndicatorRelease(hSlow);}
void OnTick()
{
 ManageTrailing();if(!NewBar()||HasPosition())return;
 double f[],s[];ArraySetAsSeries(f,true);ArraySetAsSeries(s,true);if(CopyBuffer(hFast,0,1,1,f)<1||CopyBuffer(hSlow,0,1,1,s)<1)return;
 double o=iOpen(_Symbol,TF,1),c=iClose(_Symbol,TF,1),point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
 if(MathAbs(c-o)/point<MinCandleSizePoints)return;
 double maxH=-DBL_MAX,minL=DBL_MAX;
 for(int j=2;j<2+ConsolidationBars;j++){maxH=MathMax(maxH,iHigh(_Symbol,TF,j));minL=MathMin(minL,iLow(_Symbol,TF,j));}
 if(c>o&&c>maxH&&f[0]>s[0])trade.Buy(Lots,_Symbol,0,0,0,"PA trend buy");
 if(c<o&&c<minL&&f[0]<s[0])trade.Sell(Lots,_Symbol,0,0,0,"PA trend sell");
}
