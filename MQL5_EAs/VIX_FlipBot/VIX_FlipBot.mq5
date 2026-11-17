//+------------------------------------------------------------------+
//| VIX_FlipBot.mq5                                                  |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;
input double RequestedLots=1.0;
input ulong Magic=750050;
input ENUM_TIMEFRAMES TF=PERIOD_M1;
input int FastEMA=10,SlowEMA=50,KPeriod=5,DPeriod=3,Slowing=3;
input double Overbought=65,Oversold=35,MaxSpreadPercent=0.05;
input int Deviation=20;
input bool StartWithSell=false;
int hFast,hSlow,hStoch;datetime lastBar=0;
double ValidLots(){double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);if(st<=0)st=mn;double v=MathMax(mn,MathMin(mx,MathRound(RequestedLots/st)*st));int d=2;if(st<0.01)d=3;if(st<0.001)d=4;return NormalizeDouble(v,d);}
bool NewBar(){datetime t=iTime(_Symbol,TF,1);if(t==0||t==lastBar)return false;lastBar=t;return true;}
bool SpreadOK(){double a=SymbolInfoDouble(_Symbol,SYMBOL_ASK),b=SymbolInfoDouble(_Symbol,SYMBOL_BID);if(a<=0||b<=0)return false;return ((a-b)/((a+b)/2.0))*100.0<=MaxSpreadPercent;}
bool OurPosition(ENUM_POSITION_TYPE &type){for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==Magic){type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);return true;}}return false;}
void CloseOur(){for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==Magic)trade.PositionClose(t);}}
void Open(ENUM_ORDER_TYPE type){double v=ValidLots();if(type==ORDER_TYPE_BUY)trade.Buy(v,_Symbol,0,0,0,"VIX flip buy");else trade.Sell(v,_Symbol,0,0,0,"VIX flip sell");}
int OnInit(){trade.SetExpertMagicNumber(Magic);trade.SetDeviationInPoints(Deviation);hFast=iMA(_Symbol,TF,FastEMA,0,MODE_EMA,PRICE_CLOSE);hSlow=iMA(_Symbol,TF,SlowEMA,0,MODE_EMA,PRICE_CLOSE);hStoch=iStochastic(_Symbol,TF,KPeriod,DPeriod,Slowing,MODE_SMA,STO_LOWHIGH);if(hFast==INVALID_HANDLE||hSlow==INVALID_HANDLE||hStoch==INVALID_HANDLE)return INIT_FAILED;return INIT_SUCCEEDED;}
void OnDeinit(const int r){IndicatorRelease(hFast);IndicatorRelease(hSlow);IndicatorRelease(hStoch);}
void OnTick()
{
 if(!NewBar()||!SpreadOK())return;
 double f[],s[],k[],d[];ArraySetAsSeries(f,true);ArraySetAsSeries(s,true);ArraySetAsSeries(k,true);ArraySetAsSeries(d,true);
 if(CopyBuffer(hFast,0,1,1,f)<1||CopyBuffer(hSlow,0,1,1,s)<1||CopyBuffer(hStoch,0,1,2,k)<2||CopyBuffer(hStoch,1,1,2,d)<2)return;
 bool buy=f[0]>s[0]&&k[1]<=d[1]&&k[0]>d[0]&&k[0]<Overbought;
 bool sell=f[0]<s[0]&&k[1]>=d[1]&&k[0]<d[0]&&k[0]>Oversold;
 ENUM_POSITION_TYPE current;bool has=OurPosition(current);
 if(!has){if(StartWithSell)Open(ORDER_TYPE_SELL);return;}
 if(current==POSITION_TYPE_BUY&&sell){CloseOur();Open(ORDER_TYPE_SELL);}
 else if(current==POSITION_TYPE_SELL&&buy){CloseOur();Open(ORDER_TYPE_BUY);}
}
// No fixed SL/TP; intended for controlled testing only.
