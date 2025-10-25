#ifndef ENGINE_EXIT_RECIPES_MQH
#define ENGINE_EXIT_RECIPES_MQH

//+------------------------------------------------------------------+
//| engine/ExitRecipes.mqh                                           |
//| Helpers for R-multiple planning                                  |
//+------------------------------------------------------------------+

struct ExitPlan {
   double tp1;
   double tp2;
   double be;
   double rPts;
};

inline ExitPlan BuildExitPlanR(const int direction, const double entry, const double initSL,
                               const double r1, const double r2,
                               const int digits, const double point)
{
   ExitPlan ep; ep.tp1=0; ep.tp2=0; ep.be=entry; ep.rPts=0;
   const double riskPts = MathMax(1.0, MathAbs(entry - initSL)/point);
   ep.rPts = riskPts;

   if(direction>0) {
      ep.tp1 = NormalizeDouble(entry + r1*riskPts*point, digits);
      ep.tp2 = NormalizeDouble(entry + r2*riskPts*point, digits);
   } else if(direction<0) {
      ep.tp1 = NormalizeDouble(entry - r1*riskPts*point, digits);
      ep.tp2 = NormalizeDouble(entry - r2*riskPts*point, digits);
   }
   return ep;
}

#endif // ENGINE_EXIT_RECIPES_MQH
