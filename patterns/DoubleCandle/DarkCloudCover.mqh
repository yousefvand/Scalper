#ifndef PATTERNS_DARKCLOUDCOVER_MQH
#define PATTERNS_DARKCLOUDCOVER_MQH

// DarkCloudCover.mqh
// Bearish "Dark Cloud Cover" using the OOP strategy base (PatternBase.mqh).
// Definition: after a strong bullish candle, the next candle opens above the prior
// high (gap-up preferred) and closes deep into the prior real body but (classically)
// not below the prior open (i.e., not a full engulfing).
//
// Direction returned: PatternBearish.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class DarkCloudCoverParams : public IPatternParams
{
public:
   // Strength of the first (bullish) candle
   double minFirstBodyPctTR;     // body/TR of 1st bar must be >= (e.g., 0.50)
   double minFirstBodyPoints;    // absolute min body size (points), 0 = disabled

   // Second (bearish) candle body size requirement (keeps it meaningful)
   double minSecondBodyPctTR;    // body/TR of 2nd bar must be >= (e.g., 0.35)
   double minSecondBodyPoints;   // absolute min body size (points), 0 = disabled

   // Gap and placement
   bool   requireGapUp;          // strict classic gap-up at the open of the 2nd bar
   bool   allowOpenAboveCloseIfNoGap; // if no strict gap, allow open >= first close

   // Penetration of 2nd close into the first body (from top down, 0..1)
   double minPenetrationPct;     // e.g., 0.50 ⇒ close below 1st body midpoint

   // Engulfing rule (classic dark cloud is NOT a full engulfing)
   bool   forbidFullEngulf;      // true ⇒ close of 2nd must stay ABOVE first open

   // Optional context: prefer upswing into the pattern (reversal bias)
   bool   preferUpswingContext;
   int    upswingLookback;

   DarkCloudCoverParams()
   {
      minFirstBodyPctTR       = 0.50;
      minFirstBodyPoints      = 0.0;
      minSecondBodyPctTR      = 0.35;
      minSecondBodyPoints     = 0.0;
      requireGapUp            = false;
      allowOpenAboveCloseIfNoGap = true;
      minPenetrationPct       = 0.50;
      forbidFullEngulf        = true;
      preferUpswingContext    = false;
      upswingLookback         = 3;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new DarkCloudCoverParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "DarkCloudCoverParams{minFirstBodyPctTR=%.2f, minFirstBodyPoints=%.2f, "
         "minSecondBodyPctTR=%.2f, minSecondBodyPoints=%.2f, requireGapUp=%s, allowOpenAboveCloseIfNoGap=%s, "
         "minPenetrationPct=%.2f, forbidFullEngulf=%s, preferUpswingContext=%s, upswingLookback=%d}",
         minFirstBodyPctTR, minFirstBodyPoints,
         minSecondBodyPctTR, minSecondBodyPoints,
         (requireGapUp ? "true":"false"),
         (allowOpenAboveCloseIfNoGap ? "true":"false"),
         minPenetrationPct,
         (forbidFullEngulf ? "true":"false"),
         (preferUpswingContext ? "true":"false"),
         upswingLookback
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const DarkCloudCoverParams* o = (const DarkCloudCoverParams*)other;
      return MathAbs(minFirstBodyPctTR - o.minFirstBodyPctTR) < 1e-9
          && MathAbs(minFirstBodyPoints - o.minFirstBodyPoints) < 1e-9
          && MathAbs(minSecondBodyPctTR - o.minSecondBodyPctTR) < 1e-9
          && MathAbs(minSecondBodyPoints - o.minSecondBodyPoints) < 1e-9
          && requireGapUp == o.requireGapUp
          && allowOpenAboveCloseIfNoGap == o.allowOpenAboveCloseIfNoGap
          && MathAbs(minPenetrationPct - o.minPenetrationPct) < 1e-9
          && forbidFullEngulf == o.forbidFullEngulf
          && preferUpswingContext == o.preferUpswingContext
          && upswingLookback == o.upswingLookback;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class DarkCloudCoverDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "DarkCloudCover";
      d.category = PatternDoubleCandle;
      d.legs     = 2;
      return d;
   }

   DarkCloudCoverDetector()
   : AbstractPatternDetector(MakeDescriptor(), new DarkCloudCoverParams()) {}

   DarkCloudCoverDetector(const DarkCloudCoverParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   DarkCloudCoverDetector(const DarkCloudCoverDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new DarkCloudCoverDetector(*this); }

protected:
   // Helpers
   static inline double BodySize(const MqlRates &b) { return MathAbs(b.close - b.open); }
   static inline double TrueRange(const MqlRates &b){ return (b.high - b.low); }
   static inline bool   IsBull(const MqlRates &b)   { return b.close > b.open; }
   static inline bool   IsBear(const MqlRates &b)   { return b.close < b.open; }

   static bool HasRecentUpswing(const string symbol,
                                const ENUM_TIMEFRAMES timeframe,
                                const int afterShift,
                                const int lookback,
                                const IMarketData &md)
   {
      if(lookback <= 0) return true;
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, afterShift, lookback+1, r))
         return false;
      int rises=0;
      for(int i=1;i<=lookback;i++)
         if(r[i-1].close < r[i].close) rises++;
      return (rises > lookback/2);
   }

   // Scoring blend (0..100): strong first bull, deep penetration, meaningful 2nd body, gap bonus.
   static double ScoreDCC(const double firstBodyPctTR,
                          const double secondBodyPctTR,
                          const double penetrationPct,  // achieved 0..1
                          const bool   hadGap,
                          const bool   hadUpswing)
   {
      double strongFirst = MathMin(1.0, MathMax(0.0, (firstBodyPctTR - 0.3)/0.7)); // 0 at 0.3, 1 at 1.0
      double strongSecond= MathMin(1.0, MathMax(0.0, (secondBodyPctTR - 0.2)/0.8));
      double deepPen     = MathMin(1.0, MathMax(0.0, penetrationPct)); // 0..1
      double bonus       = (hadGap?0.08:0.0) + (hadUpswing?0.07:0.0);

      double w1=0.30, w2=0.25, w3=0.45;
      double score01 = w1*strongFirst + w2*strongSecond + w3*deepPen + bonus;
      if(score01>1.0) score01=1.0;
      if(score01<0.0) score01=0.0;
      return score01*100.0;
   }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const DarkCloudCoverParams* e = (const DarkCloudCoverParams*)p;
      if(e.minFirstBodyPctTR < 0.0 || e.minFirstBodyPctTR > 1.0) return false;
      if(e.minSecondBodyPctTR < 0.0 || e.minSecondBodyPctTR > 1.0) return false;
      if(e.minPenetrationPct < 0.0 || e.minPenetrationPct > 1.0) return false;
      if(e.minFirstBodyPoints < 0.0 || e.minSecondBodyPoints < 0.0) return false;
      if(e.upswingLookback < 0) return false;
      return true;
   }

   // Core detection
   virtual bool DetectImpl(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift,
                           const IMarketData &md,
                           PatternSignal &out) const
   {
      const DarkCloudCoverParams* Pptr = (const DarkCloudCoverParams*)m_params;
      if(Pptr==NULL) return false;
      DarkCloudCoverParams P = *Pptr;

      // Need two bars: current [shift] (bear), previous [shift+1] (bull)
      MqlRates rr[];
      if(!md.GetRates(symbol, timeframe, shift, 2, rr))
         return false;

      const MqlRates c0 = rr[0]; // current (bearish)
      const MqlRates c1 = rr[1]; // previous (bullish)

      // Colors
      if(!IsBull(c1)) return false;
      if(!IsBear(c0)) return false;

      // Sizes
      const double b1 = BodySize(c1);
      const double tr1= TrueRange(c1);
      const double b0 = BodySize(c0);
      const double tr0= TrueRange(c0);

      if(tr1<=0.0 || tr0<=0.0 || b1<=0.0 || b0<=0.0) return false;
      if(P.minFirstBodyPoints  > 0.0 && b1 < P.minFirstBodyPoints)  return false;
      if(P.minSecondBodyPoints > 0.0 && b0 < P.minSecondBodyPoints) return false;

      const double firstBodyPctTR  = b1 / tr1;
      const double secondBodyPctTR = b0 / tr0;
      if(firstBodyPctTR  < P.minFirstBodyPctTR)  return false;
      if(secondBodyPctTR < P.minSecondBodyPctTR) return false;

      // Gap / placement checks
      bool hadGap = false;
      if(P.requireGapUp)
      {
         if(c0.open > c1.high) hadGap = true; else return false;
      }
      else
      {
         if(P.allowOpenAboveCloseIfNoGap)
         {
            if(!(c0.open >= c1.close)) return false; // at least open at/above prior close
         }
         // no strict gap; hadGap remains false
      }

      // Penetration: close of c0 must be below a threshold inside c1 body
      const double bodyLo = MathMin(c1.open, c1.close); // for bull: open
      const double bodyHi = MathMax(c1.open, c1.close); // for bull: close
      const double bodySpan = MathMax(1e-12, bodyHi - bodyLo);

      // Required close <= bodyHi - minPenetrationPct * span
      const double requiredClose = bodyHi - P.minPenetrationPct * bodySpan;
      if(c0.close > requiredClose) return false;

      // Not a full engulfing (classic)
      if(P.forbidFullEngulf)
      {
         if(c0.close <= bodyLo) return false; // closing below first open ⇒ engulfing, reject
      }

      // Optional context (prior upswing)
      bool hadUp = true;
      if(P.preferUpswingContext)
         hadUp = HasRecentUpswing(symbol, timeframe, shift+2, P.upswingLookback, md);
      if(!hadUp && P.preferUpswingContext) return false;

      // Penetration actually achieved (0..1), for scoring
      const double achievedPen = MathMin(1.0, MathMax(0.0, (bodyHi - c0.close) / bodySpan));

      // Score & fill
      const double score = ScoreDCC(firstBodyPctTR, secondBodyPctTR, achievedPen, hadGap, hadUp);

      out.direction  = PatternBearish;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = hadGap ? "dark_cloud_gap" : "dark_cloud";

      return true;
   }
};

#endif // PATTERNS_DARKCLOUDCOVER_MQH
