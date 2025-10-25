#ifndef STRATEGIES_PLAN_MQH
#define STRATEGIES_PLAN_MQH
#property strict

struct StrategyPlan
{
   bool   valid;
   int    direction;  // +1 buy, -1 sell
   double entry;
   double sl;
   double tp1;
   double tp2;
   string reason;     // human-readable label (pattern / setup)
};

static void StrategyPlan_Reset(StrategyPlan &p)
{
   p.valid     = false;
   p.direction = 0;
   p.entry     = 0.0;
   p.sl        = 0.0;
   p.tp1       = 0.0;
   p.tp2       = 0.0;
   p.reason    = "";
}
#endif
