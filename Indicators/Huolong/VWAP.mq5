//+------------------------------------------------------------------+
//|                                                         VWAP.mq5 |
//|                                                       Dylan Ding |
//|                                         https://www.fateking.com |
//+------------------------------------------------------------------+
#property copyright "Dylan Ding"
#property link      "https://www.fateking.com"
#property version   "1.00"
#property indicator_chart_window

//--- Plotting properties
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots 1

//--- Plot 1: Daily VWAP
#property indicator_label1	"Daily VWAP"
#property indicator_type1	DRAW_LINE
#property indicator_color1	clrDodgerBlue
#property indicator_width1	1

//--- Indicator Data Buffer
double VWAPBuffer[];

//--- Global Variables
double   CumulativeTPV    = 0.0;
double   CumulativeVolume = 0.0;
datetime dtLastDay;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime CreateDateTime(datetime dtDay=D'2000.01.01 00:00:00',
                        int pHour=0,
                        int pMinute=0,
                        int pSecond=0) {
   datetime    dtReturnDate;
   MqlDateTime timeStruct;

   TimeToStruct(dtDay, timeStruct);
   timeStruct.hour = pHour;
   timeStruct.min = pMinute;
   timeStruct.sec = pSecond;
   dtReturnDate = (StructToTime(timeStruct));
   return dtReturnDate;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   //--- Indicator buffer mapping
   SetIndexBuffer(0, VWAPBuffer, INDICATOR_DATA);

   //--- Setup for Plot 0 (Daily VWAP)
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);

   //--- Set indicator short name
   IndicatorSetString(INDICATOR_SHORTNAME, "Daily VWAP");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int       rates_total,
                const int       prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[]) {
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   if(prev_calculated == 0)
      dtLastDay = 0;

   //--- VWAP Calculation
   for(int i = start; i < rates_total; i++) {
      MqlDateTime timeStruct;
      TimeToStruct(time[i], timeStruct);

      if (i > 0) {
         MqlDateTime prevTimeStruct;
         TimeToStruct(time[i-1], prevTimeStruct);
         if (timeStruct.day != prevTimeStruct.day) {
            CumulativeTPV = 0.0;
            CumulativeVolume = 0.0;
         }
      }

      double typicalPrice = (high[i] + low[i] + close[i]) / 3.0;
      long barVolume = (tick_volume[i] > 1) ? tick_volume[i] : 1;

      CumulativeTPV += typicalPrice * barVolume;
      CumulativeVolume += (double)barVolume;

      VWAPBuffer[i] = (CumulativeVolume != 0) ? CumulativeTPV / CumulativeVolume : 0.0;
   }
   return rates_total;
}
//+------------------------------------------------------------------+