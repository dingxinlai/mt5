//+------------------------------------------------------------------+
//|                                                        Trend.mqh |
//|                                                       Dylan Ding |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"
#include <Morphology\TrendState.mqh>


struct Trend {
private:
   TrendState              trendState;
   double                  trendPower;

}