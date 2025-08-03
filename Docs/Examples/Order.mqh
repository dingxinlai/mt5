//+------------------------------------------------------------------+
//|                                                        Order.mqh |
//|                                                          dingxin |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "dingxin"
#property link      "https://www.fateking.com"
#property version   "1.00"

class Order {
   public:
      ulong                            order;
      string                           symbol;
      double                           volume;
      double                           price;
      double                           sl;
      double                           tp;
      double                           deviation;
      ENUM_ORDER_TYPE                  type;
      ENUM_TRADE_REQUEST_ACTIONS       action;
      string                           comment;
      int                              magic;
};
//+------------------------------------------------------------------+
