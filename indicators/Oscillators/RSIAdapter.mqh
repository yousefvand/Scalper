#ifndef RSI_ADAPTER_MQH
#define RSI_ADAPTER_MQH

#include "../Common/IndicatorBase.mqh"
#include "../Common/IndicatorCache.mqh"
#include "../Common/IndicatorSpec.mqh"
#include "../Common/IndicatorRegistry.mqh"

class CRSI_Adapter : public IndicatorBase
{
private:
   int                m_period;
   ENUM_APPLIED_PRICE m_price;

public:
   CRSI_Adapter(){ m_handle=INVALID_HANDLE; m_symbol=_Symbol; m_tf=PERIOD_CURRENT; m_ready=false; m_period=14; m_price=PRICE_CLOSE; }
   virtual ~CRSI_Adapter(){ Release(); }

   void ConfigureKV(const string kv)
   {
      m_period = (int)StringToInteger(Extract(kv,"period","14"));
      m_price  = ToAppliedPrice(Extract(kv,"price","PRICE_CLOSE"));
   }

   virtual bool Init(const string symbol, ENUM_TIMEFRAMES tf)
   {
      Release();
      m_symbol = (symbol==NULL || symbol=="") ? _Symbol : symbol;
      m_tf     = tf;
      m_handle = IndicatorCache::AcquireRSI(m_symbol, m_tf, MathMax(2,m_period), m_price);
      m_ready  = IndicatorCache::IsValid(m_handle);
      return m_ready;
   }

   virtual bool   Refresh(){ m_ready=(m_handle!=INVALID_HANDLE); return m_ready; }
   virtual void   Release(){ if(m_handle!=INVALID_HANDLE) IndicatorCache::ReleaseRSI(m_handle); m_handle=INVALID_HANDLE; m_ready=false; }
   virtual double Value(const int shift=1) const { if(!IsReady()) return EMPTY_VALUE; double buf[]; if(CopyBuffer(m_handle,0,shift,1,buf)!=1) return EMPTY_VALUE; return buf[0]; }
   virtual int    Series(const int startShift,const int count,double &out[]) const { if(!IsReady()||count<=0) return 0; ArrayResize(out,count); return (int)CopyBuffer(m_handle,0,startShift,count,out); }
   virtual string Name() const { return "RSI.Adapter"; }

private:
   static string Extract(const string kv,const string key,const string def)
   {
      string parts[]; StringSplit(kv,';',parts);
      for(int i=0;i<ArraySize(parts);++i){
         string kvp=StringTrim(parts[i]);
         int p=StringFind(kvp,"=");
         if(p>0){ string k=StringTrim(StringSubstr(kvp,0,p)); string v=StringTrim(StringSubstr(kvp,p+1)); if(StringCompare(k,key)==0) return v; }
      }
      return def;
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

// ---- Self-registration creator ----
class RSI_Creator : public AutoRegistrar
{
public:
   virtual string Type() const { return "RSI"; }
   virtual IndicatorBase* Create(const IndicatorSpec &spec)
   {
      CRSI_Adapter *r = new CRSI_Adapter();
      r.ConfigureKV(spec.params);
      return r;
   }
};
static RSI_Creator __auto_reg_rsi;

#endif // RSI_ADAPTER_MQH
