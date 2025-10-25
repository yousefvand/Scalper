#ifndef ENGINE_LATENCY_COMPENSATOR_MQH
#define ENGINE_LATENCY_COMPENSATOR_MQH

//+------------------------------------------------------------------+
//| engine/LatencyCompensator.mqh                                    |
//| Purpose: Nudge intended entry price toward the likely execution  |
//|          price using recent tick drift (micro-trend).            |
//| Notes:                                                           |
//|  - Pulls a small window of recent ticks on demand (CopyTicks).   |
//|  - Computes mid-price slope per second and estimates short-term  |
//|    move over an expected delay window, then clamps to max pts.   |
//|  - Designed to be safe (no exceptions if ticks unavailable).     |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>

#include "../config/EA.mqh"
#include "../utils/Logger.mqh"

class LatencyCompensator
{
private:
   string m_symbol;
   bool   m_enabled;
   int    m_tickWindow;         // number of ticks to sample (e.g., 20..60)
   double m_maxAdjustPts;       // clamp magnitude in points
   double m_expectDelaySec;     // assumed "from decision to fill" delay

public:
   LatencyCompensator()
   : m_symbol(_Symbol),
     m_enabled(false),
     m_tickWindow(30),
     m_maxAdjustPts(0.0),
     m_expectDelaySec(0.15)   // ~150ms default
   {}

   bool Init(const EAConfig &ea)
   {
      m_symbol        = (ea.symbol==NULL || ea.symbol=="" ? _Symbol : ea.symbol);
      // These inputs must exist in EAConfig (you already asked for the toggle)
      // If missing in your local EAConfig, set them here explicitly or add them in EAConfig.
      m_enabled       = ea.enableLatencyComp;          // <- bool
      m_tickWindow    = (ea.tickWindow > 5 ? ea.tickWindow : 30); // <- int
      m_maxAdjustPts  = (ea.maxAdjustPoints > 0.0 ? ea.maxAdjustPoints : 0.0); // <- double
      // Optional: allow EAConfig to override expected delay
      if(ea.latencyExpectedMs > 0)
         m_expectDelaySec = ((double)ea.latencyExpectedMs)/1000.0;

      // sanitize
      if(m_maxAdjustPts < 0.0) m_maxAdjustPts = 0.0;
      if(m_tickWindow < 6)     m_tickWindow   = 6;
      if(m_expectDelaySec <= 0.0) m_expectDelaySec = 0.15;

      return true;
   }

   // Convenience setter in case you wish to tweak at runtime
   void Configure(const string symbol,
                  const bool enabled,
                  const int tickWindow,
                  const double maxAdjustPts,
                  const double expectedDelaySec=0.15)
   {
      if(symbol!=NULL && symbol!="") m_symbol = symbol;
      m_enabled       = enabled;
      m_tickWindow    = (tickWindow>=6?tickWindow:6);
      m_maxAdjustPts  = (maxAdjustPts>0.0?maxAdjustPts:0.0);
      m_expectDelaySec= (expectedDelaySec>0.0?expectedDelaySec:0.15);
   }

   // Optionally feed ticks in; not required because we use CopyTicks on demand.
   void OnTick(const double /*bid*/, const double /*ask*/) {}

   // Compute adjusted entry price for a market order.
   // Strategy: estimate drift from recent mid-prices and bias price in the slope direction.
   double AdjustPrice(const bool /*isBuy*/, const double basePrice) const
   {
      if(!m_enabled || m_maxAdjustPts<=0.0) return basePrice;

      double pt = 0.0;
      if(!SymbolInfoDouble(m_symbol, SYMBOL_POINT, pt) || pt<=0.0)
         return basePrice;

      // Fetch recent ticks
      MqlTick ticks[];
      int want = m_tickWindow;
      if(want > 200) want = 200; // be reasonable
      int n = CopyTicks(m_symbol, ticks, COPY_TICKS_INFO | COPY_TICKS_TRADE, 0, want);
      if(n < 3) return basePrice;

      // Compute mid-price slope (price units per second)
      // Use first and last valid mid in the buffer
      int first = -1, last = -1;
      double midFirst=0.0, midLast=0.0;
      long   tFirst=0, tLast=0;

      for(int i=0;i<n;i++)
      {
         double b=ticks[i].bid, a=ticks[i].ask;
         if(b>0.0 && a>0.0 && a!=EMPTY_VALUE && b!=EMPTY_VALUE)
         {
            first = i; midFirst=(a+b)*0.5; tFirst=(long)ticks[i].time_msc; break;
         }
      }
      for(int j=n-1;j>=0;j--)
      {
         double b=ticks[j].bid, a=ticks[j].ask;
         if(b>0.0 && a>0.0 && a!=EMPTY_VALUE && b!=EMPTY_VALUE)
         {
            last = j; midLast=(a+b)*0.5; tLast=(long)ticks[j].time_msc; break;
         }
      }
      if(first<0 || last<0 || tLast<=tFirst) return basePrice;

      double dtSec = (double)(tLast - tFirst) / 1000.0;
      if(dtSec <= 0.0) return basePrice;

      double slope = (midLast - midFirst) / dtSec; // price/sec
      // Estimate near-future move over expected latency window
      double estMovePrice = slope * m_expectDelaySec;
      // Convert to points and clamp
      double estMovePts = estMovePrice / pt;
      if(estMovePts >  m_maxAdjustPts) estMovePts =  m_maxAdjustPts;
      if(estMovePts < -m_maxAdjustPts) estMovePts = -m_maxAdjustPts;

      // Apply in slope direction (independent of side; we align to likely execution)
      double adjusted = basePrice + (estMovePts * pt);

      return adjusted;
   }
};

#endif // ENGINE_LATENCY_COMPENSATOR_MQH
