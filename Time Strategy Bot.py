//+------------------------------------------------------------------+
//| Boom 500 Timed Sell Bot                                          |
//| Opens SELL → holds → closes → waits → repeats                    |
//+------------------------------------------------------------------+
#property strict

input string TradeSymbol = "Boom 500 Index";
input double DesiredLot = 9.99;
input int HoldSeconds = 90;
input int WaitSeconds = 240;
input int MagicNumber = 123456;

datetime lastTradeTime = 0;
bool tradeOpen = false;
ulong ticket = 0;

//+------------------------------------------------------------------+
//| Get valid lot size based on broker rules                         |
//+------------------------------------------------------------------+
double GetValidLot()
{
   double minLot = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_STEP);

   double lot = DesiredLot;

   if(lot > maxLot)
      lot = maxLot;

   if(lot < minLot)
      lot = minLot;

   lot = MathFloor(lot / step) * step;

   Print("Using lot size: ", lot);
   return lot;
}

//+------------------------------------------------------------------+
//| Open Sell Trade                                                  |
//+------------------------------------------------------------------+
bool OpenSell()
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);

   double lot = GetValidLot();
   double price = SymbolInfoDouble(TradeSymbol, SYMBOL_BID);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = TradeSymbol;
   request.volume = lot;
   request.type = ORDER_TYPE_SELL;
   request.price = price;
   request.deviation = 20;
   request.magic = MagicNumber;
   request.comment = "Boom Timed Sell";
   request.type_filling = ORDER_FILLING_FOK;
   request.type_time = ORDER_TIME_GTC;

   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
      return false;
   }

   if(result.retcode == TRADE_RETCODE_DONE)
   {
      ticket = result.order;
      lastTradeTime = TimeCurrent();
      tradeOpen = true;
      Print("SELL opened successfully");
      return true;
   }

   Print("Trade failed retcode: ", result.retcode);
   return false;
}

//+------------------------------------------------------------------+
//| Close Trade                                                      |
//+------------------------------------------------------------------+
void CloseTrade()
{
   if(!PositionSelect(TradeSymbol))
   {
      Print("No position found to close.");
      tradeOpen = false;
      return;
   }

   double volume = PositionGetDouble(POSITION_VOLUME);
   ulong positionTicket = PositionGetInteger(POSITION_TICKET);

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = TradeSymbol;
   request.volume = volume;
   request.type = ORDER_TYPE_BUY;
   request.position = positionTicket;
   request.price = SymbolInfoDouble(TradeSymbol, SYMBOL_ASK);
   request.deviation = 20;
   request.magic = MagicNumber;
   request.comment = "Close Timed Sell";
   request.type_filling = ORDER_FILLING_FOK;
   request.type_time = ORDER_TIME_GTC;

   if(!OrderSend(request, result))
   {
      Print("Close failed: ", GetLastError());
      return;
   }

   if(result.retcode == TRADE_RETCODE_DONE)
   {
      Print("Trade closed successfully");
      tradeOpen = false;
      lastTradeTime = TimeCurrent();
   }
   else
      Print("Close retcode: ", result.retcode);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  MqlTick tick;
if(!SymbolInfoTick(TradeSymbol, tick))
   return;


   datetime now = TimeCurrent();

   // If no trade open → wait period passed → open trade
   if(!tradeOpen)
   {
      if(now - lastTradeTime >= WaitSeconds)
         OpenSell();
   }
   else
   {
      // If trade open → hold time passed → close trade
      if(now - lastTradeTime >= HoldSeconds)
         CloseTrade();
   }
}
