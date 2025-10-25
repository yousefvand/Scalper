#ifndef ENGINE_MTFCONFIRM_MQH
#define ENGINE_MTFCONFIRM_MQH

//+------------------------------------------------------------------+
//| engine/MTFConfirm.mqh                                            |
//| Light-weight higher-timeframe bias check via close slope.        |
//| Returns +1 (up bias), -1 (down bias), 0 (flat/unknown).          |
//+------------------------------------------------------------------+

class MTFConfirm
{
public:
   // Compute sign of linear slope over N bars of CLOSE on (symbol, tf).
   // +1 if slope > 0, -1 if slope < 0, 0 if insufficient data or near-flat.
   static int SlopeSign(const string symbol, const ENUM_TIMEFRAMES tf, const int lookback)
   {
      if(symbol==NULL || symbol=="" || tf<=0 || lookback<2) return 0;

      // Ensure enough bars
      int bars = Bars(symbol, tf);
      if(bars < lookback) return 0;

      // Simple linear regression slope over x=0..(N-1)
      double sumx=0.0, sumy=0.0, sumxy=0.0, sumxx=0.0;
      for(int i=0;i<lookback;i++)
      {
         double y = iClose(symbol, tf, i);
         if(y<=0.0) return 0;
         double x = (double)i;
         sumx  += x;
         sumy  += y;
         sumxy += x*y;
         sumxx += x*x;
      }
      double n = (double)lookback;
      double denom = (n*sumxx - sumx*sumx);
      if(denom==0.0) return 0;
      double slope = (n*sumxy - sumx*sumy) / denom;

      // Tolerance: require slope magnitude to exceed 1e-10 * price to avoid noise
      double ref = iClose(symbol, tf, 0);
      double tol = (ref>0.0 ? ref*1e-10 : 1e-10);
      if(slope >  tol) return +1;
      if(slope < -tol) return -1;
      return 0;
   }

   // Require MTF slope agrees with trade side.
   // Returns true if confirmed or the signal is flat (0) => treat as neutral (pass).
   static bool ConfirmDirection(const string symbol,
                                const ENUM_TIMEFRAMES tf,
                                const int lookback,
                                const bool isBuy)
   {
      int s = SlopeSign(symbol, tf, lookback);
      if(s==0) return true; // neutral: don't block
      return (isBuy ? (s>0) : (s<0));
   }
};

#endif // ENGINE_MTFCONFIRM_MQH
