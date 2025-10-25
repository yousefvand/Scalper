#ifndef PATTERNS_GRAVESTONEDOJI_MQH
#define PATTERNS_GRAVESTONEDOJI_MQH

// GravestoneDoji.mqh
// Bearish-leaning "Gravestone Doji" using the OOP strategy base (PatternBase.mqh).
// Definition: tiny real body near the LOW, very long upper shadow, minimal lower shadow.

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class GravestoneDojiParams : public IPatternParams
{
public:
   // Body must be <= this fraction of True Range (0..1). Typical: ≤ 10%.
   double maxBodyPctTR;

   // Lower wick must be <= this fraction of True Range (0..1). Typical: ≤ 10–15%.
   double maxLowerWickPctTR;

   // Upper wick must be >= this multiple of body size. Typical: ≥ 3x body.
   double minUpperWickToBody;

   // Optional: minimum TR (points) to ignore micro-bars (0 disables).
   double minTRPoints;

   // Optional context: prefer detection after an upswing (bullish move) for reversal bias.
   bool   preferUpswingContext;
   int    upswingLookback; // bars to check prior to this candle (e.g., 3)

   GravestoneDojiParams()
   {
      maxBodyPctTR         = 0.10;
      maxLowerWickPctTR    = 0.12;
      minUpperWickToBody   = 3.0;
      minTRPoints          = 0.0;
      preferUpswingContext = false;
      upswingLookback      = 3;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new GravestoneDojiParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "GravestoneDojiParams{maxBodyPctTR=%.2f, maxLowerWickPctTR=%.2f, minUpperWickToBody=%.2f, "
         "minTRPoints=%.2f, preferUpswingContext=%s, upswingLookback=%d}",
         maxBodyPctTR, maxLowerWickPctTR, minUpperWickToBody,
         minTRPoints, (preferUpswingContext ? "true":"false"), upswingLookback
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const GravestoneDojiParams* o = (const GravestoneDojiParams*)other;
      return MathAbs(maxBodyPctTR - o.maxBodyPctTR) < 1e-9
          && MathAbs(maxLowerWickPctTR - o.maxLowerWickPctTR) < 1e-9
          && MathAbs(minUpperWickToBody - o.minUpperWickToBody) < 1e-9
          && MathAbs(minTRPoints - o.minTRPoints) < 1e-9
          && preferUpswingContext == o.preferUpswingContext
          && upswingLookback == o.upswingLookback;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class GravestoneDojiDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "GravestoneDoji";
      d.category = PatternSingleCandle;
      d.legs     = 1;
      return d;
   }

   GravestoneDojiDetector()
   : AbstractPatternDetector(MakeDescriptor(), new GravestoneDojiParams()) {}

   GravestoneDojiDetector(const GravestoneDojiParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   GravestoneDojiDetector(const GravestoneDojiDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new GravestoneDojiDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b)  { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b) { return (b.high - b.low); }
   static double UpperWick(const MqlRates &b) { return b.high - MathMax(b.open, b.close); }
   static double LowerWick(const MqlRates &b) { return MathMin(b.open, b.close) - b.low; }

   static bool HasRecentUpswing(const string symbol,
                                const ENUM_TIMEFRAMES timeframe,
                                const int afterShift,  // bar right after target
                                const int lookback,
                                const IMarketData &md)
   {
      if(lookback <= 0) return true;
      MqlRates r[];
      if(!md.GetRates(symbol, timeframe, afterShift, lookback+1, r))
         return false;
      int rises=0;
      for(int i=1;i<=lookback;i++)
         if(r[i-1].close < r[i].close) rises++;
      return (rises > lookback/2);
   }

   virtual bool ValidateParams(const IPatternParams* p) const
   {
      if(p==NULL) return false;
      const GravestoneDojiParams* e = (const GravestoneDojiParams*)p;
      if(e.maxBodyPctTR < 0.0 || e.maxBodyPctTR > 1.0) return false;
      if(e.maxLowerWickPctTR < 0.0 || e.maxLowerWickPctTR > 1.0) return false;
      if(e.minUpperWickToBody < 0.0) return false;
      if(e.minTRPoints < 0.0) return false;
      if(e.upswingLookback < 0) return false;
      return true;
   }

   // Scoring: smaller body, tiny lower wick, longer upper wick, (optional) upswing context.
   static double ScoreGravestone(const double bodyPctTR,
                                 const double lowerWickPctTR,
                                 const double upperToBody,
                                 const bool   hadUpswing)
   {
      double smallBody = 1.0 - MathMin(1.0, bodyPctTR / 0.12);       // full at 0, fades by ~12% TR
      double tinyLower = 1.0 - MathMin(1.0, lowerWickPctTR / 0.15);  // full at 0, fades by ~15% TR
      double longUpper = MathMin(1.0, upperToBody / 4.0);            // full credit ~4x body
      double bonus     = hadUpswing ? 0.10 : 0.0;                     // +10% if context present

      double wBody=0.35, wLower=0.25, wUpper=0.40;
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
      const GravestoneDojiParams* Pptr = (const GravestoneDojiParams*)m_params;
      if(Pptr==NULL) return false;
      GravestoneDojiParams P = *Pptr; // use dot-access

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

      const double bodyPctTR       = body / tr;
      const double lowerWickPctTR  = lw / tr;
      const double upperToBody     = (body > 0.0 ? uw / body : (uw>0.0 ? 10.0 : 0.0)); // if body≈0, treat as very large

      // Geometry checks for gravestone
      if(bodyPctTR > P.maxBodyPctTR) return false;
      if(lowerWickPctTR > P.maxLowerWickPctTR) return false;
      if(upperToBody < P.minUpperWickToBody) return false;

      // Optional context: upswing before this bar
      bool hadUp = true;
      if(P.preferUpswingContext)
         hadUp = HasRecentUpswing(symbol, timeframe, shift+1, P.upswingLookback, md);
      if(!hadUp && P.preferUpswingContext) return false;

      // Score and fill
      const double score = ScoreGravestone(bodyPctTR, lowerWickPctTR, upperToBody, hadUp);

      out.direction  = PatternBearish;   // Bearish-leaning reversal; adjust in manager if you prefer neutral
      out.score      = score;
      out.time       = c.time;
      out.price_hint = c.close;
      out.tag        = "gravestone_doji";

      return true;
   }
};

#endif // PATTERNS_GRAVESTONEDOJI_MQH
