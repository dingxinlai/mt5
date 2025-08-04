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
      
      // 开仓准备状态管理
      bool                          ready_buy;              // 准备做多状态
      bool                          ready_sell;             // 准备做空状态
      double                        ready_buy_vwap;         // 进入准备做多状态时的VWAP价格
      double                        ready_sell_vwap;        // 进入准备做空状态时的VWAP价格
      
      void                          SyncOrder(void);
      bool                          ShouldBuy(void);
      bool                          ShouldSell(void);
      void                          OpenBuyPosition(void);
      void                          OpenSellPosition(void);
      void                          ProcessTakeProfit(void);
      bool                          CheckVegasDistance(DIRECTION direction);
      bool                          CheckVegasTpCondition(DIRECTION direction);
      bool                          CheckVwapReversal(DIRECTION direction);
      bool                          CheckSuperTrendReversal(DIRECTION direction);
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
   
   // 初始化开仓准备状态
   ready_buy = false;
   ready_sell = false;
   ready_buy_vwap = 0.0;
   ready_sell_vwap = 0.0;
   
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
   lots = config.GetDouble(symbol + ".M15.lots", 0.4);
   
   // 初始化日志限制器，5分钟(300秒)打印一次
   limiter = new RateLimiter(300);
   
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

   // 打印VWAP最近5根价格（5分钟限制一次）
   if (limiter.CanExecute()) {
      string vwap_info = StringFormat("VWAP最近5根价格: [0]=%.5f [1]=%.5f [2]=%.5f [3]=%.5f [4]=%.5f", 
                                     vwap_handle.data[0], vwap_handle.data[1], vwap_handle.data[2], 
                                     vwap_handle.data[3], vwap_handle.data[4]);
      Print(vwap_info);
   }

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
   // 检查VWAP上穿信号，进入准备做多状态
   // 要求连续两根K线(1,2)都大于VWAP，第3根小于VWAP，防止插针
   bool vwap_bullish = iClose(symbol, period, 1) > vwap_handle.data[1] && 
                       iClose(symbol, period, 2) > vwap_handle.data[2] && 
                       iClose(symbol, period, 3) <= vwap_handle.data[3];
   
   if (vwap_bullish && !ready_buy) {
      ready_buy = true;
      ready_buy_vwap = vwap_handle.data[1]; // 记录进入准备状态时的VWAP价格
      Print("进入准备做多状态，记录VWAP价格: ", ready_buy_vwap);
   }
   
   // 如果处于准备状态，检查是否满足开仓条件
   if (ready_buy) {
      double current_close = iClose(symbol, period, 1); // 使用前一根K线收盘价
      
      // 使用记录的VWAP价格作为基准，检查是否满足开仓条件：收盘价 > 记录的VWAP + 2倍ATR
      bool can_open = current_close > ready_buy_vwap + (atr_value * 2.0);
      
      // 检查是否回到中性区域，取消准备状态
      // 使用记录的VWAP价格作为中性区域的基准
      bool back_to_neutral = current_close <= ready_buy_vwap;
      
      if (back_to_neutral) {
         ready_buy = false;
         ready_buy_vwap = 0.0;
         Print("回到中性区域，取消准备做多状态");
         return false;
      }
      
      return can_open;
   }
   
   return false;
}

bool SuperStrategy::ShouldSell(void) {
   // 检查VWAP下穿信号，进入准备做空状态
   // 要求连续两根K线(1,2)都小于VWAP，第3根大于VWAP，防止插针
   bool vwap_bearish = iClose(symbol, period, 1) < vwap_handle.data[1] && 
                       iClose(symbol, period, 2) < vwap_handle.data[2] && 
                       iClose(symbol, period, 3) >= vwap_handle.data[3];
   
   if (vwap_bearish && !ready_sell) {
      ready_sell = true;
      ready_sell_vwap = vwap_handle.data[1]; // 记录进入准备状态时的VWAP价格
      Print("进入准备做空状态，记录VWAP价格: ", ready_sell_vwap);
   }
   
   // 如果处于准备状态，检查是否满足开仓条件
   if (ready_sell) {
      double current_close = iClose(symbol, period, 1); // 使用前一根K线收盘价
      
      // 使用记录的VWAP价格作为基准，检查是否满足开仓条件：收盘价 < 记录的VWAP - 2倍ATR
      bool can_open = (current_close < ready_sell_vwap - (atr_value * 2.0));
      
      // 检查是否回到中性区域，取消准备状态
      // 使用记录的VWAP价格作为中性区域的基准
      bool back_to_neutral = current_close >= ready_sell_vwap;
      
      if (back_to_neutral) {
         ready_sell = false;
         ready_sell_vwap = 0.0;
         Print("回到中性区域，取消准备做空状态");
         return false;
      }
      
      return can_open;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 开多头仓位                                                        |
//+------------------------------------------------------------------+
void SuperStrategy::OpenBuyPosition(void) {
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double sl = ask - (atr_value * 2.0); // 止损2倍ATR
   
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
      
      // 重置准备状态
      ready_buy = false;
      ready_sell = false;
      ready_buy_vwap = 0.0;
      ready_sell_vwap = 0.0;
      
      Print("开多仓成功 - 价格:", ask, " 止损:", sl, " ATR:", atr_value, " 使用Vegas:", use_vegas_tp);
   }
}

//+------------------------------------------------------------------+
//| 开空头仓位                                                        |
//+------------------------------------------------------------------+
void SuperStrategy::OpenSellPosition(void) {
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double sl = bid + (atr_value * 2.0); // 止损2倍ATR

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
      
      // 重置准备状态
      ready_buy = false;
      ready_sell = false;
      ready_buy_vwap = 0.0;
      ready_sell_vwap = 0.0;
      
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
   
   // SuperTrend翻转检测：无论是否触发止盈，SuperTrend翻转都应该立即平仓
   bool st_reversal_exit = CheckSuperTrendReversal(current_position);
   if (st_reversal_exit) {
      // 立即全部平仓
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
      
      Print("SuperTrend翻转信号触发 - 立即全部平仓");
      return; // 退出函数，不执行后续逻辑
   }

   // 紧急止损：如果还没有触发第一层止盈，但VWAP反转信号出现，立即止损出场
   if (!first_tp_hit) {
      bool emergency_exit = false;
      
      if (current_position == BUY) {
         // 多头紧急止损：检查是否出现强烈的VWAP下穿信号
         // 连续两根K线都小于VWAP，第4根大于VWAP
         bool vwap_bearish = iClose(symbol, period, 1) < vwap_handle.data[1] && 
                            iClose(symbol, period, 2) < vwap_handle.data[2] && 
                            iClose(symbol, period, 4) >= vwap_handle.data[4];
         double current_close = iClose(symbol, period, 1); // 使用前一根K线收盘价
         double vwap_current = vwap_handle.data[0];
         bool price_filter = (current_close <= vwap_current - (atr_value * 2.0));
         emergency_exit = vwap_bearish && price_filter;
         
      } else if (current_position == SELL) {
         // 空头紧急止损：检查是否出现强烈的VWAP上穿信号
         // 连续两根K线都大于VWAP，第4根小于VWAP
         bool vwap_bullish = iClose(symbol, period, 1) > vwap_handle.data[1] && 
                            iClose(symbol, period, 2) > vwap_handle.data[2] && 
                            iClose(symbol, period, 4) <= vwap_handle.data[4];
         double current_close = iClose(symbol, period, 1); // 使用前一根K线收盘价
         double vwap_current = vwap_handle.data[0];
         bool price_filter = (current_close >= vwap_current + (atr_value * 2.0));
         emergency_exit = vwap_bullish && price_filter;
      }
      
      if (emergency_exit) {
         // 立即全部平仓止损
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
         
         Print("紧急止损触发 - VWAP反转信号，全部平仓止损");
         return; // 退出函数，不执行后续止盈逻辑
      }
   }
   
   // 第一层止盈（50%）
   if (!first_tp_hit) {
      bool hit_first_tp = false;
      
      if (current_position == BUY) {
         hit_first_tp = (current_price >= entry_price + (atr_value * 3.0)); // 3倍ATR止盈
      } else if (current_position == SELL) {
         hit_first_tp = (current_price <= entry_price - (atr_value * 3.0)); // 3倍ATR止盈
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
   double distance_required = atr_value * 4.0; // 4倍ATR

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
   double current_close = iClose(symbol, period, 1); // 使用前一根K线收盘价
   double prev_close = iClose(symbol, period, 2);
   double prev2_close = iClose(symbol, period, 3);
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

//+------------------------------------------------------------------+
//| 检查SuperTrend翻转条件                                           |
//+------------------------------------------------------------------+  
bool SuperStrategy::CheckSuperTrendReversal(DIRECTION direction) {
   // 检查是否有足够的数据
   if (!st_handle || ArraySize(st_handle.trend) < 3) {
      return false;
   }
   
   // 获取SuperTrend趋势值
   // trend[1] = 当前K线趋势, trend[2] = 前一根K线趋势
   int current_trend = st_handle.trend[1];  // 当前趋势
   int prev_trend = st_handle.trend[2];     // 前一根趋势
   
   bool trend_reversed = false;
   
   if (direction == BUY) {
      // 多头仓位：检查SuperTrend是否从上升趋势翻转为下降趋势
      // 上升趋势 = 1, 下降趋势 = -1
      trend_reversed = (prev_trend > 0 && current_trend < 0);
      
      if (trend_reversed) {
         Print("SuperTrend翻转检测 - 多头仓位，趋势从上升(", prev_trend, ")翻转为下降(", current_trend, ")");
      }
      
   } else if (direction == SELL) {
      // 空头仓位：检查SuperTrend是否从下降趋势翻转为上升趋势
      trend_reversed = (prev_trend < 0 && current_trend > 0);
      
      if (trend_reversed) {
         Print("SuperTrend翻转检测 - 空头仓位，趋势从下降(", prev_trend, ")翻转为上升(", current_trend, ")");
      }
   }
   
   return trend_reversed;
}
