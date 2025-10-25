#ifndef PATTERNS_ENGULFING_MQH
#define PATTERNS_ENGULFING_MQH

// Engulfing.mqh
// Implementation of Bullish/Bearish Engulfing using the OOP strategy base.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class EngulfingParams : public IPatternParams
{
public:
   // Current body must be at least this multiple of the previous body
   double minBodyFactor;        // e.g., 1.05 (>= +5% larger)
   // Require opposite candle colors (classic definition)
   bool   requireOpposite;      // true = strict bullish/bearish color flip
   // Allow equality on edges (<= or >= instead of strict < / >)
   bool   allowEqualEdges;      // true = inclusive comparisons on "engulf"
   // Minimum current-body overlap relative to previous-body size [0..1]
   double minOverlapPct;        // e.g., 0.10 = at least 10% overlap
   // Minimum absolute body size (points) to avoid micro-bodies
   double minBodyPoints;        // e.g., 0.0 = disabled

   EngulfingParams()
   : minBodyFactor(1.05),
     requireOpposite(true),
     allowEqualEdges(true),
     minOverlapPct(0.10),
     minBodyPoints(0.0)
   {}

   // IPatternParams
   virtual IPatternParams* Clone() const { return new EngulfingParams(*this); }

   virtual string ToString() const
   {
      return StringFormat("EngulfingParams{minBodyFactor=%.3f, requireOpposite=%s, allowEqualEdges=%s, minOverlapPct=%.3f, minBodyPoints=%.2f}",
                          minBodyFactor,
                          requireOpposite ? "true" : "false",
                          allowEqualEdges ? "true" : "false",
                          minOverlapPct,
                          minBodyPoints);
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const EngulfingParams* o = (const EngulfingParams*)other;
      return MathAbs(minBodyFactor - o.minBodyFactor) < 1e-9
          && requireOpposite == o.requireOpposite
          && allowEqualEdges == o.allowEqualEdges
          && MathAbs(minOverlapPct - o.minOverlapPct) < 1e-9
          && MathAbs(minBodyPoints - o.minBodyPoints) < 1e-9;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class EngulfingDetector : public AbstractPatternDetector
{
public:
   // Descriptor for this strategy
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "Engulfing";
      d.category = PatternDoubleCandle;
      d.legs     = 2;
      return d;
   }

   // Ctors
   EngulfingDetector()
   : AbstractPatternDetector(MakeDescriptor(), new EngulfingParams())
   {}

   EngulfingDetector(const EngulfingParams& p)
   : AbstractPatternDetector(MakeDescriptor(), &p)
   {}

   EngulfingDetector(const EngulfingDetector& rhs)
   : AbstractPatternDetector(rhs)
   {}

   EngulfingDetector operator=(const EngulfingDetector& rhs)
   {
      if(GetPointer(this) != GetPointer(rhs))
      {
         AbstractPatternDetector::AssignFrom(rhs);
      }
      {
         AbstractPatternDetector::AssignFrom(rhs);
      }
      return *this;
   }

   // Polymorphic copy
   virtual IPatternDetector* Clone() const { return new EngulfingDetector(*this); }

protected:
   // Parameter validation
   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const EngulfingParams* e = (const EngulfingParams*)p;
      if(e.minBodyFactor < 1.0) return false;
      if(e.minOverlapPct < 0.0 || e.minOverlapPct > 1.0) return false;
      if(e.minBodyPoints < 0.0) return false;
      return true;
   }

   // Helpers
   static inline double BodySize(const MqlRates& b) { return MathAbs(b.close - b.open); }
   static inline bool   IsBull(const MqlRates& b)   { return b.close > b.open; }
   static inline bool   IsBear(const MqlRates& b)   { return b.close < b.open; }

   // Compute overlap between current and previous bodies (distance on price axis)
   static double BodyOverlap(const MqlRates& cur, const MqlRates& prev, const bool inclusive)
   {
      const double c_lo = MathMin(cur.open,  cur.close);
      const double c_hi = MathMax(cur.open,  cur.close);
      const double p_lo = MathMin(prev.open, prev.close);
      const double p_hi = MathMax(prev.open, prev.close);

      double lo = inclusive ? MathMax(c_lo, p_lo) : (MathMax(c_lo, p_lo));
      double hi = inclusive ? MathMin(c_hi, p_hi) : (MathMin(c_hi, p_hi));

      double overlap = hi - lo;
      return (overlap > 0.0 ? overlap : 0.0);
   }

   // Score function: blend dominance + overlap; cap to [0..100]
   static double ScoreEngulfing(const double bodyFactor, const double overlapRatio)
   {
      // bodyFactor:   currentBody / prevBody (>= 1.0)
      // overlapRatio: overlap / prevBody     (0..1+ potentially)
      // Map to 0..100 with emphasis on both being strong
      double dom   = MathMin(1.5, bodyFactor) - 1.0; // 0..0.5 (at 1.5x)
      double domSc = 100.0 * (dom / 0.5);            // 0..100

      double ovl   = MathMin(1.0, overlapRatio);     // 0..1
      double ovlSc = 100.0 * ovl;                    // 0..100

      // Weighted blend (favor dominance slightly)
      double score = 0.6*domSc + 0.4*ovlSc;
      if(score < 0.0) score = 0.0;
      if(score > 100.0) score = 100.0;
      return score;
   }

   // Core detection
   virtual bool DetectImpl(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift,
                           const IMarketData& md,
                           PatternSignal& out) const
   {
      const EngulfingParams* P = (const EngulfingParams*)m_params;
      if(P==NULL) return false;

      // Need two bars: current [shift], previous [shift+1]
      MqlRates rr[];
      if(!md.GetRates(symbol, timeframe, shift, 2, rr))
         return false;

      const MqlRates c0 = rr[0]; // current
      const MqlRates c1 = rr[1]; // previous

      const double b0 = BodySize(c0);
      const double b1 = BodySize(c1);

      // Guard against tiny bodies if a minimum is set
      if(b0 <= 0.0 || b1 <= 0.0) return false;
      if(P.minBodyPoints > 0.0 && (b0 < P.minBodyPoints || b1 < P.minBodyPoints))
         return false;

      // Color logic
      const bool curBull = IsBull(c0);
      const bool curBear = IsBear(c0);
      const bool prvBull = IsBull(c1);
      const bool prvBear = IsBear(c1);

      if(P.requireOpposite)
      {
         // Must flip colors: bull after bear (bullish engulf) or bear after bull (bearish engulf)
         if(!((curBull && prvBear) || (curBear && prvBull)))
            return false;
      }

      // Size dominance
      const double bodyFactor = (b1>0.0 ? (b0 / b1) : 0.0);
      if(bodyFactor < P.minBodyFactor)
         return false;

      // Overlap requirement (relative to previous body size)
      const double overlapAbs = BodyOverlap(c0, c1, P.allowEqualEdges);
      const double overlapRat = (b1>0.0 ? overlapAbs / b1 : 0.0);
      if(overlapRat < P.minOverlapPct)
         return false;

      // Determine direction per classic definition (if colors are ambiguous and requireOpposite=false, infer by closes)
      PatternDirection dir = PatternNone;
      if(curBull && prvBear) dir = PatternBullish;
      else if(curBear && prvBull) dir = PatternBearish;
      else
      {
         // Fallback: current close vs previous close if colors weren’t opposite (looser mode)
         if(c0.close > c1.close) dir = PatternBullish;
         if(c0.close < c1.close) dir = PatternBearish;
      }
      if(dir == PatternNone) return false;

      // Score
      const double score = ScoreEngulfing(bodyFactor, overlapRat);

      // Fill signal
      out.direction  = dir;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = "engulf"; // free-form; adjust as you wish

      return true;
   }
};

#endif // PATTERNS_ENGULFING_MQH
