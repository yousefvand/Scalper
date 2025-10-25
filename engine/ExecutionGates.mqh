#ifndef ENGINE_EXECUTION_GATES_MQH
#define ENGINE_EXECUTION_GATES_MQH

bool Exec_SpreadVsATR_Pass(const string symbol, const double atr, const double maxSpreadToAtr)
{
   if(atr<=0.0) return false;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int spread_points = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   double spread_price = spread_points * point;
   return (spread_price <= maxSpreadToAtr * atr);
}

#endif
