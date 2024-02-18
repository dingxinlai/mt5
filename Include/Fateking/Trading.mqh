//+------------------------------------------------------------------+
//|                                                      Trading.mqh |
//|                                                       Dylan Ding |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"

class Trading {
private:
public:
                     Trading();
                    ~Trading();
   ulong             Buy(string symbol, double lots, int slpoint, int tppoint, string comment, int magic);
   ulong             BuyPending(string symbol, double lots, double pendingPrice, int slpoint, int tppoint, string comment, int magic);
   ulong             BuyStopLimit(string symbol, double lots, double stopPrice, double limitPrice, int slpoint, int tppoint, string comment, int magic);
   ulong             Sell(string symbol, double lots, int slpoint, int tppoint, string comment, int magic);
   void              CloseAllBuy(string symbol, int magic);
   void              CloseAllSell(string symbol, int magic);
   void              CloseAll(string symbol, int magic);
   void              Modifysltp(string symbol, ENUM_POSITION_TYPE type, double sl, double tp, int magic);
   void              DelOrders(string symbol, int magic);
   void              ModifyPending(string symbo, ENUM_ORDER_TYPE type, double pendingPrice, double limitPrice, double sl, double tp, int magic);
   int               OrderCount(string symbol, ENUM_POSITION_TYPE type, int magic);
   int               OrderCount(string symbol, int magic);
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Trading::Trading() {
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Trading::~Trading() {
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong Trading::Buy(string symbol, double lots, int slpoint, int tppoint, string comment, int magic) {
   ulong order = 0;
   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--) {
      if (PositionGetTicket(i) > 0) {
         if (PositionGetString(POSITION_SYMBOL) == symbol
               && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY
               && PositionGetInteger(POSITION_MAGIC) == magic) {
            return (0);
         }
      }
   }
   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   req.action = TRADE_ACTION_DEAL;
   req.symbol = symbol;
   req.type = ORDER_TYPE_BUY;
   req.volume = lots;
   req.deviation = 100;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   req.price = ask;
   req.sl = ask - slpoint * Point();
   req.tp = ask + tppoint * Point();
   req.comment = comment;
   req.magic = magic;

   if (!OrderSend(req, res)) {
      PrintFormat("TradeBuy encountered error %d", GetLastError());
      return (0);
   }
   PrintFormat("TradeBuy return code: %u, deal: %I64u, order=%I64u", res.retcode, res.deal, res.order);
   order = res.order;
   return (order);
}
//+------------------------------------------------------------------+
ulong Trading::BuyPending(string symbol, double lots, double pendingPrice, int slpoint, int tppoint, string comment, int magic) {
   ulong order = 0;
   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--) {
      if(OrderGetTicket(i)>0) {
         if(OrderGetString(ORDER_SYMBOL) == symbol
               && (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
               && OrderGetInteger(ORDER_MAGIC) == magic) {
            return(0);
         }
      }
   }

   pendingPrice = NormalizeDouble(pendingPrice, Digits());
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action=TRADE_ACTION_PENDING;
   req.symbol=symbol;
   double askp =SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(pendingPrice > askp) {
      req.type = ORDER_TYPE_BUY_STOP;
   }
   if(pendingPrice < askp) {
      req.type = ORDER_TYPE_BUY_LIMIT;
   }
   req.volume = lots;
   req.deviation = 100;
   req.price = pendingPrice;
   req.sl = pendingPrice-slpoint*Point();
   req.tp = pendingPrice+tppoint*Point();
   req.comment = comment;
   req.magic = magic;
//--- 发送请求
   if(!OrderSend(req, res)) {
      PrintFormat("OrderSend error %d",GetLastError());     // 如果不能发送请求，输出错误代码
      return (0);
   }
   order = res.order;
   return (order);
}
//+------------------------------------------------------------------+
ulong Trading::BuyStopLimit(string symbol, double lots, double stopPrice, double limitPrice, int slpoint, int tppoint, string comment, int magic) {
   ulong order = 0;
   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--) {
      if(OrderGetTicket(i)>0) {
         if(OrderGetString(ORDER_SYMBOL) == symbol
               && (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP_LIMIT)
               && OrderGetInteger(ORDER_MAGIC) == magic) {
            return(0);
         }
      }
   }

   stopPrice = NormalizeDouble(stopPrice, Digits());
   limitPrice = NormalizeDouble(limitPrice, Digits());
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_PENDING;
   req.type = ORDER_TYPE_BUY_STOP_LIMIT;
   req.symbol = symbol;
   double askp = SymbolInfoDouble(symbol,SYMBOL_ASK);
   if(stopPrice <= askp) {
      Alert("stop  price必须大于市价");
      return(0);
   }
   if(limitPrice >= stopPrice) {
      Alert("limit price必须大于stop price");
      return(0);
   }
   req.volume = lots;
   req.deviation = 100;
   req.price = stopPrice;
   req.stoplimit = limitPrice;
   req.sl = limitPrice-slpoint*Point();
   req.tp = limitPrice+tppoint*Point();
   req.comment = comment;
   req.magic = magic;
//--- 发送请求
   if(!OrderSend(req, res)) {
      PrintFormat("OrderSend error %d",GetLastError());     // 如果不能发送请求，输出错误代码
      return (0);
   }
   order = res.order;
   return(order);
}
//+------------------------------------------------------------------+
ulong Trading::Sell(string symbol, double lots, int slpoint, int tppoint, string comment, int magic) {
   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   req.action = TRADE_ACTION_DEAL;
   req.symbol = symbol;
   req.type = ORDER_TYPE_SELL;
   req.volume = lots;
   req.deviation = 100;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   req.price = bid;
   req.sl = bid + slpoint * Point();
   req.tp = bid - tppoint * Point();
   req.comment = comment;
   req.magic = magic;

   if (!OrderSend(req, res)) {
      PrintFormat("TradeSell encountered error %d", GetLastError());
      return (0);
   }
   PrintFormat("TradeSell return code: %u, deal: %I64u, order=%I64u", res.retcode, res.deal, res.order);
   return (res.order);
}
//+------------------------------------------------------------------+
void Trading::CloseAllBuy(string symbol, int magic) {
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--) {
      if(PositionGetTicket(i) > 0) {                                     //选中订单
         if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            if(magic == 0) {
               MqlTradeRequest req= {};
               MqlTradeResult  res= {};
               req.action   = TRADE_ACTION_DEAL;                     // 交易操作类型
               req.symbol   = symbol;                                // 交易品种
               req.volume   = PositionGetDouble(POSITION_VOLUME);    // 0.1手交易量
               req.type     = ORDER_TYPE_SELL;                       // 订单类型
               req.price    = SymbolInfoDouble(symbol,SYMBOL_BID);   // 持仓价格
               req.deviation= 100; // 允许价格偏差
               req.position = PositionGetTicket(i);
               if(!OrderSend(req, res))
                  PrintFormat("OrderSend error %d",GetLastError());      // 如果不能发送请求，输出错误
            } else {
               if(PositionGetInteger(POSITION_MAGIC) == magic) {
                  MqlTradeRequest req= {};
                  MqlTradeResult  res= {};
                  req.action   = TRADE_ACTION_DEAL;                   // 交易操作类型
                  req.symbol   = symbol;                              // 交易品种
                  req.volume   = PositionGetDouble(POSITION_VOLUME);  // 0.1手交易量
                  req.type     = ORDER_TYPE_SELL;                     // 订单类型
                  req.price    = SymbolInfoDouble(symbol,SYMBOL_BID); // 持仓价格
                  req.deviation= 100;                                 // 允许价格偏差
                  req.position = PositionGetTicket(i);
                  if(!OrderSend(req, res))
                     PrintFormat("OrderSend error %d",GetLastError());    // 如果不能发送请求，输出错误
               }
            }

         }
      }
   }
}
//+------------------------------------------------------------------+
int Trading::OrderCount(string symbol, ENUM_POSITION_TYPE type, int magic = 0) {
   int count = 0;
   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--) {
      if (PositionGetTicket(i) > 0) {
         if (PositionGetString(POSITION_SYMBOL) == symbol
               && PositionGetInteger(POSITION_TYPE) == type) {
            if (magic == 0) {
               count++;
            } else {
               if (PositionGetInteger(POSITION_MAGIC) == magic) {
                  count++;
               }
            }
         }
      }
   }
   return (count);
}
//+------------------------------------------------------------------+
int Trading::OrderCount(string symbol, int magic = 0) {
   int count = 0;
   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--) {
      if (PositionGetTicket(i) > 0) {
         if (PositionGetString(POSITION_SYMBOL) == symbol) {
            if (magic == 0) {
               count++;
            } else {
               if (PositionGetInteger(POSITION_MAGIC) == magic) {
                  count++;
               }
            }
         }
      }
   }
   return (count);
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
