#ifndef TIME_UTILS_MQH
#define TIME_UTILS_MQH

inline bool IsNewBar(const string sym, const ENUM_TIMEFRAMES tf, datetime &out_bar_time)
{
   const datetime cur=iTime(sym,tf,0);
   if(cur==0){ out_bar_time=0; return false; }
   static datetime last_bar=0; // single stream
   out_bar_time=cur;
   if(cur!=last_bar){ last_bar=cur; return true; }
   return false;
}

#endif
