//+------------------------------------------------------------------+
//|                                             TrendCalculation.mqh |
//|                                                       Dylan Ding |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"

#include <Morphology/TrendState.mqh>

class TrendCalculation {
   private:
   public:
                                TrendCalculation() {}
                               ~TrendCalculation() {}
   TrendType                    execute(ENUM_TIMEFRAMES tframes, MqlRates &rates[]);
   
};

