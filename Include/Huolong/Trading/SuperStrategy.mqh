//+------------------------------------------------------------------+
//|                                               SuperStrategy.mqh |
//|                                                          DingXin |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "DingXin"
#property link      "https://www.mql5.com"

#include <Huolong/Manager/IndicatorManager.mqh>
#include <Huolong/Manager/ConfigManager.mqh>
#include <Huolong/Manager/OrderManager.mqh>
#include <Huolong/Manager/CacheManager.mqh>
#include <Huolong/Manager/PositionManager.mqh>
#include <Utils/Utils.mqh>
#include <Utils/RateLimiter.mqh>
#include <Utils/Collection/HashMap.mqh>
#include <Utils/Collection/HashSet.mqh>
#include <Utils/Collection/ArrayList.mqh>
#include <Arrays/Array.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayInt.mqh>

#include "Strategy.mqh"
#include "Order.mqh"


class SuperStrategy : public Strategy {
   private:
      string                        symbol;
      ENUM_TIMEFRAMES               period;
      int                           digits;
      double                        point; 
      int                           magic;
      
      RateLimiter*                  limiter;

      ConfigManager*                config;               // 配置管理
      IndicatorManager*             im;                   // 指标管理
      OrderManager*                 om;                   // 交易操作
      PositionManager*              pm;                   // 仓位管理
      CacheManager*                 cache;
      
      STIndicatorHandle*            st_handle;            // SuperTrend指标
      MAIndicatorHandle*            ema_m15_handle;       // EMA100指标 (15分钟周期)
      MAIndicatorHandle*            ema_m30_handle;        // EMA100指标 (30分钟周期)
      MAIndicatorHandle*            ema_m60_handle;        // EMA100指标 (60分钟周期)
      VWAPIndicatorHandle*          vwap_handle;          // VWAP指标
      ATRIndicatorHandle*           atr_handle;           // ATR指标
      VegasIndicatorHandle*         vegas_m15_handle;       // VEGAS指标 (15分钟周期)
      VegasIndicatorHandle*         vegas_m30_handle;       // VEGAS指标（30分钟周期）
      VegasIndicatorHandle*         vegas_m60_handle;       // VEGAS指标（60分钟周期）

      CArrayList<Order*>*           buy_order;
      CArrayList<Order*>*           sell_order;

      int                           buffer_size;
      double                        lots;
      
      // 订单跟踪和止盈管理
      int                           last_signal_bar;        // 最后信号K线
      double                        entry_price;            // 开仓价格
      double                        atr_value;              // 当前ATR值
      bool                          first_tp_hit;           // 第一层止盈是否已触发（50%）
      bool                          vegas_tp_hit;           // Vegas止盈是否已触发（25%）
      bool                          use_vegas_tp;           // 是否使用Vegas止盈
      DIRECTION                     current_position;       // 当前持仓方向
      double                        remaining_lots;         // 剩余仓位大小
      bool                          has_position;           // 是否有持仓
      
      // 反频繁交易过滤
      datetime                      last_close_time;        // 最后平仓时间
      int                           consecutive_losses;     // 连续亏损次数
      double                        min_breakout_distance;  // 最小突破距离（ATR倍数）
      
      // 趋势反转确认机制
      int                           reversal_confirm_bars;  // 反转确认K线数
      int                           last_reversal_bar;      // 最后检测到反转的K线
      
      void                          SyncOrder(void);
      bool                          ShouldBuy(void);
      bool                          ShouldSell(void);
      void                          OpenBuyPosition(void);
      void                          OpenSellPosition(void);
      void                          ProcessTakeProfit(void);
      bool                          CheckVegasDistance(DIRECTION direction);
      bool                          CheckVegasTpCondition(DIRECTION direction);
      bool                          CheckVwapReversal(DIRECTION direction);
   public:
      SuperStrategy(string symbol, ENUM_TIMEFRAMES period, int magic, IndicatorManager* im);
      ~SuperStrategy(void);
      
      void                          Execute(void) override;
};

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
SuperStrategy::SuperStrategy(string _symbol, ENUM_TIMEFRAMES _period, int _magic, IndicatorManager* _im) 
   : symbol(_symbol), magic(_magic), im(_im), period(_period)
{
   cache = new CacheManager();
   Print("缓存管理器初始化完毕");
   pm = new PositionManager(symbol);
   Print("仓位管理器初始化完毕");
   config = new ConfigManager("TRD", false);
   Print("配置管理器初始化完毕");
   om = new OrderManager(symbol, magic);
   Print("订单管理器初始化完毕");

   point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   buy_order = new CArrayList<Order*>();
   sell_order = new CArrayList<Order*>();

   buffer_size = 20;  
   
   // 初始化交易状态变量
   last_signal_bar = 0;
   entry_price = 0.0;
   atr_value = 0.0;
   first_tp_hit = false;
   vegas_tp_hit = false;
   use_vegas_tp = false;
   current_position = DIRECTION_UNKNOWN;
   remaining_lots = 0.0;
   has_position = false;
   
   // 初始化过滤参数
   last_close_time = 0;
   consecutive_losses = 0;
   min_breakout_distance = config.GetDouble(symbol + ".min_breakout_atr", 0.3); // 默认0.3倍ATR
   
   // 初始化反转确认参数
   reversal_confirm_bars = config.GetInt(symbol + ".reversal_confirm_bars", 2); // 默认需要2根K线确认反转
   last_reversal_bar = 0;
   
   // 初始化指标
   st_handle = im.GetST(period, buffer_size);
   ema_m15_handle = im.GetMA(PERIOD_M15, 100, buffer_size);
   ema_m30_handle = im.GetMA(PERIOD_M30, 100, buffer_size);
   ema_m60_handle = im.GetMA(PERIOD_H1, 100, buffer_size);
   vwap_handle = im.GetVWAP(period, buffer_size);
   atr_handle = im.GetATR(period, buffer_size);
   vegas_m15_handle = im.GetVegas(PERIOD_M15, buffer_size);
   vegas_m30_handle = im.GetVegas(PERIOD_M30, buffer_size);
   vegas_m60_handle = im.GetVegas(PERIOD_H1, buffer_size);

   // 初始化策略参数
   lots = config.GetDouble(symbol + ".M15.lots", 0.1);
   
   Print("SuperStrategy初始化完毕 - Magic:", magic, " Lots:", lots);
}

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
SuperStrategy::~SuperStrategy(void) {
   delete limiter;
   delete config;
   delete pm;
   delete om;
   delete cache;
   
   delete st_handle;
   delete ema_m15_handle;
   delete ema_m30_handle;
   delete ema_m60_handle;
   delete vwap_handle;
   delete atr_handle;
   delete vegas_m15_handle;
   delete vegas_m30_handle;
   delete vegas_m60_handle;
   
   ReleaseList(buy_order);
   ReleaseList(sell_order);
   
   Print("SuperStrategy析构完毕");
}

//+------------------------------------------------------------------+
//| 同步订单状态                                                      |
//+------------------------------------------------------------------+
void SuperStrategy::SyncOrder(void) {
   if (buy_order.Count() > 0) {
      for (int i = buy_order.Count() - 1; i >= 0; i--) {
         Order* o;
         if (buy_order.TryGetValue(i, o)) {
            if (CheckPointer(o) == POINTER_DYNAMIC && o != NULL && om.IsOrderClosed(o.ticket)) {
               delete o;
               buy_order.RemoveAt(i);
            }
         }
      }
   }
   if (sell_order.Count() > 0) {
      for (int i = sell_order.Count() - 1; i >= 0; i--) {
         Order* o;
         if (sell_order.TryGetValue(i, o)) {
            if (CheckPointer(o) == POINTER_DYNAMIC && o != NULL && om.IsOrderClosed(o.ticket)) {
               delete o;
               sell_order.RemoveAt(i);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 主执行函数                                                        |
//+------------------------------------------------------------------+
void SuperStrategy::Execute(void) {
   // 同步订单状态
   SyncOrder();
   
   if (!st_handle.Refresh(buffer_size)) return;
   if (!ema_m15_handle.Refresh(buffer_size)) return;
   if (!ema_m30_handle.Refresh(buffer_size)) return;
   if (!ema_m60_handle.Refresh(buffer_size)) return;
   if (!vwap_handle.Refresh(buffer_size)) return;
   if (!atr_handle.Refresh(buffer_size)) return;
   if (!vegas_m15_handle.Refresh(buffer_size)) return;
   if (!vegas_m30_handle.Refresh(buffer_size)) return;
   if (!vegas_m60_handle.Refresh(buffer_size)) return;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   int bar = iBars(symbol, period);
   
   // 更新ATR值
   atr_value = atr_handle.data[0];
   
   // 检查是否有持仓
   has_position = (buy_order.Count() > 0 || sell_order.Count() > 0);
   
   if (has_position) {
      // 如果有持仓，处理止盈逻辑
      ProcessTakeProfit();
   } else {
      // 如果没有持仓，检查开仓信号
      if (ShouldBuy()) {
         OpenBuyPosition();
      } else if (ShouldSell()) {
         OpenSellPosition();
      }
   }
}


bool SuperStrategy::ShouldBuy(void) {
   bool vwap_bullish = iClose(symbol, period, 0) > vwap_handle.data[0] && iClose(symbol, period, 1) > vwap_handle.data[1] && iClose(symbol, period, 2) <= vwap_handle.data[2]; 
   return vwap_bullish;
}

bool SuperStrategy::ShouldSell(void) {
   bool vwap_bearish = iClose(symbol, period, 0) < vwap_handle.data[0] && iClose(symbol, period, 1) < vwap_handle.data[1] && iClose(symbol, period, 2) >= vwap_handle.data[2];
   return vwap_bearish;
}

//+------------------------------------------------------------------+
//| 开多头仓位                                                        |
//+------------------------------------------------------------------+
void SuperStrategy::OpenBuyPosition(void) {
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double sl = ask - atr_value; // 止损
   
   Order* order = om.Buy(lots, sl, 0.0, "VWAP_Buy");
   if (order != NULL) {
      buy_order.Add(order);
      
      // 记录开仓信息
      entry_price = ask;
      current_position = BUY;
      remaining_lots = lots;
      first_tp_hit = false;
      vegas_tp_hit = false;
      
      // 判断是否使用Vegas止盈
      use_vegas_tp = CheckVegasDistance(BUY);
      
      Print("开多仓成功 - 价格:", ask, " 止损:", sl, " ATR:", atr_value, " 使用Vegas:", use_vegas_tp);
   }
}

//+------------------------------------------------------------------+
//| 开空头仓位                                                        |
//+------------------------------------------------------------------+
void SuperStrategy::OpenSellPosition(void) {
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double sl = bid + atr_value; // 止损
   
   Order* order = om.Sell(lots, sl, 0.0, "VWAP_Sell");
   if (order != NULL) {
      sell_order.Add(order);
      
      // 记录开仓信息
      entry_price = bid;
      current_position = SELL;
      remaining_lots = lots;
      first_tp_hit = false;
      vegas_tp_hit = false;
      
      // 判断是否使用Vegas止盈
      use_vegas_tp = CheckVegasDistance(SELL);
      
      Print("开空仓成功 - 价格:", bid, " 止损:", sl, " ATR:", atr_value, " 使用Vegas:", use_vegas_tp);
   }
}

//+------------------------------------------------------------------+
//| 处理止盈逻辑                                                      |
//+------------------------------------------------------------------+
void SuperStrategy::ProcessTakeProfit(void) {
   double current_price = (current_position == BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   // 第一层止盈（50%）
   if (!first_tp_hit) {
      bool hit_first_tp = false;
      
      if (current_position == BUY) {
         hit_first_tp = (current_price >= entry_price + atr_value);
      } else if (current_position == SELL) {
         hit_first_tp = (current_price <= entry_price - atr_value);
      }
      
      if (hit_first_tp) {
         double close_lots = lots * 0.5; // 平仓50%
         if (current_position == BUY && buy_order.Count() > 0) {
            Order* order;
            if (buy_order.TryGetValue(0, order)) {
               om.CloseBuy(order.ticket, close_lots, "TP1_50%");
            }
         } else if (current_position == SELL && sell_order.Count() > 0) {
            Order* order;
            if (sell_order.TryGetValue(0, order)) {
               om.CloseSell(order.ticket, close_lots, "TP1_50%");
            }
         }
         
         first_tp_hit = true;
         remaining_lots = lots * 0.5;
         Print("第一层止盈触发 - 平仓50%, 剩余仓位:", remaining_lots);
      }
   }
   
   // 第二层止盈 - Vegas止盈（25%）或跳过到VWAP止盈（50%）
   if (first_tp_hit && !vegas_tp_hit) {
      if (use_vegas_tp) {
         // 使用Vegas止盈
         if (CheckVegasTpCondition(current_position)) {
            double close_lots = lots * 0.25; // 平仓25%
            if (current_position == BUY && buy_order.Count() > 0) {
               Order* order;
               if (buy_order.TryGetValue(0, order)) {
                  om.CloseBuy(order.ticket, close_lots, "TP2_Vegas_25%");
               }
            } else if (current_position == SELL && sell_order.Count() > 0) {
               Order* order;
               if (sell_order.TryGetValue(0, order)) {
                  om.CloseSell(order.ticket, close_lots, "TP2_Vegas_25%");
               }
            }
            
            vegas_tp_hit = true;
            remaining_lots = lots * 0.25;
            Print("Vegas止盈触发 - 平仓25%, 剩余仓位:", remaining_lots);
         }
      } else {
         // 不使用Vegas，直接跳到VWAP止盈
         vegas_tp_hit = true;
         remaining_lots = lots * 0.5; // 剩余50%等待VWAP止盈
      }
   }
   
   // 第三层止盈 - VWAP反转止盈（剩余25%或50%）
   if (first_tp_hit && vegas_tp_hit) {
      if (CheckVwapReversal(current_position)) {
         // 平掉所有剩余仓位
         if (current_position == BUY && buy_order.Count() > 0) {
            Order* order;
            if (buy_order.TryGetValue(0, order)) {
               om.CloseByTicket(order.ticket);
            }
         } else if (current_position == SELL && sell_order.Count() > 0) {
            Order* order;
            if (sell_order.TryGetValue(0, order)) {
               om.CloseByTicket(order.ticket);
            }
         }
         
         // 重置状态
         entry_price = 0.0;
         current_position = DIRECTION_UNKNOWN;
         remaining_lots = 0.0;
         first_tp_hit = false;
         vegas_tp_hit = false;
         use_vegas_tp = false;
         
         Print("VWAP反转止盈触发 - 平掉所有剩余仓位");
      }
   }
}

//+------------------------------------------------------------------+
//| 检查Vegas通道距离是否足够使用Vegas止盈                            |
//+------------------------------------------------------------------+
bool SuperStrategy::CheckVegasDistance(DIRECTION direction) {
   double vegas_upper = vegas_m15_handle.Upper(0);
   double vegas_lower = vegas_m15_handle.Lower(0);
   double distance_required = atr_value * 2.0; // 2倍ATR
   
   if (direction == BUY) {
      // 做多：检查开仓价格到Vegas下沿的距离
      return (vegas_lower > entry_price + distance_required);
   } else if (direction == SELL) {
      // 做空：检查开仓价格到Vegas上沿的距离
      return (vegas_upper < entry_price - distance_required);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 检查Vegas止盈条件                                                |
//+------------------------------------------------------------------+
bool SuperStrategy::CheckVegasTpCondition(DIRECTION direction) {
   double current_price = (direction == BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   double vegas_upper = vegas_m15_handle.Upper(0);
   double vegas_lower = vegas_m15_handle.Lower(0);
   
   if (direction == BUY) {
      // 做多：价格触及Vegas下沿
      return (current_price <= vegas_lower);
   } else if (direction == SELL) {
      // 做空：价格触及Vegas上沿
      return (current_price >= vegas_upper);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 检查VWAP反转条件                                                 |
//+------------------------------------------------------------------+  
bool SuperStrategy::CheckVwapReversal(DIRECTION direction) {
   double current_close = iClose(symbol, period, 0);
   double prev_close = iClose(symbol, period, 1);
   double prev2_close = iClose(symbol, period, 2);
   double vwap_current = vwap_handle.data[0];
   double vwap_prev = vwap_handle.data[1];
   double vwap_prev2 = vwap_handle.data[2];
   
   // 获取当前ATR作为过滤条件
   double current_atr = atr_handle.data[0];
   double min_reversal_distance = current_atr * 0.3; // 至少0.3倍ATR的穿越距离
   
   if (direction == BUY) {
      // 做多平仓条件：价格已经在VWAP下方且有足够的反转距离
      bool below_vwap = (current_close < vwap_current);
      bool sufficient_distance = (vwap_current - current_close) >= min_reversal_distance;
      
      // 检查反转趋势：当前价格比前一根更远离VWAP，或者连续在VWAP下方
      bool trend_deteriorating = (current_close < prev_close) || 
                                (current_close < vwap_current && prev_close < vwap_prev);
      
      return below_vwap && sufficient_distance && trend_deteriorating;
      
   } else if (direction == SELL) {
      // 做空平仓条件：价格已经在VWAP上方且有足够的反转距离
      bool above_vwap = (current_close > vwap_current);
      bool sufficient_distance = (current_close - vwap_current) >= min_reversal_distance;
      
      // 检查反转趋势：当前价格比前一根更远离VWAP，或者连续在VWAP上方
      bool trend_deteriorating = (current_close > prev_close) || 
                                (current_close > vwap_current && prev_close > vwap_prev);
      
      return above_vwap && sufficient_distance && trend_deteriorating;
   }
   
   return false;
}
