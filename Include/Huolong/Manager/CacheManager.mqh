//+------------------------------------------------------------------+
//|                                                 CacheManager.mqh |
//|                                                          DingXin |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "DingXin"
#property link      "https://www.mql5.com"

#include <Huolong/Trading/Order.mqh>
#include <Utils/Collection/HashMap.mqh>

class CacheManager {
   private:
      CHashMap<string, Order*>         cache;
    
   public:
      CacheManager(void);
      ~CacheManager(void);
      
      bool                           Set(string key, Order* order);
      Order*                         Get(string key);
      bool                           Del(string key);
      bool                           Contains(string key);
      void                           Clear();
};

CacheManager::CacheManager(void) {};

CacheManager::~CacheManager(void) {
   Clear();
};

bool CacheManager::Set(string key, Order* order) {
   Del(key);
   return cache.Add(key, order);
}

Order* CacheManager::Get(string key) {
   Order* order;
   return cache.TryGetValue(key, order) ? order : NULL;
}

bool CacheManager::Del(string key) {
   if (cache.ContainsKey(key)) {
      Order* del = Get(key);
      if (del != NULL) {
         bool r = cache.Remove(key);
         delete del;
         return r;
      }
   }
   return false;
}

bool CacheManager::Contains(string key) {
   return cache.ContainsKey(key);
}

void CacheManager::Clear(void) {
    string keys[];
    Order* values[];
    int copied = cache.CopyTo(keys, values);
    
    for (int i = 0; i < copied; i++) {
        if (CheckPointer(values[i]) == POINTER_DYNAMIC) {
            delete values[i];  
            values[i] = NULL;  
        }
    }
   cache.Clear();
}