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
// #include <Utils/Collection/HashMap.mqh>
// #include <Utils/Collection/HashSet.mqh>
// #include <Utils/Collection/ArrayList.mqh>
#include <Arrays/Array.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayInt.mqh>

#include "Strategy.mqh"
#include "Order.mqh"
#include "TakeProfitManager.mqh"


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
      double                        atr_max;
      double                        atr_min;
      
      // 订单跟踪和止盈管理
      int                           last_signal_bar;        // 最后信号K线
      double                        entry_price;            // 开仓价格
      double                        atr_value;              // 当前ATR值
      DIRECTION                     current_position;       // 当前持仓方向
      bool                          has_position;           // 是否有持仓
      TakeProfitManager*            tp_manager;             // 止盈管理器
      
      // 止盈参数配置
      double                        atr_tp_percentage;      // ATR止盈比例参数
      double                        vegas_total_percentage; // Vegas总比例参数
      
      // ATR倍数参数配置
      double                        entry_atr_multiplier;   // 开仓条件ATR倍数 (默认2.0)
      double                        stop_loss_atr_multiplier; // 止损ATR倍数 (默认2.0)
      double                        take_profit_atr_multiplier; // 止盈ATR倍数 (默认3.0)
      
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
      
      double                        CorrectATR(double atr_value);
      void                          SyncOrder(void);
      bool                          ShouldBuy(void);
      bool                          ShouldSell(void);
      void                          OpenBuyPosition(void);
      void                          OpenSellPosition(void);
      void                          ProcessTakeProfit(void);
      
      // 新的止盈检查方法
      bool                          CheckATR3xCondition(DIRECTION direction);
      bool                          CheckVegas15mCondition(DIRECTION direction);
      bool                          CheckVegas30mCondition(DIRECTION direction);
      bool                          CheckVegas1hCondition(DIRECTION direction);
      bool                          CheckVwapReversalCondition(DIRECTION direction);
      bool                          CheckSuperTrendReversalCondition(DIRECTION direction);
      void                          InitializeTakeProfitTriggers(DIRECTION direction);
      
      // 平仓辅助方法
      void                          CloseAllPositions(string comment);
      void                          ExecutePartialClose(double close_lots, string comment);
   public:
      SuperStrategy(string symbol, ENUM_TIMEFRAMES period, int magic, IndicatorManager* im, 
                    double atr_tp_percentage = 0.4, double vegas_total_percentage = 0.24,
                    double entry_atr_multiplier = 2.0, double stop_loss_atr_multiplier = 2.0, 
                    double take_profit_atr_multiplier = 3.0);
      ~SuperStrategy(void);
      
      void                          Execute(void) override;
};

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
SuperStrategy::SuperStrategy(string _symbol, ENUM_TIMEFRAMES _period, int _magic, IndicatorManager* _im,
                             double _atr_tp_percentage = 0.4, double _vegas_total_percentage = 0.24,
                             double _entry_atr_multiplier = 2.0, double _stop_loss_atr_multiplier = 2.0, 
                             double _take_profit_atr_multiplier = 3.0) 
   : symbol(_symbol), magic(_magic), im(_im), period(_period), 
     atr_tp_percentage(_atr_tp_percentage), vegas_total_percentage(_vegas_total_percentage),
     entry_atr_multiplier(_entry_atr_multiplier), stop_loss_atr_multiplier(_stop_loss_atr_multiplier),
     take_profit_atr_multiplier(_take_profit_atr_multiplier)
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
   current_position = DIRECTION_UNKNOWN;
   has_position = false;
   tp_manager = NULL;
   
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
   lots = config.GetDouble(symbol + ".M15.lots", 0.5);
   atr_max = config.GetDouble(symbol + ".M15.atr_max", 12.0);
   atr_min = config.GetDouble(symbol + ".M15.atr_min", 4.0);
   
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
   if (tp_manager != NULL) delete tp_manager;
   
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

double SuperStrategy::CorrectATR(double atr_input) {
   if (atr_input < atr_min) return atr_min;
   if (atr_input > atr_max) return atr_max;
   return atr_input;
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
      
      // 使用记录的VWAP价格作为基准，检查是否满足开仓条件：收盘价 > 记录的VWAP + entry_atr_multiplier倍ATR
      bool can_open = current_close > ready_buy_vwap + (CorrectATR(atr_value) * entry_atr_multiplier);
      
      // 检查是否回到中性区域，取消准备状态
      // 使用记录的VWAP价格作为中性区域的基准
      bool back_to_neutral = current_close <= ready_buy_vwap;
      
      if (back_to_neutral) {
         ready_buy = false;
         ready_buy_vwap = 0.0;
         Print("回到中性区域，取消准备做多状态");
         return false;
      }
      
      if (atr_max != 0 && atr_value >= atr_max) {
         ready_buy = false;
         ready_buy_vwap = 0.0;
         Print("ATR大于阈值，取消准备做多状态");
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
      
      // 使用记录的VWAP价格作为基准，检查是否满足开仓条件：收盘价 < 记录的VWAP - entry_atr_multiplier倍ATR
      bool can_open = (current_close < ready_sell_vwap - (CorrectATR(atr_value) * entry_atr_multiplier));
      
      // 检查是否回到中性区域，取消准备状态
      // 使用记录的VWAP价格作为中性区域的基准
      bool back_to_neutral = current_close >= ready_sell_vwap;
      
      if (back_to_neutral) {
         ready_sell = false;
         ready_sell_vwap = 0.0;
         Print("回到中性区域，取消准备做空状态");
         return false;
      }
      
      if (atr_max != 0 && atr_value >= atr_max) {
         ready_sell = false;
         ready_sell_vwap = 0.0;
         Print("ATR大于阈值，取消准备做空状态");
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
   double sl = ask - (CorrectATR(atr_value) * stop_loss_atr_multiplier); // 止损使用参数化ATR倍数
   
   Order* order = om.Buy(lots, sl, 0.0, "VWAP_Buy");
   if (order != NULL) {
      buy_order.Add(order);
      
      // 记录开仓信息
      entry_price = ask;
      current_position = BUY;
      
      // 初始化止盈管理器
      if (tp_manager != NULL) delete tp_manager;
      tp_manager = new TakeProfitManager(lots, atr_tp_percentage, vegas_total_percentage);
      
      // 初始化各种止盈触发器
      InitializeTakeProfitTriggers(BUY);
      
      // 重置准备状态
      ready_buy = false;
      ready_sell = false;
      ready_buy_vwap = 0.0;
      ready_sell_vwap = 0.0;
      
      Print("开多仓成功 - 价格:", ask, " 止损:", sl, " ATR:", atr_value);
      if (tp_manager != NULL) tp_manager.PrintStatus();
   }
}

//+------------------------------------------------------------------+
//| 开空头仓位                                                        |
//+------------------------------------------------------------------+
void SuperStrategy::OpenSellPosition(void) {
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double sl = bid + (CorrectATR(atr_value) * stop_loss_atr_multiplier); // 止损使用参数化ATR倍数

   Order* order = om.Sell(lots, sl, 0.0, "VWAP_Sell");
   if (order != NULL) {
      sell_order.Add(order);
      
      // 记录开仓信息
      entry_price = bid;
      current_position = SELL;
      
      // 初始化止盈管理器
      if (tp_manager != NULL) delete tp_manager;
      tp_manager = new TakeProfitManager(lots, atr_tp_percentage, vegas_total_percentage);
      
      // 初始化各种止盈触发器
      InitializeTakeProfitTriggers(SELL);
      
      // 重置准备状态
      ready_buy = false;
      ready_sell = false;
      ready_buy_vwap = 0.0;
      ready_sell_vwap = 0.0;
      
      Print("开空仓成功 - 价格:", bid, " 止损:", sl, " ATR:", atr_value);
      if (tp_manager != NULL) tp_manager.PrintStatus();
   }
}

//+------------------------------------------------------------------+
//| 处理止盈逻辑                                                      |
//+------------------------------------------------------------------+
void SuperStrategy::ProcessTakeProfit(void) {
   if (tp_manager == NULL) return;
   
   // 检查各种止盈触发条件（无序检查）
   
   // 1. SuperTrend翻转检测（最高优先级，立即平仓100%）
   bool supertrend_reversal = CheckSuperTrendReversalCondition(current_position);
   if (!tp_manager.IsTriggered(TP_SUPERTREND_REVERSAL) && supertrend_reversal) {
      Print("SuperTrend翻转触发 - 平仓100%");
      // SuperTrend翻转是100%平仓，直接执行完全平仓
      CloseAllPositions("SuperTrend_Reversal");
      return;
   }
   
   // 2. VWAP反转止盈检测
   bool vwap_reversal = CheckVwapReversalCondition(current_position);
   if (!tp_manager.IsTriggered(TP_VWAP_REVERSAL) && vwap_reversal) {
      Print("VWAP反转止盈触发 - 平仓100%");
      // VWAP反转也是100%平仓
      CloseAllPositions("VWAP_Reversal");
      return;
   }
   
   // 3. 检查其他部分平仓触发器（ATR和Vegas）
   bool need_partial_close = false;
   double total_close_lots = 0.0;
   
   // ATR 3倍止盈检测
   bool atr_3x_condition = CheckATR3xCondition(current_position);
   if (!tp_manager.IsTriggered(TP_ATR_3X) && atr_3x_condition) {
      tp_manager.SetTriggered(TP_ATR_3X, true);
      double atr_close_lots = lots * tp_manager.GetTriggerPercentage(TP_ATR_3X);
      total_close_lots += atr_close_lots;
      need_partial_close = true;
      Print("ATR ", DoubleToString(take_profit_atr_multiplier, 1), "倍止盈触发 - 平仓 ", DoubleToString(atr_close_lots, 2), " 手");
   }
   
   // Vegas多周期止盈检测
   bool vegas_15m_condition = CheckVegas15mCondition(current_position);
   if (!tp_manager.IsTriggered(TP_VEGAS_15M) && vegas_15m_condition) {
      tp_manager.SetTriggered(TP_VEGAS_15M, true);
      double vegas_close_lots = lots * tp_manager.GetTriggerPercentage(TP_VEGAS_15M);
      total_close_lots += vegas_close_lots;
      need_partial_close = true;
      Print("Vegas 15分钟止盈触发 - 平仓 ", DoubleToString(vegas_close_lots, 2), " 手");
   }
   
   bool vegas_30m_condition = CheckVegas30mCondition(current_position);
   if (!tp_manager.IsTriggered(TP_VEGAS_30M) && vegas_30m_condition) {
      tp_manager.SetTriggered(TP_VEGAS_30M, true);
      double vegas_close_lots = lots * tp_manager.GetTriggerPercentage(TP_VEGAS_30M);
      total_close_lots += vegas_close_lots;
      need_partial_close = true;
      Print("Vegas 30分钟止盈触发 - 平仓 ", DoubleToString(vegas_close_lots, 2), " 手");
   }
   
   bool vegas_1h_condition = CheckVegas1hCondition(current_position);
   if (!tp_manager.IsTriggered(TP_VEGAS_1H) && vegas_1h_condition) {
      tp_manager.SetTriggered(TP_VEGAS_1H, true);
      double vegas_close_lots = lots * tp_manager.GetTriggerPercentage(TP_VEGAS_1H);
      total_close_lots += vegas_close_lots;
      need_partial_close = true;
      Print("Vegas 1小时止盈触发 - 平仓 ", DoubleToString(vegas_close_lots, 2), " 手");
   }
   
   // 如果有新的触发器，执行一次部分平仓
   if (need_partial_close && total_close_lots > 0) {
      // 确保不超过原始手数
      total_close_lots = MathMin(total_close_lots, lots);
      ExecutePartialClose(total_close_lots, "TakeProfit_Triggered");
      
      // 检查是否已经全部平仓
      double remaining_lots = tp_manager.GetRemainingLots();
      if (remaining_lots <= 0.01) {
         CloseAllPositions("TakeProfit_Complete");
      }
   }
}

//+------------------------------------------------------------------+
//| 初始化止盈触发器                                                  |
//+------------------------------------------------------------------+
void SuperStrategy::InitializeTakeProfitTriggers(DIRECTION direction) {
   if (tp_manager == NULL) return;
   
   Print("初始化止盈触发器，方向:", EnumToString(direction));
   
   // 重置所有触发器状态
   tp_manager.Reset();
   
   // 根据当前市场条件动态调整Vegas触发器
   tp_manager.AdjustVegasPercentages();
   
   // 打印当前止盈配置
   tp_manager.PrintStatus();
}

//+------------------------------------------------------------------+
//| 执行触发器                                                        |
//+------------------------------------------------------------------+
/*
void SuperStrategy::ExecuteTrigger(ENUM_TP_TRIGGER_TYPE type, const string &comment) {
   // 暂时注释掉所有ExecuteTrigger逻辑
   Print("ExecuteTrigger - 暂时禁用，类型:", type, " 注释:", comment);
}
*/

//+------------------------------------------------------------------+
//| 检查ATR倍数止盈条件                                              |
//+------------------------------------------------------------------+
bool SuperStrategy::CheckATR3xCondition(DIRECTION direction) {
   double current_price = (direction == BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   if (direction == BUY) {
      return (current_price >= entry_price + (atr_value * take_profit_atr_multiplier));
   } else if (direction == SELL) {
      return (current_price <= entry_price - (atr_value * take_profit_atr_multiplier));
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 检查Vegas 15分钟止盈条件                                         |
//+------------------------------------------------------------------+
bool SuperStrategy::CheckVegas15mCondition(DIRECTION direction) {
   double current_price = (direction == BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   double vegas_upper = vegas_m15_handle.Upper(0);
   double vegas_lower = vegas_m15_handle.Lower(0);
   
   if (direction == BUY) {
      return (current_price <= vegas_lower);
   } else if (direction == SELL) {
      return (current_price >= vegas_upper);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 检查Vegas 30分钟止盈条件                                         |
//+------------------------------------------------------------------+
bool SuperStrategy::CheckVegas30mCondition(DIRECTION direction) {
   double current_price = (direction == BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   double vegas_upper = vegas_m30_handle.Upper(0);
   double vegas_lower = vegas_m30_handle.Lower(0);
   
   if (direction == BUY) {
      return (current_price <= vegas_lower);
   } else if (direction == SELL) {
      return (current_price >= vegas_upper);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 检查Vegas 1小时止盈条件                                          |
//+------------------------------------------------------------------+
bool SuperStrategy::CheckVegas1hCondition(DIRECTION direction) {
   double current_price = (direction == BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   double vegas_upper = vegas_m60_handle.Upper(0);
   double vegas_lower = vegas_m60_handle.Lower(0);
   
   if (direction == BUY) {
      return (current_price <= vegas_lower);
   } else if (direction == SELL) {
      return (current_price >= vegas_upper);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 检查VWAP反转条件                                                 |
//+------------------------------------------------------------------+
bool SuperStrategy::CheckVwapReversalCondition(DIRECTION direction) {
   double current_close = iClose(symbol, period, 1); // 使用前一根K线收盘价
   double prev_close = iClose(symbol, period, 2);
   double vwap_current = vwap_handle.data[0];
   double vwap_prev = vwap_handle.data[1];
   
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
bool SuperStrategy::CheckSuperTrendReversalCondition(DIRECTION direction) {
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

//+------------------------------------------------------------------+
//| 平仓所有持仓                                                      |
//+------------------------------------------------------------------+
void SuperStrategy::CloseAllPositions(string comment) {
   // 使用OrderManager的批量平仓方法
   bool buy_closed = om.CloseAllBuy(comment);
   bool sell_closed = om.CloseAllSell(comment);
   
   // 清理订单列表
   for (int i = buy_order.Count() - 1; i >= 0; i--) {
      Order* order;
      if (buy_order.TryGetValue(i, order) && order != NULL) {
         delete order;
         buy_order.RemoveAt(i);
      }
   }
   
   for (int i = sell_order.Count() - 1; i >= 0; i--) {
      Order* order;
      if (sell_order.TryGetValue(i, order) && order != NULL) {
         delete order;
         sell_order.RemoveAt(i);
      }
   }
   
   // 重置持仓状态
   has_position = false;
   current_position = DIRECTION_UNKNOWN;
   entry_price = 0.0;
   
   // 重置止盈管理器
   if (tp_manager != NULL) {
      tp_manager.Reset();
   }
   
   Print("所有持仓已平仓: ", comment, " (买单:", buy_closed, " 卖单:", sell_closed, ")");
}

//+------------------------------------------------------------------+
//| 执行部分平仓                                                      |
//+------------------------------------------------------------------+
void SuperStrategy::ExecutePartialClose(double close_lots, string comment) {
   if (close_lots <= 0.0) return;
   
   // 优化的部分平仓逻辑：
   // 1. 策略确保买单和卖单不会同时存在
   // 2. 每个方向最多只有一个订单
   // 3. 直接使用close_lots，无需循环计算总手数
   
   Order* order = NULL;
   
   // 处理买单
   if (buy_order.Count() > 0 && buy_order.TryGetValue(0, order) && order != NULL) {
      om.CloseBuy(order.ticket, close_lots);
      
      // 如果平仓手数大于等于订单手数，清理订单
      if (close_lots >= lots) {
         delete order;
         buy_order.RemoveAt(0);
      }
      Print("买单部分平仓: ", DoubleToString(close_lots, 2), " 手 - ", comment);
      return;
   }
   
   // 处理卖单
   if (sell_order.Count() > 0 && sell_order.TryGetValue(0, order) && order != NULL) {
      om.CloseSell(order.ticket, close_lots);
      
      // 如果平仓手数大于等于订单手数，清理订单
      if (close_lots >= lots) {
         delete order;
         sell_order.RemoveAt(0);
      }
      Print("卖单部分平仓: ", DoubleToString(close_lots, 2), " 手 - ", comment);
      return;
   }
}
