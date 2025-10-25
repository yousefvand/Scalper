#ifndef PATTERNS_TWEEZERBOTTOM_MQH
#define PATTERNS_TWEEZERBOTTOM_MQH

// TweezerBottom.mqh
// Bullish "Tweezer Bottom" using the OOP strategy base (PatternBase.mqh).
// Definition: two consecutive candles with (nearly) equal lows. Typical variant:
// first is bearish, second is bullish and closes strongly upward.
// Direction returned: PatternBullish.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class TweezerBottomParams : public IPatternParams
{
public:
   // How close must the two lows be?
   // Either absolute (points) or relative to True Range (percentage). If both
   // are set (>0), both conditions must be satisfied.
   double maxLowDiffPoints;    // e.g., 2-5 points on FX (0 disables)
   double maxLowDiffPctTR;     // fraction of avg(TR1,TR0). e.g., 0.10 (=10% of TR)

   // Candle body requirements to avoid micro-bars
   double minFirstBodyPctTR;   // first (usually bearish) body/TR ≥ this (e.g., 0.25)
   double minSecondBodyPctTR;  // second (usually bullish) body/TR ≥ this (e.g., 0.30)
   double minBodyPoints;       // absolute min body (points), 0 = disabled

   // Color/confirmation rules
   bool   requireOppositeColors;          // c1 bearish & c0 bullish (classic)
   bool   requireSecondCloseAboveMidFirst;// c0.close ≥ midpoint of c1 body
   bool   requireSecondCloseAboveOpen;    // c0.close > c0.open (explicitly bullish)

   // Optional guard: upper shadows not too large on the second candle (keep thrusty look)
   double maxSecondUpperWickPctTR;        // e.g., 0.40 (0 disables)

   // Optional context: prefer a downswing before the pattern
   bool   preferDownswingContext;
   int    downswingLookback;              // bars before c1 (e.g., 3)

   // Ignore tiny bars entirely
   double minTRPoints;                    // 0 disables

   TweezerBottomParams()
   {
      maxLowDiffPoints             = 0.0;
      maxLowDiffPctTR              = 0.10;

      minFirstBodyPctTR            = 0.25;
      minSecondBodyPctTR           = 0.30;
      minBodyPoints                = 0.0;

      requireOppositeColors        = true;
      requireSecondCloseAboveMidFirst = true;
      requireSecondCloseAboveOpen  = true;

      maxSecondUpperWickPctTR      = 0.40;

      preferDownswingContext       = false;
      downswingLookback            = 3;

      minTRPoints                  = 0.0;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new TweezerBottomParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "TweezerBottomParams{maxLowDiffPoints=%.2f, maxLowDiffPctTR=%.2f, "
         "minFirstBodyPctTR=%.2f, minSecondBodyPctTR=%.2f, minBodyPoints=%.2f, "
         "requireOppositeColors=%s, requireSecondCloseAboveMidFirst=%s, requireSecondCloseAboveOpen=%s, "
         "maxSecondUpperWickPctTR=%.2f, preferDownswingContext=%s, downswingLookback=%d, minTRPoints=%.2f}",
         maxLowDiffPoints, maxLowDiffPctTR,
         minFirstBodyPctTR, minSecondBodyPctTR, minBodyPoints,
         (requireOppositeColors?"true":"false"),
         (requireSecondCloseAboveMidFirst?"true":"false"),
         (requireSecondCloseAboveOpen?"true":"false"),
         maxSecondUpperWickPctTR,
         (preferDownswingContext?"true":"false"), downswingLookback, minTRPoints
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const TweezerBottomParams* o = (const TweezerBottomParams*)other;
      return MathAbs(maxLowDiffPoints - o.maxLowDiffPoints) < 1e-9
          && MathAbs(maxLowDiffPctTR - o.maxLowDiffPctTR) < 1e-9
          && MathAbs(minFirstBodyPctTR - o.minFirstBodyPctTR) < 1e-9
          && MathAbs(minSecondBodyPctTR - o.minSecondBodyPctTR) < 1e-9
          && MathAbs(minBodyPoints - o.minBodyPoints) < 1e-9
          && requireOppositeColors == o.requireOppositeColors
          && requireSecondCloseAboveMidFirst == o.requireSecondCloseAboveMidFirst
          && requireSecondCloseAboveOpen == o.requireSecondCloseAboveOpen
          && MathAbs(maxSecondUpperWickPctTR - o.maxSecondUpperWickPctTR) < 1e-9
          && preferDownswingContext == o.preferDownswingContext
          && downswingLookback == o.downswingLookback
          && MathAbs(minTRPoints - o.minTRPoints) < 1e-9;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class TweezerBottomDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "TweezerBottom";
      d.category = PatternDoubleCandle;
      d.legs     = 2;
      return d;
   }

   TweezerBottomDetector()
   : AbstractPatternDetector(MakeDescriptor(), new TweezerBottomParams()) {}

   TweezerBottomDetector(const TweezerBottomParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   TweezerBottomDetector(const TweezerBottomDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new TweezerBottomDetector(*this); }

protected:
   // Helpers
   static inline double BodySize(const MqlRates &b)  { return MathAbs(b.close - b.open); }
   static inline double TrueRange(const MqlRates &b) { return (b.high - b.low); }
   static inline double UpperWick(const MqlRates &b) { return b.high - MathMax(b.open, b.close); }
   static inline bool   IsBull(const MqlRates &b)    { return b.close > b.open; }
   static inline bool   IsBear(const MqlRates &b)    { return b.close < b.open; }

   static bool HasRecentDownswing(const string symbol,
                                  const ENUM_TIMEFRAMES timeframe,
                                  const int afterShift,
                                  const int lookback,
                                  const IMarketData &md)
   {
      if(lookback <= 0) return true;
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, afterShift, lookback+1, r))
         return false;
      int falls=0;
      for(int i=1;i<=lookback;i++)
         if(r[i-1].close > r[i].close) falls++;
      return (falls > lookback/2);
   }

   static bool LowsCloseEnough(const MqlRates &c1, const MqlRates &c0,
                               const double maxPts, const double maxPctTR)
   {
      const double diff = MathAbs(c1.low - c0.low);
      bool okPts = (maxPts <= 0.0) ? true : (diff <= maxPts);
      double avgTR = (TrueRange(c1) + TrueRange(c0)) * 0.5;
      bool okPct = (maxPctTR <= 0.0 || avgTR <= 0.0) ? true : (diff <= maxPctTR * avgTR);
      return okPts && okPct;
   }

   // Score: closeness of lows + second body strength + position of second close.
   static double ScoreTweezerBottom(const double lowDiff,
                                    const double refRange,    // avg TR
                                    const double secondBodyPctTR,
                                    const bool   secondAboveMid,
                                    const bool   hadDownswing)
   {
      double closeLows = 1.0;
      if(refRange > 0.0) closeLows = 1.0 - MathMin(1.0, lowDiff / (0.3 * refRange)); // full if diff≈0, fades at 30% TR
      double strongSecond = MathMin(1.0, MathMax(0.0, (secondBodyPctTR - 0.2)/0.8)); // 0 at 0.2, 1 at 1.0
      double confirmBonus = secondAboveMid ? 0.10 : 0.0;
      double ctxBonus     = hadDownswing ? 0.08 : 0.0;

      double wClose=0.40, wSecond=0.50;
      double score01 = wClose*closeLows + wSecond*strongSecond + confirmBonus + ctxBonus;
      if(score01 > 1.0) score01 = 1.0;
      if(score01 < 0.0) score01 = 0.0;
      return score01 * 100.0;
   }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const TweezerBottomParams* e = (const TweezerBottomParams*)p;
      if(e.maxLowDiffPctTR < 0.0 || e.maxLowDiffPctTR > 1.0) return false;
      if(e.minFirstBodyPctTR < 0.0 || e.minFirstBodyPctTR > 1.0) return false;
      if(e.minSecondBodyPctTR < 0.0 || e.minSecondBodyPctTR > 1.0) return false;
      if(e.maxSecondUpperWickPctTR < 0.0 || e.maxSecondUpperWickPctTR > 1.0) return false;
      if(e.minBodyPoints < 0.0 || e.minTRPoints < 0.0) return false;
      if(e.downswingLookback < 0) return false;
      return true;
   }

   // Core detection
   virtual bool DetectImpl(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift,
                           const IMarketData &md,
                           PatternSignal &out) const
   {
      const TweezerBottomParams* P = (const TweezerBottomParams*)m_params;
      if(P==NULL) return false;

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
         if(!(IsBear(c1) && IsBull(c0))) return false;
      }
      else
      {
         // at least require the second to be bullish if enabled
         if(P.requireSecondCloseAboveOpen && !(c0.close > c0.open)) return false;
      }

      // Lows nearly equal
      if(!LowsCloseEnough(c1, c0, P.maxLowDiffPoints, P.maxLowDiffPctTR)) return false;

      // Optional wick constraint on second candle
      if(P.maxSecondUpperWickPctTR > 0.0)
      {
         const double uw0 = UpperWick(c0) / tr0;
         if(uw0 > P.maxSecondUpperWickPctTR) return false;
      }

      // Second closes above midpoint of first body?
      bool aboveMid = true;
      if(P.requireSecondCloseAboveMidFirst)
      {
         const double firstLo = MathMin(c1.open, c1.close);
         const double firstHi = MathMax(c1.open, c1.close);
         const double mid     = 0.5 * (firstLo + firstHi);
         aboveMid = (c0.close >= mid);
         if(!aboveMid) return false;
      }

      // Optional prior downswing
      bool hadDown = true;
      if(P.preferDownswingContext)
         hadDown = HasRecentDownswing(symbol, timeframe, shift+2, P.downswingLookback, md);
      if(!hadDown && P.preferDownswingContext) return false;

      // Score
      const double avgTR = 0.5 * (tr1 + tr0);
      const double lowDiff = MathAbs(c1.low - c0.low);
      const double score = ScoreTweezerBottom(lowDiff, avgTR, b0PctTR, aboveMid, hadDown);

      // Fill signal
      out.direction  = PatternBullish;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = "tweezer_bottom";

      return true;
   }
};

#endif // PATTERNS_TWEEZERBOTTOM_MQH
