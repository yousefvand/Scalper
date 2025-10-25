#ifndef PATTERNS_DRAGONFLYDOJI_MQH
#define PATTERNS_DRAGONFLYDOJI_MQH

// DragonflyDoji.mqh
// Bullish-leaning "Dragonfly Doji" using the OOP strategy base (PatternBase.mqh).
// Definition: tiny real body near the HIGH, very long lower shadow, minimal upper shadow.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class DragonflyDojiParams : public IPatternParams
{
public:
   // Body must be <= this fraction of True Range (0..1). Typical: ≤ 10%.
   double maxBodyPctTR;

   // Upper wick must be <= this fraction of True Range (0..1). Typical: ≤ 10–15%.
   double maxUpperWickPctTR;

   // Lower wick must be >= this multiple of body size. Typical: ≥ 3x body.
   double minLowerWickToBody;

   // Optional: minimum TR (points) to ignore micro-bars (0 disables).
   double minTRPoints;

   // Optional context: prefer detection after a downswing (bearish move) for reversal bias.
   bool   preferDownswingContext;
   int    downswingLookback; // bars to check prior to this candle (e.g., 3)

   DragonflyDojiParams()
   {
      maxBodyPctTR           = 0.10;
      maxUpperWickPctTR      = 0.12;
      minLowerWickToBody     = 3.0;
      minTRPoints            = 0.0;
      preferDownswingContext = false;
      downswingLookback      = 3;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new DragonflyDojiParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "DragonflyDojiParams{maxBodyPctTR=%.2f, maxUpperWickPctTR=%.2f, minLowerWickToBody=%.2f, "
         "minTRPoints=%.2f, preferDownswingContext=%s, downswingLookback=%d}",
         maxBodyPctTR, maxUpperWickPctTR, minLowerWickToBody,
         minTRPoints, (preferDownswingContext ? "true":"false"), downswingLookback
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const DragonflyDojiParams* o = (const DragonflyDojiParams*)other;
      return MathAbs(maxBodyPctTR - o.maxBodyPctTR) < 1e-9
          && MathAbs(maxUpperWickPctTR - o.maxUpperWickPctTR) < 1e-9
          && MathAbs(minLowerWickToBody - o.minLowerWickToBody) < 1e-9
          && MathAbs(minTRPoints - o.minTRPoints) < 1e-9
          && preferDownswingContext == o.preferDownswingContext
          && downswingLookback == o.downswingLookback;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class DragonflyDojiDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "DragonflyDoji";
      d.category = PatternSingleCandle;
      d.legs     = 1;
      return d;
   }

   DragonflyDojiDetector()
   : AbstractPatternDetector(MakeDescriptor(), new DragonflyDojiParams()) {}

   DragonflyDojiDetector(const DragonflyDojiParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   DragonflyDojiDetector(const DragonflyDojiDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new DragonflyDojiDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b)  { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b) { return (b.high - b.low); }
   static double UpperWick(const MqlRates &b) { return b.high - MathMax(b.open, b.close); }
   static double LowerWick(const MqlRates &b) { return MathMin(b.open, b.close) - b.low; }
   static bool   IsBull(const MqlRates &b)    { return b.close > b.open; }
   static bool   IsBear(const MqlRates &b)    { return b.close < b.open; }

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
      const DragonflyDojiParams* e = (const DragonflyDojiParams*)p;
      if(e.maxBodyPctTR < 0.0 || e.maxBodyPctTR > 1.0) return false;
      if(e.maxUpperWickPctTR < 0.0 || e.maxUpperWickPctTR > 1.0) return false;
      if(e.minLowerWickToBody < 0.0) return false;
      if(e.minTRPoints < 0.0) return false;
      if(e.downswingLookback < 0) return false;
      return true;
   }

   // Scoring: smaller body, tiny upper wick, longer lower wick, (optional) downswing context.
   static double ScoreDragonfly(const double bodyPctTR,
                                const double upperWickPctTR,
                                const double lowerToBody,
                                const bool   hadDownswing)
   {
      // Normalize components to 0..1
      double smallBody = 1.0 - MathMin(1.0, bodyPctTR / 0.12);       // full at 0, fades by ~12% TR
      double tinyUpper = 1.0 - MathMin(1.0, upperWickPctTR / 0.15);  // full at 0, fades by ~15% TR
      double longLower = MathMin(1.0, lowerToBody / 4.0);            // full credit ~4x body
      double bonus     = hadDownswing ? 0.10 : 0.0;                   // +10% if context present

      double wBody=0.35, wUpper=0.25, wLower=0.40;
      double score01 = wBody*smallBody + wUpper*tinyUpper + wLower*longLower + bonus;
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
      const DragonflyDojiParams* P = (const DragonflyDojiParams*)m_params;
      if(P==NULL) return false;

      // Single bar at 'shift'
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, shift, 1, r))
         return false;
      const MqlRates c = r[0];

      const double body = BodySize(c);
      const double tr   = TrueRange(c);
      if(tr <= 0.0) return false;

      if(P.minTRPoints > 0.0 && tr < P.minTRPoints) return false;

      const double uw = UpperWick(c);
      const double lw = LowerWick(c);

      const double bodyPctTR      = body / tr;
      const double upperWickPctTR = uw / tr;
      const double lowerToBody    = (body > 0.0 ? lw / body : (lw>0.0 ? 10.0 : 0.0)); // if body≈0, treat as very large

      // Geometry checks for dragonfly
      if(bodyPctTR > P.maxBodyPctTR) return false;
      if(upperWickPctTR > P.maxUpperWickPctTR) return false;
      if(lowerToBody < P.minLowerWickToBody) return false;

      // Optional context: downswing before this bar
      bool hadDown = true;
      if(P.preferDownswingContext)
         hadDown = HasRecentDownswing(symbol, timeframe, shift+1, P.downswingLookback, md);
      if(!hadDown && P.preferDownswingContext) return false;

      // Score and fill
      const double score = ScoreDragonfly(bodyPctTR, upperWickPctTR, lowerToBody, hadDown);

      out.direction  = PatternBullish;    // Bullish-leaning reversal; adjust in manager if you prefer neutral
      out.score      = score;
      out.time       = c.time;
      out.price_hint = c.close;
      out.tag        = "dragonfly_doji";

      return true;
   }
};

#endif // PATTERNS_DRAGONFLYDOJI_MQH
