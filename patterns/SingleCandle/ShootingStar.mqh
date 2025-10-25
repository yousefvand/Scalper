#ifndef PATTERNS_SHOOTINGSTAR_MQH
#define PATTERNS_SHOOTINGSTAR_MQH

// ShootingStar.mqh
// Bearish-leaning "Shooting Star" using the OOP strategy base (PatternBase.mqh).
// Definition: small body near the LOW, very long upper shadow, minimal lower shadow,
// typically after an upswing (potential bearish reversal).

#include "../PatternBase.mqh"

//──────────────────────────────────────────────────────────────────────────────
// Parameters
//──────────────────────────────────────────────────────────────────────────────
class ShootingStarParams : public IPatternParams
{
public:
   // Body/TR should be small-to-medium (doji would be smaller). Typical cap ~40%.
   double maxBodyPctTR;

   // Lower wick should be very small (as fraction of TR).
   double maxLowerWickPctTR;

   // Upper wick must be >= this multiple of body (e.g., ≥ 2.0x).
   double minUpperWickToBody;

   // Optional: close should be in the lower X% of the candle range (0..1). 0 disables.
   double maxClosePositionInRange; // e.g., 0.35 ⇒ close in bottom 35% of (low..high)

   // Optional absolute guards
   double minTRPoints;   // ignore micro-bars (0 disables)
   double minBodyPoints; // avoid near-zero bodies (0 disables)

   // Optional context: prefer upswing before star (reversal bias).
   bool   preferUpswingContext;
   int    upswingLookback;

   ShootingStarParams()
   {
      maxBodyPctTR            = 0.40;
      maxLowerWickPctTR       = 0.20;
      minUpperWickToBody      = 2.0;
      maxClosePositionInRange = 0.35;
      minTRPoints             = 0.0;
      minBodyPoints           = 0.0;
      preferUpswingContext    = false;
      upswingLookback         = 3;
   }

   // IPatternParams
   virtual IPatternParams* Clone() const { return new ShootingStarParams(*this); }

   virtual string ToString() const
   {
      return StringFormat(
         "ShootingStarParams{maxBodyPctTR=%.2f, maxLowerWickPctTR=%.2f, minUpperWickToBody=%.2f, "
         "maxClosePositionInRange=%.2f, minTRPoints=%.2f, minBodyPoints=%.2f, "
         "preferUpswingContext=%s, upswingLookback=%d}",
         maxBodyPctTR, maxLowerWickPctTR, minUpperWickToBody,
         maxClosePositionInRange, minTRPoints, minBodyPoints,
         (preferUpswingContext ? "true":"false"), upswingLookback
      );
   }

   virtual bool Equals(const IPatternParams* other) const
   {
      if(other==NULL) return false;
      const ShootingStarParams* o = (const ShootingStarParams*)other;
      return MathAbs(maxBodyPctTR - o.maxBodyPctTR) < 1e-9
          && MathAbs(maxLowerWickPctTR - o.maxLowerWickPctTR) < 1e-9
          && MathAbs(minUpperWickToBody - o.minUpperWickToBody) < 1e-9
          && MathAbs(maxClosePositionInRange - o.maxClosePositionInRange) < 1e-9
          && MathAbs(minTRPoints - o.minTRPoints) < 1e-9
          && MathAbs(minBodyPoints - o.minBodyPoints) < 1e-9
          && preferUpswingContext == o.preferUpswingContext
          && upswingLookback == o.upswingLookback;
   }
};

//──────────────────────────────────────────────────────────────────────────────
// Detector
//──────────────────────────────────────────────────────────────────────────────
class ShootingStarDetector : public AbstractPatternDetector
{
public:
   static PatternDescriptor MakeDescriptor()
   {
      PatternDescriptor d;
      d.name     = "ShootingStar";
      d.category = PatternSingleCandle;
      d.legs     = 1;
      return d;
   }

   ShootingStarDetector()
   : AbstractPatternDetector(MakeDescriptor(), new ShootingStarParams()) {}

   ShootingStarDetector(const ShootingStarParams &p)
   : AbstractPatternDetector(MakeDescriptor(), &p) {}

   ShootingStarDetector(const ShootingStarDetector &rhs)
   : AbstractPatternDetector(rhs) {}

   virtual IPatternDetector* Clone() const { return new ShootingStarDetector(*this); }

protected:
   // Helpers
   static double BodySize(const MqlRates &b)  { return MathAbs(b.close - b.open); }
   static double TrueRange(const MqlRates &b) { return (b.high - b.low); }
   static double UpperWick(const MqlRates &b) { return b.high - MathMax(b.open, b.close); }
   static double LowerWick(const MqlRates &b) { return MathMin(b.open, b.close) - b.low; }
   static bool   IsBear(const MqlRates &b)    { return b.close < b.open; }
   static bool   IsBull(const MqlRates &b)    { return b.close > b.open; }

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
      const ShootingStarParams* e = (const ShootingStarParams*)p;
      if(e.maxBodyPctTR < 0.0 || e.maxBodyPctTR > 1.0) return false;
      if(e.maxLowerWickPctTR < 0.0 || e.maxLowerWickPctTR > 1.0) return false;
      if(e.minUpperWickToBody < 0.0) return false;
      if(e.maxClosePositionInRange < 0.0 || e.maxClosePositionInRange > 1.0) return false;
      if(e.minTRPoints < 0.0) return false;
      if(e.minBodyPoints < 0.0) return false;
      if(e.upswingLookback < 0) return false;
      return true;
   }

   // Score: small body, tiny lower wick, very long upper wick, bearish close preferred,
   // optional upswing context bonus.
   static double ScoreShootingStar(const double bodyPctTR,
                                   const double lowerWickPctTR,
                                   const double upperToBody,
                                   const bool   bearishClose,
                                   const bool   hadUpswing)
   {
      double smallBody = 1.0 - MathMin(1.0, (bodyPctTR - 0.05) / 0.35); // full near 5%, fades by ~40%
      if(smallBody < 0.0) smallBody = 0.0;
      double tinyLower = 1.0 - MathMin(1.0, lowerWickPctTR / 0.20);     // full at 0, fades by 20% TR
      double longUpper = MathMin(1.0, upperToBody / 3.0);               // full credit ~3x body
      double bearishB  = bearishClose ? 0.08 : 0.0;                     // small boost if red close
      double ctxB      = hadUpswing ? 0.07 : 0.0;                        // context bonus

      double wBody=0.35, wLower=0.20, wUpper=0.45;
      double score01 = wBody*smallBody + wLower*tinyLower + wUpper*longUpper + bearishB + ctxB;
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
      const ShootingStarParams* Pptr = (const ShootingStarParams*)m_params;
      if(Pptr==NULL) return false;
      ShootingStarParams P = *Pptr; // dot-access copy

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

      const double bodyPctTR       = body / tr;
      const double lowerWickPctTR  = lw   / tr;
      const double upperToBody     = (body > 0.0 ? uw / body : (uw>0.0 ? 10.0 : 0.0)); // if body≈0, treat as very large

      // Geometry checks for shooting star
      if(bodyPctTR > P.maxBodyPctTR) return false;
      if(lowerWickPctTR > P.maxLowerWickPctTR) return false;
      if(upperToBody < P.minUpperWickToBody) return false;

      // Close position within the candle range (optional)
      if(P.maxClosePositionInRange > 0.0)
      {
         const double pos = (c.close - c.low) / MathMax(1e-12, (c.high - c.low)); // 0 bottom .. 1 top
         if(pos > P.maxClosePositionInRange) return false;
      }

      // Optional upswing context
      bool hadUp = true;
      if(P.preferUpswingContext)
         hadUp = HasRecentUpswing(symbol, timeframe, shift+1, P.upswingLookback, md);
      if(!hadUp && P.preferUpswingContext) return false;

      // Score & fill
      const bool bearishClose = IsBear(c) && !IsBull(c); // red close preferred
      const double score = ScoreShootingStar(bodyPctTR, lowerWickPctTR, upperToBody, bearishClose, hadUp);

      out.direction  = PatternBearish;   // bearish-leaning reversal
      out.score      = score;
      out.time       = c.time;
      out.price_hint = c.close;
      out.tag        = "shooting_star";

      return true;
   }
};

#endif // PATTERNS_SHOOTINGSTAR_MQH
