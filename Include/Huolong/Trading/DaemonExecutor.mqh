//+------------------------------------------------------------------+
//|                                               DaemonExecutor.mqh |
//|                                                          DingXin |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "DingXin"
#property link      "https://www.mql5.com"

#include <Huolong/Manager/OrderManager.mqh>

class DaemonExecutor {
   private:
      OrderManager*              om;
      
   public:
      DaemonExecutor(OrderManager* om);
      ~DaemonExecutor(void);
      
      void                       Execute(void);
};

DaemonExecutor::DaemonExecutor(OrderManager* _om) : om(_om) {
}

DaemonExecutor::~DaemonExecutor(void) {
}

void DaemonExecutor::Execute(void) {

}