#ifndef ENGINE_VWAP_MQH
#define ENGINE_VWAP_MQH

//+------------------------------------------------------------------+
//| engine/VWAP.mqh                                                  |
//| Simple session VWAP (per symbol/TF) using tick volume.           |
//| VWAP(t) = sum(price_typical * volume) / sum(volume) over session |
//| Session boundary = broker day (00:00 server time).               |
//+------------------------------------------------------------------+

class VWAPCalculator
{
public:
   // Returns current-bar VWAP for (symbol, tf). If insufficient data, returns 0.0.
   // Uses typical price = (H+L+C)/3 and iVolume (tick volume).
   static double SessionVWAP(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      if(symbol==NULL || symbol=="" || tf<=0) return 0.0;

      // Determine session start (00:00 server time of today)
      datetime now = TimeCurrent();
      MqlDateTime st; TimeToStruct(now, st);
      st.hour=0; st.min=0; st.sec=0;
      const datetime sessionStart = StructToTime(st);

      // Find bar index at/after sessionStart
      int bars = Bars(symbol, tf);
      if(bars <= 0) return 0.0;

      // Scan bars forward until bar time < sessionStart (MQL bars are reverse indexed)
      // We'll sum from the first bar whose time >= sessionStart to 0.
      int idxStart = -1;
      for(int i=0;i<bars;++i)
      {
         datetime bt = iTime(symbol, tf, i);
         if(bt <= 0) break;
         if(bt >= sessionStart) { idxStart = i; }
         else break;
      }
      if(idxStart < 0) return 0.0;

      double num=0.0, den=0.0;
      for(int i=idxStart; i>=0; --i)
      {
         double h = iHigh(symbol, tf, i);
         double l = iLow(symbol, tf, i);
         double c = iClose(symbol, tf, i);
         long   v = (long)iVolume(symbol, tf, i);
         if(h==0.0 || l==0.0 || c==0.0 || v<=0) continue;
         const double tp = (h + l + c) / 3.0;
         num += tp * (double)v;
         den += (double)v;
      }
      if(den <= 0.0) return 0.0;
      return num / den;
   }

   // Distance from current price to VWAP in POINTS (absolute).
   static double DistanceToVWAPPts(const string symbol, const ENUM_TIMEFRAMES tf, const bool useBidForShort=true)
   {
      const double vwap = SessionVWAP(symbol, tf);
      if(vwap <= 0.0) return 0.0;

      double px = 0.0;
      // mid-price is fine; using bid/ask optional
      const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(bid<=0.0 || ask<=0.0) return 0.0;
      px = 0.5*(bid+ask);

      double point=0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_POINT, point) || point<=0.0) return 0.0;

      return MathAbs(px - vwap) / point;
   }
};

#endif // ENGINE_VWAP_MQH
