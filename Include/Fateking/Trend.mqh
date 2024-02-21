//+------------------------------------------------------------------+
//|                                                        Trend.mqh |
//|                                                       Dylan Ding |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"

enum Trend {
   
   TrendUnknown = 0,
   ShortTermRise = 1,
   ShortTernFall = -1,
   MediumTermRise = 2,
   MediumTermFall = -2,
   LongTermRise = 3,
   LongTermFall = -3,

};