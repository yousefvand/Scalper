#ifndef PATTERNS_SPINNINGTOP_MQH
#define PATTERNS_SPINNINGTOP_MQH

// SpinningTop.mqh
// Neutral "Spinning Top" using the OOP strategy base (PatternBase.mqh).
// Definition: medium/small real body with upper & lower shadows of notable size.
// By default returns PatternNone (neutral). You can optionally infer direction from color.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class SpinningTopParams : public IPatternParams
{
public:
   // Body/TR must be within [minBodyPctTR .. maxBodyPctTR] (avoid doji/tiny and long-body candles)
   double minBodyPctTR;            // e.g., 0.12
   double maxBodyPctTR;            // e.g., 0.45

   // Each wick should be at least this multiple of body (encourage "spinning" look)
   double minWickToBody;           // e.g., 0.50

   // Prefer symmetric wicks? (score boost for balance)
   bool   preferBalancedWicks;
   double wickBalanceTolerance;    // 0..1; 0 strict (equal), higher allows more diff

   // Optional absolute guards
   double minTRPoints;             // ignore micro-bars (0 disables)
   double minBodyPoints;           // avoid near-zero bodies (0 disables)

   // Direction handling
   bool   inferDirectionFromColor; // if true: bull/bear by close>open / close<open; else PatternNone

   SpinningTopParams()
   {
      minBodyPctTR          = 0.12;
      maxBodyPctTR          = 0.45;
      minWickToBody         = 0.50;
      preferBalancedWicks   = true;
      wickBalanceTolerance  = 0.30;
      minTRPoints           = 0.0;
      minBodyPoints         = 0.0;
      inferDirectionFromColor = false;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new SpinningTopParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "SpinningTopParams{minBodyPctTR=%.2f, maxBodyPctTR=%.2f, minWickToBody=%.2f, "
         "preferBalancedWicks=%s, wickBalanceTolerance=%.2f, minTRPoints=%.2f, minBodyPoints=%.2f, "
         "inferDirectionFromColor=%s}",
         minBodyPctTR, maxBodyPctTR, minWickToBody,
         (preferBalancedWicks ? "true":"false"), wickBalanceTolerance,
         minTRPoints, minBodyPoints,
         (inferDirectionFromColor ? "true":"false")
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const SpinningTopParams* o = (const SpinningTopParams*)other;
      return MathAbs(minBodyPctTR - o.minBodyPctTR) < 1e-9
          && MathAbs(maxBodyPctTR - o.maxBodyPctTR) < 1e-9
          && MathAbs(minWickToBody - o.minWickToBody) < 1e-9
          && preferBalancedWicks == o.preferBalancedWicks
          && MathAbs(wickBalanceTolerance - o.wickBalanceTolerance) < 1e-9
          && MathAbs(minTRPoints - o.minTRPoints) < 1e-9
          && MathAbs(minBodyPoints - o.minBodyPoints) < 1e-9
          && inferDirectionFromColor == o.inferDirectionFromColor;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class SpinningTopDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "SpinningTop";
      d.category = PatternSingleCandle;
      d.legs     = 1;
      return d;
   }

   SpinningTopDetector()
   : AbstractPatternDetector(MakeDescriptor(), new SpinningTopParams()) {}

   SpinningTopDetector(const SpinningTopParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   SpinningTopDetector(const SpinningTopDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new SpinningTopDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b)  { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b) { return (b.high - b.low); }
   static double UpperWick(const MqlRates &b) { return b.high - MathMax(b.open, b.close); }
   static double LowerWick(const MqlRates &b) { return MathMin(b.open, b.close) - b.low; }
   static bool   IsBull(const MqlRates &b)    { return b.close > b.open; }
   static bool   IsBear(const MqlRates &b)    { return b.close < b.open; }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const SpinningTopParams* e = (const SpinningTopParams*)p;
      if(e.minBodyPctTR < 0.0 || e.minBodyPctTR > 1.0) return false;
      if(e.maxBodyPctTR < 0.0 || e.maxBodyPctTR > 1.0) return false;
      if(e.minBodyPctTR >= e.maxBodyPctTR) return false;
      if(e.minWickToBody < 0.0) return false;
      if(e.wickBalanceTolerance < 0.0 || e.wickBalanceTolerance > 1.0) return false;
      if(e.minTRPoints < 0.0 || e.minBodyPoints < 0.0) return false;
      return true;
   }

   // Score: ideal body in the middle of the band + both wicks sizable + balanced.
   static double ScoreSpinningTop(const double bodyPctTR,
                                  const double uw,
                                  const double lw,
                                  const double body,
                                  const SpinningTopParams &P,
                                  string &subtypeOut)
   {
      // 1) Body within band: score by distance from midpoint of [min,max]
      const double mid = 0.5 * (P.minBodyPctTR + P.maxBodyPctTR);
      const double halfSpan = 0.5 * (P.maxBodyPctTR - P.minBodyPctTR);
      double bodyBand01 = 1.0 - MathMin(1.0, MathAbs(bodyPctTR - mid) / MathMax(1e-12, halfSpan));

      // 2) Wick lengths vs body (both should be "present")
      double wu = (body>0.0 ? uw/body : (uw>0.0 ? 2.0 : 0.0));
      double wl = (body>0.0 ? lw/body : (lw>0.0 ? 2.0 : 0.0));
      double wickPresence01 = MathMin(1.0, MathMin(wu, wl) / MathMax(1e-12, P.minWickToBody)); // full credit when both ≥ minWickToBody

      // 3) Balance
      double balance01 = 1.0;
      if(P.preferBalancedWicks)
      {
         double sum = uw + lw;
         if(sum > 0.0)
         {
            double diffRatio = MathAbs(uw - lw) / sum; // 0 perfect, 1 very imbalanced
            // Map [0..tol..1] -> [1..~0.4..0]
            double tol = MathMax(1e-12, P.wickBalanceTolerance);
            balance01 = MathMax(0.0, 1.0 - (diffRatio / (1.0 + tol)));
         }
      }

      // Subtype tag (optional): lean bullish/bearish if one wick clearly dominates
      subtypeOut = "spinning_top";
      if(uw > 1.5*lw) subtypeOut = "spinning_top_upper_bias";
      else if(lw > 1.5*uw) subtypeOut = "spinning_top_lower_bias";

      // Blend
      double wBody=0.45, wWicks=0.35, wBal=0.20;
      double score01 = wBody*bodyBand01 + wWicks*wickPresence01 + wBal*balance01;
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
      const SpinningTopParams* Pptr = (const SpinningTopParams*)m_params;
      if(Pptr==NULL) return false;
      SpinningTopParams P = *Pptr; // dot-access copy

      // Single bar at 'shift'
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, shift, 1, r))
         return false;
      const MqlRates c = r[0];

      const double body = BodySize(c);
      const double tr   = TrueRange(c);
      if(tr <= 0.0) return false;

      if(P.minTRPoints  > 0.0 && tr   < P.minTRPoints)  return false;
      if(P.minBodyPoints> 0.0 && body < P.minBodyPoints) return false;

      const double uw = UpperWick(c);
      const double lw = LowerWick(c);

      const double bodyPctTR = body / tr;

      // Geometry band for body
      if(bodyPctTR < P.minBodyPctTR) return false;
      if(bodyPctTR > P.maxBodyPctTR) return false;

      // Wick presence relative to body
      const double wu = (body>0.0 ? uw/body : (uw>0.0 ? 2.0 : 0.0));
      const double wl = (body>0.0 ? lw/body : (lw>0.0 ? 2.0 : 0.0));
      if(wu < P.minWickToBody || wl < P.minWickToBody) return false;

      // Score & fill
      string subtype;
      const double score = ScoreSpinningTop(bodyPctTR, uw, lw, body, P, subtype);

      out.direction  = P.inferDirectionFromColor ? (IsBull(c) ? PatternBullish : (IsBear(c) ? PatternBearish : PatternNone))
                                                 : PatternNone;
      out.score      = score;
      out.time       = c.time;
      out.price_hint = c.close;
      out.tag        = subtype;

      return true;
   }
};

#endif // PATTERNS_SPINNINGTOP_MQH
