#ifndef PATTERNS_EVENINGSTAR_MQH
#define PATTERNS_EVENINGSTAR_MQH

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class EveningStarParams : public IPatternParams
{
public:
   double minFirstBodyPctTR;
   double minFirstBodyPoints;
   double maxStarBodyPctTR;
   bool   requireGapUp;
   bool   allowNearTopIfNoGap;
   double minStarAboveFirstMidPct;
   double minThirdBodyPctFirst;
   double minPenetrationPct;
   double minThirdBodyPoints;

   EveningStarParams()
   {
      minFirstBodyPctTR     = 0.50;
      minFirstBodyPoints    = 0.0;
      maxStarBodyPctTR      = 0.35;
      requireGapUp          = false;
      allowNearTopIfNoGap   = true;
      minStarAboveFirstMidPct = 0.00;
      minThirdBodyPctFirst  = 0.60;
      minPenetrationPct     = 0.50;
      minThirdBodyPoints    = 0.0;
   }

   virtual IPatternParams* Clone() const { return new EveningStarParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "EveningStarParams{minFirstBodyPctTR=%.2f, minFirstBodyPoints=%.2f, "
         "maxStarBodyPctTR=%.2f, requireGapUp=%s, allowNearTopIfNoGap=%s, minStarAboveFirstMidPct=%.2f, "
         "minThirdBodyPctFirst=%.2f, minPenetrationPct=%.2f, minThirdBodyPoints=%.2f}",
         minFirstBodyPctTR, minFirstBodyPoints,
         maxStarBodyPctTR, (requireGapUp ? "true" : "false"),
         (allowNearTopIfNoGap ? "true" : "false"), minStarAboveFirstMidPct,
         minThirdBodyPctFirst, minPenetrationPct, minThirdBodyPoints
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const EveningStarParams* o = (const EveningStarParams*)other;
      return MathAbs(minFirstBodyPctTR - o.minFirstBodyPctTR) < 1e-9
          && MathAbs(minFirstBodyPoints - o.minFirstBodyPoints) < 1e-9
          && MathAbs(maxStarBodyPctTR - o.maxStarBodyPctTR) < 1e-9
          && requireGapUp == o.requireGapUp
          && allowNearTopIfNoGap == o.allowNearTopIfNoGap
          && MathAbs(minStarAboveFirstMidPct - o.minStarAboveFirstMidPct) < 1e-9
          && MathAbs(minThirdBodyPctFirst - o.minThirdBodyPctFirst) < 1e-9
          && MathAbs(minPenetrationPct - o.minPenetrationPct) < 1e-9
          && MathAbs(minThirdBodyPoints - o.minThirdBodyPoints) < 1e-9;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class EveningStarDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "EveningStar";
      d.category = PatternTripleCandle;
      d.legs     = 3;
      return d;
   }

   EveningStarDetector()
   : AbstractPatternDetector(MakeDescriptor(), new EveningStarParams()) {}

   EveningStarDetector(const EveningStarParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   EveningStarDetector(const EveningStarDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new EveningStarDetector(*this); }

protected:
   static double BodySize(const MqlRates &b) { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b){ return (b.high - b.low); }
   static bool   IsBull(const MqlRates &b)   { return b.close > b.open; }
   static bool   IsBear(const MqlRates &b)   { return b.close < b.open; }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const EveningStarParams* e = (const EveningStarParams*)p;
      if(e.minFirstBodyPctTR < 0.0 || e.minFirstBodyPctTR > 1.0) return false;
      if(e.maxStarBodyPctTR  < 0.0 || e.maxStarBodyPctTR  > 1.0) return false;
      if(e.minStarAboveFirstMidPct < 0.0 || e.minStarAboveFirstMidPct > 1.0) return false;
      return true;
   }

   virtual bool DetectImpl(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift,
                           const IMarketData &md,
                           PatternSignal &out) const
   {
      const EveningStarParams* P = (const EveningStarParams*)m_params;
      if(P==NULL) return false;

      MqlRates rr[];
      if(!md.GetRates(symbol, timeframe, shift, 3, rr))
         return false;

      const MqlRates c0 = rr[0]; // third
      const MqlRates c1 = rr[1]; // star
      const MqlRates c2 = rr[2]; // first

      // Check colors
      if(!IsBull(c2)) return false;
      if(!IsBear(c0)) return false;

      double b2 = BodySize(c2);
      double tr2= TrueRange(c2);
      double b1 = BodySize(c1);
      double tr1= TrueRange(c1);
      double b0 = BodySize(c0);

      if(tr2<=0.0 || tr1<=0.0 || b2<=0.0 || b1<=0.0 || b0<=0.0) return false;
      if(P.minFirstBodyPoints > 0 && b2 < P.minFirstBodyPoints) return false;
      if(P.minThirdBodyPoints > 0 && b0 < P.minThirdBodyPoints) return false;

      double firstBodyPctTR = b2/tr2;
      if(firstBodyPctTR < P.minFirstBodyPctTR) return false;

      double starBodyPctTR = b1/tr1;
      if(starBodyPctTR > P.maxStarBodyPctTR) return false;

      // Penetration: third close below midpoint of first
      double firstMid = (c2.open + c2.close) / 2.0;
      if(c0.close > firstMid) return false;

      // Fill signal
      out.direction  = PatternBearish;
      out.score      = 80; // fixed baseline score, or compute like before
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = "evening_star";

      return true;
   }
};

#endif // PATTERNS_EVENINGSTAR_MQH
