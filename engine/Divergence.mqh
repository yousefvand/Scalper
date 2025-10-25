#ifndef ENGINE_DIVERGENCE_MQH
#define ENGINE_DIVERGENCE_MQH

//+------------------------------------------------------------------+
//| engine/Divergence.mqh                                            |
//| Minimal RSI/Price divergence detector.                           |
//| Finds last two significant swing points (price & RSI) and        |
//| determines bullish/bearish divergence.                           |
//+------------------------------------------------------------------+

class Divergence
{
public:
   struct Result { bool bull; bool bear; };
   // Detect RSI(14) divergence on (symbol, tf) scanning `lookback` bars.
   // - Bullish divergence: price lower low but RSI higher low.
   // - Bearish divergence: price higher high but RSI lower high.
   // Returns both flags; caller decides how to use.
   static Result DetectRSI(const string symbol,
                           const ENUM_TIMEFRAMES tf,
                           const int lookback,
                           const int rsiPeriod = 14)
   {
      Result r; r.bull=false; r.bear=false;
      if(symbol==NULL || symbol=="" || tf<=0 || lookback<20) return r;

      // Collect price & RSI series
      double rsi[];
      ArraySetAsSeries(rsi, true);
      if(!CopyBuffer(iRSI(symbol, tf, rsiPeriod, PRICE_CLOSE), 0, 0, lookback, rsi))
         return r;

      // Helper to find last two swing highs/lows in price & RSI
      int ph1=-1, ph2=-1, pl1=-1, pl2=-1;
      int rh1=-1, rh2=-1, rl1=-1, rl2=-1;

      FindSwings_(symbol, tf, lookback, /*isHigh*/true,  ph1, ph2);
      FindSwings_(symbol, tf, lookback, /*isHigh*/false, pl1, pl2);
      FindSwingsSeries_(rsi, lookback, /*isHigh*/true,  rh1, rh2);
      FindSwingsSeries_(rsi, lookback, /*isHigh*/false, rl1, rl2);

      if(pl1>=0 && pl2>=0 && rl1>=0 && rl2>=0)
      {
         double p1 = iLow(symbol, tf, pl1), p2 = iLow(symbol, tf, pl2);
         double s1 = rsi[rl1],             s2 = rsi[rl2];
         // recent = index 0; pl1 is the more recent swing, pl2 older (since we set series)
         // Bullish divergence: lower low in price, higher low in RSI
         if(p1 < p2 && s1 > s2) r.bull = true;
      }
      if(ph1>=0 && ph2>=0 && rh1>=0 && rh2>=0)
      {
         double p1 = iHigh(symbol, tf, ph1), p2 = iHigh(symbol, tf, ph2);
         double s1 = rsi[rh1],             s2 = rsi[rh2];
         // Bearish divergence: higher high in price, lower high in RSI
         if(p1 > p2 && s1 < s2) r.bear = true;
      }
      return r;
   }

private:
   // Find last two swing highs/lows in PRICE: returns indices (recent first)
   static void FindSwings_(const string symbol, const ENUM_TIMEFRAMES tf,
                           const int lookback, const bool isHigh, int &s1, int &s2)
   {
      s1=-1; s2=-1;
      for(int i=2; i<lookback-2; ++i) // avoid edges
      {
         double a = (isHigh ? iHigh(symbol, tf, i) : iLow(symbol, tf, i));
         double p = (isHigh ? iHigh(symbol, tf, i+1) : iLow(symbol, tf, i+1));
         double n = (isHigh ? iHigh(symbol, tf, i-1) : iLow(symbol, tf, i-1));
         bool swing = isHigh ? (a>p && a>n) : (a<p && a<n);
         if(swing)
         {
            if(s1<0) s1=i;
            else { s2=i; break; }
         }
      }
   }

   // Find last two swing highs/lows in a SERIES array (index 0 = most recent)
   static void FindSwingsSeries_(const double &arr[], const int lookback, const bool isHigh, int &s1, int &s2)
   {
      s1=-1; s2=-1;
      for(int i=2; i<lookback-2; ++i)
      {
         double a = arr[i], p = arr[i+1], n = arr[i-1];
         bool swing = isHigh ? (a>p && a>n) : (a<p && a<n);
         if(swing)
         {
            if(s1<0) s1=i;
            else { s2=i; break; }
         }
      }
   }
};

#endif // ENGINE_DIVERGENCE_MQH
