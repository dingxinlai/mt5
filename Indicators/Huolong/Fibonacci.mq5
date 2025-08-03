//+------------------------------------------------------------------+
//|                                                    Fibonacci.mq5 |
//|                                                           di.gao |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots 7
//--- plot ZigZag
#property indicator_label1 "ZigZag"
#property indicator_type1 DRAW_SECTION
#property indicator_color1 clrRed
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1
#include <Huolong\Indicators\FibonacciSignal.mqh>
//--- input parameters
input int InpDepth = 12;    // Depth
input int InpDeviation = 5; // Deviation
input int InpBackstep = 3;  // Back Step
input color InpFiboLineColor = clrYellow; // Fibonacci Line Color
//--- indicator buffers
double ZigZagBuffer[];  // main buffer
double HighMapBuffer[]; // ZigZag high extremes (peaks)
double LowMapBuffer[];  // ZigZag low extremes (bottoms)
double FiboBuffer[];  // FiboBuffer, last 8 values are zigzag direction and 7 Fibo values from 100 to 0
int FiboNumbers = 7;
string fiboNames[7] = {"Fibo1000", "Fibo786", "Fibo618", "Fibo500", "Fibo382", "Fibo236", "Fibo000"};

int ExtRecalc = 3; // number of last extremes for recalculation

string randomNumber = "_"+(string)MathRand();

enum EnSearchMode
{
   Extremum = 0, // searching for the first extremum
   Peak = 1,     // searching for the next ZigZag peak
   Bottom = -1   // searching for the next ZigZag bottom
};

struct ExtremumPoint
{
   double high;
   double low;
   datetime highDatetime;
   datetime lowDatetime;
   ZigZagDirection direction;
   double lastHigh;
   double lastLow;
   datetime lastHighDatetime;
   datetime lastLowDatetime;
};

ExtremumPoint currentExtremumPoint = {
    0.0,
    0.0,
    D'01.01.1970',
    D'01.01.1970',
    None,
    0.0,
    0.0,
    D'01.01.1970',
    D'01.01.1970'};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(FIBONACCI_BUFFER_ZIGZAG, ZigZagBuffer, INDICATOR_DATA);
   SetIndexBuffer(FIBONACCI_BUFFER_ZIGZAG_HIGH, HighMapBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(FIBONACCI_BUFFER_ZIGZAG_LOW, LowMapBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(FIBONACCI_BUFFER, FiboBuffer, INDICATOR_CALCULATIONS); 
   
   //--- set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   //--- set short name and digits
   string short_name = StringFormat("ZigZag Fibonacci(%d,%d,%d)", InpDepth, InpDeviation, InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
}
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 删除所有旧线
   for (int i = 0; i < ArraySize(fiboNames); i++)
   {
      ObjectDelete(0, fiboNames[i]+randomNumber);
      ObjectDelete(0, fiboNames[i]+randomNumber + "_label");
   }
   
   // 清空缓冲区
   ArrayInitialize(ZigZagBuffer, 0.0);
   ArrayInitialize(HighMapBuffer, 0.0);
   ArrayInitialize(LowMapBuffer, 0.0);
}
//+------------------------------------------------------------------+
//| ZigZag calculation                                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if (rates_total < 100)
      return (0);
   //---
   int i = 0;
   int start = 0, extreme_counter = 0, extreme_search = Extremum;
   int shift = 0, back = 0, last_high_pos = 0, last_low_pos = 0;
   double val = 0, res = 0;
   double curlow = 0, curhigh = 0, last_high = 0, last_low = 0;
   //--- initializing
   if (prev_calculated == 0)
   {
      ArrayInitialize(ZigZagBuffer, 0.0);
      ArrayInitialize(HighMapBuffer, 0.0);
      ArrayInitialize(LowMapBuffer, 0.0);
      start = InpDepth;
   }

   //--- ZigZag was already calculated before
   if (prev_calculated > 0)
   {
      i = rates_total - 1;
      //--- searching for the third extremum from the last uncompleted bar
      while (extreme_counter < ExtRecalc && i > rates_total - 100)
      {
         res = ZigZagBuffer[i];
         if (res != 0.0)
            extreme_counter++;
         i--;
      }
      i++;
      start = i;

      //--- what type of exremum we search for
      if (LowMapBuffer[i] != 0.0)
      {
         curlow = LowMapBuffer[i];
         extreme_search = Peak;
      }
      else
      {
         curhigh = HighMapBuffer[i];
         extreme_search = Bottom;
      }
      //--- clear indicator values
      for (i = start + 1; i < rates_total && !IsStopped(); i++)
      {
         ZigZagBuffer[i] = 0.0;
         LowMapBuffer[i] = 0.0;
         HighMapBuffer[i] = 0.0;
      }
   }

   //--- searching for high and low extremes
   for (shift = start; shift < rates_total && !IsStopped(); shift++)
   {
      //--- low
      val = low[Lowest(low, InpDepth, shift)];
      if (val == last_low)
         val = 0.0;
      else
      {
         last_low = val;
         if ((low[shift] - val) > InpDeviation * _Point)
            val = 0.0;
         else
         {
            for (back = 1; back <= InpBackstep; back++)
            {
               res = LowMapBuffer[shift - back];
               if ((res != 0) && (res > val))
                  LowMapBuffer[shift - back] = 0.0;
            }
         }
      }
      if (low[shift] == val)
         LowMapBuffer[shift] = val;
      else
         LowMapBuffer[shift] = 0.0;
      //--- high
      val = high[Highest(high, InpDepth, shift)];
      if (val == last_high)
         val = 0.0;
      else
      {
         last_high = val;
         if ((val - high[shift]) > InpDeviation * _Point)
            val = 0.0;
         else
         {
            for (back = 1; back <= InpBackstep; back++)
            {
               res = HighMapBuffer[shift - back];
               if ((res != 0) && (res < val))
                  HighMapBuffer[shift - back] = 0.0;
            }
         }
      }
      if (high[shift] == val)
         HighMapBuffer[shift] = val;
      else
         HighMapBuffer[shift] = 0.0;
   }

   //--- set last values
   if (extreme_search == 0) // undefined values
   {
      last_low = 0.0;
      last_high = 0.0;
   }
   else
   {
      last_low = curlow;
      last_high = curhigh;
   }

   //--- final selection of extreme points for ZigZag
   for (shift = start; shift < rates_total && !IsStopped(); shift++)
   {
      res = 0.0;
      switch (extreme_search)
      {
      case Extremum:
         if (last_low == 0.0 && last_high == 0.0)
         {
            if (HighMapBuffer[shift] != 0)
            {
               last_high = high[shift];
               last_high_pos = shift;
               extreme_search = Bottom;
               ZigZagBuffer[shift] = last_high;
               res = 1;
            }
            if (LowMapBuffer[shift] != 0.0)
            {
               last_low = low[shift];
               last_low_pos = shift;
               extreme_search = Peak;
               ZigZagBuffer[shift] = last_low;
               res = 1;
            }
         }
         break;
      case Peak:
         if (LowMapBuffer[shift] != 0.0 && LowMapBuffer[shift] < last_low && HighMapBuffer[shift] == 0.0)
         {
            ZigZagBuffer[last_low_pos] = 0.0;
            last_low_pos = shift;
            last_low = LowMapBuffer[shift];
            ZigZagBuffer[shift] = last_low;
            res = 1;
         }
         if (HighMapBuffer[shift] != 0.0 && LowMapBuffer[shift] == 0.0)
         {
            last_high = HighMapBuffer[shift];
            last_high_pos = shift;
            ZigZagBuffer[shift] = last_high;
            extreme_search = Bottom;
            res = 1;
         }
         break;
      case Bottom:
         if (HighMapBuffer[shift] != 0.0 && HighMapBuffer[shift] > last_high && LowMapBuffer[shift] == 0.0)
         {
            ZigZagBuffer[last_high_pos] = 0.0;
            last_high_pos = shift;
            last_high = HighMapBuffer[shift];
            ZigZagBuffer[shift] = last_high;
         }
         if (LowMapBuffer[shift] != 0.0 && HighMapBuffer[shift] == 0.0)
         {
            last_low = LowMapBuffer[shift];
            last_low_pos = shift;
            ZigZagBuffer[shift] = last_low;
            extreme_search = Peak;
         }
         break;
      default:
         return (rates_total);
      }
   }

   if (rates_total >=7) {
      // Calculate and draw Fibonacci levels
      ExtremumPoint extremumPoint = {
          0.0,
          0.0,
          D'01.01.1970',
          D'01.01.1970',
          None,
          currentExtremumPoint.high,
          currentExtremumPoint.low,
          currentExtremumPoint.highDatetime,
          currentExtremumPoint.lowDatetime};
   
      // if (time[rates_total-1] > D'2024.01.02 11:33:00'){
      //    Print("debug");
      // }
   
      // use InpBackstep to filter out not confirmed ZigZag
      for (shift = rates_total - 1; shift > 0; shift--)
      {
         if (ZigZagBuffer[shift] > _Point)
         {
            if (extremumPoint.high < _Point)
            {
               extremumPoint.high = ZigZagBuffer[shift];
               extremumPoint.highDatetime = time[shift];
            }
            else if (ZigZagBuffer[shift] > extremumPoint.high)
            {
               extremumPoint.low = extremumPoint.high;
               extremumPoint.lowDatetime = extremumPoint.highDatetime;
               extremumPoint.high = ZigZagBuffer[shift];
               extremumPoint.highDatetime = time[shift];
               break;
            }
            else
            {
               extremumPoint.low = ZigZagBuffer[shift];
               extremumPoint.lowDatetime = time[shift];
               break;
            }
         }
      }
      // Calculate direction
      if (extremumPoint.low == 0.0 || extremumPoint.high == 0.0)
      {
         extremumPoint.direction = None;
      }
      else if (extremumPoint.lowDatetime < extremumPoint.highDatetime)
      {
         extremumPoint.direction = Incremental;
      }
      else
      {
         extremumPoint.direction = Decremental;
      }
   
      if (currentExtremumPoint.direction == None ||
          (currentExtremumPoint.direction == extremumPoint.direction && (extremumPoint.high > currentExtremumPoint.high || extremumPoint.low < currentExtremumPoint.low)))
      {
         currentExtremumPoint = extremumPoint;
      }
      else if (currentExtremumPoint.direction != extremumPoint.direction &&
               ((currentExtremumPoint.direction == Incremental && extremumPoint.low < currentExtremumPoint.high * 0.2 + currentExtremumPoint.low * 0.8) || (currentExtremumPoint.direction == Decremental && extremumPoint.high > currentExtremumPoint.low * 0.2 + currentExtremumPoint.high * 0.8)))
      {
         currentExtremumPoint = extremumPoint;
      }
   
      UpdateLines(rates_total);
   }

   //--- return value of prev_calculated for next call
   return (rates_total);
}
//+------------------------------------------------------------------+
//|  Search for the index of the highest bar                         |
//+------------------------------------------------------------------+
int Highest(const double &array[], const int depth, const int start)
{
   if (start < 0)
      return (0);

   double max = array[start];
   int index = start;
   //--- start searching
   for (int i = start - 1; i > start - depth && i >= 0; i--)
   {
      if (array[i] > max)
      {
         index = i;
         max = array[i];
      }
   }
   //--- return index of the highest bar
   return (index);
}
//+------------------------------------------------------------------+
//|  Search for the index of the lowest bar                          |
//+------------------------------------------------------------------+
int Lowest(const double &array[], const int depth, const int start)
{
   if (start < 0)
      return (0);

   double min = array[start];
   int index = start;
   //--- start searching
   for (int i = start - 1; i > start - depth && i >= 0; i--)
   {
      if (array[i] < min)
      {
         index = i;
         min = array[i];
      }
   }
   //--- return index of the lowest bar
   return (index);
}
//+------------------------------------------------------------------+

void UpdateLines(const int rates_total)
{
   if (currentExtremumPoint.direction == None)
   {
      return;
   }

   if (currentExtremumPoint.high == currentExtremumPoint.lastHigh && currentExtremumPoint.low == currentExtremumPoint.lastLow && currentExtremumPoint.highDatetime == currentExtremumPoint.lastHighDatetime && currentExtremumPoint.lowDatetime == currentExtremumPoint.lastLowDatetime)
   {
      return;
   }

   // 创建斐波那契水平数组
   double fiboLevels[7] = {1.000, 0.786, 0.618, 0.500, 0.382, 0.236, 0.000};
   double fiboValues[7] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};

   if (currentExtremumPoint.direction == Incremental)
   {
      fiboValues[6] = currentExtremumPoint.high;
      fiboValues[0] = currentExtremumPoint.low;
   }
   else
   {
      fiboValues[6] = currentExtremumPoint.low;
      fiboValues[0] = currentExtremumPoint.high;
   }

   // 计算所有斐波那契水平值
   for (int i = 1; i < ArraySize(fiboValues) - 1; i++)
   {
      fiboValues[i] = fiboValues[0] * fiboLevels[i] + fiboValues[6] * (1 - fiboLevels[i]);
   }
   
   // 保存7个斐波那契值
   for (int i=0; i< FiboNumbers; i++)
   {
      FiboBuffer[rates_total-1-i] = fiboValues[FiboNumbers-1-i];
   }

   // 保存当前方向
   FiboBuffer[rates_total-8] = (double)currentExtremumPoint.direction;


   // 删除所有旧线
   for (int i = 0; i < ArraySize(fiboNames); i++)
   {
      ObjectDelete(0, fiboNames[i]);
   }

   datetime start, end;

   if (currentExtremumPoint.highDatetime > currentExtremumPoint.lowDatetime)
   {
      start = currentExtremumPoint.lowDatetime;
      end = currentExtremumPoint.highDatetime;
   }
   else
   {
      end = currentExtremumPoint.lowDatetime;
      start = currentExtremumPoint.highDatetime;
   }
   // 创建新的斐波那契线
   for (int i = 0; i < ArraySize(fiboNames); i++)
   {
      if (ObjectCreate(0, fiboNames[i]+randomNumber, OBJ_TREND, 0,
                       start,
                       fiboValues[i],
                       end,
                       fiboValues[i]))
      {
         string objectName = fiboNames[i]+randomNumber;
         ObjectSetInteger(0, objectName, OBJPROP_COLOR, InpFiboLineColor);
         ObjectSetInteger(0, objectName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, objectName, OBJPROP_RAY_RIGHT, true);
         // 添加百分比标签
         string label = StringFormat("%.1f%%", fiboLevels[i] * 100);
         string name= objectName + "_label";
         // ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         // //--- set the text 
         // ObjectSetString(0,name,OBJPROP_TEXT,label); 
         if (ObjectCreate(0, name, OBJ_TEXT, 0, start, fiboValues[i]))
         {
            ObjectSetString(0, name, OBJPROP_TEXT, label);
            ObjectSetInteger(0, name, OBJPROP_COLOR, InpFiboLineColor);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
            ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         }
      }
   }

   string fibolist = StringFormat("Fibonacci%s:(%f,%f,%f,%f,%f,%f,%f)", randomNumber,
                                  fiboValues[0], fiboValues[1], fiboValues[2],
                                  fiboValues[3], fiboValues[4], fiboValues[5],
                                  fiboValues[6]);
   //printf(fibolist);
}

