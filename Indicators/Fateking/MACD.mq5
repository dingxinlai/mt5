//+------------------------------------------------------------------+
//|                                                         MACD.mq5 |
//|                                                     fateking.com |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   6
//--- plot macd
#property indicator_label1  "macd"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot signal
#property indicator_label2  "signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- plot diff
#property indicator_label3  "diff"
#property indicator_type3   DRAW_COLOR_HISTOGRAM
#property indicator_color3  clrWhite,clrAqua,clrDarkGray
#property indicator_style3  STYLE_SOLID
#property indicator_width3  6
//--- plot up
#property indicator_label4  "up"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1
//--- plot down
#property indicator_label5  "down"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrDarkOrange
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1
//--- plot filling
#property indicator_label6  "filling"
#property indicator_type6   DRAW_FILLING
#property indicator_color6  clrRed,clrYellow
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1
//--- input parameters
input int                InpFastEMA=12;               // Fast EMA period
input int                InpSlowEMA=26;               // Slow EMA period
input int                InpSignalSMA=9;              // Signal SMA period
input ENUM_APPLIED_PRICE InpAppliedPrice=PRICE_CLOSE; // Applied price
//--- indicator buffers
double         macdBuffer[];
double         signalBuffer[];
double         diffBuffer[];
double         diffColors[];
double         upBuffer[];
double         downBuffer[];
double         fillingBuffer1[];
double         fillingBuffer2[];

int macd_h;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
//--- indicator buffers mapping
   SetIndexBuffer(0,macdBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,signalBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,diffBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,diffColors,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4,upBuffer,INDICATOR_DATA);
   SetIndexBuffer(5,downBuffer,INDICATOR_DATA);
   SetIndexBuffer(6,fillingBuffer1,INDICATOR_DATA);
   SetIndexBuffer(7,fillingBuffer2,INDICATOR_DATA);
//--- setting a code from the Wingdings charset as the property of PLOT_ARROW
   PlotIndexSetInteger(3,PLOT_ARROW,225);
   PlotIndexSetInteger(4,PLOT_ARROW,226);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,0);
   macd_h = iMACD(NULL, 0, InpFastEMA, InpSlowEMA, InpSignalSMA, InpAppliedPrice);
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
   double macd[];
   double signal[];
   CopyBuffer(macd_h, 0, 0, rates_total, macd);
   CopyBuffer(macd_h, 1, 0, rates_total, signal);

   int start = 100;
   if (prev_calculated > 0) {
      start = prev_calculated - 1;
   }
   for (int i = start; i < rates_total; i++) {
      macdBuffer[i] = macd[i];
      signalBuffer[i] = signal[i];
      diffBuffer[i] = macd[i] - signal[i];
      if (diffBuffer[i] > 0) {
         if (diffBuffer[i] > diffBuffer[i - 1]) {
            diffColors[i] = 0;
         } else {
            diffColors[i] = 2;
         }
      } else {
         if (diffBuffer[i] < diffBuffer[i - 1]) {
            diffColors[i] = 1;
         } else {
            diffColors[i] = 2;
         }
      }
      if (macdBuffer[i] > signalBuffer[i] && macdBuffer[i - 1] < signalBuffer[i - 1]) {
         upBuffer[i] = signalBuffer[i] - 50 * Point();
      }
      if (macdBuffer[i] < signalBuffer[i] && macdBuffer[i - 1] > signalBuffer[i - 1]) {
         downBuffer[i] = signalBuffer[i] + 50 * Point();
      }
   }


//--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
