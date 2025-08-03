//+------------------------------------------------------------------+
//|                                                  ICollection.mqh |
//|                                                          DingXin |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "DingXin"
#property link      "https://www.mql5.com"

template<typename T>
interface ICollection
  {
//--- methods of filling data 
   bool      Add(T value);
//--- methods of access to protected data
   int       Count(void);
   bool      Contains(T item);
//--- methods of copy data from collection   
   int       CopyTo(T &dst_array[],const int dst_start=0);
//--- methods of cleaning and removing
   void      Clear(void);
   bool      Remove(T item);
  };
//+------------------------------------------------------------------+
