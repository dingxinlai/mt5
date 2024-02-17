//+------------------------------------------------------------------+
//|                                                         Demo.mq5 |
//|                                                       Dylan Ding |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"
#include <Fateking\Trade.mqh>
Trade tr;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
//---
   tr.buy(Symbol(), 0.1, 200, 200, "BUY", 123456);
}
//+------------------------------------------------------------------+
