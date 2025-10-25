#ifndef ENGINE_EXECUTION_OPTIMIZER_MQH
#define ENGINE_EXECUTION_OPTIMIZER_MQH

//+------------------------------------------------------------------+
//| ExecutionOptimizer                                               |
//| - Tightens/relaxes deviation in *points* based on spread & retry |
//| - Simple success/fail stats to adapt retry behavior              |
//| - Pure helper: called by TradeManager before/after OrderSend     |
//+------------------------------------------------------------------+

#include "../config/EA.mqh"
#include "../utils/Logger.mqh"

class ExecutionOptimizer
{
private:
   EAConfig m_ea;

   // simple stats
   int      m_success;
   int      m_fail;

   // runtime knobs (kept internal to avoid new EAConfig members)
   int      m_maxRetries;         // default 1 retry
   double   m_maxSlippagePts;     // absolute cap for req.deviation
   double   m_spreadAdaptFactor;  // scales spread->deviation

public:
   ExecutionOptimizer() : m_success(0), m_fail(0),
                          m_maxRetries(1), m_maxSlippagePts(20.0),
                          m_spreadAdaptFactor(1.0) {}

   bool Init(const EAConfig &ea)
   {
      m_ea = ea;

      // Sensible defaults (can be tuned later or exposed to EAConfig)
      m_maxRetries        = 1;      // one retry is plenty for scalping
      m_maxSlippagePts    = 25.0;   // absolute maximum deviation in points
      m_spreadAdaptFactor = 1.2;    // deviation ~= spread * factor

      return true;
   }

   // Compute a deviation (points) based on current spread; set filling/time defaults
   bool PrepareRequest(MqlTradeRequest &req, const bool /*isBuy*/, const double /*lots*/, const double /*sl*/, const double /*tp*/)
   {
      double ask=0.0, bid=0.0, pt=0.0;
      SymbolInfoDouble(m_ea.symbol, SYMBOL_ASK, ask);
      SymbolInfoDouble(m_ea.symbol, SYMBOL_BID, bid);
      SymbolInfoDouble(m_ea.symbol, SYMBOL_POINT, pt);

      int devPts = 3; // base
      if(ask>0.0 && bid>0.0 && pt>0.0)
      {
         double spreadPts = (ask - bid) / pt;
         double rawDev    = spreadPts * m_spreadAdaptFactor;
         if(rawDev < 1.0) rawDev = 1.0;
         if(rawDev > m_maxSlippagePts) rawDev = m_maxSlippagePts;
         devPts = (int)MathRound(rawDev);
      }

      req.deviation   = devPts;               // in points (NOT pips)
      req.type_time   = ORDER_TIME_GTC;       // good-til-cancelled
      req.type_filling= ORDER_FILLING_FOK;    // conservative fill policy

      if(LOG.DebugEnabled())
      {
         LOG.Debug(StringFormat("ExecOpt: PrepareRequest -> deviation=%d",
                                          (int)req.deviation));
      }
      return true;
   }

   // Decide whether we should retry the order after a failure
   bool ShouldRetry(const bool ok, const MqlTradeResult &res, const int attempts) const
   {
      if(ok && res.retcode == TRADE_RETCODE_DONE) return false;
      if(attempts >= m_maxRetries)                return false;

      switch(res.retcode)
      {
         case TRADE_RETCODE_REQUOTE:
         case TRADE_RETCODE_PRICE_OFF:
         case TRADE_RETCODE_OFFQUOTES:
         case TRADE_RETCODE_SERVER_BUSY:
         case TRADE_RETCODE_TRADE_CONTEXT_BUSY:
            return true;
      }
      return false;
   }

   // For retries: modestly expand allowed deviation
   void PrepareRetry(MqlTradeRequest &req, const int attempts)
   {
      int dev = (int)req.deviation;
      dev += 2 + attempts * 2;                  // gentle ramp
      if(dev > (int)m_maxSlippagePts) dev = (int)m_maxSlippagePts;
      req.deviation = dev;

      if(LOG.DebugEnabled())
      {
         LOG.Debug(StringFormat("ExecOpt: PrepareRetry(%d) -> deviation=%d",
                                          attempts, dev));
      }
   }

   // Record outcome for simple adaptation/telemetry
   bool OnResult(const MqlTradeResult &res)
   {
      if(res.retcode == TRADE_RETCODE_DONE)
      {
         m_success++;
         if(LOG.DebugEnabled())
            LOG.Debug("ExecOpt: RESULT=OK");
         return true;
      }
      m_fail++;
      if(LOG.DebugEnabled())
         LOG.Debug(StringFormat("ExecOpt: RESULT=FAIL retcode=%d", (int)res.retcode));
      return false;
   }

   // Optional: simple getters (unused now, handy for telemetry)
   int SuccessCount() const { return m_success; }
   int FailCount()    const { return m_fail; }
};

#endif // ENGINE_EXECUTION_OPTIMIZER_MQH
