//+------------------------------------------------------------------+
//|                                          IntelligentTrading2.mq5 |
//|                                                       Dylan Ding |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"

#include <Fateking\Runner.mqh>

datetime epoch = 0;

Runner runner;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
   if (IsNewKLine()) {
      runner.Run();
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNewKLine() {
   datetime tm = iTime(Symbol(), 0, 0);
   MqlDateTime stm;
   TimeToStruct(tm, stm);
   int hour = stm.hour;
   if (hour >= 22 || hour <= 6) {
      bool new_k_line = tm != epoch;
      if (new_k_line) {
         epoch = tm;
      }
      return new_k_line;
   }
   return false;
}
