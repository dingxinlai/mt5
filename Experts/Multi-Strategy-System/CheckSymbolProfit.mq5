//+------------------------------------------------------------------+
//|                                            CheckSymbolProfit.mq5 |
//|                              Spencer Luck and Thiyagan Marimuthu |
//+------------------------------------------------------------------+

double CheckSymbolProfit (string ProfitSymbol, int OrderType){

   double ProfitSymbolExposure = 0;
   int System1Count = 0;
   int System2Count = 0;
   int System3Count = 0;
   int System4Count = 0;
   int System5Count = 0;
   int System6Count = 0;
   int System7Count = 0;
   int System8Count = 0;
   
      for(int i = PositionsTotal()-1; i>=0; i--)
      {
         string CurrencyPair = PositionGetSymbol(i);
         string CurrentSymbolProfit = SymbolInfoString(CurrencyPair,SYMBOL_CURRENCY_PROFIT);

         
         if(PositionGetInteger(POSITION_TYPE)==OrderType)
         {
            if(CurrentSymbolProfit==ProfitSymbol)
            {
            
               //System 1
               if(PositionGetInteger(POSITION_MAGIC)==001)
               {
                 System1Count += 1;
               }
               //System 2
               if(PositionGetInteger(POSITION_MAGIC)==002)
               {
                 System2Count += 1;
               }
               //System 3
               if(PositionGetInteger(POSITION_MAGIC)==003)
               {
                 System3Count += 1;
               }
               //System 4
               if(PositionGetInteger(POSITION_MAGIC)==004)
               {
                 System4Count += 1;
               }
               //System 5
               if(PositionGetInteger(POSITION_MAGIC)==005)
               {
                 System5Count += 1;
               }
               //System 6
               if(PositionGetInteger(POSITION_MAGIC)==006)
               {
                 System6Count += 1;
               }
               //System 7
               if(PositionGetInteger(POSITION_MAGIC)==007)
               {
                 System7Count += 1;
               }
               //System 8
               if(PositionGetInteger(POSITION_MAGIC)==008)
               {
                 System7Count += 1;
               }
               
            }
         
         }
         
         
         
         
         
      }   
         
   // Increment preset risk exposures retrieved from each system      
   if(System1Count==2)
   {
      ProfitSymbolExposure+=0.015;
   }
   
   if(System2Count==1)
   {
      ProfitSymbolExposure+=0.01;
   }
   
   if(System3Count==2)
   {
      ProfitSymbolExposure+=0.015;
   }
   
   if(System4Count==1)
   {
      ProfitSymbolExposure+=0.01;
   }
   
   if(System5Count==2)
   {
      ProfitSymbolExposure+=0.015;
   }
   
   if(System6Count==1)
   {
      ProfitSymbolExposure+=0.01;
   }
   
   if(System7Count==1)
   {
      ProfitSymbolExposure+=0.01;
   }
   
   if(System8Count==1)
   {
      ProfitSymbolExposure+=0.01;
   }
   
   // Returns the total volume exposed to the profit symbol currency
   return ProfitSymbolExposure;
   
}
