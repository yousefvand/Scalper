#ifndef INDICATOR_FACTORY_MQH
#define INDICATOR_FACTORY_MQH

#include "IndicatorSpec.mqh"
#include "IndicatorBase.mqh"

// existing
#include "../Trend/MovingAverage.mqh"
// new
#include "../Oscillators/RSIAdapter.mqh"
#include "../Oscillators/ATRAdapter.mqh"

class IndicatorFactory
{
public:
   static IndicatorBase* Create(const IndicatorSpec &spec)
   {
      IndicatorBase *ind=NULL;

      if(spec.type=="MA")
      {
         // params: "period=9;method=EMA;price=PRICE_CLOSE;shift=0"
         CMovingAverage *ma = new CMovingAverage();
         const int period = (int)StringToInteger(Extract(spec.params,"period","9"));
         const string method = Extract(spec.params,"method","EMA");
         const string price  = Extract(spec.params,"price","PRICE_CLOSE");
         const int shift     = (int)StringToInteger(Extract(spec.params,"shift","0"));
         ma.Configure(period, ToMaMethod(method), ToAppliedPrice(price), shift);
         ind = ma;
      }
      else if(spec.type=="RSI")
      {
         CRSI_Adapter *r = new CRSI_Adapter();
         r.Configure(spec.params);
         ind = r;
      }
      else if(spec.type=="ATR")
      {
         CATR_Adapter *a = new CATR_Adapter();
         a.Configure(spec.params);
         ind = a;
      }
      // else: extend here for VWAP, MACD, etc.

      if(ind && !ind.Init(spec.symbol, spec.tf))
      { delete ind; ind=NULL; }
      return ind;
   }

private:
   static string Extract(const string kv, const string key, const string def)
   {
      string parts[]; StringSplit(kv,';',parts);
      for(int i=0;i<ArraySize(parts);++i)
      {
         string kvp=StringTrim(parts[i]);
         int p=StringFind(kvp,"=");
         if(p>0){
            string k=StringTrim(StringSubstr(kvp,0,p));
            string v=StringTrim(StringSubstr(kvp,p+1));
            if(StringCompare(k,key)==0) return v;
         }
      }
      return def;
   }

   static ENUM_MA_METHOD ToMaMethod(const string s)
   {
      if(s=="SMA")  return MODE_SMA;
      if(s=="SMMA") return MODE_SMMA;
      if(s=="LWMA") return MODE_LWMA;
      return MODE_EMA;
   }
   static ENUM_APPLIED_PRICE ToAppliedPrice(const string s)
   {
      if(s=="PRICE_OPEN") return PRICE_OPEN;
      if(s=="PRICE_HIGH") return PRICE_HIGH;
      if(s=="PRICE_LOW")  return PRICE_LOW;
      if(s=="PRICE_MEDIAN") return PRICE_MEDIAN;
      if(s=="PRICE_TYPICAL") return PRICE_TYPICAL;
      if(s=="PRICE_WEIGHTED") return PRICE_WEIGHTED;
      return PRICE_CLOSE;
   }
};

#endif // INDICATOR_FACTORY_MQH
