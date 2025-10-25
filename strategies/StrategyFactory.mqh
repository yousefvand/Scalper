#ifndef STRATEGY_FACTORY_MQH
#define STRATEGY_FACTORY_MQH
#property strict

#include "IStrategy.mqh"
#include "RevA/RevA_Strategy.mqh"
// #include "RevB/RevB_Strategy.mqh"
// #include "RevC/RevC_Strategy.mqh"

class StrategyFactory
{
public:
   // returns pointer to a static instance so we don't heap-allocate
   static IStrategy* Create(const string variant)
   {
      string v = StringTrim(StringToLower(variant));
      if(v == "a" || v == "reva")
      {
         static RevA_Strategy reva;
         return &reva;
      }
      // else if(v=="b" || v=="revb") { static RevB_Strategy revb; return &revb; }
      // else if(v=="c" || v=="revc") { static RevC_Strategy revc; return &revc; }

      // default
      static RevA_Strategy defa;
      return &defa;
   }
};
#endif
