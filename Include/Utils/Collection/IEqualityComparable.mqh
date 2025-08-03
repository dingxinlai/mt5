//+------------------------------------------------------------------+
//|                                          IEqualityComparable.mqh |
//|                                                          DingXin |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "DingXin"
#property link      "https://www.mql5.com"

template<typename T>
interface IEqualityComparable
  {
//--- method for determining equality
   bool              Equals(T value);
//--- method to calculate hash code   
   int               HashCode(void);
  };
//+------------------------------------------------------------------+
