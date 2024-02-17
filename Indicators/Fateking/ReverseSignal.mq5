//+------------------------------------------------------------------+
//|                                                ReverseSignal.mq5 |
//|                                                     fateking.com |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
//--- plot DarkCloud
#property indicator_label1  "DarkCloud"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot Pierce
#property indicator_label2  "Pierce"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- indicator buffers
double         DarkCloudBuffer[];
double         PierceBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
//--- indicator buffers mapping
   SetIndexBuffer(0,DarkCloudBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,PierceBuffer,INDICATOR_DATA);
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
   if (rates_total < 2) {
      return (0);
   }
   int pre = rates_total - 2;
   int cur = rates_total - 1;

   if (open[pre] < close[pre]
         && open[cur] > close[cur]
         && close[pre] < open[cur]
         && close[cur] < ((open[pre] + close[pre]) * 0.5)) {
      DarkCloudBuffer[cur] = high[cur] + 100 * Point();   //down
   } else if (open[pre] > close[pre]
              && open[cur] < close[cur]
              && close[pre] > open[cur]
              && close[cur] > ((open[pre] + close[pre]) * 0.5)) {
      PierceBuffer[cur] = low[cur] - 100 * Point();      // up
   }

//--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
