//+------------------------------------------------------------------+
//|                                                     Strategy.mqh |
//|                                                          DingXin |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "DingXin"
#property link      "https://www.mql5.com"

enum DIRECTION { DIRECTION_UNKNOWN, BUY, SELL };

class Strategy {
   public:
      Strategy(void);
      ~Strategy(void);
      
      virtual void                   Execute(void);
};

Strategy::Strategy() {
}

Strategy::~Strategy(void) {
}