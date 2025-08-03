//+------------------------------------------------------------------+
//|                                                    IchimokuSignal.mqh |
//|                                                          DiGao   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "di.gao"
#property link      "https://www.mql5.com"

#include "IndicatorSignal.mqh"

class IchimokuSignal : public IndicatorSignal {
    private:
        double                            tenkan_buffer[];
        double                            kijun_buffer[];
        double                            span_a_buffer[];
        double                            span_b_buffer[];
        double                            chikou_buffer[];

    public:
        IchimokuSignal(string _symbol, ENUM_TIMEFRAMES _period, double &tenkan_buffer[], double &kijun_buffer[], double &span_a_buffer[], double &span_b_buffer[], double &chikou_buffer[]);
        ~IchimokuSignal(void);

        double                            CheckSignal();
};

IchimokuSignal::IchimokuSignal(string _symbol, ENUM_TIMEFRAMES _period, double &_tenkan_buffer[], double &_kijun_buffer[], double &_span_a_buffer[], double &_span_b_buffer[], double &_chikou_buffer[]) 
   : IndicatorSignal(_symbol, _period) {
    ArrayResize(tenkan_buffer, ArraySize(_tenkan_buffer));
    ArrayCopy(tenkan_buffer, _tenkan_buffer);
    ArrayResize(kijun_buffer, ArraySize(_kijun_buffer));
    ArrayCopy(kijun_buffer, _kijun_buffer);
    ArrayResize(span_a_buffer, ArraySize(_span_a_buffer));
    ArrayCopy(span_a_buffer, _span_a_buffer);
    ArrayResize(span_b_buffer, ArraySize(_span_b_buffer));
    ArrayCopy(span_b_buffer, _span_b_buffer);
    ArrayResize(chikou_buffer, ArraySize(_chikou_buffer));
    ArrayCopy(chikou_buffer, _chikou_buffer);
}

IchimokuSignal::~IchimokuSignal(void) {
    ArrayFree(tenkan_buffer);
    ArrayFree(kijun_buffer);
    ArrayFree(span_a_buffer);
    ArrayFree(span_b_buffer);
    ArrayFree(chikou_buffer);
}

//+------------------------------------------------------------------+
//| MA信号检测函数                                               |
//| 返回值说明：                                                     |
//|  1  = 买入信号                                                   |
//| -1  = 卖出信号                                                   |
//|  0  = 无信号                                                     |
//+------------------------------------------------------------------+
double IchimokuSignal::CheckSignal(void) {
    int total = ArraySize(tenkan_buffer);
    double tenkan_0 = tenkan_buffer[total - 1];
    double tenkan_1 = tenkan_buffer[total - 2];
    double kijun_0 = kijun_buffer[total - 1];
    double kijun_1 = kijun_buffer[total - 2];
    double senkouA = span_a_buffer[total - 1];
    double senkouB = span_b_buffer[total - 1];

   double close = iClose(symbol, period, 0);

   
   // 计算云层顶部和底部
   double cloudTop = MathMax(senkouA, senkouB);
   double cloudBottom = MathMin(senkouA, senkouB);
   
   // 判断交叉信号
   bool bullishCross = (tenkan_0 > kijun_0) && (tenkan_1 <= kijun_1); // 转换线上穿基准线
   bool bearishCross = (tenkan_0 < kijun_0) && (tenkan_1 >= kijun_1); // 转换线下穿基准线
   
   // 判断价格与云层关系
   bool priceAboveCloud = (close > cloudTop);
   bool priceBelowCloud = (close < cloudBottom);
   
   // 综合信号逻辑
   if (bullishCross && priceAboveCloud) {
      return 1; // 买入信号
   } else if (bearishCross && priceBelowCloud) {
      return -1; // 卖出信号
   }
   
   return 0; // 无信号
}
