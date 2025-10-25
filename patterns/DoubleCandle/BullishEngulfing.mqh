#ifndef PATTERNS_BULLISHENGULFING_MQH
#define PATTERNS_BULLISHENGULFING_MQH

// BullishEngulfing.mqh
// Classic 2-candle Bullish Engulfing using the OOP strategy base (PatternBase.mqh).
// Definition: a bullish candle whose real body engulfs the prior bearish body.
// Direction returned: PatternBullish.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class BullishEngulfingParams : public IPatternParams
{
public:
   // Current (bullish) body must be at least this multiple of previous (bearish) body
   double minBodyFactor;           // e.g., 1.05 → current body ≥ 105% of previous body
   // Require opposite colors: previous bearish, current bullish
   bool   requireOppositeColors;   // usually true
   // Allow equality on edges when checking "engulf" (inclusive range)
   bool   allowEqualEdges;         // true = ≥ / ≤ comparisons
   // Minimum body overlap as % of previous body range [0..1]
   double minOverlapPct;           // e.g., 0.10
   // Absolute guards
   double minPrevBodyPoints;       // ignore tiny previous body (0 disables)
   double minCurrBodyPoints;       // ignore tiny current body (0 disables)
   // Optional context: prefer prior downswing (reversal bias)
   bool   preferDownswingContext;
   int    downswingLookback;

   BullishEngulfingParams()
   {
      minBodyFactor           = 1.05;
      requireOppositeColors   = true;
      allowEqualEdges         = true;
      minOverlapPct           = 0.10;
      minPrevBodyPoints       = 0.0;
      minCurrBodyPoints       = 0.0;
      preferDownswingContext  = false;
      downswingLookback       = 3;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new BullishEngulfingParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "BullishEngulfingParams{minBodyFactor=%.3f, requireOppositeColors=%s, allowEqualEdges=%s, "
         "minOverlapPct=%.3f, minPrevBodyPoints=%.2f, minCurrBodyPoints=%.2f, preferDownswingContext=%s, downswingLookback=%d}",
         minBodyFactor,
         (requireOppositeColors?"true":"false"),
         (allowEqualEdges?"true":"false"),
         minOverlapPct,
         minPrevBodyPoints, minCurrBodyPoints,
         (preferDownswingContext?"true":"false"), downswingLookback
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const BullishEngulfingParams* o = (const BullishEngulfingParams*)other;
      return MathAbs(minBodyFactor - o.minBodyFactor) < 1e-9
          && requireOppositeColors == o.requireOppositeColors
          && allowEqualEdges == o.allowEqualEdges
          && MathAbs(minOverlapPct - o.minOverlapPct) < 1e-9
          && MathAbs(minPrevBodyPoints - o.minPrevBodyPoints) < 1e-9
          && MathAbs(minCurrBodyPoints - o.minCurrBodyPoints) < 1e-9
          && preferDownswingContext == o.preferDownswingContext
          && downswingLookback == o.downswingLookback;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class BullishEngulfingDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "BullishEngulfing";
      d.category = PatternDoubleCandle;
      d.legs     = 2;
      return d;
   }

   BullishEngulfingDetector()
   : AbstractPatternDetector(MakeDescriptor(), new BullishEngulfingParams()) {}

   BullishEngulfingDetector(const BullishEngulfingParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   BullishEngulfingDetector(const BullishEngulfingDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new BullishEngulfingDetector(*this); }

protected:
   // Helpers
   static inline double BodySize(const MqlRates &b) { return MathAbs(b.close - b.open); }
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

   static double BodyOverlap(const MqlRates &cur, const MqlRates &prev, const bool inclusive)
   {
      const double c_lo = MathMin(cur.open,  cur.close);
      const double c_hi = MathMax(cur.open,  cur.close);
      const double p_lo = MathMin(prev.open, prev.close);
      const double p_hi = MathMax(prev.open, prev.close);

      const double lo = (inclusive ? MathMax(c_lo, p_lo) : MathMax(c_lo, p_lo));
      const double hi = (inclusive ? MathMin(c_hi, p_hi) : MathMin(c_hi, p_hi));
      const double overlap = hi - lo;
      return (overlap > 0.0 ? overlap : 0.0);
   }

   static double ScoreBullishEngulf(const double bodyFactor, const double overlapRatio, const bool hadDownswing)
   {
      // Dominance (≥1) and overlap (0..1) with small context bonus.
      double dom   = MathMin(1.5, bodyFactor) - 1.0; // 0..0.5
      double domSc = 100.0 * (dom / 0.5);            // 0..100
      double ovlSc = 100.0 * MathMin(1.0, overlapRatio);
      double bonus = hadDownswing ? 7.0 : 0.0;
      double score = 0.6*domSc + 0.4*ovlSc + bonus;
      if(score > 100.0) score = 100.0;
      if(score < 0.0)   score = 0.0;
      return score;
   }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const BullishEngulfingParams* e = (const BullishEngulfingParams*)p;
      if(e.minBodyFactor < 1.0) return false;
      if(e.minOverlapPct < 0.0 || e.minOverlapPct > 1.0) return false;
      if(e.minPrevBodyPoints < 0.0 || e.minCurrBodyPoints < 0.0) return false;
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
      const BullishEngulfingParams* P = (const BullishEngulfingParams*)m_params;
      if(P==NULL) return false;

      // Need two bars: current [shift] (bullish), previous [shift+1] (bearish)
      MqlRates rr[];
      if(!md.GetRates(symbol, timeframe, shift, 2, rr))
         return false;

      const MqlRates c0 = rr[0]; // current
      const MqlRates c1 = rr[1]; // previous

      const double b0 = BodySize(c0);
      const double b1 = BodySize(c1);
      if(b0<=0.0 || b1<=0.0) return false;

      if(P.minPrevBodyPoints > 0.0 && b1 < P.minPrevBodyPoints) return false;
      if(P.minCurrBodyPoints > 0.0 && b0 < P.minCurrBodyPoints) return false;

      // Colors
      if(P.requireOppositeColors)
      {
         if(!(IsBull(c0) && IsBear(c1))) return false;
      }
      else
      {
         // If not strict, still require current to be bullish; previous can be small/neutral.
         if(!IsBull(c0)) return false;
      }

      // Dominance and overlap
      const double bodyFactor = (b1>0.0 ? (b0 / b1) : 0.0);
      if(bodyFactor < P.minBodyFactor) return false;

      const double overlapAbs = BodyOverlap(c0, c1, P.allowEqualEdges);
      const double overlapRat = (b1>0.0 ? overlapAbs / b1 : 0.0);
      if(overlapRat < P.minOverlapPct) return false;

      // Optional downswing context
      bool hadDown = true;
      if(P.preferDownswingContext)
         hadDown = HasRecentDownswing(symbol, timeframe, shift+2, P.downswingLookback, md);
      if(!hadDown && P.preferDownswingContext) return false;

      // Score & fill
      const double score = ScoreBullishEngulf(bodyFactor, overlapRat, hadDown);

      out.direction  = PatternBullish;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = "bullish_engulfing";

      return true;
   }
};

#endif // PATTERNS_BULLISHENGULFING_MQH
