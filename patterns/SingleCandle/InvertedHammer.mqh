#ifndef PATTERNS_INVERTEDHAMMER_MQH
#define PATTERNS_INVERTEDHAMMER_MQH

// InvertedHammer.mqh
// Bullish-leaning "Inverted Hammer" using the OOP strategy base (PatternBase.mqh).
// Definition: small body near the LOW, long upper shadow, short lower shadow,
// typically after a downswing (potential bullish reversal).

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class InvertedHammerParams : public IPatternParams
{
public:
   // Body/TR should be small-to-medium (doji would be smaller). Typical cap ~35%.
   double maxBodyPctTR;

   // Lower wick should be relatively short (as fraction of TR).
   double maxLowerWickPctTR;

   // Upper wick must be >= this multiple of body (e.g., ≥ 2.5x).
   double minUpperWickToBody;

   // Optional: minimum TR (points) to ignore micro-bars (0 disables).
   double minTRPoints;

   // Optional: minimum body points to avoid near-zero bodies (0 disables).
   double minBodyPoints;

   // Optional context: prefer downswing before inverted hammer (reversal bias).
   bool   preferDownswingContext;
   int    downswingLookback;

   InvertedHammerParams()
   {
      maxBodyPctTR           = 0.35;
      maxLowerWickPctTR      = 0.25;
      minUpperWickToBody     = 2.5;
      minTRPoints            = 0.0;
      minBodyPoints          = 0.0;
      preferDownswingContext = false;
      downswingLookback      = 3;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new InvertedHammerParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "InvertedHammerParams{maxBodyPctTR=%.2f, maxLowerWickPctTR=%.2f, minUpperWickToBody=%.2f, "
         "minTRPoints=%.2f, minBodyPoints=%.2f, preferDownswingContext=%s, downswingLookback=%d}",
         maxBodyPctTR, maxLowerWickPctTR, minUpperWickToBody,
         minTRPoints, minBodyPoints,
         (preferDownswingContext ? "true":"false"), downswingLookback
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const InvertedHammerParams* o = (const InvertedHammerParams*)other;
      return MathAbs(maxBodyPctTR - o.maxBodyPctTR) < 1e-9
          && MathAbs(maxLowerWickPctTR - o.maxLowerWickPctTR) < 1e-9
          && MathAbs(minUpperWickToBody - o.minUpperWickToBody) < 1e-9
          && MathAbs(minTRPoints - o.minTRPoints) < 1e-9
          && MathAbs(minBodyPoints - o.minBodyPoints) < 1e-9
          && preferDownswingContext == o.preferDownswingContext
          && downswingLookback == o.downswingLookback;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class InvertedHammerDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "InvertedHammer";
      d.category = PatternSingleCandle;
      d.legs     = 1;
      return d;
   }

   InvertedHammerDetector()
   : AbstractPatternDetector(MakeDescriptor(), new InvertedHammerParams()) {}

   InvertedHammerDetector(const InvertedHammerParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   InvertedHammerDetector(const InvertedHammerDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new InvertedHammerDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b)  { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b) { return (b.high - b.low); }
   static double UpperWick(const MqlRates &b) { return b.high - MathMax(b.open, b.close); }
   static double LowerWick(const MqlRates &b) { return MathMin(b.open, b.close) - b.low; }

   static bool HasRecentDownswing(const string symbol,
                                  const ENUM_TIMEFRAMES timeframe,
                                  const int afterShift,  // bar right after target
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

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const InvertedHammerParams* e = (const InvertedHammerParams*)p;
      if(e.maxBodyPctTR < 0.0 || e.maxBodyPctTR > 1.0) return false;
      if(e.maxLowerWickPctTR < 0.0 || e.maxLowerWickPctTR > 1.0) return false;
      if(e.minUpperWickToBody < 0.0) return false;
      if(e.minTRPoints < 0.0) return false;
      if(e.minBodyPoints < 0.0) return false;
      if(e.downswingLookback < 0) return false;
      return true;
   }

   // Scoring: smaller body, tiny lower wick, long upper wick, optional downswing context.
   static double ScoreInvertedHammer(const double bodyPctTR,
                                     const double lowerWickPctTR,
                                     const double upperToBody,
                                     const bool   hadDownswing)
   {
      // Normalize components to 0..1
      double smallBody = 1.0 - MathMin(1.0, (bodyPctTR - 0.05) / 0.30); // full near 5%, fades by ~35%
      if(smallBody < 0.0) smallBody = 0.0;
      double tinyLower = 1.0 - MathMin(1.0, lowerWickPctTR / 0.25);     // full at 0, fades by 25% TR
      double longUpper = MathMin(1.0, upperToBody / 3.0);               // full credit ~3x body
      double bonus     = hadDownswing ? 0.10 : 0.0;

      double wBody=0.35, wLower=0.20, wUpper=0.45;
      double score01 = wBody*smallBody + wLower*tinyLower + wUpper*longUpper + bonus;
      if(score01 > 1.0) score01 = 1.0;
      if(score01 < 0.0) score01 = 0.0;
      return score01 * 100.0;
   }

   virtual bool DetectImpl(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift,
                           const IMarketData &md,
                           PatternSignal &out) const
   {
      const InvertedHammerParams* Pptr = (const InvertedHammerParams*)m_params;
      if(Pptr==NULL) return false;
      InvertedHammerParams P = *Pptr; // dot-access copy

      // Single bar at 'shift'
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, shift, 1, r))
         return false;
      const MqlRates c = r[0];

      const double body = BodySize(c);
      const double tr   = TrueRange(c);
      if(tr <= 0.0) return false;

      if(P.minTRPoints > 0.0 && tr < P.minTRPoints) return false;
      if(P.minBodyPoints > 0.0 && body < P.minBodyPoints) return false;

      const double uw = UpperWick(c);
      const double lw = LowerWick(c);

      const double bodyPctTR      = body / tr;
      const double lowerWickPctTR = lw / tr;
      const double upperToBody    = (body > 0.0 ? uw / body : (uw>0.0 ? 10.0 : 0.0)); // if body≈0, treat as very large

      // Geometry checks for inverted hammer
      if(bodyPctTR > P.maxBodyPctTR) return false;
      if(lowerWickPctTR > P.maxLowerWickPctTR) return false;
      if(upperToBody < P.minUpperWickToBody) return false;

      // Optional downswing context
      bool hadDown = true;
      if(P.preferDownswingContext)
         hadDown = HasRecentDownswing(symbol, timeframe, shift+1, P.downswingLookback, md);
      if(!hadDown && P.preferDownswingContext) return false;

      // Score & fill
      const double score = ScoreInvertedHammer(bodyPctTR, lowerWickPctTR, upperToBody, hadDown);

      out.direction  = PatternBullish;   // bullish-leaning reversal
      out.score      = score;
      out.time       = c.time;
      out.price_hint = c.close;
      out.tag        = "inverted_hammer";

      return true;
   }
};

#endif // PATTERNS_INVERTEDHAMMER_MQH
