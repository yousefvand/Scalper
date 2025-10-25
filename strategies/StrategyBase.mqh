// strategies/StrategyBase.mqh
#ifndef STRATEGY_BASE_MQH
#define STRATEGY_BASE_MQH
#property strict

class IStrategy
{
public:
   virtual bool Init(const EAConfig &ea, const SignalConfig &sig) { return true; }
   virtual void OnNewBar(const string symbol, ENUM_TIMEFRAMES tf, const datetime barTime) {}
   virtual void OnTimer() {}
   virtual void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res) {}
   virtual void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp) {}
   virtual void OnBookEvent(const string &symbol) {}
   virtual void Shutdown() {}
};
#endif
