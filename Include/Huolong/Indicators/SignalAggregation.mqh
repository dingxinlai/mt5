//+------------------------------------------------------------------+
//|                                            SignalAggregation.mqh |
//|                                                          DingXin |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "DingXin"
#property link      "https://www.mql5.com"

#include <Huolong/Indicators/TrendLine.mqh>
#include <Huolong/Indicators/IndicatorSignal.mqh>
#include <Huolong/Manager/ConfigManager.mqh>
#include <Huolong/Manager/IndicatorManager.mqh>

enum VERTICAL_SIGNAL_TYPE { VERTICAL_SIGNAL_UNKNOWN, 
                   // 趋势线
                   SIGNAL_SR_UP, SIGNAL_SR_DOWN, 
                   // 斐波那契
                   FIBO_000, FIBO_236, FIBO_382, FIBO_500, FIBO_618, FIBO_786, FIBO_100,
                   // Bands
                   SIGNAL_BANDS_UPPER, SIGNAL_BANDS_MIDDLE, SIGNAL_BANDS_LOWER,
                   // MA
                   SIGNAL_MA };

enum HORIZONTAL_SIGNAL_TYPE { HORIZONTAL_SIGNAL_UNKNOWN, 
                              SIGNAL_MA_CROSS_UP, SIGNAL_MA_CROSS_DOWN,
                              SIGNAL_BANDS_EXPANSION, SIGNAL_BANDS_CONVERGENCE, SIGNAL_BANDS_STABILIZATION                        
   };

class SignalAggregation {
   private:
      SignalAggregation(ConfigManager* config, IndicatorManager* im);
      ~SignalAggregation(void);
      
      ConfigManager*                          config;
      IndicatorManager*                       im;
      
      double                                  h1_trend_price_threshold;
      double                                  m30_trend_price_threshold;
      double                                  m15_trend_price_threshold;
      double                                  m5_trend_price_threshold;
      double                                  m1_trend_price_threshold;
      
      double                                  lots;

      // vertical signal
      VERTICAL_SIGNAL_TYPE                    verticalSignalTypes[];
      ENUM_TIMEFRAMES                         verticalSignalPeriods[];
      double                                  verticalSignalPrices[];
      double                                  verticalSignalConfidences[];

      // horizontal signal
      HORIZONTAL_SIGNAL_TYPE                  horizontalSignalTypes[];
      ENUM_TIMEFRAMES                         horizontalSignalPeriods[];
      datetime                                horizontalSignalTimes[];
      double                                  horizontalSignalConfidences[];
      
      bool                                    h1_hit_trend;
      bool                                    m30_hit_trend;
      bool                                    m15_hit_trend;
      bool                                    m5_hit_trend;
      bool                                    m1_hit_trend;

      bool                                    h1_hit_ma;
      bool                                    m5_hit_ma;

      bool                                    h1_hit_bands_upper;
      bool                                    h1_hit_bands_middle;
      bool                                    h1_hit_bands_lower;

   public:
      void                                    Analyze();

      void                                    InsertVerticalSignal(VERTICAL_SIGNAL_TYPE type, ENUM_TIMEFRAMES period, double price, double confidence);
      void                                    InsertHorizontalSignal(HORIZONTAL_SIGNAL_TYPE type, ENUM_TIMEFRAMES period, datetime time, double confidence);

      // 趋势线
      void                                    AggregateTrendLine(TrendLine* line);
      // MA
      void                                    AggregateMA(MAIndicatorHandle* handle);
      // Bands
      void                                    AggregateBands(BandsIndicatorHandle* handle);
      
      int                                     GetSignal(ENUM_TIMEFRAMES period);
};

SignalAggregation::SignalAggregation(ConfigManager* _config, IndicatorManager* _im) : config(_config), im(_im) {
}

SignalAggregation::~SignalAggregation(void) {
   delete im;

   ArrayFree(verticalSignalTypes);
   ArrayFree(verticalSignalPeriods);
   ArrayFree(verticalSignalPrices);
   ArrayFree(verticalSignalConfidences);

   ArrayFree(horizontalSignalTypes);
   ArrayFree(horizontalSignalPeriods);
   ArrayFree(horizontalSignalConfidences);
}

void SignalAggregation::InsertVerticalSignal(VERTICAL_SIGNAL_TYPE type, ENUM_TIMEFRAMES period, double price, double confidence) {
   int size = ArraySize(verticalSignalTypes);
   ArrayResize(verticalSignalTypes, size + 1);
   ArrayResize(verticalSignalPeriods, size + 1);
   ArrayResize(verticalSignalPrices, size + 1);
   ArrayResize(verticalSignalConfidences, size + 1);
   
   int insertIdx = -1;
   for (int i = 0; i <= size; i++) {
      if (price >= verticalSignalPrices[i]) {
         insertIdx = i;
         break;
      }
   }
   if (insertIdx == -1) {
      insertIdx = size;
   }

   for (int i = size; i > insertIdx; i--) {
      verticalSignalTypes[i] = verticalSignalTypes[i - 1];
      verticalSignalPeriods[i] = verticalSignalPeriods[i - 1];
      verticalSignalPrices[i] = verticalSignalPrices[i - 1];
      verticalSignalConfidences[i] = verticalSignalConfidences[i - 1];
   }
   verticalSignalTypes[insertIdx] = type;
   verticalSignalPeriods[insertIdx] = period;
   verticalSignalPrices[insertIdx] = price;
   verticalSignalConfidences[insertIdx] = confidence;
}

void SignalAggregation::InsertHorizontalSignal(HORIZONTAL_SIGNAL_TYPE type, ENUM_TIMEFRAMES period, datetime time, double confidence) {

}

void SignalAggregation::AggregateTrendLine(TrendLine* line) {
   int bars = iBars(line.symbol, line.period);
   double price = line.GetPriceByIndex(bars - 1);
   bool bold = line.bold;
   bool existSignal = ArraySize(line.eventIndexes) > 0 && line.eventIndexes[0] == bars - 1;

   EVENT_TYPE type = existSignal ? line.eventTypes[0] : EVENT_UNKNOW;
   VERTICAL_SIGNAL_TYPE verticalSignalType = VERTICAL_SIGNAL_UNKNOWN;
   double confidence = 0.0;

   if (type == SUPPORT_STEPBACK) {
      confidence = bold ? 2.0 : 1.0;
      verticalSignalType = SIGNAL_SR_UP;
   } 
   else if (type == SUPPORT_BREAK) {
      confidence = bold ? 2.0 : 1.0;
      verticalSignalType = SIGNAL_SR_DOWN;
   }
   else if (type == RESISTANCE_STEPBACK) {
      confidence = bold ? 2.0 : 1.0;
      verticalSignalType = SIGNAL_SR_DOWN;
   } 
   else if (type == RESISTANCE_BREAK) {
      confidence = bold ? 2.0 : 1.0;
      verticalSignalType = SIGNAL_SR_UP;
   } else {
      confidence = 0.0;
      verticalSignalType = VERTICAL_SIGNAL_UNKNOWN;
   }
   InsertVerticalSignal(verticalSignalType, line.period, price, confidence);
}

void SignalAggregation::AggregateMA(MAIndicatorHandle* handle) {
}

void SignalAggregation::AggregateBands(BandsIndicatorHandle* handle) {
}

int SignalAggregation::GetSignal(ENUM_TIMEFRAMES period) {
   return 0;
}

void SignalAggregation::Analyze(void) {
   // 中期方向
   TrendIndicatorHandle* sr_h1_handle = im.GetSR(PERIOD_H1);
   for (int i = 0; i < sr_h1_handle.lines.Total(); i++) {
      TrendLine* line = (TrendLine*)sr_h1_handle.lines.At(i);
      AggregateTrendLine(line);
   }
   
   // 中短期
   TrendIndicatorHandle* sr_m30_handle = im.GetSR(PERIOD_M30);
   for (int i = 0; i < sr_m30_handle.lines.Total(); i++) {
      TrendLine* line = (TrendLine*)sr_m30_handle.lines.At(i);
      AggregateTrendLine(line);
   }
   
   // 短期
   TrendIndicatorHandle* sr_m15_handle = im.GetSR(PERIOD_M15);
   for (int i = 0; i < sr_m15_handle.lines.Total(); i++) {
      TrendLine* line = (TrendLine*)sr_m15_handle.lines.At(i);
      AggregateTrendLine(line);
   }

   // 超短期
   TrendIndicatorHandle* sr_m5_handle = im.GetSR(PERIOD_M5);
   for (int i = 0; i < sr_m5_handle.lines.Total(); i++) {
      TrendLine* line = (TrendLine*)sr_m5_handle.lines.At(i);
      AggregateTrendLine(line);
   }

   // MA - 1h
   MAIndicatorHandle* ma_h1_handle = im.GetMA(PERIOD_H1, 50, 1);
   AggregateMA(ma_h1_handle);

   // MA - 5min
   MAIndicatorHandle* ma_m5_handle = im.GetMA(PERIOD_M5, 50, 1);
   AggregateMA(ma_m5_handle);

   // Bands - 1h
   BandsIndicatorHandle* bands_h1_handle = im.GetBands(PERIOD_H1, 1);
   AggregateBands(bands_h1_handle);

   // Bands - 5min
   BandsIndicatorHandle* bands_m5_handle = im.GetBands(PERIOD_M5, 1);
   AggregateBands(bands_m5_handle);
}

