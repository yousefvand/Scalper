#ifndef MATH_UTILS_MQH
#define MATH_UTILS_MQH

struct SStops { double sl; double tp; };

inline double BrokerStopsLevelPoints(const string sym)
{
   return (double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
}

inline double SpreadPoints(const string sym)
{
   MqlTick t; if(!SymbolInfoTick(sym,t)) return 0.0;
   const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   return (point>0.0) ? (t.ask - t.bid)/point : 0.0;
}

inline SStops MakeStops(const bool isBuy, const double entry, const double slPts, const double tpPts, const double point)
{
   SStops s;
   if(isBuy){ s.sl=entry - slPts*point; s.tp=entry + tpPts*point; }
   else     { s.sl=entry + slPts*point; s.tp=entry - tpPts*point; }
   return s;
}

inline double NormalizeToTick(const string sym, const double price)
{
   const double step = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   return (step>0.0) ? MathRound(price/step)*step : price;
}

#endif
