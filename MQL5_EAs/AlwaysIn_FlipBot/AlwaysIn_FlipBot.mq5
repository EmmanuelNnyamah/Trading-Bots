//+------------------------------------------------------------------+
//| AlwaysIn_FlipBot.mq5                                             |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;
input ENUM_TIMEFRAMES SignalTF=PERIOD_H1;
input double Lots=0.20;
input ulong Magic=600600;
input int FastEMA=10,SlowEMA=50,KPeriod=5,DPeriod=3,Slowing=3;
input double Overbought=80.0,Oversold=20.0;
input int DeviationPoints=50;
int hFast=INVALID_HANDLE,hSlow=INVALID_HANDLE,hStoch=INVALID_HANDLE;
datetime lastBar=0;
bool NewClosedBar(){datetime t=iTime(_Symbol,SignalTF,1);if(t==0||t==lastBar)return false;lastBar=t;return true;}
bool HasOurPosition(ENUM_POSITION_TYPE &type)
{
 for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==Magic){type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);return true;}}
 return false;
}
void CloseOurPositions(){for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==Magic)trade.PositionClose(t);}}
void OpenDirection(ENUM_ORDER_TYPE type){if(type==ORDER_TYPE_BUY)trade.Buy(Lots,_Symbol,0,0,0,"AlwaysIn BUY");else trade.Sell(Lots,_Symbol,0,0,0,"AlwaysIn SELL");}
int OnInit()
{
 trade.SetExpertMagicNumber(Magic);trade.SetDeviationInPoints(DeviationPoints);
 hFast=iMA(_Symbol,SignalTF,FastEMA,0,MODE_EMA,PRICE_CLOSE);hSlow=iMA(_Symbol,SignalTF,SlowEMA,0,MODE_EMA,PRICE_CLOSE);
 hStoch=iStochastic(_Symbol,SignalTF,KPeriod,DPeriod,Slowing,MODE_SMA,STO_LOWHIGH);
 if(hFast==INVALID_HANDLE||hSlow==INVALID_HANDLE||hStoch==INVALID_HANDLE)return INIT_FAILED;
 return INIT_SUCCEEDED;
}
void OnDeinit(const int r){if(hFast!=INVALID_HANDLE)IndicatorRelease(hFast);if(hSlow!=INVALID_HANDLE)IndicatorRelease(hSlow);if(hStoch!=INVALID_HANDLE)IndicatorRelease(hStoch);}
void OnTick()
{
 if(!NewClosedBar())return;
 double f[],s[],k[],d[];ArraySetAsSeries(f,true);ArraySetAsSeries(s,true);ArraySetAsSeries(k,true);ArraySetAsSeries(d,true);
 if(CopyBuffer(hFast,0,1,1,f)<1||CopyBuffer(hSlow,0,1,1,s)<1||CopyBuffer(hStoch,0,1,2,k)<2||CopyBuffer(hStoch,1,1,2,d)<2)return;
 bool buy=f[0]>s[0]&&k[1]<=d[1]&&k[0]>d[0]&&k[0]<Overbought;
 bool sell=f[0]<s[0]&&k[1]>=d[1]&&k[0]<d[0]&&k[0]>Oversold;
 ENUM_POSITION_TYPE current;bool has=HasOurPosition(current);
 if(!has){OpenDirection(ORDER_TYPE_SELL);return;}
 if(current==POSITION_TYPE_BUY&&sell){CloseOurPositions();OpenDirection(ORDER_TYPE_SELL);}
 else if(current==POSITION_TYPE_SELL&&buy){CloseOurPositions();OpenDirection(ORDER_TYPE_BUY);}
}
// No fixed SL/TP by design. Test on demo before use.
//+------------------------------------------------------------------+
