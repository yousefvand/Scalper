#ifndef PATTERNS_THREEINSIDEUPDOWN_MQH
#define PATTERNS_THREEINSIDEUPDOWN_MQH

// ThreeInsideUpDown.mqh
// Bullish "Three Inside Up" and bearish "Three Inside Down"
// implemented with the OOP strategy base (PatternBase.mqh).

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class ThreeInsideParams : public IPatternParams
{
public:
   // Enable which sides to detect
   bool   enableBullish;                // Three Inside Up
   bool   enableBearish;                // Three Inside Down

   // Candle 1 (trend candle) requirements
   double minFirstBodyPctTR;            // e.g., 0.50 (strong body vs TR)
   double minFirstBodyPoints;           // absolute min body size (points), 0 = disabled

   // Candle 2 (harami) requirements
   bool   requireOppositeColors12;      // classic: opposite color to candle 1
   bool   requireSecondInsideFirstBody; // second candle body fully inside first body
   bool   inclusiveEdges;               // allow equal edges when checking "inside"
   double maxSecondBodyPctTR;           // e.g., <= 0.40 ⇒ "small" star/harami body

   // Candle 3 (confirmation) requirements
   double minThirdBodyPctFirst;         // e.g., >= 0.50 * body(first)
   double minThirdBodyPoints;           // absolute min body size (points), 0 = disabled

   // Confirmation style:
   //  - strictBreak: candle 3 close must break first candle extreme (Up: > high1, Down: < low1)
   //  - otherwise: require penetration beyond first-body midpoint by minPenetrationPct
   bool   requireStrictBreak;
   double minPenetrationPct;            // 0..1 (only used if !strictBreak)

   ThreeInsideParams()
   {
      enableBullish                = true;
      enableBearish                = true;

      minFirstBodyPctTR            = 0.50;
      minFirstBodyPoints           = 0.0;

      requireOppositeColors12      = true;
      requireSecondInsideFirstBody = true;
      inclusiveEdges               = true;
      maxSecondBodyPctTR           = 0.40;

      minThirdBodyPctFirst         = 0.60;
      minThirdBodyPoints           = 0.0;

      requireStrictBreak           = false;
      minPenetrationPct            = 0.50; // midpoint by default
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new ThreeInsideParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "ThreeInsideParams{enableBullish=%s, enableBearish=%s, "
         "minFirstBodyPctTR=%.2f, minFirstBodyPoints=%.2f, "
         "requireOppositeColors12=%s, requireSecondInsideFirstBody=%s, inclusiveEdges=%s, maxSecondBodyPctTR=%.2f, "
         "minThirdBodyPctFirst=%.2f, minThirdBodyPoints=%.2f, requireStrictBreak=%s, minPenetrationPct=%.2f}",
         (enableBullish?"true":"false"), (enableBearish?"true":"false"),
         minFirstBodyPctTR, minFirstBodyPoints,
         (requireOppositeColors12?"true":"false"),
         (requireSecondInsideFirstBody?"true":"false"),
         (inclusiveEdges?"true":"false"),
         maxSecondBodyPctTR,
         minThirdBodyPctFirst, minThirdBodyPoints,
         (requireStrictBreak?"true":"false"), minPenetrationPct
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const ThreeInsideParams* o = (const ThreeInsideParams*)other;
      return enableBullish == o.enableBullish
          && enableBearish == o.enableBearish
          && MathAbs(minFirstBodyPctTR - o.minFirstBodyPctTR) < 1e-9
          && MathAbs(minFirstBodyPoints - o.minFirstBodyPoints) < 1e-9
          && requireOppositeColors12 == o.requireOppositeColors12
          && requireSecondInsideFirstBody == o.requireSecondInsideFirstBody
          && inclusiveEdges == o.inclusiveEdges
          && MathAbs(maxSecondBodyPctTR - o.maxSecondBodyPctTR) < 1e-9
          && MathAbs(minThirdBodyPctFirst - o.minThirdBodyPctFirst) < 1e-9
          && MathAbs(minThirdBodyPoints - o.minThirdBodyPoints) < 1e-9
          && requireStrictBreak == o.requireStrictBreak
          && MathAbs(minPenetrationPct - o.minPenetrationPct) < 1e-9;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class ThreeInsideDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "ThreeInsideUpDown";
      d.category = PatternTripleCandle;
      d.legs     = 3;
      return d;
   }

   ThreeInsideDetector()
   : AbstractPatternDetector(MakeDescriptor(), new ThreeInsideParams()) {}

   ThreeInsideDetector(const ThreeInsideParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   ThreeInsideDetector(const ThreeInsideDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new ThreeInsideDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b)   { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b)  { return (b.high - b.low); }
   static bool   IsBull(const MqlRates &b)     { return b.close > b.open; }
   static bool   IsBear(const MqlRates &b)     { return b.close < b.open; }

   static bool BodyInside(const MqlRates &inner, const MqlRates &outer, const bool inclusive)
   {
      const double inLo  = MathMin(inner.open, inner.close);
      const double inHi  = MathMax(inner.open, inner.close);
      const double outLo = MathMin(outer.open, outer.close);
      const double outHi = MathMax(outer.open, outer.close);
      if(inclusive) return (inLo >= outLo && inHi <= outHi);
      return (inLo > outLo && inHi < outHi);
   }

   static double InsideQuality(const MqlRates &inner, const MqlRates &outer) // 0..1, deeper inside = higher
   {
      const double inLo  = MathMin(inner.open, inner.close);
      const double inHi  = MathMax(inner.open, inner.close);
      const double outLo = MathMin(outer.open, outer.close);
      const double outHi = MathMax(outer.open, outer.close);
      const double outSpan = MathMax(1e-12, outHi - outLo);
      const double marginLo = MathMax(0.0, inLo - outLo);
      const double marginHi = MathMax(0.0, outHi - inHi);
      const double minMargin = MathMin(marginLo, marginHi);
      return MathMin(1.0, minMargin / (0.5 * outSpan)); // full score if inner body has at least 50% margin total
   }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const ThreeInsideParams* e = (const ThreeInsideParams*)p;
      if(e.minFirstBodyPctTR < 0.0 || e.minFirstBodyPctTR > 1.0) return false;
      if(e.maxSecondBodyPctTR < 0.0 || e.maxSecondBodyPctTR > 1.0) return false;
      if(e.minThirdBodyPctFirst < 0.0) return false;
      if(e.minPenetrationPct < 0.0 || e.minPenetrationPct > 1.0) return false;
      if(e.minFirstBodyPoints < 0.0 || e.minThirdBodyPoints < 0.0) return false;
      if(!e.enableBullish && !e.enableBearish) return false;
      return true;
   }

   // Scoring: combine first-candle strength, second-candle "inside smallness",
   // and third-candle confirmation strength. Return 0..100.
   static double ScoreThreeInside(const double firstBodyPctTR,
                                  const double secondBodyPctTR,
                                  const double insideQual01,
                                  const double thirdRelFirst,
                                  const bool   strictBreakMet,
                                  const double penetrationPct)
   {
      // Normalize components: higher firstBodyPctTR & thirdRelFirst are better,
      // lower secondBodyPctTR is better, insideQual01 already 0..1, penetration 0..1.
      double strongFirst = MathMin(1.0, MathMax(0.0, (firstBodyPctTR - 0.3) / 0.7));
      double smallSecond = MathMin(1.0, MathMax(0.0, (0.5 - secondBodyPctTR) / 0.5));
      double bigThird    = MathMin(1.0, MathMax(0.0, (thirdRelFirst - 0.3) / 0.7));
      double pen         = MathMin(1.0, MathMax(0.0, penetrationPct)); // if strict break, pen will be 1

      // Add a small bonus for strict break
      double bonus = strictBreakMet ? 0.1 : 0.0;

      double w1=0.30, w2=0.20, w3=0.20, w4=0.20, w5=0.10; // first, second, inside, third, penetration
      double score01 = w1*strongFirst + w2*smallSecond + w3*insideQual01 + w4*bigThird + w5*pen + bonus;
      if(score01 > 1.0) score01 = 1.0;
      if(score01 < 0.0) score01 = 0.0;
      return score01 * 100.0;
   }

   // Attempt bullish (Three Inside Up)
   bool TryBullish(const MqlRates &c0, const MqlRates &c1, const MqlRates &c2,
                   const ThreeInsideParams *P, PatternSignal &out) const
   {
      // Candle1 (c2) must be bearish; Candle2 (c1) bullish & inside; Candle3 (c0) bullish confirm
      if(!IsBear(c2) || !IsBull(c1) || !IsBull(c0)) return false;

      const double b2 = BodySize(c2), tr2 = TrueRange(c2);
      const double b1 = BodySize(c1), tr1 = TrueRange(c1);
      const double b0 = BodySize(c0);

      if(tr2<=0.0 || tr1<=0.0 || b2<=0.0 || b1<=0.0 || b0<=0.0) return false;
      if(P.minFirstBodyPoints>0.0 && b2 < P.minFirstBodyPoints) return false;
      if(P.minThirdBodyPoints>0.0 && b0 < P.minThirdBodyPoints) return false;

      const double firstBodyPctTR  = b2 / tr2;
      if(firstBodyPctTR < P.minFirstBodyPctTR) return false;

      const double secondBodyPctTR = b1 / tr1;
      if(secondBodyPctTR > P.maxSecondBodyPctTR) return false;

      if(P.requireOppositeColors12)
      {
         // already true (bearish then bullish)
      }

      if(P.requireSecondInsideFirstBody && !BodyInside(c1, c2, P.inclusiveEdges)) return false;

      // Confirmation: strict break or penetration
      bool strictOK = false;
      double penPct = 0.0;

      const double firstLo = MathMin(c2.open, c2.close);
      const double firstHi = MathMax(c2.open, c2.close);
      const double firstSpan = MathMax(1e-12, firstHi - firstLo);

      if(P.requireStrictBreak)
      {
         strictOK = (c0.close > firstHi);
         if(!strictOK) return false;
         penPct = 1.0; // full credit on strict
      }
      else
      {
         const double required = firstLo + P.minPenetrationPct * firstSpan;
         if(c0.close < required) return false;
         // Normalize how deep we penetrated (0..1)
         penPct = MathMin(1.0, MathMax(0.0, (c0.close - firstLo) / firstSpan));
      }

      const double thirdRelFirst = (b2>0.0 ? (b0 / b2) : 0.0);
      if(thirdRelFirst < P.minThirdBodyPctFirst) return false;

      const double insideQual01 = InsideQuality(c1, c2);

      // Score & fill
      const double score = ScoreThreeInside(firstBodyPctTR, secondBodyPctTR, insideQual01, thirdRelFirst, strictOK, penPct);
      out.direction  = PatternBullish;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = strictOK ? "three_inside_up_break" : "three_inside_up";
      return true;
   }

   // Attempt bearish (Three Inside Down)
   bool TryBearish(const MqlRates &c0, const MqlRates &c1, const MqlRates &c2,
                   const ThreeInsideParams *P, PatternSignal &out) const
   {
      // Candle1 (c2) must be bullish; Candle2 (c1) bearish & inside; Candle3 (c0) bearish confirm
      if(!IsBull(c2) || !IsBear(c1) || !IsBear(c0)) return false;

      const double b2 = BodySize(c2), tr2 = TrueRange(c2);
      const double b1 = BodySize(c1), tr1 = TrueRange(c1);
      const double b0 = BodySize(c0);

      if(tr2<=0.0 || tr1<=0.0 || b2<=0.0 || b1<=0.0 || b0<=0.0) return false;
      if(P.minFirstBodyPoints>0.0 && b2 < P.minFirstBodyPoints) return false;
      if(P.minThirdBodyPoints>0.0 && b0 < P.minThirdBodyPoints) return false;

      const double firstBodyPctTR  = b2 / tr2;
      if(firstBodyPctTR < P.minFirstBodyPctTR) return false;

      const double secondBodyPctTR = b1 / tr1;
      if(secondBodyPctTR > P.maxSecondBodyPctTR) return false;

      if(P.requireOppositeColors12)
      {
         // already true (bullish then bearish)
      }

      if(P.requireSecondInsideFirstBody && !BodyInside(c1, c2, P.inclusiveEdges)) return false;

      // Confirmation: strict break or penetration downward
      bool strictOK = false;
      double penPct = 0.0;

      const double firstLo = MathMin(c2.open, c2.close);
      const double firstHi = MathMax(c2.open, c2.close);
      const double firstSpan = MathMax(1e-12, firstHi - firstLo);

      if(P.requireStrictBreak)
      {
         strictOK = (c0.close < firstLo);
         if(!strictOK) return false;
         penPct = 1.0;
      }
      else
      {
         const double required = firstHi - P.minPenetrationPct * firstSpan;
         if(c0.close > required) return false;
         // Normalize depth downward (0..1)
         penPct = MathMin(1.0, MathMax(0.0, (firstHi - c0.close) / firstSpan));
      }

      const double thirdRelFirst = (b2>0.0 ? (b0 / b2) : 0.0);
      if(thirdRelFirst < P.minThirdBodyPctFirst) return false;

      const double insideQual01 = InsideQuality(c1, c2);

      // Score & fill
      const double score = ScoreThreeInside(firstBodyPctTR, secondBodyPctTR, insideQual01, thirdRelFirst, strictOK, penPct);
      out.direction  = PatternBearish;
      out.score      = score;
      out.time       = c0.time;
      out.price_hint = c0.close;
      out.tag        = strictOK ? "three_inside_down_break" : "three_inside_down";
      return true;
   }

   // Core detection
   virtual bool DetectImpl(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift,
                           const IMarketData &md,
                           PatternSignal &out) const
   {
      const ThreeInsideParams* P = (const ThreeInsideParams*)m_params;
      if(P==NULL) return false;

      // Need 3 bars: current [shift] = third, [shift+1] = second, [shift+2] = first
      MqlRates rr[];
      if(!md.GetRates(symbol, timeframe, shift, 3, rr))
         return false;

      const MqlRates c0 = rr[0]; // third (confirmation)
      const MqlRates c1 = rr[1]; // second (harami)
      const MqlRates c2 = rr[2]; // first  (trend candle)

      bool got = false;
      PatternSignal bull, bear;
      bull.score = 0.0; bear.score = 0.0;
      bull.direction = PatternNone; bear.direction = PatternNone;

      if(P.enableBullish)
         got |= TryBullish(c0, c1, c2, P, bull);

      if(P.enableBearish)
         got |= TryBearish(c0, c1, c2, P, bear);

      if(!got) return false;

      // If both matched (rare), pick higher score
      if(bull.direction != PatternNone && bear.direction != PatternNone)
      {
         out = (bull.score >= bear.score ? bull : bear);
         return true;
      }
      if(bull.direction != PatternNone) { out = bull; return true; }
      if(bear.direction != PatternNone) { out = bear; return true; }

      return false;
   }
};

#endif // PATTERNS_THREEINSIDEUPDOWN_MQH
