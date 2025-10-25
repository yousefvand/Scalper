#ifndef PATTERNS_THREEBLACKCROWS_MQH
#define PATTERNS_THREEBLACKCROWS_MQH

// ThreeBlackCrows.mqh
// Bearish "Three Black Crows" implemented with the OOP strategy base.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class ThreeBlackCrowsParams : public IPatternParams
{
public:
   // Minimum body strength for each crow relative to its true range (0..1)
   double minBodyPctTR;          // e.g., 0.55 means body >= 55% of TR
   // Max lower wick proportion relative to TR (close should be near the low)
   double maxLowerWickPctTR;     // e.g., 0.20
   // Max upper wick proportion relative to TR (long real bodies, not long wicks)
   double maxUpperWickPctTR;     // e.g., 0.35
   // Require each open to be inside previous candle's real body (classic)
   bool   requireOpenInsidePrevBody;
   // Require strictly lower closes each bar (c2 > c1 > c0)
   bool   requireProgressivelyLowerCloses;
   // Optional: simple uptrend context (rising closes before the pattern)
   bool   requireUpswingContext;
   int    upswingLookback;       // e.g., 3 bars before the first crow

   // Absolute minimum body size (points) to avoid micro candles
   double minBodyPoints;

   ThreeBlackCrowsParams()
   {
      minBodyPctTR                 = 0.55;
      maxLowerWickPctTR            = 0.20;
      maxUpperWickPctTR            = 0.35;
      requireOpenInsidePrevBody    = true;
      requireProgressivelyLowerCloses = true;
      requireUpswingContext        = false;
      upswingLookback              = 3;
      minBodyPoints                = 0.0;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new ThreeBlackCrowsParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "ThreeBlackCrowsParams{minBodyPctTR=%.2f, maxLowerWickPctTR=%.2f, maxUpperWickPctTR=%.2f, "
         "requireOpenInsidePrevBody=%s, requireProgressivelyLowerCloses=%s, requireUpswingContext=%s, "
         "upswingLookback=%d, minBodyPoints=%.2f}",
         minBodyPctTR, maxLowerWickPctTR, maxUpperWickPctTR,
         (requireOpenInsidePrevBody ? "true":"false"),
         (requireProgressivelyLowerCloses ? "true":"false"),
         (requireUpswingContext ? "true":"false"),
         upswingLookback, minBodyPoints
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const ThreeBlackCrowsParams* o = (const ThreeBlackCrowsParams*)other;
      return MathAbs(minBodyPctTR - o.minBodyPctTR) < 1e-9
          && MathAbs(maxLowerWickPctTR - o.maxLowerWickPctTR) < 1e-9
          && MathAbs(maxUpperWickPctTR - o.maxUpperWickPctTR) < 1e-9
          && requireOpenInsidePrevBody == o.requireOpenInsidePrevBody
          && requireProgressivelyLowerCloses == o.requireProgressivelyLowerCloses
          && requireUpswingContext == o.requireUpswingContext
          && upswingLookback == o.upswingLookback
          && MathAbs(minBodyPoints - o.minBodyPoints) < 1e-9;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class ThreeBlackCrowsDetector : public AbstractPatternDetector
{
public:
   // Descriptor
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "ThreeBlackCrows";
      d.category = PatternTripleCandle;
      d.legs     = 3;
      return d;
   }

   // Ctors
   ThreeBlackCrowsDetector()
   : AbstractPatternDetector(MakeDescriptor(), new ThreeBlackCrowsParams()) {}

   ThreeBlackCrowsDetector(const ThreeBlackCrowsParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   ThreeBlackCrowsDetector(const ThreeBlackCrowsDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new ThreeBlackCrowsDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b)   { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b)  { return (b.high - b.low); }
   static double UpperWick(const MqlRates &b)  { return b.high - MathMax(b.open, b.close); }
   static double LowerWick(const MqlRates &b)  { return MathMin(b.open, b.close) - b.low; }
   static bool   IsBear(const MqlRates &b)     { return b.close < b.open; }
   static bool   IsBull(const MqlRates &b)     { return b.close > b.open; }

   static bool OpenInsidePrevBody(const MqlRates &cur, const MqlRates &prev, const bool inclusive=true)
   {
      const double prevLo = MathMin(prev.open, prev.close);
      const double prevHi = MathMax(prev.open, prev.close);
      if(inclusive) return (cur.open >= prevLo && cur.open <= prevHi);
      return (cur.open > prevLo && cur.open < prevHi);
   }

   // Simple upswing check: count rising closes over lookback bars BEFORE c2
   static bool HasRecentUpswing(const string symbol,
                                const ENUM_TIMEFRAMES timeframe,
                                const int firstCrowShiftPlusOne, // shift index right after first crow
                                const int lookback,
                                const IMarketData &md)
   {
      if(lookback <= 0) return true;
      // We want bars AFTER c2 (older bars), so start at firstCrowShiftPlusOne and fetch 'lookback+1'
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, firstCrowShiftPlusOne, lookback+1, r))
         return false;
      int rises = 0;
      for(int i=1; i<=lookback; ++i)
      {
         if(r[i-1].close < r[i].close) rises++;
      }
      return (rises > lookback/2); // majority rising closes
   }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const ThreeBlackCrowsParams* e = (const ThreeBlackCrowsParams*)p;
      if(e.minBodyPctTR < 0.0 || e.minBodyPctTR > 1.0) return false;
      if(e.maxLowerWickPctTR < 0.0 || e.maxLowerWickPctTR > 1.0) return false;
      if(e.maxUpperWickPctTR < 0.0 || e.maxUpperWickPctTR > 1.0) return false;
      if(e.upswingLookback < 0) return false;
      if(e.minBodyPoints < 0.0) return false;
      return true;
   }

   // Score blend: body strength, closes near lows, sequencing
   static double ScoreCrows(const double avgBodyPctTR,
                            const double avgCloseNearLow,  // 0..1 (1 = very near low)
                            const double sequencing)       // 0..1 (1 = strong lower-closes progression)
   {
      double wBody = 0.45, wNearLow = 0.35, wSeq = 0.20;
      double s = wBody*avgBodyPctTR + wNearLow*avgCloseNearLow + wSeq*sequencing;
      if(s < 0.0) s = 0.0;
      if(s > 1.0) s = 1.0;
      return s * 100.0;
   }

   virtual bool DetectImpl(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift,
                           const IMarketData &md,
                           PatternSignal &out) const
   {
      const ThreeBlackCrowsParams* P = (const ThreeBlackCrowsParams*)m_params;
      if(P==NULL) return false;

      // Need three consecutive bearish bars: c2 (oldest), c1, c0 (current)
      MqlRates rr[];
      if(!md.GetRates(symbol, timeframe, shift, 3, rr))
         return false;

      const MqlRates c0 = rr[0];
      const MqlRates c1 = rr[1];
      const MqlRates c2 = rr[2];

      // Optional context: prior upswing before c2
      if(P.requireUpswingContext)
      {
         // Bars right after c2 are at shift+3 and further
         if(!HasRecentUpswing(symbol, timeframe, shift+3, P.upswingLookback, md))
            return false;
      }

      // All three must be bearish
      if(!IsBear(c2) || !IsBear(c1) || !IsBear(c0))
         return false;

      // Compute TR, bodies, wicks
      const double tr2 = TrueRange(c2), tr1 = TrueRange(c1), tr0 = TrueRange(c0);
      const double b2  = BodySize(c2),  b1  = BodySize(c1),  b0  = BodySize(c0);
      if(tr2<=0.0 || tr1<=0.0 || tr0<=0.0) return false;
      if(b2<=0.0 || b1<=0.0 || b0<=0.0) return false;

      if(P.minBodyPoints > 0.0 && (b2 < P.minBodyPoints || b1 < P.minBodyPoints || b0 < P.minBodyPoints))
         return false;

      // Body strength per candle
      const double s2 = b2 / tr2;
      const double s1 = b1 / tr1;
      const double s0 = b0 / tr0;

      if(s2 < P.minBodyPctTR || s1 < P.minBodyPctTR || s0 < P.minBodyPctTR)
         return false;

      // Wick constraints
      const double lw2 = LowerWick(c2)/tr2, lw1 = LowerWick(c1)/tr1, lw0 = LowerWick(c0)/tr0;
      const double uw2 = UpperWick(c2)/tr2, uw1 = UpperWick(c1)/tr1, uw0 = UpperWick(c0)/tr0;

      if(lw2 > P.maxLowerWickPctTR || lw1 > P.maxLowerWickPctTR || lw0 > P.maxLowerWickPctTR)
         return false;
      if(uw2 > P.maxUpperWickPctTR || uw1 > P.maxUpperWickPctTR || uw0 > P.maxUpperWickPctTR)
         return false;

      // Opens within previous real body?
      if(P.requireOpenInsidePrevBody)
      {
         if(!OpenInsidePrevBody(c1, c2)) return false;
         if(!OpenInsidePrevBody(c0, c1)) return false;
      }

      // Progressively lower closes?
      if(P.requireProgressivelyLowerCloses)
      {
         if(!(c1.close < c2.close && c0.close < c1.close))
            return false;
      }

      // Build score
      const double avgBodyPctTR   = (s2 + s1 + s0) / 3.0; // already 0..1-ish
      // Near low metric: 1 - (lower wick / TR) for each, averaged
      const double nl2 = 1.0 - MathMin(1.0, lw2);
      const double nl1 = 1.0 - MathMin(1.0, lw1);
      const double nl0 = 1.0 - MathMin(1.0, lw0);
      const double avgCloseNearLow = MathMax(0.0, (nl2 + nl1 + nl0) / 3.0);

      // Sequencing strength: measure how much lower the closes are relative to c2->c1 and c1->c0
      double seq = 0.0;
      const double drop1 = (c2.close - c1.close);
      const double drop2 = (c1.close - c0.close);
      if(drop1 > 0 && drop2 > 0)
      {
         // Normalize by average TR to 0..1
         const double avgTR = (tr2 + tr1 + tr0) / 3.0;
         if(avgTR > 0.0)
         {
            seq = MathMin(1.0, (drop1 + drop2) / (2.0 * avgTR));
         }
      }

      const double score = ScoreCrows(avgBodyPctTR, avgCloseNearLow, seq);

      // Fill signal
      out.direction  = PatternBearish;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = "three_black_crows";

      return true;
   }
};

#endif // PATTERNS_THREEBLACKCROWS_MQH
