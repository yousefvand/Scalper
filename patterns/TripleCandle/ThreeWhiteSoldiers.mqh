#ifndef PATTERNS_THREEWHITESOLDIERS_MQH
#define PATTERNS_THREEWHITESOLDIERS_MQH

// ThreeWhiteSoldiers.mqh
// Bullish "Three White Soldiers" implemented with the OOP strategy base.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class ThreeWhiteSoldiersParams : public IPatternParams
{
public:
   // Minimum body strength for each soldier relative to its true range (0..1)
   double minBodyPctTR;              // e.g., 0.55 means body >= 55% of TR
   // Max upper wick proportion relative to TR (close should be near the high)
   double maxUpperWickPctTR;         // e.g., 0.20
   // Max lower wick proportion relative to TR (prefer real bodies, not long lower wicks)
   double maxLowerWickPctTR;         // e.g., 0.35
   // Require each open to be inside previous candle's real body (classic)
   bool   requireOpenInsidePrevBody;
   // Require strictly higher closes each bar (c2 < c1 < c0)
   bool   requireProgressivelyHigherCloses;
   // Optional: simple downtrend context (falling closes before the pattern)
   bool   requireDownswingContext;
   int    downswingLookback;         // e.g., 3 bars before the first soldier

   // Absolute minimum body size (points) to avoid micro candles
   double minBodyPoints;

   ThreeWhiteSoldiersParams()
   {
      minBodyPctTR                    = 0.55;
      maxUpperWickPctTR               = 0.20;
      maxLowerWickPctTR               = 0.35;
      requireOpenInsidePrevBody       = true;
      requireProgressivelyHigherCloses= true;
      requireDownswingContext         = false;
      downswingLookback               = 3;
      minBodyPoints                   = 0.0;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new ThreeWhiteSoldiersParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "ThreeWhiteSoldiersParams{minBodyPctTR=%.2f, maxUpperWickPctTR=%.2f, maxLowerWickPctTR=%.2f, "
         "requireOpenInsidePrevBody=%s, requireProgressivelyHigherCloses=%s, requireDownswingContext=%s, "
         "downswingLookback=%d, minBodyPoints=%.2f}",
         minBodyPctTR, maxUpperWickPctTR, maxLowerWickPctTR,
         (requireOpenInsidePrevBody ? "true":"false"),
         (requireProgressivelyHigherCloses ? "true":"false"),
         (requireDownswingContext ? "true":"false"),
         downswingLookback, minBodyPoints
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const ThreeWhiteSoldiersParams* o = (const ThreeWhiteSoldiersParams*)other;
      return MathAbs(minBodyPctTR - o.minBodyPctTR) < 1e-9
          && MathAbs(maxUpperWickPctTR - o.maxUpperWickPctTR) < 1e-9
          && MathAbs(maxLowerWickPctTR - o.maxLowerWickPctTR) < 1e-9
          && requireOpenInsidePrevBody == o.requireOpenInsidePrevBody
          && requireProgressivelyHigherCloses == o.requireProgressivelyHigherCloses
          && requireDownswingContext == o.requireDownswingContext
          && downswingLookback == o.downswingLookback
          && MathAbs(minBodyPoints - o.minBodyPoints) < 1e-9;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class ThreeWhiteSoldiersDetector : public AbstractPatternDetector
{
public:
   // Descriptor
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "ThreeWhiteSoldiers";
      d.category = PatternTripleCandle;
      d.legs     = 3;
      return d;
   }

   // Ctors
   ThreeWhiteSoldiersDetector()
   : AbstractPatternDetector(MakeDescriptor(), new ThreeWhiteSoldiersParams()) {}

   ThreeWhiteSoldiersDetector(const ThreeWhiteSoldiersParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   ThreeWhiteSoldiersDetector(const ThreeWhiteSoldiersDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new ThreeWhiteSoldiersDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b)   { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b)  { return (b.high - b.low); }
   static double UpperWick(const MqlRates &b)  { return b.high - MathMax(b.open, b.close); }
   static double LowerWick(const MqlRates &b)  { return MathMin(b.open, b.close) - b.low; }
   static bool   IsBull(const MqlRates &b)     { return b.close > b.open; }
   static bool   IsBear(const MqlRates &b)     { return b.close < b.open; }

   static bool OpenInsidePrevBody(const MqlRates &cur, const MqlRates &prev, const bool inclusive=true)
   {
      const double prevLo = MathMin(prev.open, prev.close);
      const double prevHi = MathMax(prev.open, prev.close);
      if(inclusive) return (cur.open >= prevLo && cur.open <= prevHi);
      return (cur.open > prevLo && cur.open < prevHi);
   }

   // Simple downswing check: count falling closes over lookback bars BEFORE c2
   static bool HasRecentDownswing(const string symbol,
                                  const ENUM_TIMEFRAMES timeframe,
                                  const int firstSoldierShiftPlusOne, // shift index right after first soldier
                                  const int lookback,
                                  const IMarketData &md)
   {
      if(lookback <= 0) return true;
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, firstSoldierShiftPlusOne, lookback+1, r))
         return false;
      int falls = 0;
      for(int i=1; i<=lookback; ++i)
      {
         if(r[i-1].close > r[i].close) falls++;
      }
      return (falls > lookback/2); // majority falling closes
   }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const ThreeWhiteSoldiersParams* e = (const ThreeWhiteSoldiersParams*)p;
      if(e.minBodyPctTR < 0.0 || e.minBodyPctTR > 1.0) return false;
      if(e.maxUpperWickPctTR < 0.0 || e.maxUpperWickPctTR > 1.0) return false;
      if(e.maxLowerWickPctTR < 0.0 || e.maxLowerWickPctTR > 1.0) return false;
      if(e.downswingLookback < 0) return false;
      if(e.minBodyPoints < 0.0) return false;
      return true;
   }

   // Score blend: body strength, closes near highs, sequencing
   static double ScoreSoldiers(const double avgBodyPctTR,
                               const double avgCloseNearHigh, // 0..1 (1 = very near high)
                               const double sequencing)        // 0..1 (1 = strong higher-closes progression)
   {
      double wBody = 0.45, wNearHigh = 0.35, wSeq = 0.20;
      double s = wBody*avgBodyPctTR + wNearHigh*avgCloseNearHigh + wSeq*sequencing;
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
      const ThreeWhiteSoldiersParams* P = (const ThreeWhiteSoldiersParams*)m_params;
      if(P==NULL) return false;

      // Need three consecutive bullish bars: c2 (oldest), c1, c0 (current)
      MqlRates rr[];
      if(!md.GetRates(symbol, timeframe, shift, 3, rr))
         return false;

      const MqlRates c0 = rr[0];
      const MqlRates c1 = rr[1];
      const MqlRates c2 = rr[2];

      // Optional context: prior downswing before c2
      if(P.requireDownswingContext)
      {
         // Bars right after c2 are at shift+3 and further
         if(!HasRecentDownswing(symbol, timeframe, shift+3, P.downswingLookback, md))
            return false;
      }

      // All three must be bullish
      if(!IsBull(c2) || !IsBull(c1) || !IsBull(c0))
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
      const double uw2 = UpperWick(c2)/tr2, uw1 = UpperWick(c1)/tr1, uw0 = UpperWick(c0)/tr0;
      const double lw2 = LowerWick(c2)/tr2, lw1 = LowerWick(c1)/tr1, lw0 = LowerWick(c0)/tr0;

      if(uw2 > P.maxUpperWickPctTR || uw1 > P.maxUpperWickPctTR || uw0 > P.maxUpperWickPctTR)
         return false;
      if(lw2 > P.maxLowerWickPctTR || lw1 > P.maxLowerWickPctTR || lw0 > P.maxLowerWickPctTR)
         return false;

      // Opens within previous real body?
      if(P.requireOpenInsidePrevBody)
      {
         if(!OpenInsidePrevBody(c1, c2)) return false;
         if(!OpenInsidePrevBody(c0, c1)) return false;
      }

      // Progressively higher closes?
      if(P.requireProgressivelyHigherCloses)
      {
         if(!(c1.close > c2.close && c0.close > c1.close))
            return false;
      }

      // Build score
      const double avgBodyPctTR    = (s2 + s1 + s0) / 3.0; // 0..1-ish
      // Near high metric: 1 - (upper wick / TR) for each, averaged
      const double nh2 = 1.0 - MathMin(1.0, uw2);
      const double nh1 = 1.0 - MathMin(1.0, uw1);
      const double nh0 = 1.0 - MathMin(1.0, uw0);
      const double avgCloseNearHigh = MathMax(0.0, (nh2 + nh1 + nh0) / 3.0);

      // Sequencing strength: measure how much higher the closes are relative to c2->c1 and c1->c0
      double seq = 0.0;
      const double rise1 = (c1.close - c2.close);
      const double rise2 = (c0.close - c1.close);
      if(rise1 > 0 && rise2 > 0)
      {
         // Normalize by average TR to 0..1
         const double avgTR = (tr2 + tr1 + tr0) / 3.0;
         if(avgTR > 0.0)
         {
            seq = MathMin(1.0, (rise1 + rise2) / (2.0 * avgTR));
         }
      }

      const double score = ScoreSoldiers(avgBodyPctTR, avgCloseNearHigh, seq);

      // Fill signal
      out.direction  = PatternBullish;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = "three_white_soldiers";

      return true;
   }
};

#endif // PATTERNS_THREEWHITESOLDIERS_MQH
