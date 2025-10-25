#ifndef STRATEGIES_ISTRATEGY_MQH
#define STRATEGIES_ISTRATEGY_MQH
#property strict
#include "Plan.mqh"

class IStrategy
{
public:
   virtual bool   Init(const string symbol, const ENUM_TIMEFRAMES tf) = 0;
   virtual void   SetSession(const bool use, const int start_hour, const int end_hour) = 0;
   virtual bool   TrySignal(StrategyPlan &outPlan) = 0;
   virtual string Name() = 0;
   virtual        ~IStrategy() {}
};
#endif
