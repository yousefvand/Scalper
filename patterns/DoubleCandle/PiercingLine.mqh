#ifndef PATTERNS_PIERCINGLINE_MQH
#define PATTERNS_PIERCINGLINE_MQH

// PiercingLine.mqh
// Bullish "Piercing Line" using the OOP strategy base (PatternBase.mqh).
// Definition: after a strong bearish candle, the next candle opens below the prior
// low (gap-down preferred) and closes deep into the prior real body but (classically)
// not above the prior open (i.e., not a full bullish engulfing).
//
// Direction returned: PatternBullish.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class PiercingLineParams : public IPatternParams
{
public:
   // Strength of the first (bearish) candle
   double minFirstBodyPctTR;      // body/TR of 1st bar must be >= (e.g., 0.50)
   double minFirstBodyPoints;     // absolute min body size (points), 0 = disabled

   // Second (bullish) candle body size requirement (keeps it meaningful)
   double minSecondBodyPctTR;     // body/TR of 2nd bar must be >= (e.g., 0.35)
   double minSecondBodyPoints;    // absolute min body size (points), 0 = disabled

   // Gap and placement
   bool   requireGapDown;         // strict classic gap-down at the open of the 2nd bar
   bool   allowOpenBelowCloseIfNoGap; // if no strict gap, allow open <= first close

   // Penetration of 2nd close into the first body (from bottom up, 0..1)
   double minPenetrationPct;      // e.g., 0.50 ⇒ close above 1st body midpoint

   // Engulfing rule (classic piercing is NOT a full engulfing)
   bool   forbidFullEngulf;       // true ⇒ close of 2nd must stay BELOW first open

   // Optional context: prefer downswing into the pattern (reversal bias)
   bool   preferDownswingContext;
   int    downswingLookback;

   PiercingLineParams()
   {
      minFirstBodyPctTR         = 0.50;
      minFirstBodyPoints        = 0.0;
      minSecondBodyPctTR        = 0.35;
      minSecondBodyPoints       = 0.0;
      requireGapDown            = false;
      allowOpenBelowCloseIfNoGap= true;
      minPenetrationPct         = 0.50;
      forbidFullEngulf          = true;
      preferDownswingContext    = false;
      downswingLookback         = 3;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new PiercingLineParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "PiercingLineParams{minFirstBodyPctTR=%.2f, minFirstBodyPoints=%.2f, "
         "minSecondBodyPctTR=%.2f, minSecondBodyPoints=%.2f, requireGapDown=%s, allowOpenBelowCloseIfNoGap=%s, "
         "minPenetrationPct=%.2f, forbidFullEngulf=%s, preferDownswingContext=%s, downswingLookback=%d}",
         minFirstBodyPctTR, minFirstBodyPoints,
         minSecondBodyPctTR, minSecondBodyPoints,
         (requireGapDown ? "true":"false"),
         (allowOpenBelowCloseIfNoGap ? "true":"false"),
         minPenetrationPct,
         (forbidFullEngulf ? "true":"false"),
         (preferDownswingContext ? "true":"false"),
         downswingLookback
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const PiercingLineParams* o = (const PiercingLineParams*)other;
      return MathAbs(minFirstBodyPctTR - o.minFirstBodyPctTR) < 1e-9
          && MathAbs(minFirstBodyPoints - o.minFirstBodyPoints) < 1e-9
          && MathAbs(minSecondBodyPctTR - o.minSecondBodyPctTR) < 1e-9
          && MathAbs(minSecondBodyPoints - o.minSecondBodyPoints) < 1e-9
          && requireGapDown == o.requireGapDown
          && allowOpenBelowCloseIfNoGap == o.allowOpenBelowCloseIfNoGap
          && MathAbs(minPenetrationPct - o.minPenetrationPct) < 1e-9
          && forbidFullEngulf == o.forbidFullEngulf
          && preferDownswingContext == o.preferDownswingContext
          && downswingLookback == o.downswingLookback;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class PiercingLineDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "PiercingLine";
      d.category = PatternDoubleCandle;
      d.legs     = 2;
      return d;
   }

   PiercingLineDetector()
   : AbstractPatternDetector(MakeDescriptor(), new PiercingLineParams()) {}

   PiercingLineDetector(const PiercingLineParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   PiercingLineDetector(const PiercingLineDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new PiercingLineDetector(*this); }

protected:
   // Helpers
   static inline double BodySize(const MqlRates &b) { return MathAbs(b.close - b.open); }
   static inline double TrueRange(const MqlRates &b){ return (b.high - b.low); }
   static inline bool   IsBull(const MqlRates &b)   { return b.close > b.open; }
   static inline bool   IsBear(const MqlRates &b)   { return b.close < b.open; }

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

   // Scoring blend (0..100): strong first bear, deep penetration, meaningful 2nd body, gap bonus.
   static double ScorePLC(const double firstBodyPctTR,
                          const double secondBodyPctTR,
                          const double penetrationPct,  // achieved 0..1
                          const bool   hadGap,
                          const bool   hadDownswing)
   {
      double strongFirst = MathMin(1.0, MathMax(0.0, (firstBodyPctTR - 0.3)/0.7));
      double strongSecond= MathMin(1.0, MathMax(0.0, (secondBodyPctTR - 0.2)/0.8));
      double deepPen     = MathMin(1.0, MathMax(0.0, penetrationPct));
      double bonus       = (hadGap?0.08:0.0) + (hadDownswing?0.07:0.0);

      double w1=0.30, w2=0.25, w3=0.45;
      double score01 = w1*strongFirst + w2*strongSecond + w3*deepPen + bonus;
      if(score01>1.0) score01=1.0;
      if(score01<0.0) score01=0.0;
      return score01*100.0;
   }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const PiercingLineParams* e = (const PiercingLineParams*)p;
      if(e.minFirstBodyPctTR < 0.0 || e.minFirstBodyPctTR > 1.0) return false;
      if(e.minSecondBodyPctTR < 0.0 || e.minSecondBodyPctTR > 1.0) return false;
      if(e.minPenetrationPct < 0.0 || e.minPenetrationPct > 1.0) return false;
      if(e.minFirstBodyPoints < 0.0 || e.minSecondBodyPoints < 0.0) return false;
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
      const PiercingLineParams* Pptr = (const PiercingLineParams*)m_params;
      if(Pptr==NULL) return false;
      PiercingLineParams P = *Pptr;

      // Need two bars: current [shift] (bull), previous [shift+1] (bear)
      MqlRates rr[];
      if(!md.GetRates(symbol, timeframe, shift, 2, rr))
         return false;

      const MqlRates c0 = rr[0]; // current (bullish)
      const MqlRates c1 = rr[1]; // previous (bearish)

      // Colors
      if(!IsBear(c1)) return false;
      if(!IsBull(c0)) return false;

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
      if(P.requireGapDown)
      {
         if(c0.open < c1.low) hadGap = true; else return false;
      }
      else
      {
         if(P.allowOpenBelowCloseIfNoGap)
         {
            if(!(c0.open <= c1.close)) return false; // at least open at/below prior close
         }
         // no strict gap; hadGap remains false
      }

      // Penetration: close of c0 must be above a threshold inside c1 body (from bottom up)
      const double bodyLo = MathMin(c1.open, c1.close); // for bear: close
      const double bodyHi = MathMax(c1.open, c1.close); // for bear: open
      const double bodySpan = MathMax(1e-12, bodyHi - bodyLo);

      // Required close >= bodyLo + minPenetrationPct * span
      const double requiredClose = bodyLo + P.minPenetrationPct * bodySpan;
      if(c0.close < requiredClose) return false;

      // Not a full engulfing (classic)
      if(P.forbidFullEngulf)
      {
         if(c0.close >= bodyHi) return false; // closing above first open ⇒ engulfing, reject
      }

      // Optional context (prior downswing)
      bool hadDown = true;
      if(P.preferDownswingContext)
         hadDown = HasRecentDownswing(symbol, timeframe, shift+2, P.downswingLookback, md);
      if(!hadDown && P.preferDownswingContext) return false;

      // Penetration actually achieved (0..1), for scoring
      const double achievedPen = MathMin(1.0, MathMax(0.0, (c0.close - bodyLo) / bodySpan));

      // Score & fill
      const double score = ScorePLC(firstBodyPctTR, secondBodyPctTR, achievedPen, hadGap, hadDown);

      out.direction  = PatternBullish;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = hadGap ? "piercing_line_gap" : "piercing_line";

      return true;
   }
};

#endif // PATTERNS_PIERCINGLINE_MQH
