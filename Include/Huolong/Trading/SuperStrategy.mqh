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
      MAIndicatorHandle*            ema100_handle;        // EMA指标
      VWAPIndicatorHandle*          vwap_handle;
      
      CArrayList<Order*>*           buy_order;
      CArrayList<Order*>*           sell_order;

      int                           buffer_size;
      double                        lots;
      
      void                          SyncOrder(void);
      bool                          ShouldBuy(void);
      bool                          ShouldSell(void);
      void                          ExecuteTrade(DIRECTION direction);
      
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
   
   // 初始化指标
   st_handle = im.GetST(period, buffer_size);
   ema100_handle = im.GetMA(period, 100, buffer_size); 
   vwap_handle = im.GetVWAP(period, buffer_size);
   
   
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
   delete ema100_handle;
   delete vwap_handle;
   
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
   if (!ema100_handle.Refresh(buffer_size)) return;
   if (!vwap_handle.Refresh(buffer_size)) return;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   int bar = iBars(symbol, period);
   
   double close = iClose(symbol, period, 1);
   
}


bool SuperStrategy::ShouldBuy(void) {
   return vwap_handle.data[1] > iClose(symbol, period, 1) && vwap_handle.data[2] <= iClose(symbol, period, 2);
}

bool SuperStrategy::ShouldSell(void) {
   return vwap_handle.data[1] < iClose(symbol, period, 1) && vwap_handle.data[2] >= iClose(symbol, period, 2);
}