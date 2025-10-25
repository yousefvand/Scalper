#ifndef INDICATOR_SPEC_MQH
#define INDICATOR_SPEC_MQH

struct IndicatorSpec
{
   string id;          // unique key, e.g. "ema.fast", "rsi.main"
   string type;        // "MA", "RSI", "ATR", ...
   string symbol;      // usually EA symbol
   ENUM_TIMEFRAMES tf; // timeframe
   string params;      // key=value;key=value (e.g. period=9;method=EMA;price=PRICE_CLOSE;shift=0)
};

#endif // INDICATOR_SPEC_MQH
