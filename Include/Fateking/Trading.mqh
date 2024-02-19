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
   ulong             deviation;
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
   double            FloorLots(string symbol, double lots);
   long              LatestOrder(string symbol, ENUM_POSITION_TYPE type, double &openprice, datetime &opentime, double &openlots, double &opensl, double &opentp, int magic);
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Trading::Trading() {
   deviation = 2;
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
   req.deviation = deviation;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   req.price = ask;
   if (slpoint != 0) {
      req.sl = ask - ((double) slpoint) / 100 * Point();
   }
   if (tppoint != 0) {
      req.tp = ask + ((double) tppoint) / 100 * Point();
   }
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
   req.deviation = deviation;
   req.price = pendingPrice;
   if (slpoint != 0) {
      req.sl = pendingPrice - ((double) slpoint) / 100 * Point();
   }
   if (tppoint != 0) {
      req.tp = pendingPrice + ((double) tppoint) / 100 * Point();
   }
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
      if(OrderGetTicket(i) > 0) {
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
   double askp = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(stopPrice <= askp) {
      printf("stop  price必须大于市价");
      return(0);
   }
   if(limitPrice >= stopPrice) {
      printf("limit price必须大于stop price");
      return(0);
   }
   req.volume = lots;
   req.deviation = deviation;
   req.price = stopPrice;
   req.stoplimit = limitPrice;
   if (slpoint != 0) {
      req.sl = limitPrice - ((double) slpoint) * Point();
   }
   if (tppoint != 0) {
      req.tp = limitPrice + ((double) tppoint) * Point();
   }
   req.comment = comment;
   req.magic = magic;
//--- 发送请求
   if(!OrderSend(req, res)) {
      PrintFormat("OrderSend error %d", GetLastError());     // 如果不能发送请求，输出错误代码
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
   req.deviation = deviation;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   req.price = bid;
   if (slpoint != 0) {
      req.sl = bid + ((double) slpoint) * Point();
   }
   if (tppoint != 0) {
      req.tp = bid - ((double) tppoint) * Point();
   }
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
      if(PositionGetTicket(i) > 0) {                                 //选中订单
         if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            if(magic == 0) {
               MqlTradeRequest req= {};
               MqlTradeResult  res= {};
               req.action   = TRADE_ACTION_DEAL;                     // 交易操作类型
               req.symbol   = symbol;                                // 交易品种
               req.volume   = PositionGetDouble(POSITION_VOLUME);    // 0.1手交易量
               req.type     = ORDER_TYPE_SELL;                       // 订单类型
               req.price    = SymbolInfoDouble(symbol,SYMBOL_BID);   // 持仓价格
               req.deviation= deviation;                             // 允许价格偏差
               req.position = PositionGetTicket(i);
               if(!OrderSend(req, res))
                  PrintFormat("OrderSend error %d",GetLastError());  // 如果不能发送请求，输出错误
            } else {
               if(PositionGetInteger(POSITION_MAGIC) == magic) {
                  MqlTradeRequest req= {};
                  MqlTradeResult  res= {};
                  req.action   = TRADE_ACTION_DEAL;                   // 交易操作类型
                  req.symbol   = symbol;                              // 交易品种
                  req.volume   = PositionGetDouble(POSITION_VOLUME);  // 0.1手交易量
                  req.type     = ORDER_TYPE_SELL;                     // 订单类型
                  req.price    = SymbolInfoDouble(symbol,SYMBOL_BID); // 持仓价格
                  req.deviation= deviation;                           // 允许价格偏差
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
void Trading::Modifysltp(string symbol, ENUM_POSITION_TYPE type, double sl, double tp, int magic = 0) {
   int t = PositionsTotal();
   for(int i = t-1; i >= 0; i--) {
      if(PositionGetTicket(i) > 0) {
         if(PositionGetString(POSITION_SYMBOL) == symbol) {
            if(type == POSITION_TYPE_BUY) {
               if(magic == 0) {
                  MqlTradeRequest request = {};
                  MqlTradeResult  result = {};
                  request.action=TRADE_ACTION_SLTP;
                  request.position=PositionGetTicket(i);
                  request.symbol=symbol;
                  if(sl != 0) {
                     request.sl=NormalizeDouble(sl,Digits());
                  }
                  if(tp != 0) {
                     request.tp=NormalizeDouble(tp,Digits());
                  }
                  if(!OrderSend(request,result))
                     PrintFormat("OrderSend error %d",GetLastError());
               } else {
                  if(PositionGetInteger(POSITION_MAGIC)==magic) {
                     MqlTradeRequest request= {};
                     MqlTradeResult  result= {};
                     request.action=TRADE_ACTION_SLTP;
                     request.position=PositionGetTicket(i);
                     request.symbol=symbol;
                     if(sl != 0) {
                        request.sl=NormalizeDouble(sl,Digits());
                     }
                     if(tp != 0) {
                        request.tp=NormalizeDouble(tp,Digits());
                     }
                     if(!OrderSend(request,result))
                        PrintFormat("OrderSend error %d",GetLastError());
                  }
               }
            }
            if(type == POSITION_TYPE_SELL) {
               if(magic == 0) {
                  MqlTradeRequest request= {};
                  MqlTradeResult  result= {};
                  request.action=TRADE_ACTION_SLTP;
                  request.position=PositionGetTicket(i);
                  request.symbol=symbol;
                  if(sl != 0) {
                     request.sl = NormalizeDouble(sl,Digits());
                  }
                  if(tp != 0) {
                     request.tp = NormalizeDouble(tp,Digits());
                  }
                  if(!OrderSend(request,result))
                     PrintFormat("OrderSend error %d",GetLastError());
               } else {
                  if(PositionGetInteger(POSITION_MAGIC) == magic) {
                     MqlTradeRequest request= {};
                     MqlTradeResult  result= {};
                     request.action=TRADE_ACTION_SLTP;
                     request.position=PositionGetTicket(i);
                     request.symbol=symbol;
                     if(sl != 0) {
                        request.sl = NormalizeDouble(sl,Digits());
                     }
                     if(tp != 0) {
                        request.tp = NormalizeDouble(tp,Digits());
                     }
                     if(!OrderSend(request,result))
                        PrintFormat("OrderSend error %d",GetLastError());
                  }
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
double Trading::FloorLots(string symbol, double lots) {
   double floorLots = 0;
   double minLots = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double stepLots = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots < minLots) return(0);
   else {
      double floorMinLots = MathFloor(lots/minLots) * minLots;
      floorLots = floorMinLots + MathFloor((lots - floorMinLots) / stepLots) * stepLots;
   }
   return(floorLots);
}
//+------------------------------------------------------------------+
long Trading::LatestOrder(string symbol, ENUM_POSITION_TYPE type, double &openprice, datetime &opentime,
                          double &openlots, double &opensl, double &opentp, int magic) {
   openprice = 0;
   opentime = 0;
   openlots = 0;
   opensl = 0;
   opentp = 0;
   long ticket = 0;
   int t = PositionsTotal();
   for(int i=t-1; i>=0; i--) {
      if(PositionGetTicket(i)>0) {
         if(PositionGetString(POSITION_SYMBOL) == symbol
               && PositionGetInteger(POSITION_TYPE) == type) {
            if(magic == 0) {
               openprice=PositionGetDouble(POSITION_PRICE_OPEN);
               opentime=PositionGetInteger(POSITION_TIME);
               openlots=PositionGetDouble(POSITION_VOLUME);
               opensl=PositionGetDouble(POSITION_SL);
               opentp=PositionGetDouble(POSITION_TP);
               ticket=PositionGetInteger(POSITION_TICKET);
               break;
            } else {
               if(PositionGetInteger(POSITION_MAGIC) == magic) {
                  openprice=PositionGetDouble(POSITION_PRICE_OPEN);
                  opentime=PositionGetInteger(POSITION_TIME);
                  openlots=PositionGetDouble(POSITION_VOLUME);
                  opensl=PositionGetDouble(POSITION_SL);
                  opentp=PositionGetDouble(POSITION_TP);
                  ticket=PositionGetInteger(POSITION_TICKET);
                  break;
               }
            }
         }
      }
   }
   return(ticket);
}
//+------------------------------------------------------------------+
