//+------------------------------------------------------------------+
//| ELITE_Adaptive_Bot.mq5                                           |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;
input ENUM_TIMEFRAMES TF=PERIOD_M1;
input double LotSize=1.0;
input ulong MagicNumber=150001;
input int FastEMA=10,SlowEMA=50,KPeriod=5,DPeriod=3,Slowing=3,ATRPeriod=14;
input double Overbought=80,Oversold=20,BaseSpike=0.5,MaxSpreadPercent=0.05;
input int CooldownSeconds=30,TrailingStart=500,TrailingDistance=300,TrailingStep=50,Deviation=20;
int hFast,hSlow,hStoch,hATR;datetime lastBar=0,lastEntry=0;
double NormalizeLots(double requested){double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);if(st<=0)st=mn;double v=MathMax(mn,MathMin(mx,MathRound(requested/st)*st));return NormalizeDouble(v,3);}
bool NewBar(){datetime t=iTime(_Symbol,TF,1);if(t==0||t==lastBar)return false;lastBar=t;return true;}
bool SpreadOK(){double a=SymbolInfoDouble(_Symbol,SYMBOL_ASK),b=SymbolInfoDouble(_Symbol,SYMBOL_BID);if(a<=0||b<=0)return false;return ((a-b)/((a+b)/2.0))*100.0<=MaxSpreadPercent;}
void ManageTrailing()
{
 double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);int stop=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);double dist=MathMax(TrailingDistance,stop+1)*point;
 double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
 for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t==0||PositionGetString(POSITION_SYMBOL)!=_Symbol||(ulong)PositionGetInteger(POSITION_MAGIC)!=MagicNumber)continue;long type=PositionGetInteger(POSITION_TYPE);double op=PositionGetDouble(POSITION_PRICE_OPEN),old=PositionGetDouble(POSITION_SL);
 if(type==POSITION_TYPE_BUY&&(bid-op)/point>=TrailingStart){double sl=NormalizeDouble(bid-dist,_Digits);if(old==0||sl-old>=TrailingStep*point)trade.PositionModify(t,sl,0);}
 if(type==POSITION_TYPE_SELL&&(op-ask)/point>=TrailingStart){double sl=NormalizeDouble(ask+dist,_Digits);if(old==0||old-sl>=TrailingStep*point)trade.PositionModify(t,sl,0);}}
}
bool HasOurPosition(){for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t>0&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==MagicNumber)return true;}return false;}
int OnInit(){trade.SetExpertMagicNumber(MagicNumber);trade.SetDeviationInPoints(Deviation);hFast=iMA(_Symbol,TF,FastEMA,0,MODE_EMA,PRICE_CLOSE);hSlow=iMA(_Symbol,TF,SlowEMA,0,MODE_EMA,PRICE_CLOSE);hStoch=iStochastic(_Symbol,TF,KPeriod,DPeriod,Slowing,MODE_SMA,STO_LOWHIGH);hATR=iATR(_Symbol,TF,ATRPeriod);if(hFast==INVALID_HANDLE||hSlow==INVALID_HANDLE||hStoch==INVALID_HANDLE||hATR==INVALID_HANDLE)return INIT_FAILED;return INIT_SUCCEEDED;}
void OnDeinit(const int r){IndicatorRelease(hFast);IndicatorRelease(hSlow);IndicatorRelease(hStoch);IndicatorRelease(hATR);}
void OnTick()
{
 ManageTrailing();if(!NewBar()||!SpreadOK()||HasOurPosition()||TimeCurrent()-lastEntry<CooldownSeconds)return;
 double f[],s[],k[],d[],atr[];ArraySetAsSeries(f,true);ArraySetAsSeries(s,true);ArraySetAsSeries(k,true);ArraySetAsSeries(d,true);ArraySetAsSeries(atr,true);
 if(CopyBuffer(hFast,0,1,1,f)<1||CopyBuffer(hSlow,0,1,1,s)<1||CopyBuffer(hStoch,0,1,2,k)<2||CopyBuffer(hStoch,1,1,2,d)<2||CopyBuffer(hATR,0,1,1,atr)<1)return;
 double range=iHigh(_Symbol,TF,1)-iLow(_Symbol,TF,1);if(atr[0]>0&&range>atr[0]*(1.0+BaseSpike))return;
 bool buy=f[0]>s[0]&&k[1]<=d[1]&&k[0]>d[0]&&k[0]<Overbought;
 bool sell=f[0]<s[0]&&k[1]>=d[1]&&k[0]<d[0]&&k[0]>Oversold;double lots=NormalizeLots(LotSize);
 if(buy&&trade.Buy(lots,_Symbol,0,0,0,"ELITE adaptive buy"))lastEntry=TimeCurrent();
 else if(sell&&trade.Sell(lots,_Symbol,0,0,0,"ELITE adaptive sell"))lastEntry=TimeCurrent();
}
// Trailing stop only; no fixed TP/SL.
