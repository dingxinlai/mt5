//+------------------------------------------------------------------+
//|                                            ClaspedMorphology.mq5 |
//|                                                     fateking.com |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
//--- plot Down
#property indicator_label1  "Down"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot Up
#property indicator_label2  "Up"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- input parameters
input int      MinPeriod=3;
//--- indicator buffers
double         DownBuffer[];
double         UpBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
//--- indicator buffers mapping
   SetIndexBuffer(0,DownBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,UpBuffer,INDICATOR_DATA);
//--- setting a code from the Wingdings charset as the property of PLOT_ARROW
   PlotIndexSetInteger(0,PLOT_ARROW,226);
   PlotIndexSetInteger(1,PLOT_ARROW,225);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0);

//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
                const int &spread[]) {
//---
   if (MinPeriod < 3 || rates_total <= MinPeriod + 1) {
      return (0);
   }
   int up = 1;
   int down = 1;
   for (int i = rates_total - (MinPeriod + 1); i < rates_total - 1; i++) {
      if (open[i - 1] < close[i - 1]) {
         up &= 1;
         down &= 0;
      } else if (open[i - 1] > close[i - 1]) {
         up &= 0;
         down &= 1;
      }
   }
   if (up == 1
         && NormalizeDouble(open[rates_total - 2], Digits()) < NormalizeDouble(close[rates_total - 2], Digits())
         && NormalizeDouble(open[rates_total - 1], Digits()) > NormalizeDouble(close[rates_total - 1], Digits())
         && NormalizeDouble(open[rates_total - 2], Digits()) > NormalizeDouble(close[rates_total - 1], Digits())
         && NormalizeDouble(close[rates_total - 2], Digits()) < NormalizeDouble(open[rates_total - 1], Digits())) {
      DownBuffer[rates_total - 1] = open[rates_total - 1] + 100 * Point();
   }
   if (down == 1
         && NormalizeDouble(open[rates_total - 2], Digits()) > NormalizeDouble(close[rates_total - 2], Digits())
         && NormalizeDouble(open[rates_total - 1], Digits()) < NormalizeDouble(close[rates_total - 1], Digits())
         && NormalizeDouble(open[rates_total - 2], Digits()) < NormalizeDouble(close[rates_total - 1], Digits())
         && NormalizeDouble(close[rates_total - 2], Digits()) > NormalizeDouble(open[rates_total - 1], Digits())) {
      UpBuffer[rates_total - 1] = open[rates_total - 1] - 100 * Point();
   }

//--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
