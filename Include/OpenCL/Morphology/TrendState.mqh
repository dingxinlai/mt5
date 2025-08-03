//+------------------------------------------------------------------+
//|                                                   TrendState.mqh |
//|                                                       Dylan Ding |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"
#include <Arrays\ArrayDouble.mqh>

enum TrendType {

   TrendUnknown = 0,
   ShortTermRise = 1,
   ShortTernFall = -1,
   MediumTermRise = 2,
   MediumTermFall = -2,
   LongTermRise = 3,
   LongTermFall = -3,

};


enum TrendSubType {

   Enhancement = 1,
   Unchanged = 0,
   Attenuation = -1,

};

struct TrendState {
public:
   TrendType                            type;
   TrendSubType                         subType;



};

class TrendUtils {
public:
                     TrendUtils() {};
                    ~TrendUtils() {};
   TrendState                        GetTrendState(double &buffer[], const double factorStep);

};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
TrendState TrendUtils::GetTrendState(double &buffer[], const double factorStep) {
   TrendState ts;
   uint length = buffer.Size();
   bool up = true;
   bool down = true;
   double total = 0.0;
   CArrayDouble cad;
   for (uint i = 0; i < length - 1; i++) {
      up = up && (buffer[i] < buffer[i + 1]);
      down = down && (buffer[i] > buffer[i + 1]);
      double factor = (buffer[i] - buffer[i + 1]) / buffer[i + 1];
      cad.Add(factor);
      total += factor;
   }
   int val = (int) MathFloor(total / (length - 1) / factorStep);
   if (val >= 3) val = 3;
   if (val <= -3) val = -3;
   ts.type = (TrendType) val;
   if (ts.type != 0) {
      bool enhancement = true;
      bool attenuation = true;
      for (int i = 0; i < cad.Total() - 1; i++) {
         double factor = cad.At(i);
         if (ts.type > 0) {
            enhancement = enhancement && (cad.At(i) > cad.At(i + 1));
            attenuation = attenuation && (cad.At(i) < cad.At(i + 1));
         } else if (ts.type < 0) {
            enhancement = enhancement && (cad.At(i) < cad.At(i + 1));
            attenuation = attenuation && (cad.At(i) > cad.At(i + 1));
         }
      }
      if (enhancement) {
         ts.subType = Enhancement;
      } else if (attenuation) {
         ts.subType = Attenuation;
      } else {
         ts.subType = Unchanged;
      }
   } else {
      ts.subType = Unchanged;
   }
   return ts;
}
//+------------------------------------------------------------------+
