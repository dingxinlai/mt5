//+------------------------------------------------------------------+
//|                                                      RSISignal.mqh |
//|                                                          DingXin |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "di.gao"
#property link      "https://www.mql5.com"

#include "IndicatorSignal.mqh"

enum RSI_SIGNAL_TYPE {RSI_SIGNAL_UNKNOWN = 0 , RSI_SIGNAL_OVERBOUGHT = -1, RSI_SIGNAL_OVERSOLD = 1};

class RSISignal : public IndicatorSignal {
    private:
        double                            overbought_threshold;
        double                            oversold_threshold;
        double                            rsi_buffer[];

    public:
        RSISignal(string symbol, ENUM_TIMEFRAMES period, double &rsi_buffer[], double _overbought_threshold, double _oversold_threshold);
        ~RSISignal(void);

        double                            CheckSignal();
};

RSISignal::RSISignal(string _symbol, ENUM_TIMEFRAMES _period, double &_rsi_buffer[], double _overbought_threshold = 80.0, double _oversold_threshold = 20.0) 
   : IndicatorSignal(_symbol, _period), overbought_threshold(_overbought_threshold), oversold_threshold(_oversold_threshold) {
   ArrayResize(rsi_buffer, ArraySize(_rsi_buffer));
   ArrayCopy(rsi_buffer, _rsi_buffer);
}

RSISignal::~RSISignal(void) {
   ArrayFree(rsi_buffer);
}

//+------------------------------------------------------------------+
//| MA信号检测函数                                               |
//| 返回值说明：                                                     |
//|  1  = 买入信号                                                   |
//| -1  = 卖出信号                                                   |
//|  0  = 无信号                                                     |
//+------------------------------------------------------------------+
double RSISignal::CheckSignal(void) {
    int total = ArraySize(rsi_buffer);
    double recent = rsi_buffer[total - 1];

    if(recent >= overbought_threshold) {
        return RSI_SIGNAL_OVERBOUGHT;
    } else if(recent <= oversold_threshold) {
        return RSI_SIGNAL_OVERSOLD;
    } else {
        return RSI_SIGNAL_UNKNOWN;
    }
}
