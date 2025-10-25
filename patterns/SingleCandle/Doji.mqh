#ifndef PATTERNS_DOJI_MQH
#define PATTERNS_DOJI_MQH

// Doji.mqh
// Neutral "Doji" implemented with the OOP strategy base (PatternBase.mqh).
// Direction is PatternNone; use in combination with context filters (trend/volume).

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class DojiParams : public IPatternParams
{
public:
   // Body must be <= this fraction of True Range (0..1). Typical: 0.10 (10%)
   double maxBodyPctTR;
   // Minimum True Range (points) to avoid micro-bars; 0 disables
   double minTRPoints;
   // Optional: require both wicks to be at least this multiple of the body (e.g., 1.0 = each wick >= body)
   double minWickToBodyRatio;
   // Prefer symmetric wicks? If true, score boosts with balanced wicks
   bool   preferBalancedWicks;
   // Balance tolerance factor in [0..1]; 0 strict, 1 lenient. Used only for scoring if preferBalancedWicks=true
   double wickBalanceTolerance;
   // Tag subtype? (auto: long_legged / dragonfly / gravestone / standard)
   bool   classifySubtype;

   DojiParams()
   {
      maxBodyPctTR        = 0.10;
      minTRPoints         = 0.0;
      minWickToBodyRatio  = 0.0;   // disabled by default
      preferBalancedWicks = true;
      wickBalanceTolerance= 0.30;
      classifySubtype     = true;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new DojiParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "DojiParams{maxBodyPctTR=%.2f, minTRPoints=%.2f, minWickToBodyRatio=%.2f, "
         "preferBalancedWicks=%s, wickBalanceTolerance=%.2f, classifySubtype=%s}",
         maxBodyPctTR, minTRPoints, minWickToBodyRatio,
         (preferBalancedWicks ? "true":"false"), wickBalanceTolerance,
         (classifySubtype ? "true":"false")
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const DojiParams* o = (const DojiParams*)other; // compare fields using dot (.)
      return MathAbs(maxBodyPctTR - o.maxBodyPctTR) < 1e-9
          && MathAbs(minTRPoints - o.minTRPoints) < 1e-9
          && MathAbs(minWickToBodyRatio - o.minWickToBodyRatio) < 1e-9
          && preferBalancedWicks == o.preferBalancedWicks
          && MathAbs(wickBalanceTolerance - o.wickBalanceTolerance) < 1e-9
          && classifySubtype == o.classifySubtype;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class DojiDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "Doji";
      d.category = PatternSingleCandle;
      d.legs     = 1;
      return d;
   }

   DojiDetector()
   : AbstractPatternDetector(MakeDescriptor(), new DojiParams()) {}

   DojiDetector(const DojiParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   DojiDetector(const DojiDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new DojiDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b)  { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b) { return (b.high - b.low); }
   static double UpperWick(const MqlRates &b) { return b.high - MathMax(b.open, b.close); }
   static double LowerWick(const MqlRates &b) { return MathMin(b.open, b.close) - b.low; }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const DojiParams* e = (const DojiParams*)p;
      if(e.maxBodyPctTR < 0.0 || e.maxBodyPctTR > 1.0) return false;
      if(e.minTRPoints < 0.0) return false;
      if(e.minWickToBodyRatio < 0.0) return false;
      if(e.wickBalanceTolerance < 0.0 || e.wickBalanceTolerance > 1.0) return false;
      return true;
   }

   // Score: smaller body & longer/balanced wicks → higher score (0..100)
   static double ScoreDoji(const double bodyPctTR,
                           const double uw,
                           const double lw,
                           const double body,
                           const DojiParams &P,
                           string &subtypeOut)
   {
      // Body smallness score: 1 at 0, 0 at P.maxBodyPctTR (clip)
      double smallBody01 = 1.0 - MathMin(1.0, MathMax(0.0, bodyPctTR / MathMax(1e-12, P.maxBodyPctTR)));

      // Wick length score: compare both wicks to body (if body=0, treat as strong)
      double wrU = (body>0.0 ? uw/body : 2.0);
      double wrL = (body>0.0 ? lw/body : 2.0);
      double longWicks01 = MathMin(1.0, (wrU + wrL) / 4.0); // ≥4x body combined gives full credit

      // Balance score (optional)
      double balance01 = 1.0;
      if(P.preferBalancedWicks)
      {
         double sum = uw + lw;
         if(sum > 0.0)
         {
            double diffRatio = MathAbs(uw - lw) / sum; // 0 perfect, 1 very imbalanced
            // map [0 .. tol .. 1] -> [1 .. ~0.4 .. 0]
            double tol = MathMax(1e-12, P.wickBalanceTolerance);
            balance01 = MathMax(0.0, 1.0 - (diffRatio / (1.0 + tol)));
         }
      }

      // Subtype classification
      subtypeOut = "doji";
      if(P.classifySubtype)
      {
         const double tr = uw + lw + body;
         double uPct = (tr>0.0 ? uw/tr : 0.0);
         double lPct = (tr>0.0 ? lw/tr : 0.0);
         if(uPct > 0.6 && lPct < 0.2) subtypeOut = "gravestone_doji";
         else if(lPct > 0.6 && uPct < 0.2) subtypeOut = "dragonfly_doji";
         else if(uPct > 0.35 && lPct > 0.35) subtypeOut = "long_legged_doji";
         else subtypeOut = "doji";
      }

      // Blend
      double wBody=0.45, wWicks=0.35, wBal=0.20;
      double score01 = wBody*smallBody01 + wWicks*longWicks01 + wBal*balance01;
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
      // Copy params to local value so we can use dot (.) and avoid '->'
      const DojiParams* Pptr = (const DojiParams*)m_params;
      if(Pptr==NULL) return false;
      DojiParams P = *Pptr;

      // Need one bar at 'shift'
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, shift, 1, r))
         return false;

      const MqlRates c = r[0];
      const double body = BodySize(c);
      const double tr   = TrueRange(c);
      if(tr <= 0.0) return false;

      if(P.minTRPoints > 0.0 && tr < P.minTRPoints) return false;

      const double bodyPctTR = body / tr;
      if(bodyPctTR > P.maxBodyPctTR) return false;

      const double uw = UpperWick(c);
      const double lw = LowerWick(c);

      if(P.minWickToBodyRatio > 0.0)
      {
         // Both wicks should be at least ratio * body; if body≈0, treat as satisfied.
         if(body > 0.0)
         {
            if(uw < P.minWickToBodyRatio * body) return false;
            if(lw < P.minWickToBodyRatio * body) return false;
         }
      }

      string subtype;
      const double score = ScoreDoji(bodyPctTR, uw, lw, body, P, subtype);

      out.direction  = PatternNone;         // Doji itself is neutral
      out.score      = score;
      out.time       = c.time;
      out.price_hint = c.close;
      out.tag        = subtype;

      return true;
   }
};

#endif // PATTERNS_DOJI_MQH
