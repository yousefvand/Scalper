#ifndef PATTERNS_MARUBOZU_MQH
#define PATTERNS_MARUBOZU_MQH

// Marubozu.mqh
// Bullish/Bearish "Marubozu" implemented with the OOP strategy base (PatternBase.mqh).
// Definition: long real body that dominates the candle; very small (ideally zero) shadows.
// Direction is inferred from candle color (bull/bear).

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class MarubozuParams : public IPatternParams
{
public:
   // Body must be >= this fraction of True Range (0..1), e.g., 0.75–0.90
   double minBodyPctTR;

   // Each wick must be <= this fraction of True Range (0..1), e.g., 0.10–0.15
   double maxUpperWickPctTR;
   double maxLowerWickPctTR;

   // Optional absolute guards (points)
   double minTRPoints;    // ignore micro-bars (0 disables)
   double minBodyPoints;  // ensure body isn’t negligible (0 disables)

   // Optional context: prefer momentum continuation in candle direction
   bool   preferContext;
   int    contextLookback;  // bars before this one (e.g., 3)

   MarubozuParams()
   {
      minBodyPctTR      = 0.80;
      maxUpperWickPctTR = 0.12;
      maxLowerWickPctTR = 0.12;
      minTRPoints       = 0.0;
      minBodyPoints     = 0.0;
      preferContext     = false;
      contextLookback   = 3;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new MarubozuParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "MarubozuParams{minBodyPctTR=%.2f, maxUpperWickPctTR=%.2f, maxLowerWickPctTR=%.2f, "
         "minTRPoints=%.2f, minBodyPoints=%.2f, preferContext=%s, contextLookback=%d}",
         minBodyPctTR, maxUpperWickPctTR, maxLowerWickPctTR,
         minTRPoints, minBodyPoints,
         (preferContext ? "true" : "false"), contextLookback
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const MarubozuParams* o = (const MarubozuParams*)other;
      return MathAbs(minBodyPctTR - o.minBodyPctTR) < 1e-9
          && MathAbs(maxUpperWickPctTR - o.maxUpperWickPctTR) < 1e-9
          && MathAbs(maxLowerWickPctTR - o.maxLowerWickPctTR) < 1e-9
          && MathAbs(minTRPoints - o.minTRPoints) < 1e-9
          && MathAbs(minBodyPoints - o.minBodyPoints) < 1e-9
          && preferContext == o.preferContext
          && contextLookback == o.contextLookback;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class MarubozuDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "Marubozu";
      d.category = PatternSingleCandle;
      d.legs     = 1;
      return d;
   }

   MarubozuDetector()
   : AbstractPatternDetector(MakeDescriptor(), new MarubozuParams()) {}

   MarubozuDetector(const MarubozuParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   MarubozuDetector(const MarubozuDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new MarubozuDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b)  { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b) { return (b.high - b.low); }
   static double UpperWick(const MqlRates &b) { return b.high - MathMax(b.open, b.close); }
   static double LowerWick(const MqlRates &b) { return MathMin(b.open, b.close) - b.low; }
   static bool   IsBull(const MqlRates &b)    { return b.close > b.open; }
   static bool   IsBear(const MqlRates &b)    { return b.close < b.open; }

   // Simple momentum context: majority of prior closes rising/falling
   static bool HasDirectionalContext(const string symbol,
                                     const ENUM_TIMEFRAMES timeframe,
                                     const int afterShift,
                                     const int lookback,
                                     const IMarketData &md,
                                     const bool wantBull)
   {
      if(lookback <= 0) return true;
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, afterShift, lookback+1, r))
         return false;

      int moves=0;
      for(int i=1; i<=lookback; ++i)
      {
         if(wantBull  && r[i].close > r[i-1].close) moves++;
         if(!wantBull && r[i].close < r[i-1].close) moves++;
      }
      return (moves > lookback/2); // majority in desired direction
   }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const MarubozuParams* e = (const MarubozuParams*)p;
      if(e.minBodyPctTR < 0.0 || e.minBodyPctTR > 1.0) return false;
      if(e.maxUpperWickPctTR < 0.0 || e.maxUpperWickPctTR > 1.0) return false;
      if(e.maxLowerWickPctTR < 0.0 || e.maxLowerWickPctTR > 1.0) return false;
      if(e.minTRPoints < 0.0) return false;
      if(e.minBodyPoints < 0.0) return false;
      if(e.contextLookback < 0) return false;
      return true;
   }

   // Score: huge body + tiny wicks, with optional context bonus
   static double ScoreMarubozu(const double bodyPctTR,
                               const double upWickPctTR,
                               const double loWickPctTR,
                               const bool   ctxOK)
   {
      // Body dominance emphasized; wicks penalized
      double strongBody = MathMin(1.0, MathMax(0.0, (bodyPctTR - 0.6) / 0.4)); // 0 at 0.6, 1 at 1.0
      double tinyUpper  = 1.0 - MathMin(1.0, upWickPctTR / 0.2);                // 1 at 0, fades by 20%
      double tinyLower  = 1.0 - MathMin(1.0, loWickPctTR / 0.2);

      double wBody=0.55, wUp=0.20, wLo=0.20, bonus= (ctxOK ? 0.05 : 0.0);
      double score01 = wBody*strongBody + wUp*tinyUpper + wLo*tinyLower + bonus;
      if(score01 < 0.0) score01 = 0.0;
      if(score01 > 1.0) score01 = 1.0;
      return score01 * 100.0;
   }

   virtual bool DetectImpl(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift,
                           const IMarketData &md,
                           PatternSignal &out) const
   {
      const MarubozuParams* Pptr = (const MarubozuParams*)m_params;
      if(Pptr==NULL) return false;
      MarubozuParams P = *Pptr; // dot-access copy

      // Single bar at 'shift'
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, shift, 1, r))
         return false;
      const MqlRates c = r[0];

      const double tr   = TrueRange(c);
      const double body = BodySize(c);
      if(tr <= 0.0 || body <= 0.0) return false;

      if(P.minTRPoints   > 0.0 && tr   < P.minTRPoints)  return false;
      if(P.minBodyPoints > 0.0 && body < P.minBodyPoints) return false;

      const double uw = UpperWick(c);
      const double lw = LowerWick(c);

      const double bodyPctTR = body / tr;
      const double upWickPct = uw   / tr;
      const double loWickPct = lw   / tr;

      // Geometry checks
      if(bodyPctTR < P.minBodyPctTR)        return false;
      if(upWickPct > P.maxUpperWickPctTR)   return false;
      if(loWickPct > P.maxLowerWickPctTR)   return false;

      // Context (optional): continuation in candle direction
      bool ctxOK = true;
      if(P.preferContext)
      {
         const bool wantBull = IsBull(c);
         ctxOK = HasDirectionalContext(symbol, timeframe, shift+1, P.contextLookback, md, wantBull);
         if(!ctxOK) return false;
      }

      // Score & fill
      const double score = ScoreMarubozu(bodyPctTR, upWickPct, loWickPct, ctxOK);

      out.direction  = IsBull(c) ? PatternBullish : PatternBearish;
      out.score      = score;
      out.time       = c.time;
      out.price_hint = c.close;
      out.tag        = IsBull(c) ? "marubozu_bull" : "marubozu_bear";

      return true;
   }
};

#endif // PATTERNS_MARUBOZU_MQH
