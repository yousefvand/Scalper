// utils/Config.mqh
#ifndef UTILS_CONFIG_MQH
#define UTILS_CONFIG_MQH
#property strict

#include "Logger.mqh"

inline string _B(const bool b) { return b ? "true" : "false"; }

// ─────────────────────────────────────────────────────────────
// CONSERVATIVE profile: selective entries, modest risk, tighter
// spread/ATR gates, closed-bar confirmation, capped concurrency.
// ─────────────────────────────────────────────────────────────

//======================================== DisplayConfig ========================================
struct DisplayConfig
{
   bool   showHUD;
   bool   showTradeMarkers;
   bool   showSRLines;
   bool   showSlopeLabel;

   int    refreshMs;

   int    priceDecimals;
   int    valueDecimals;
   int    paddingPx;
   int    cornerRadiusPx;
   int    shadowPx;
   int    fontSizePt;

   int    hudOffsetX;
   int    hudOffsetY;
   int    markerZIndex;

   bool   darkTheme;
   int    alphaBg;  // 0..255
   int    alphaFg;  // 0..255

   // ── EMA overlay colors ─────────────────────────────
   color  emaFastColor;   // fast EMA line color (default: orange)
   color  emaSlowColor;   // slow EMA line color (default: skyblue)

   void Validate()
   {
      if(refreshMs < 100)      refreshMs = 100;
      if(priceDecimals < -1)   priceDecimals = -1;
      if(valueDecimals < 0)    valueDecimals = 0;
      if(paddingPx < 0)        paddingPx = 0;
      if(cornerRadiusPx < 0)   cornerRadiusPx = 0;
      if(shadowPx < 0)         shadowPx = 0;
      if(fontSizePt < 6)       fontSizePt = 6;

      if(hudOffsetX < -2000)   hudOffsetX = -2000;
      if(hudOffsetY < -2000)   hudOffsetY = -2000;

      if(markerZIndex < 0)     markerZIndex = 0;

      if(alphaBg < 0)          alphaBg = 0;
      if(alphaBg > 255)        alphaBg = 255;
      if(alphaFg < 0)          alphaFg = 0;
      if(alphaFg > 255)        alphaFg = 255;
   }
};

//========================================== EAConfig =============================================
struct EAConfig
{
   // identity / routing
   string           version;
   string           symbol;
   ENUM_TIMEFRAMES  timeframe;
   long             magic;

   // trading permissions
   bool    allowBuy;
   bool    allowSell;

   // execution model
   bool    marketOnly;
   bool    allowPendingOrders;

   // behavior
   bool    enableNewBarOnly;
   bool    oneTradePerBar;
   int     cooldownSeconds;

   // position caps
   int     maxPositions;   // 0 = unlimited
   int     maxLong;        // 0 = unlimited
   int     maxShort;       // 0 = unlimited

   // broker & costs
   double  maxSpreadPts;
   double  minLot, maxLot, lotStep;
   int     volDigits;
   int     pricePrecision;

   // logging
   bool    logToFile;
   bool    debugLogs;

   // telemetry / performance
   bool    logTelemetryToFile;
   bool    logPerformanceToFile;
   bool    logPerformanceToJournal;
   int     performanceReportMinutes;
   bool    performancePerSymbol;

   // Optional gates
   bool    enableVolatilityGate;
   bool    enableNewsFilter;

   // Adaptive (placeholders)
   bool    enableAdaptiveController;
   int     adaptiveLookbackBars;
   double  adaptiveMinScale;
   double  adaptiveMaxScale;
   bool    logAdaptiveController;

   // Equity Balancer
   bool    enableEquityBalancer;
   double  eqBal_drawdownSoftPct;
   double  eqBal_drawdownHardPct;
   double  eqBal_minRiskScale;
   double  eqBal_exposureHardPct;
   int     eqBal_checkSeconds;
   bool    logEquityBalancer;

   // Drawdown Protector
   bool    drawdownProtectEnabled;
   double  drawdownTriggerPct;
   double  drawdownRecoverPct;
   bool    panicCloseEnabled;

   // Execution Optimizer
   bool    enableExecutionOptimizer;
   int     maxRetries;
   double  maxSlippagePts;
   double  spreadAdaptFactor;

   // Latency Compensator
   bool   enableLatencyComp;
   double maxAdjustPoints;
   int    tickWindow;
   int    latencyExpectedMs;

   // Auto Rebooter
   bool enableAutoReboot;
   int  rebootThresholdSec;

   // System Integrity Monitor
   bool enableIntegrityMonitor;
   int  integrityCheckSec;
   bool integrityHaltOnFailure;

   void Validate()
   {
      if(magic <= 0) magic = 1;
      if(timeframe <= 0) timeframe = PERIOD_M5;
      if(symbol == NULL || symbol == "") symbol = _Symbol;

      if(marketOnly) allowPendingOrders = false;

      if(maxPositions < 0) maxPositions = 0;
      if(maxLong      < 0) maxLong      = 0;
      if(maxShort     < 0) maxShort     = 0;

      if(maxSpreadPts < 0.0) maxSpreadPts = 0.0;

      if(minLot < 0.0)   minLot = 0.0;
      if(maxLot < 0.0)   maxLot = 0.0;
      if(lotStep < 0.0)  lotStep = 0.0;
      if(volDigits < 0)  volDigits = 2;
      if(pricePrecision < 0) pricePrecision = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      if(performanceReportMinutes < 1) performanceReportMinutes = 60;

      if(adaptiveLookbackBars < 10) adaptiveLookbackBars = 120;
      if(adaptiveMinScale < 0.0)    adaptiveMinScale = 0.0;
      if(adaptiveMaxScale > 1.0)    adaptiveMaxScale = 1.0;
      if(adaptiveMinScale > adaptiveMaxScale)
         adaptiveMinScale = adaptiveMaxScale;

      if(eqBal_drawdownSoftPct < 0.0)  eqBal_drawdownSoftPct = 0.0;
      if(eqBal_drawdownHardPct < 0.0)  eqBal_drawdownHardPct = 0.0;
      if(eqBal_drawdownHardPct > 100.) eqBal_drawdownHardPct = 100.0;
      if(eqBal_drawdownSoftPct > eqBal_drawdownHardPct && eqBal_drawdownHardPct > 0.0)
         eqBal_drawdownSoftPct = 0.5 * eqBal_drawdownHardPct;

      if(eqBal_minRiskScale <= 0.0)    eqBal_minRiskScale = 0.10;
      if(eqBal_minRiskScale > 1.0)     eqBal_minRiskScale = 1.0;

      if(eqBal_exposureHardPct < 0.0)  eqBal_exposureHardPct = 0.0;
      if(eqBal_exposureHardPct > 100.) eqBal_exposureHardPct = 100.0;

      if(eqBal_checkSeconds < 1)       eqBal_checkSeconds = 1;

      if(rebootThresholdSec < 30) rebootThresholdSec = 30;
   }
};

//======================================== PatternConfig ========================================
struct PatternConfig
{
   // Single-candle
   bool doji;
   bool dragonflyDoji;
   bool gravestoneDoji;
   bool hammer;
   bool hangingMan;
   bool invertedHammer;
   bool marubozu;
   bool shootingStar;
   bool spinningTop;

   // Double-candle
   bool bullishEngulfing;
   bool bearishEngulfing;
   bool engulfing;
   bool darkCloudCover;
   bool piercingLine;
   bool tweezerBottom;
   bool tweezerTop;

   // Triple-candle
   bool eveningStar;
   bool morningStar;
   bool threeBlackCrows;
   bool threeInsideUpDown;
   bool threeWhiteSoldiers;

   void Validate() {}
};

//========================================= RiskConfig ==========================================
struct RiskConfig
{
   double riskPercent;          // % of balance/equity per trade
   bool   useEquityForRisk;

   bool   enableDrawdownGuardian;
   double maxDrawdownPercent;
   bool   closeAllOnDrawdown;

   double dailyLossPercent;
   double dailyLossAmount;
   bool   enableDailyLossGuard;

   bool   profitLockEnabled;
   double profitLockPercent;

   bool   limitConsecutiveLosses;
   int    maxConsecutiveLosses;
   double maxLotPerTrade;

   void Validate()
   {
      if(riskPercent < 0.0) riskPercent = 0.0;
      if(maxDrawdownPercent < 0.0) maxDrawdownPercent = 0.0;
      if(dailyLossPercent < 0.0) dailyLossPercent = 0.0;
      if(profitLockPercent < 0.0) profitLockPercent = 0.0;
      if(maxConsecutiveLosses < 0) maxConsecutiveLosses = 0;
      if(maxLotPerTrade < 0.0) maxLotPerTrade = 0.0;
   }
};

//===================================== SessionConfig =========================================
struct SessionConfig
{
   bool   enableTimeFilter;
   int    startHour;          // 0..23
   int    endHour;            // 0..23
   string timezone;

   bool   newsBlackout;
   int    preNewsMinutes;
   int    postNewsMinutes;

   bool   closePositionsAtSessionEnd;
   bool   blockNewOnFriday;
   int    fridayCutoffHour;

   void Validate()
   {
      if(startHour < 0 || startHour > 23) startHour = 0;
      if(endHour   < 0 || endHour   > 23) endHour   = 23;
      if(preNewsMinutes  < 0) preNewsMinutes  = 0;
      if(postNewsMinutes < 0) postNewsMinutes = 0;
      if(fridayCutoffHour < 0 || fridayCutoffHour > 23) fridayCutoffHour = 18;
   }
   bool IsWithinTradingWindow(const datetime now) const
   {
      if(!enableTimeFilter) return true;
      MqlDateTime t; TimeToStruct(now, t);
      const int h = t.hour;
      if(startHour <= endHour) return (h >= startHour && h <= endHour);
      return (h >= startHour || h <= endHour); // wrap-around
   }
   bool IsFridayBlocked(const datetime now) const
   {
      if(!blockNewOnFriday) return false;
      MqlDateTime t; TimeToStruct(now, t);
      return (t.day_of_week == 5 && t.hour >= fridayCutoffHour);
   }
};

//======================================== SignalConfig =========================================
enum TrendSource   { TREND_NONE=0, TREND_SLOPE=1, TREND_MA=2, TREND_RSI=3 };
enum ThresholdMode { THRESH_ABSOLUTE=0, THRESH_STRICT=1 };
enum PatternFusionMode { PATT_ADD=0, PATT_MULT=1, PATT_VETO=2, PATT_NONE=3 };

struct IndicatorToggles { bool useSMA; bool showSMA; bool useEMA; bool showEMA; };
struct OscillatorToggles{ bool useRSI; bool showRSI; bool useATR; bool showATR; };

struct SignalConfig
{
   bool   tradeByPatterns;
   bool   tradeByIndicators;
   bool   enablePatterns;

   double wPattern, wRSI, wATR, wMA, wVWAP, wSpread;
   double wEMA, wSMA;
   double wPatternDirectional, wPatternNeutral;
   PatternFusionMode patternMode;

   double decisionThreshold;  ThresholdMode threshMode;

   double minPatternStrength;
   bool   enableTrendFilter;  TrendSource trendSource;  double slopeSensitivityDeg;  int barsLookback;
   bool   useRsiMidline;      int rsiMid;
   int    minCandlePoints;    double minBodyToRangeRatio, maxUpperWickRatio, maxLowerWickRatio;

   bool enableMTFConfirm;  ENUM_TIMEFRAMES mtfTimeframe;  int mtfBarsLookback;
   bool enableVWAPFilter;  double vwapMaxDistancePts;
   bool enableDivergence;  int divergenceLookback;
   bool showPatternLog;

   int maFastPeriod, maSlowPeriod;  ENUM_MA_METHOD maMethod;  ENUM_APPLIED_PRICE maApplied;  ENUM_TIMEFRAMES maTimeframe;
   int rsiPeriod;                   ENUM_APPLIED_PRICE rsiApplied;  ENUM_TIMEFRAMES rsiTimeframe;
   int atrPeriod;  ENUM_TIMEFRAMES atrTimeframe;   double atrMinPts, atrMaxPts;

   IndicatorToggles   indicators;
   OscillatorToggles  oscillators;

   bool useClosedBarOnly;

   bool  showEmaCrossLabels;
   int   emaCrossLookbackBars;
   int   emaCrossYShiftPts;
   color emaBuyLabelColor;
   color emaSellLabelColor;

   // NEW: reverse final entry decision
   bool  reverseDecision;

   void Validate()
   {
      #define _CLAMP01(v) { if(v<0.0) v=0.0; if(v>1.0) v=1.0; }
      _CLAMP01(wPattern); _CLAMP01(wRSI); _CLAMP01(wATR); _CLAMP01(wMA); _CLAMP01(wVWAP); _CLAMP01(wSpread);
      _CLAMP01(wEMA); _CLAMP01(wSMA);
      _CLAMP01(wPatternDirectional); _CLAMP01(wPatternNeutral);
      if(decisionThreshold<0.0) decisionThreshold=0.0; if(decisionThreshold>1.0) decisionThreshold=1.0;

      if((int)patternMode < (int)PATT_ADD || (int)patternMode > (int)PATT_NONE)
         patternMode = PATT_ADD;

      if(minPatternStrength>1.0) minPatternStrength/=100.0;
      if(minPatternStrength<0.0) minPatternStrength=0.0; if(minPatternStrength>1.0) minPatternStrength=1.0;

      if(barsLookback<1) barsLookback=1;
      if(slopeSensitivityDeg<0.0) slopeSensitivityDeg=0.0;
      if(rsiMid<0) rsiMid=0; if(rsiMid>100) rsiMid=100;

      if(minCandlePoints<0) minCandlePoints=0;
      _CLAMP01(minBodyToRangeRatio);
      if(maxUpperWickRatio>1.0) maxUpperWickRatio=1.0;
      if(maxLowerWickRatio>1.0) maxLowerWickRatio=1.0;
      if(mtfBarsLookback<1) mtfBarsLookback=1;
      if(vwapMaxDistancePts<0.0) vwapMaxDistancePts=0.0;
      if(divergenceLookback<1) divergenceLookback=1;

      if(maFastPeriod<1) maFastPeriod=1;
      if(maSlowPeriod<=maFastPeriod) maSlowPeriod=maFastPeriod+1;
      if(rsiPeriod<2) rsiPeriod=14;
      if(atrPeriod<1) atrPeriod=14;
      if(atrMinPts<0.0) atrMinPts=0.0;
      if(atrMaxPts<=atrMinPts) atrMaxPts=atrMinPts+1.0;

      if(emaCrossLookbackBars < 1) emaCrossLookbackBars = 300;
      if(emaCrossYShiftPts < -10000) emaCrossYShiftPts = -10000;
      if(emaCrossYShiftPts >  10000) emaCrossYShiftPts =  10000;

      #undef _CLAMP01
   }
};

//======================================== INPUTS (grouped) ===================================

// ===== General (CONSERVATIVE) =====
input group "===== General (CONSERVATIVE) =====";
input string          Inp_Version                 = "1.0.0-conservative";
input ENUM_TIMEFRAMES Inp_Timeframe               = PERIOD_M5;
input long            Inp_Magic                   = 0;
input bool            Inp_AllowBuy                = true;
input bool            Inp_AllowSell               = true;
input bool            Inp_MarketOnly              = true;
input bool            Inp_AllowPendingOrders      = false;
input bool            Inp_NewBarOnly              = true;
input bool            Inp_OneTradePerBar          = true;
input int             Inp_CooldownSeconds         = 0;
input int             Inp_MaxPositions            = 2;
input int             Inp_MaxLong                 = 1;
input int             Inp_MaxShort                = 1;
input double          Inp_MaxSpreadPts            = 30.0;

// ===== Guards (per chart) =====
input group "===== Guards (per chart) =====";
input bool            Inp_Enable_VolatilityGate   = true;
input bool            Inp_Enable_NewsFilter       = false;

// ===== Logging & Telemetry =====
input group "===== Logging & Telemetry =====";
input bool            Inp_LogToFile               = false;
input bool            Inp_DebugLogs               = false;
input bool            Inp_Telemetry_ToFile        = false;
input bool            Inp_Perf_ToFile             = false;
input bool            Inp_Perf_ToJournal          = true;
input int             Inp_Perf_Report_Minutes     = 60;
input bool            Inp_Perf_PerSymbol          = true;

// ===== Protections & Optimizers =====
input group "===== Protections & Optimizers =====";
input bool            Inp_EnableEquityBalancer    = true;
input double          Inp_EQ_SoftDD_Pct           = 3.0;
input double          Inp_EQ_HardDD_Pct           = 6.0;
input double          Inp_EQ_MinRiskScale         = 0.20;
input double          Inp_EQ_ExposureHard_Pct     = 10.0;
input int             Inp_EQ_CheckSeconds         = 10;
input bool            Inp_EQ_Log                  = false;

input bool            Inp_EnableDrawdownProtect   = true;
input double          Inp_DD_TriggerPct           = 6.0;
input double          Inp_DD_RecoverPct           = 3.0;
input bool            Inp_DD_PanicClose           = false;

input bool            Inp_EnableExecOptimizer     = true;
input int             Inp_Exec_MaxRetries         = 2;
input double          Inp_Exec_MaxSlippagePts     = 6.0;
input double          Inp_Exec_SpreadAdaptFactor  = 0.0;

input bool            Inp_EnableLatencyComp       = false;
input double          Inp_Latency_MaxAdjustPts    = 2.0;
input int             Inp_Latency_TickWindow      = 20;
input int             Inp_Latency_ExpectedMs      = 120;

input bool            Inp_EnableAutoReboot        = false;
input int             Inp_Reboot_ThresholdSec     = 180;

input bool            Inp_EnableIntegrityMon      = true;
input int             Inp_Integrity_CheckSec      = 60;
input bool            Inp_Integrity_HaltOnFail    = false;

// ===== Risk (CONSERVATIVE) =====
input group "===== Risk (CONSERVATIVE) =====";
input double          Inp_Risk_RiskPercent        = 1.0;
input bool            Inp_Risk_UseEquity          = true;
input bool            Inp_Risk_EnableDDGuardian   = true;
input double          Inp_Risk_MaxDD_Pct          = 10.0;
input bool            Inp_Risk_CloseAllOnDD       = true;
input double          Inp_Risk_DailyLossPct       = 1.0;
input double          Inp_Risk_DailyLossAmt       = 0.0;
input bool            Inp_Risk_EnableDailyLoss    = true;
input bool            Inp_Risk_ProfitLock         = false;
input double          Inp_Risk_ProfitLockPct      = 0.7;
input bool            Inp_Risk_LimitConsLosses    = true;
input int             Inp_Risk_MaxConsLosses      = 2;
input double          Inp_Risk_MaxLotPerTrade     = 0.0;

// ===== Session (CONSERVATIVE) =====
input group "===== Session (CONSERVATIVE) =====";
input bool            Inp_Sess_EnableTimeFilter   = false;
input int             Inp_Sess_StartHour          = 0;
input int             Inp_Sess_EndHour            = 24;
input string          Inp_Sess_TimezoneLabel      = "Server";
input bool            Inp_Sess_NewsBlackout       = false;
input int             Inp_Sess_PreNewsMin         = 45;
input int             Inp_Sess_PostNewsMin        = 45;
input bool            Inp_Sess_CloseAtEnd         = false;
input bool            Inp_Sess_BlockNewOnFriday   = true;
input int             Inp_Sess_FridayCutoffHour   = 17;

// ===== Signals (CONSERVATIVE) =====
input group "===== Signals (CONSERVATIVE) =====";
input bool            Inp_Sig_TradeByPatterns     = true;
input bool            Inp_Sig_TradeByIndicators   = true;
input bool            Inp_Sig_EnablePatterns      = true;
input bool            Inp_Sig_UseClosedBarOnly    = true;
input bool            Inp_Sig_ShowPatternLog      = true;
input double          Inp_Sig_wEMA                = 0.60;
input double          Inp_Sig_wSMA                = 0.40;
input double          Inp_Sig_wRSI                = 0.10;
input double          Inp_Sig_wATR                = 0.05;
input double          Inp_Sig_wSpread             = 0.05;
input double          Inp_Sig_wPatternDirectional = 0.30;
input double          Inp_Sig_wPatternNeutral     = 0.05;
input int             Inp_Sig_PatternFusionMode   = 0;
input double          Inp_Sig_DecisionThreshold   = 0.58;
input int             Inp_Sig_ThresholdMode       = 1;
input double          Inp_Sig_MinPatternStrength  = 0.60;
input bool            Inp_Sig_EnableTrendFilter   = true;
input int             Inp_Sig_TrendSource         = 2;
input double          Inp_Sig_SlopeSensitivityDeg = 5.0;
input int             Inp_Sig_BarsLookback        = 100;
input bool            Inp_Sig_UseRsiMidline       = true;
input int             Inp_Sig_RsiMid              = 50;

input group "===== EMA Cross Labels (Display) =====";
input bool            Inp_Sig_ShowEmaCrossLabels     = false;
input int             Inp_Sig_EmaCross_LookbackBars  = 300;
input int             Inp_Sig_EmaCross_YShiftPts     = 0;
input color           Inp_Sig_EmaBuyLabelColor       = clrLime;
input color           Inp_Sig_EmaSellLabelColor      = clrRed;

input int             Inp_Sig_MinCandlePoints     = 5;
input double          Inp_Sig_MinBodyToRange      = 0.18;
input double          Inp_Sig_MaxUpperWickRatio   = -1.0;
input double          Inp_Sig_MaxLowerWickRatio   = -1.0;

input bool            Inp_Sig_EnableMTFConfirm    = true;
input ENUM_TIMEFRAMES Inp_Sig_MTF_Timeframe       = PERIOD_M15;
input int             Inp_Sig_MTF_BarsLookback    = 30;

input bool            Inp_Sig_EnableVWAPFilter    = false;
input double          Inp_Sig_VWAP_MaxDistPts     = 8.0;

input bool            Inp_Sig_EnableDivergence    = false;
input int             Inp_Sig_DivergenceLookback  = 80;

input int             Inp_Sig_MA_Fast             = 8;
input int             Inp_Sig_MA_Slow             = 20;
input ENUM_MA_METHOD  Inp_Sig_MA_Method           = 1; // MODE_EMA
input ENUM_APPLIED_PRICE Inp_Sig_MA_Applied       = 1; // PRICE_CLOSE
input ENUM_TIMEFRAMES Inp_Sig_MA_Timeframe        = 0; // PERIOD_CURRENT

input int             Inp_Sig_RSI_Period          = 3;
input ENUM_APPLIED_PRICE Inp_Sig_RSI_Applied      = 1; // PRICE_CLOSE
input ENUM_TIMEFRAMES Inp_Sig_RSI_Timeframe       = 0; // PERIOD_CURRENT

input int             Inp_Sig_ATR_Period          = 14;
input ENUM_TIMEFRAMES Inp_Sig_ATR_Timeframe       = 0; // PERIOD_CURRENT
input double          Inp_Sig_ATR_MinPts          = 3.0;
input double          Inp_Sig_ATR_MaxPts          = 60.0;

// ===== Experimental =====
input group "===== Experimental =====";
input bool            Inp_Sig_ReverseDecision     = false;

// ===== Signal Toggles (Charts) =====
input group "===== Signal Toggles (Charts) =====";
input bool            Inp_Tog_UseSMA              = true;
input bool            Inp_Tog_ShowSMA             = false;
input bool            Inp_Tog_UseEMA              = true;
input bool            Inp_Tog_ShowEMA             = true;
input bool            Inp_Tog_UseRSI              = true;
input bool            Inp_Tog_ShowRSI             = true;
input bool            Inp_Tog_UseATR              = true;
input bool            Inp_Tog_ShowATR             = true;

// ===== Display =====
input group "===== Display =====";
input bool            Inp_Dsp_ShowHUD             = false;
input bool            Inp_Dsp_ShowTradeMarkers    = true;
input bool            Inp_Dsp_ShowSRLines         = true;
input bool            Inp_Dsp_ShowSlopeLabel      = false;
input int             Inp_Dsp_RefreshMs           = 600;
input int             Inp_Dsp_PriceDecimals       = -1;
input int             Inp_Dsp_ValueDecimals       = 2;
input int             Inp_Dsp_PaddingPx           = 6;
input int             Inp_Dsp_CornerRadiusPx      = 6;
input int             Inp_Dsp_ShadowPx            = 2;
input int             Inp_Dsp_FontSizePt          = 10;
input int             Inp_Dsp_HudOffsetX          = 8;
input int             Inp_Dsp_HudOffsetY          = 8;
input int             Inp_Dsp_MarkerZIndex        = 10;
input bool            Inp_Dsp_DarkTheme           = true;
input int             Inp_Dsp_AlphaBg             = 180;
input int             Inp_Dsp_AlphaFg             = 255;
input color           Inp_Dsp_EMA_FastColor       = clrOrange;
input color           Inp_Dsp_EMA_SlowColor       = clrSkyBlue;

// ===== Patterns (basic) =====
input group "===== Patterns (basic) =====";
input bool            Inp_Patt_EnableDefaults     = true;

// ===== Diagnostics =====
input group "===== Diagnostics =====";
input bool            Inp_Debug_LogSanitized      = true;

//==================================== Sanitizer & API ========================================
namespace Config
{
   static EAConfig       sEA;
   static RiskConfig     sRisk;
   static SessionConfig  sSession;
   static SignalConfig   sSignal;
   static DisplayConfig  sDisplay;
   static PatternConfig  sPattern;
   static bool           s_ready = false;

   double _ClampD(const double v, const double lo, const double hi)
   { if(v<lo) return lo; if(v>hi) return hi; return v; }
   int _ClampI(const int v, const int lo, const int hi)
   { if(v<lo) return lo; if(v>hi) return hi; return v; }

   uint _Hash16_(const string s)
   {
      uint h = 2166136261u;
      const int n = StringLen(s);
      for(int i=0;i<n;i++)
      {
         uint c = (uint)StringGetCharacter(s,i);
         h ^= (c & 0xFF);
         h *= 16777619u;
      }
      return (uint)((h ^ (h>>16)) & 0xFFFF);
   }
   long _AutoMagic_(const string sym, const ENUM_TIMEFRAMES tf)
   {
      const string key = sym + ":" + IntegerToString((int)tf);
      uint h = _Hash16_(key);
      return (long)(100000 + (int)h);
   }

   void SanitizeInputs()
   {
      // EA
      sEA.version               = Inp_Version;
      sEA.symbol                = _Symbol;
      sEA.timeframe             = Inp_Timeframe;
      sEA.magic                 = (Inp_Magic <= 0 ? _AutoMagic_(_Symbol, Inp_Timeframe) : Inp_Magic);

      sEA.allowBuy              = Inp_AllowBuy;
      sEA.allowSell             = Inp_AllowSell;

      sEA.marketOnly            = Inp_MarketOnly;
      sEA.allowPendingOrders    = (sEA.marketOnly ? false : Inp_AllowPendingOrders);

      sEA.enableNewBarOnly      = Inp_NewBarOnly;
      sEA.oneTradePerBar        = Inp_OneTradePerBar;
      sEA.cooldownSeconds       = _ClampI(Inp_CooldownSeconds, 0, 86400);

      sEA.maxPositions          = _ClampI(Inp_MaxPositions, 0, 1000);
      sEA.maxLong               = _ClampI(Inp_MaxLong, 0, 1000);
      sEA.maxShort              = _ClampI(Inp_MaxShort, 0, 1000);

      sEA.maxSpreadPts          = (Inp_MaxSpreadPts < 0.0 ? 0.0 : Inp_MaxSpreadPts);

      sEA.enableVolatilityGate  = Inp_Enable_VolatilityGate;
      sEA.enableNewsFilter      = Inp_Enable_NewsFilter;

      // Broker caps
      sEA.minLot        = 0.0;
      sEA.maxLot        = 0.0;
      sEA.lotStep       = 0.0;
      sEA.volDigits     = 2;
      sEA.pricePrecision= (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      // Logging / telemetry
      sEA.logToFile               = Inp_LogToFile;
      sEA.debugLogs               = Inp_DebugLogs;
      sEA.logTelemetryToFile      = Inp_Telemetry_ToFile;
      sEA.logPerformanceToFile    = Inp_Perf_ToFile;
      sEA.logPerformanceToJournal = Inp_Perf_ToJournal;
      sEA.performanceReportMinutes= _ClampI(Inp_Perf_Report_Minutes, 1, 10080);
      sEA.performancePerSymbol    = Inp_Perf_PerSymbol;

      // Protections & optimizers
      sEA.enableEquityBalancer    = Inp_EnableEquityBalancer;
      sEA.eqBal_drawdownSoftPct   = _ClampD(Inp_EQ_SoftDD_Pct, 0.0, 100.0);
      sEA.eqBal_drawdownHardPct   = _ClampD(Inp_EQ_HardDD_Pct, 0.0, 100.0);
      if(sEA.eqBal_drawdownSoftPct > sEA.eqBal_drawdownHardPct && sEA.eqBal_drawdownHardPct > 0.0)
         sEA.eqBal_drawdownSoftPct = 0.5 * sEA.eqBal_drawdownHardPct;
      sEA.eqBal_minRiskScale      = _ClampD(Inp_EQ_MinRiskScale, 0.0, 1.0);
      sEA.eqBal_exposureHardPct   = _ClampD(Inp_EQ_ExposureHard_Pct, 0.0, 100.0);
      sEA.eqBal_checkSeconds      = _ClampI(Inp_EQ_CheckSeconds, 1, 3600);
      sEA.logEquityBalancer       = Inp_EQ_Log;

      sEA.drawdownProtectEnabled  = Inp_EnableDrawdownProtect;
      sEA.drawdownTriggerPct      = _ClampD(Inp_DD_TriggerPct, 0.0, 100.0);
      sEA.drawdownRecoverPct      = _ClampD(Inp_DD_RecoverPct,  0.0, 100.0);
      sEA.panicCloseEnabled       = Inp_DD_PanicClose;

      sEA.enableExecutionOptimizer= Inp_EnableExecOptimizer;
      sEA.maxRetries              = _ClampI(Inp_Exec_MaxRetries, 0, 20);
      sEA.maxSlippagePts          = _ClampD(Inp_Exec_MaxSlippagePts, 0.0, 10000.0);
      sEA.spreadAdaptFactor       = _ClampD(Inp_Exec_SpreadAdaptFactor, 0.0, 100.0);

      sEA.enableLatencyComp       = Inp_EnableLatencyComp;
      sEA.maxAdjustPoints         = _ClampD(Inp_Latency_MaxAdjustPts, 0.0, 1000.0);
      sEA.tickWindow              = _ClampI(Inp_Latency_TickWindow, 1, 10000);
      sEA.latencyExpectedMs       = _ClampI(Inp_Latency_ExpectedMs, 1, 60000);

      sEA.enableAutoReboot        = Inp_EnableAutoReboot;
      sEA.rebootThresholdSec      = _ClampI(Inp_Reboot_ThresholdSec, 30, 86400);

      sEA.enableIntegrityMonitor  = Inp_EnableIntegrityMon;
      sEA.integrityCheckSec       = _ClampI(Inp_Integrity_CheckSec, 5, 86400);
      sEA.integrityHaltOnFailure  = Inp_Integrity_HaltOnFail;

      // Risk
      double rp = Inp_Risk_RiskPercent;
      if(rp < 0.0 || rp > 5.0) rp = 2.0; // guardrail
      sRisk.riskPercent            = rp;
      sRisk.useEquityForRisk       = Inp_Risk_UseEquity;

      sRisk.enableDrawdownGuardian = Inp_Risk_EnableDDGuardian;
      sRisk.maxDrawdownPercent     = (Inp_Risk_MaxDD_Pct < 0.0 ? 0.0 : Inp_Risk_MaxDD_Pct);
      sRisk.closeAllOnDrawdown     = Inp_Risk_CloseAllOnDD;

      sRisk.dailyLossPercent       = (Inp_Risk_DailyLossPct < 0.0 ? 0.0 : Inp_Risk_DailyLossPct);
      sRisk.dailyLossAmount        = (Inp_Risk_DailyLossAmt < 0.0 ? 0.0 : Inp_Risk_DailyLossAmt);
      sRisk.enableDailyLossGuard   = Inp_Risk_EnableDailyLoss;

      sRisk.profitLockEnabled      = Inp_Risk_ProfitLock;
      sRisk.profitLockPercent      = (Inp_Risk_ProfitLockPct < 0.0 ? 0.0 : Inp_Risk_ProfitLockPct);

      sRisk.limitConsecutiveLosses = Inp_Risk_LimitConsLosses;
      sRisk.maxConsecutiveLosses   = (Inp_Risk_MaxConsLosses < 0 ? 0 : Inp_Risk_MaxConsLosses);
      sRisk.maxLotPerTrade         = (Inp_Risk_MaxLotPerTrade < 0.0 ? 0.0 : Inp_Risk_MaxLotPerTrade);

      // Session
      sSession.enableTimeFilter           = Inp_Sess_EnableTimeFilter;
      sSession.startHour                  = _ClampI(Inp_Sess_StartHour, 0, 23);
      sSession.endHour                    = _ClampI(Inp_Sess_EndHour,   0, 23);
      sSession.timezone                   = Inp_Sess_TimezoneLabel;

      sSession.newsBlackout               = Inp_Sess_NewsBlackout;
      sSession.preNewsMinutes             = _ClampI(Inp_Sess_PreNewsMin, 0, 600);
      sSession.postNewsMinutes            = _ClampI(Inp_Sess_PostNewsMin,0, 600);

      sSession.closePositionsAtSessionEnd = Inp_Sess_CloseAtEnd;
      sSession.blockNewOnFriday           = Inp_Sess_BlockNewOnFriday;
      sSession.fridayCutoffHour           = _ClampI(Inp_Sess_FridayCutoffHour, 0, 23);

      // Signal
      sSignal.tradeByPatterns     = Inp_Sig_TradeByPatterns;
      sSignal.tradeByIndicators   = Inp_Sig_TradeByIndicators;
      sSignal.enablePatterns      = Inp_Sig_EnablePatterns;
      sSignal.showPatternLog      = Inp_Sig_ShowPatternLog;

      sSignal.wPattern = 0.0; sSignal.wMA = 0.0; sSignal.wVWAP = 0.0;
      sSignal.wRSI = _ClampD(Inp_Sig_wRSI, 0.0, 1.0);
      sSignal.wATR = _ClampD(Inp_Sig_wATR, 0.0, 1.0);
      sSignal.wSpread = _ClampD(Inp_Sig_wSpread, 0.0, 1.0);

      sSignal.wEMA   = _ClampD(Inp_Sig_wEMA, 0.0, 1.0);
      sSignal.wSMA   = _ClampD(Inp_Sig_wSMA, 0.0, 1.0);

      sSignal.wPatternDirectional = _ClampD(Inp_Sig_wPatternDirectional, 0.0, 1.0);
      sSignal.wPatternNeutral     = _ClampD(Inp_Sig_wPatternNeutral,     0.0, 1.0);
      sSignal.patternMode         = (PatternFusionMode)_ClampI(Inp_Sig_PatternFusionMode, 0, 3);

      sSignal.decisionThreshold   = _ClampD(Inp_Sig_DecisionThreshold, 0.0, 1.0);
      sSignal.threshMode          = (ThresholdMode)_ClampI(Inp_Sig_ThresholdMode, 0, 1);

      sSignal.minPatternStrength  = Inp_Sig_MinPatternStrength;
      sSignal.enableTrendFilter   = Inp_Sig_EnableTrendFilter;
      sSignal.trendSource         = (TrendSource)_ClampI(Inp_Sig_TrendSource, 0, 3);
      sSignal.slopeSensitivityDeg = (Inp_Sig_SlopeSensitivityDeg < 0.0 ? 0.0 : Inp_Sig_SlopeSensitivityDeg);
      sSignal.barsLookback        = _ClampI(Inp_Sig_BarsLookback, 1, 100000);
      sSignal.useRsiMidline       = Inp_Sig_UseRsiMidline;
      sSignal.rsiMid              = _ClampI(Inp_Sig_RsiMid, 0, 100);

      sSignal.minCandlePoints     = _ClampI(Inp_Sig_MinCandlePoints, 0, 100000);
      sSignal.minBodyToRangeRatio = _ClampD(Inp_Sig_MinBodyToRange, 0.0, 1.0);
      sSignal.maxUpperWickRatio   = (Inp_Sig_MaxUpperWickRatio > 1.0 ? 1.0 : Inp_Sig_MaxUpperWickRatio);
      sSignal.maxLowerWickRatio   = (Inp_Sig_MaxLowerWickRatio > 1.0 ? 1.0 : Inp_Sig_MaxLowerWickRatio);

      sSignal.enableMTFConfirm    = Inp_Sig_EnableMTFConfirm;
      sSignal.mtfTimeframe        = Inp_Sig_MTF_Timeframe;
      sSignal.mtfBarsLookback     = _ClampI(Inp_Sig_MTF_BarsLookback, 1, 100000);

      sSignal.enableVWAPFilter    = Inp_Sig_EnableVWAPFilter;
      sSignal.vwapMaxDistancePts  = (Inp_Sig_VWAP_MaxDistPts < 0.0 ? 0.0 : Inp_Sig_VWAP_MaxDistPts);

      sSignal.enableDivergence    = Inp_Sig_EnableDivergence;
      sSignal.divergenceLookback  = _ClampI(Inp_Sig_DivergenceLookback, 1, 100000);

      sSignal.maFastPeriod        = _ClampI(Inp_Sig_MA_Fast, 1, 100000);
      sSignal.maSlowPeriod        = _ClampI(Inp_Sig_MA_Slow, sSignal.maFastPeriod+1, 100000);
      sSignal.maMethod            = Inp_Sig_MA_Method;
      sSignal.maApplied           = Inp_Sig_MA_Applied;
      sSignal.maTimeframe         = Inp_Sig_MA_Timeframe;

      sSignal.rsiPeriod           = _ClampI(Inp_Sig_RSI_Period, 2, 100000);
      sSignal.rsiApplied          = Inp_Sig_RSI_Applied;
      sSignal.rsiTimeframe        = Inp_Sig_RSI_Timeframe;

      sSignal.atrPeriod           = _ClampI(Inp_Sig_ATR_Period, 1, 100000);
      sSignal.atrTimeframe        = Inp_Sig_ATR_Timeframe;
      sSignal.atrMinPts           = (Inp_Sig_ATR_MinPts < 0.0 ? 0.0 : Inp_Sig_ATR_MinPts);
      sSignal.atrMaxPts           = (Inp_Sig_ATR_MaxPts <= sSignal.atrMinPts ? sSignal.atrMinPts + 1.0 : Inp_Sig_ATR_MaxPts);

      sSignal.indicators.useSMA   = Inp_Tog_UseSMA;
      sSignal.indicators.showSMA  = Inp_Tog_ShowSMA;
      sSignal.indicators.useEMA   = Inp_Tog_UseEMA;
      sSignal.indicators.showEMA  = Inp_Tog_ShowEMA;

      sSignal.oscillators.useRSI  = Inp_Tog_UseRSI;
      sSignal.oscillators.showRSI = Inp_Tog_ShowRSI;
      sSignal.oscillators.useATR  = Inp_Tog_UseATR;
      sSignal.oscillators.showATR = Inp_Tog_ShowATR;

      sSignal.useClosedBarOnly    = Inp_Sig_UseClosedBarOnly;

      sSignal.showEmaCrossLabels   = Inp_Sig_ShowEmaCrossLabels;
      sSignal.emaCrossLookbackBars = _ClampI(Inp_Sig_EmaCross_LookbackBars, 1, 100000);
      sSignal.emaCrossYShiftPts    = _ClampI(Inp_Sig_EmaCross_YShiftPts, -10000, 10000);
      sSignal.emaBuyLabelColor     = Inp_Sig_EmaBuyLabelColor;
      sSignal.emaSellLabelColor    = Inp_Sig_EmaSellLabelColor;

      // NEW
      sSignal.reverseDecision      = Inp_Sig_ReverseDecision;

      // Display
      sDisplay.showHUD         = Inp_Dsp_ShowHUD;
      sDisplay.showTradeMarkers= Inp_Dsp_ShowTradeMarkers;
      sDisplay.showSRLines     = Inp_Dsp_ShowSRLines;
      sDisplay.showSlopeLabel  = Inp_Dsp_ShowSlopeLabel;

      sDisplay.refreshMs       = _ClampI(Inp_Dsp_RefreshMs, 100, 60000);
      sDisplay.priceDecimals   = (Inp_Dsp_PriceDecimals < -1 ? -1 : Inp_Dsp_PriceDecimals);
      sDisplay.valueDecimals   = (Inp_Dsp_ValueDecimals < 0 ? 0 : Inp_Dsp_ValueDecimals);
      sDisplay.paddingPx       = (Inp_Dsp_PaddingPx < 0 ? 0 : Inp_Dsp_PaddingPx);
      sDisplay.cornerRadiusPx  = (Inp_Dsp_CornerRadiusPx < 0 ? 0 : Inp_Dsp_CornerRadiusPx);
      sDisplay.shadowPx        = (Inp_Dsp_ShadowPx < 0 ? 0 : Inp_Dsp_ShadowPx);
      sDisplay.fontSizePt      = _ClampI(Inp_Dsp_FontSizePt, 6, 200);

      sDisplay.hudOffsetX      = (Inp_Dsp_HudOffsetX < -2000 ? -2000 : Inp_Dsp_HudOffsetX);
      sDisplay.hudOffsetY      = (Inp_Dsp_HudOffsetY < -2000 ? -2000 : Inp_Dsp_HudOffsetY);
      sDisplay.markerZIndex    = (Inp_Dsp_MarkerZIndex < 0 ? 0 : Inp_Dsp_MarkerZIndex);

      sDisplay.darkTheme       = Inp_Dsp_DarkTheme;
      sDisplay.alphaBg         = _ClampI(Inp_Dsp_AlphaBg, 0, 255);
      sDisplay.alphaFg         = _ClampI(Inp_Dsp_AlphaFg, 0, 255);
      sDisplay.emaFastColor    = Inp_Dsp_EMA_FastColor;
      sDisplay.emaSlowColor    = Inp_Dsp_EMA_SlowColor;

      // Patterns default set
      if(Inp_Patt_EnableDefaults)
      {
         sPattern.doji=true; sPattern.dragonflyDoji=true; sPattern.gravestoneDoji=true; sPattern.hammer=true;
         sPattern.hangingMan=true; sPattern.invertedHammer=true; sPattern.marubozu=true; sPattern.shootingStar=true; sPattern.spinningTop=true;
         sPattern.bullishEngulfing=true; sPattern.bearishEngulfing=true; sPattern.engulfing=true; sPattern.darkCloudCover=true; sPattern.piercingLine=true; sPattern.tweezerBottom=true; sPattern.tweezerTop=true;
         sPattern.eveningStar=true; sPattern.morningStar=true; sPattern.threeBlackCrows=true; sPattern.threeInsideUpDown=true; sPattern.threeWhiteSoldiers=true;
      }

      // Final validation
      sEA.Validate();
      sRisk.Validate();
      sSession.Validate();
      sSignal.Validate();
      sDisplay.Validate();
      sPattern.Validate();

      if(Inp_Debug_LogSanitized)
      {
         LOG.Info(
            StringFormat("[%s] [config] tf=%d magic=%I64d buy=%s sell=%s maxSpread=%.1f",
                         sEA.symbol, (int)sEA.timeframe, sEA.magic,
                         _B(sEA.allowBuy), _B(sEA.allowSell), sEA.maxSpreadPts));
         LOG.Info(
            StringFormat("[%s] [config] Caps pos=%d long=%d short=%d cooldown=%ds 1TPB=%s",
                         sEA.symbol, sEA.maxPositions, sEA.maxLong, sEA.maxShort,
                         sEA.cooldownSeconds, _B(sEA.oneTradePerBar)));
         LOG.Info(
            StringFormat("[%s] [config] Signal thr=%.2f closedBar=%s pattMin=%.2f ATR[%.1f..%.1f] VWAP<=%.1f reverse=%s",
                         sEA.symbol, sSignal.decisionThreshold, _B(sSignal.useClosedBarOnly),
                         sSignal.minPatternStrength, sSignal.atrMinPts, sSignal.atrMaxPts, sSignal.vwapMaxDistancePts,
                         _B(sSignal.reverseDecision)));
      }
      s_ready = true;
   }

   EAConfig       EA()      { return sEA; }
   RiskConfig     Risk()    { return sRisk; }
   SessionConfig  Session() { return sSession; }
   SignalConfig   Signal()  { return sSignal; }
   DisplayConfig  Display() { return sDisplay; }
   PatternConfig  Pattern() { return sPattern; }
   bool Ready() { return s_ready; }
}
#endif // UTILS_CONFIG_MQH
