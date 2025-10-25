#ifndef PATTERNS_MORNINGSTAR_MQH
#define PATTERNS_MORNINGSTAR_MQH

// MorningStar.mqh
// Bullish "Morning Star" pattern implemented with the OOP strategy base.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class MorningStarParams : public IPatternParams
{
public:
   // 1) Strong bearish first candle
   double minFirstBodyPctTR;      // body/TR of 1st bar must be >= this (e.g., 0.50)
   double minFirstBodyPoints;     // absolute min body size (points), 0 = disabled

   // 2) Small "star" (middle) candle
   double maxStarBodyPctTR;       // body/TR of 2nd bar must be <= this (e.g., 0.35)
   bool   requireGapDown;         // classic gap-down into the star
   bool   allowNearBottomIfNoGap; // if no strict gap, enforce star near bottom of first body
   double minStarBelowFirstMidPct;// fraction below first-body midpoint (0..1), e.g., 0.00..1.00

   // 3) Strong bullish third candle
   double minThirdBodyPctFirst;   // body_third >= this * body_first (e.g., 0.60)
   double minPenetrationPct;      // close_third must penetrate this fraction into first body from bottom (e.g., 0.50 = above midpoint)
   double minThirdBodyPoints;     // absolute min body size (points), 0 = disabled

   MorningStarParams()
   {
      minFirstBodyPctTR       = 0.50;
      minFirstBodyPoints      = 0.0;
      maxStarBodyPctTR        = 0.35;
      requireGapDown          = false;
      allowNearBottomIfNoGap  = true;
      minStarBelowFirstMidPct = 0.00;
      minThirdBodyPctFirst    = 0.60;
      minPenetrationPct       = 0.50;
      minThirdBodyPoints      = 0.0;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new MorningStarParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "MorningStarParams{minFirstBodyPctTR=%.2f, minFirstBodyPoints=%.2f, "
         "maxStarBodyPctTR=%.2f, requireGapDown=%s, allowNearBottomIfNoGap=%s, minStarBelowFirstMidPct=%.2f, "
         "minThirdBodyPctFirst=%.2f, minPenetrationPct=%.2f, minThirdBodyPoints=%.2f}",
         minFirstBodyPctTR, minFirstBodyPoints,
         maxStarBodyPctTR, (requireGapDown ? "true" : "false"),
         (allowNearBottomIfNoGap ? "true" : "false"), minStarBelowFirstMidPct,
         minThirdBodyPctFirst, minPenetrationPct, minThirdBodyPoints
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const MorningStarParams* o = (const MorningStarParams*)other;
      return MathAbs(minFirstBodyPctTR - o.minFirstBodyPctTR) < 1e-9
          && MathAbs(minFirstBodyPoints - o.minFirstBodyPoints) < 1e-9
          && MathAbs(maxStarBodyPctTR - o.maxStarBodyPctTR) < 1e-9
          && requireGapDown == o.requireGapDown
          && allowNearBottomIfNoGap == o.allowNearBottomIfNoGap
          && MathAbs(minStarBelowFirstMidPct - o.minStarBelowFirstMidPct) < 1e-9
          && MathAbs(minThirdBodyPctFirst - o.minThirdBodyPctFirst) < 1e-9
          && MathAbs(minPenetrationPct - o.minPenetrationPct) < 1e-9
          && MathAbs(minThirdBodyPoints - o.minThirdBodyPoints) < 1e-9;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class MorningStarDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "MorningStar";
      d.category = PatternTripleCandle;
      d.legs     = 3;
      return d;
   }

   // Ctors
   MorningStarDetector()
   : AbstractPatternDetector(MakeDescriptor(), new MorningStarParams()) {}

   MorningStarDetector(const MorningStarParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   MorningStarDetector(const MorningStarDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new MorningStarDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b) { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b){ return (b.high - b.low); }
   static bool   IsBull(const MqlRates &b)   { return b.close > b.open; }
   static bool   IsBear(const MqlRates &b)   { return b.close < b.open; }

   // Parameter validation
   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const MorningStarParams* e = (const MorningStarParams*)p;
      if(e.minFirstBodyPctTR < 0.0 || e.minFirstBodyPctTR > 1.0) return false;
      if(e.maxStarBodyPctTR  < 0.0 || e.maxStarBodyPctTR  > 1.0) return false;
      if(e.minStarBelowFirstMidPct < 0.0 || e.minStarBelowFirstMidPct > 1.0) return false;
      if(e.minThirdBodyPctFirst < 0.0) return false;
      if(e.minPenetrationPct < 0.0 || e.minPenetrationPct > 1.0) return false;
      if(e.minFirstBodyPoints < 0.0 || e.minThirdBodyPoints < 0.0) return false;
      return true;
   }

   // Score blend (0..100) mirroring Evening Star logic
   static double ScoreMorningStar(const double firstBodyPctTR,
                                  const double starBodyPctTR,
                                  const double thirdBodyRelFirst,
                                  const double penetrationPct,
                                  const bool   hadGap)
   {
      double strongFirst = MathMin(1.0, MathMax(0.0, (firstBodyPctTR - 0.3) / 0.7)); // bigger bearish first → stronger
      double tinyStar    = MathMin(1.0, MathMax(0.0, (0.5 - starBodyPctTR) / 0.5));  // smaller star → stronger
      double bigThird    = MathMin(1.0, MathMax(0.0, (thirdBodyRelFirst - 0.3) / 0.7)); // bigger bullish third → stronger
      double deepPen     = MathMin(1.0, MathMax(0.0, penetrationPct));                // deeper penetration up → stronger
      double gapBoost    = hadGap ? 0.1 : 0.0;

      double wFirst = 0.30, wStar = 0.25, wThird = 0.25, wPen = 0.20;
      double score01 = wFirst*strongFirst + wStar*tinyStar + wThird*bigThird + wPen*deepPen + gapBoost;
      if(score01 > 1.0) score01 = 1.0;
      if(score01 < 0.0) score01 = 0.0;
      return score01 * 100.0;
   }

   // Core detection
   virtual bool DetectImpl(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift,
                           const IMarketData &md,
                           PatternSignal &out) const
   {
      const MorningStarParams* P = (const MorningStarParams*)m_params;
      if(P==NULL) return false;

      // Need three bars: current [shift] = third (bullish), [shift+1] = star, [shift+2] = first (bearish)
      MqlRates rr[];
      if(!md.GetRates(symbol, timeframe, shift, 3, rr))
         return false;

      const MqlRates c0 = rr[0]; // third (current)
      const MqlRates c1 = rr[1]; // star (middle)
      const MqlRates c2 = rr[2]; // first (left)

      // Sizes
      const double b2 = BodySize(c2);
      const double tr2= TrueRange(c2);
      const double b1 = BodySize(c1);
      const double tr1= TrueRange(c1);
      const double b0 = BodySize(c0);
      const double tr0= TrueRange(c0);

      if(tr2<=0.0 || tr1<=0.0 || tr0<=0.0) return false;
      if(b2<=0.0 || b1<=0.0 || b0<=0.0) return false;

      // Absolute minima
      if(P.minFirstBodyPoints>0.0 && b2 < P.minFirstBodyPoints) return false;
      if(P.minThirdBodyPoints>0.0 && b0 < P.minThirdBodyPoints) return false;

      // Colors: first bearish, third bullish
      if(!IsBear(c2)) return false;
      if(!IsBull(c0)) return false;

      // First candle strength
      const double firstBodyPctTR = b2 / tr2;
      if(firstBodyPctTR < P.minFirstBodyPctTR) return false;

      // Star smallness
      const double starBodyPctTR = b1 / tr1;
      if(starBodyPctTR > P.maxStarBodyPctTR) return false;

      // Gap / placement relative to first body
      bool hadGap = false;
      const double firstBodyLo = MathMin(c2.open, c2.close);
      const double firstBodyHi = MathMax(c2.open, c2.close);
      const double starBodyLo  = MathMin(c1.open, c1.close);
      const double starBodyHi  = MathMax(c1.open, c1.close);

      if(P.requireGapDown)
      {
         // Strict classic: star entirely below first body's low
         if(starBodyHi < firstBodyLo)
            hadGap = true;
         else
            return false;
      }
      else
      {
         if(P.allowNearBottomIfNoGap)
         {
            // Require star near bottom of first body:
            // starBodyHi <= firstBodyHi - minStarBelowFirstMidPct * (firstBodyHi - firstBodyLo)
            const double threshold = firstBodyHi - P.minStarBelowFirstMidPct * (firstBodyHi - firstBodyLo);
            if(starBodyHi > threshold) return false;
         }
      }

      // Third candle penetration into first body from bottom up:
      // required close >= firstBodyLo + minPenetrationPct * (firstBodyHi - firstBodyLo)
      const double requiredClose = firstBodyLo + P.minPenetrationPct * (firstBodyHi - firstBodyLo);
      if(c0.close < requiredClose) return false;

      // Third body relative to first
      const double thirdBodyRelFirst = (b2>0.0 ? (b0 / b2) : 0.0);
      if(thirdBodyRelFirst < P.minThirdBodyPctFirst) return false;

      // Score
      const double score = ScoreMorningStar(firstBodyPctTR, starBodyPctTR, thirdBodyRelFirst, P.minPenetrationPct, hadGap);

      // Fill signal
      out.direction  = PatternBullish;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = hadGap ? "morning_star_gap" : "morning_star";

      return true;
   }
};

#endif // PATTERNS_MORNINGSTAR_MQH
