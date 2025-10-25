#ifndef PATTERNS_TWEEZERTOP_MQH
#define PATTERNS_TWEEZERTOP_MQH

// TweezerTop.mqh
// Bearish "Tweezer Top" using the OOP strategy base (PatternBase.mqh).
// Definition: two consecutive candles with (nearly) equal highs. Typical variant:
// first is bullish, second is bearish and closes decisively lower.
// Direction returned: PatternBearish.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class TweezerTopParams : public IPatternParams
{
public:
   // How close must the two highs be?
   // Either absolute (points) or relative to True Range (percentage). If both
   // are set (>0), both conditions must be satisfied.
   double maxHighDiffPoints;    // e.g., 2-5 points on FX (0 disables)
   double maxHighDiffPctTR;     // fraction of avg(TR1,TR0). e.g., 0.10 (=10% of TR)

   // Candle body requirements to avoid micro-bars
   double minFirstBodyPctTR;    // first (usually bullish) body/TR ≥ this (e.g., 0.25)
   double minSecondBodyPctTR;   // second (usually bearish) body/TR ≥ this (e.g., 0.30)
   double minBodyPoints;        // absolute min body (points), 0 = disabled

   // Color/confirmation rules
   bool   requireOppositeColors;           // c1 bullish & c0 bearish (classic)
   bool   requireSecondCloseBelowMidFirst; // c0.close ≤ midpoint of c1 body
   bool   requireSecondCloseBelowOpen;     // c0.close < c0.open (explicitly bearish)

   // Optional guard: lower shadow not too large on the second candle (keep thrusty look)
   double maxSecondLowerWickPctTR;         // e.g., 0.40 (0 disables)

   // Optional context: prefer an upswing before the pattern
   bool   preferUpswingContext;
   int    upswingLookback;                 // bars before c1 (e.g., 3)

   // Ignore tiny bars entirely
   double minTRPoints;                     // 0 disables

   TweezerTopParams()
   {
      maxHighDiffPoints              = 0.0;
      maxHighDiffPctTR               = 0.10;

      minFirstBodyPctTR              = 0.25;
      minSecondBodyPctTR             = 0.30;
      minBodyPoints                  = 0.0;

      requireOppositeColors          = true;
      requireSecondCloseBelowMidFirst= true;
      requireSecondCloseBelowOpen    = true;

      maxSecondLowerWickPctTR        = 0.40;

      preferUpswingContext           = false;
      upswingLookback                = 3;

      minTRPoints                    = 0.0;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new TweezerTopParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "TweezerTopParams{maxHighDiffPoints=%.2f, maxHighDiffPctTR=%.2f, "
         "minFirstBodyPctTR=%.2f, minSecondBodyPctTR=%.2f, minBodyPoints=%.2f, "
         "requireOppositeColors=%s, requireSecondCloseBelowMidFirst=%s, requireSecondCloseBelowOpen=%s, "
         "maxSecondLowerWickPctTR=%.2f, preferUpswingContext=%s, upswingLookback=%d, minTRPoints=%.2f}",
         maxHighDiffPoints, maxHighDiffPctTR,
         minFirstBodyPctTR, minSecondBodyPctTR, minBodyPoints,
         (requireOppositeColors?"true":"false"),
         (requireSecondCloseBelowMidFirst?"true":"false"),
         (requireSecondCloseBelowOpen?"true":"false"),
         maxSecondLowerWickPctTR,
         (preferUpswingContext?"true":"false"), upswingLookback, minTRPoints
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const TweezerTopParams* o = (const TweezerTopParams*)other;
      return MathAbs(maxHighDiffPoints - o.maxHighDiffPoints) < 1e-9
          && MathAbs(maxHighDiffPctTR - o.maxHighDiffPctTR) < 1e-9
          && MathAbs(minFirstBodyPctTR - o.minFirstBodyPctTR) < 1e-9
          && MathAbs(minSecondBodyPctTR - o.minSecondBodyPctTR) < 1e-9
          && MathAbs(minBodyPoints - o.minBodyPoints) < 1e-9
          && requireOppositeColors == o.requireOppositeColors
          && requireSecondCloseBelowMidFirst == o.requireSecondCloseBelowMidFirst
          && requireSecondCloseBelowOpen == o.requireSecondCloseBelowOpen
          && MathAbs(maxSecondLowerWickPctTR - o.maxSecondLowerWickPctTR) < 1e-9
          && preferUpswingContext == o.preferUpswingContext
          && upswingLookback == o.upswingLookback
          && MathAbs(minTRPoints - o.minTRPoints) < 1e-9;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class TweezerTopDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "TweezerTop";
      d.category = PatternDoubleCandle;
      d.legs     = 2;
      return d;
   }

   TweezerTopDetector()
   : AbstractPatternDetector(MakeDescriptor(), new TweezerTopParams()) {}

   TweezerTopDetector(const TweezerTopParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   TweezerTopDetector(const TweezerTopDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new TweezerTopDetector(*this); }

protected:
   // Helpers
   static inline double BodySize(const MqlRates &b)  { return MathAbs(b.close - b.open); }
   static inline double TrueRange(const MqlRates &b) { return (b.high - b.low); }
   static inline double LowerWick(const MqlRates &b) { return MathMin(b.open, b.close) - b.low; }
   static inline bool   IsBull(const MqlRates &b)    { return b.close > b.open; }
   static inline bool   IsBear(const MqlRates &b)    { return b.close < b.open; }

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

   static bool HighsCloseEnough(const MqlRates &c1, const MqlRates &c0,
                                const double maxPts, const double maxPctTR)
   {
      const double diff = MathAbs(c1.high - c0.high);
      bool okPts = (maxPts <= 0.0) ? true : (diff <= maxPts);
      double avgTR = (TrueRange(c1) + TrueRange(c0)) * 0.5;
      bool okPct = (maxPctTR <= 0.0 || avgTR <= 0.0) ? true : (diff <= maxPctTR * avgTR);
      return okPts && okPct;
   }

   // Score: closeness of highs + second body strength + position of second close.
   static double ScoreTweezerTop(const double highDiff,
                                 const double refRange,    // avg TR
                                 const double secondBodyPctTR,
                                 const bool   secondBelowMid,
                                 const bool   hadUpswing)
   {
      double closeHighs = 1.0;
      if(refRange > 0.0) closeHighs = 1.0 - MathMin(1.0, highDiff / (0.3 * refRange)); // full if diff≈0, fades at 30% TR
      double strongSecond = MathMin(1.0, MathMax(0.0, (secondBodyPctTR - 0.2)/0.8));   // 0 at 0.2, 1 at 1.0
      double confirmBonus = secondBelowMid ? 0.10 : 0.0;
      double ctxBonus     = hadUpswing ? 0.08 : 0.0;

      double wClose=0.40, wSecond=0.50;
      double score01 = wClose*closeHighs + wSecond*strongSecond + confirmBonus + ctxBonus;
      if(score01 > 1.0) score01 = 1.0;
      if(score01 < 0.0) score01 = 0.0;
      return score01 * 100.0;
   }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const TweezerTopParams* e = (const TweezerTopParams*)p;
      if(e.maxHighDiffPctTR < 0.0 || e.maxHighDiffPctTR > 1.0) return false;
      if(e.minFirstBodyPctTR < 0.0 || e.minFirstBodyPctTR > 1.0) return false;
      if(e.minSecondBodyPctTR < 0.0 || e.minSecondBodyPctTR > 1.0) return false;
      if(e.maxSecondLowerWickPctTR < 0.0 || e.maxSecondLowerWickPctTR > 1.0) return false;
      if(e.minBodyPoints < 0.0 || e.minTRPoints < 0.0) return false;
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
      const TweezerTopParams* Pptr = (const TweezerTopParams*)m_params;
      if(Pptr==NULL) return false;
      TweezerTopParams P = *Pptr; // use dot-access

      // Need two bars: c1 (previous at shift+1), c0 (current at shift)
      MqlRates rr[];
      if(!md.GetRates(symbol, timeframe, shift, 2, rr))
         return false;

      const MqlRates c0 = rr[0]; // current (second)
      const MqlRates c1 = rr[1]; // previous (first)

      // Basic TR guards
      const double tr1 = TrueRange(c1);
      const double tr0 = TrueRange(c0);
      if(tr1 <= 0.0 || tr0 <= 0.0) return false;
      if(P.minTRPoints > 0.0 && (tr1 < P.minTRPoints || tr0 < P.minTRPoints)) return false;

      // Bodies
      const double b1 = BodySize(c1);
      const double b0 = BodySize(c0);
      if(b1 <= 0.0 || b0 <= 0.0) return false;
      if(P.minBodyPoints > 0.0 && (b1 < P.minBodyPoints || b0 < P.minBodyPoints)) return false;

      const double b1PctTR = b1 / tr1;
      const double b0PctTR = b0 / tr0;
      if(b1PctTR < P.minFirstBodyPctTR)  return false;
      if(b0PctTR < P.minSecondBodyPctTR) return false;

      // Colors & confirmation
      if(P.requireOppositeColors)
      {
         if(!(IsBull(c1) && IsBear(c0))) return false;
      }
      else
      {
         if(P.requireSecondCloseBelowOpen && !(c0.close < c0.open)) return false;
      }

      // Highs nearly equal
      if(!HighsCloseEnough(c1, c0, P.maxHighDiffPoints, P.maxHighDiffPctTR)) return false;

      // Optional wick constraint on second candle
      if(P.maxSecondLowerWickPctTR > 0.0)
      {
         const double lw0 = LowerWick(c0) / tr0;
         if(lw0 > P.maxSecondLowerWickPctTR) return false;
      }

      // Second closes below midpoint of first body?
      bool belowMid = true;
      if(P.requireSecondCloseBelowMidFirst)
      {
         const double firstLo = MathMin(c1.open, c1.close);
         const double firstHi = MathMax(c1.open, c1.close);
         const double mid     = 0.5 * (firstLo + firstHi);
         belowMid = (c0.close <= mid);
         if(!belowMid) return false;
      }

      // Optional prior upswing
      bool hadUp = true;
      if(P.preferUpswingContext)
         hadUp = HasRecentUpswing(symbol, timeframe, shift+2, P.upswingLookback, md);
      if(!hadUp && P.preferUpswingContext) return false;

      // Score
      const double avgTR   = 0.5 * (tr1 + tr0);
      const double highDiff= MathAbs(c1.high - c0.high);
      const double score   = ScoreTweezerTop(highDiff, avgTR, b0PctTR, belowMid, hadUp);

      // Fill signal
      out.direction  = PatternBearish;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = "tweezer_top";

      return true;
   }
};

#endif // PATTERNS_TWEEZERTOP_MQH
