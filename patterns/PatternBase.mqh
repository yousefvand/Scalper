#ifndef PATTERNS_BASE_MQH
#define PATTERNS_BASE_MQH

// ─────────────────────────────────────────────────────────────────────────────
// PatternBase.mqh
// OOP base layer for candlestick pattern detectors.
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// Common enums & types
// ─────────────────────────────────────────────────────────────────────────────
#include <Object.mqh>

#ifndef ENGINE_TYPES_MQH
#define ENGINE_TYPES_MQH

enum PatternDirection
{
   PatternNone    = 0,
   PatternBullish = 1,
   PatternBearish = -1
};

#endif // ENGINE_TYPES_MQH

enum PatternCategory
{
   PatternSingleCandle = 1,   // 1-bar geometry (e.g., Doji, Hammer)
   PatternDoubleCandle = 2,   // 2-bar (e.g., Engulfing, Piercing)
   PatternTripleCandle = 3,   // 3-bar (e.g., Morning/Evening Star)
   PatternComposite    = 4    // Multi-bar / composite logic
};

// Basic metadata describing a pattern strategy
struct PatternDescriptor
{
   string          name;        // e.g., "ShootingStar"
   PatternCategory category;    // Single/Double/Triple/Composite
   int             legs;        // number of bars used (1..N)
};


// ─────────────────────────────────────────────────────────────────────────────
// Parameters interface
// ─────────────────────────────────────────────────────────────────────────────

class IPatternParams
{
public:
   virtual ~IPatternParams() {}
   virtual IPatternParams* Clone() const = 0;
   virtual string ToString() const = 0;
   virtual bool   Equals(const IPatternParams* other) const = 0;
};


// ─────────────────────────────────────────────────────────────────────────────
// Market Data access (abstracted to enable caching & testability)
// ─────────────────────────────────────────────────────────────────────────────

class IMarketData
{
public:
   virtual ~IMarketData() {}

   // Retrieve a block of bars [fromShift .. fromShift+count-1]
   // Returns true on success and fills 'out' with exactly 'count' bars.
   virtual bool GetRates(const string symbol,
                         const ENUM_TIMEFRAMES timeframe,
                         const int fromShift,
                         const int count,
                         MqlRates &out[]) const = 0;

   // Convenience getter (implemented via GetRates)
   virtual bool GetBar(const string symbol,
                       const ENUM_TIMEFRAMES timeframe,
                       const int shift,
                       MqlRates &bar) const
   {
      MqlRates tmp[];
      if(!GetRates(symbol, timeframe, shift, 1, tmp)) return false;
      bar = tmp[0];
      return true;
   }

   // Tick volume series for recent bars (index 0 = most recent)
   virtual bool GetTickVolumes(const string symbol,
                               const ENUM_TIMEFRAMES timeframe,
                               const int fromShift,
                               const int count,
                               long &out[]) const = 0;
};


// ─────────────────────────────────────────────────────────────────────────────
// Detector output (normalized, engine-friendly)
// ─────────────────────────────────────────────────────────────────────────────

struct PatternSignal
{
   PatternDescriptor  desc;
   PatternDirection   direction;
   double             score;        // 0..100
   datetime           time;         // time of the anchor bar
   ENUM_TIMEFRAMES    timeframe;
   int                shift;        // bar index
   double             price_hint;   // optional anchor price
   string             tag;          // optional metadata/context
};


// ─────────────────────────────────────────────────────────────────────────────
// Detector interface (Strategy pattern)
// ─────────────────────────────────────────────────────────────────────────────

class IPatternDetector : public CObject
{
public:
   virtual ~IPatternDetector() {}

   // Describe this detector (static metadata)
   virtual PatternDescriptor Describe() const = 0;

   // Compatibility alias
   virtual PatternDescriptor Descriptor() const { return Describe(); }

   // Current parameters (non-owning access)
   virtual const IPatternParams* Params() const = 0;

   // Replace parameters (detector owns the copy)
   virtual bool SetParams(const IPatternParams* p) = 0;

   // Simple self-check
   virtual bool Validate() const = 0;

   // Core detection API
   virtual bool Detect(const string symbol,
                       const ENUM_TIMEFRAMES timeframe,
                       const int shift,
                       const IMarketData &md,
                       PatternSignal &out) const = 0;

   // Polymorphic copy
   virtual IPatternDetector* Clone() const = 0;
};


// ─────────────────────────────────────────────────────────────────────────────
// Abstract base class to minimize boilerplate in concrete detectors
// ─────────────────────────────────────────────────────────────────────────────

class AbstractPatternDetector : public IPatternDetector
{
protected:
   PatternDescriptor   m_desc;
   IPatternParams     *m_params;   // owned

protected:
   // To be implemented by concrete detectors:
   virtual bool DetectImpl(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int shift,
                           const IMarketData &md,
                           PatternSignal &out) const = 0;

   // Optional hook: validate parameters shape/range
   virtual bool ValidateParams(const IPatternParams* p) const { return (p!=NULL); }

   // Copy helper for derived Clone()
   void CopyFrom(const AbstractPatternDetector &rhs)
   {
      m_desc = rhs.m_desc;
      m_params = (rhs.m_params ? rhs.m_params.Clone() : NULL);
   }

public:
   AbstractPatternDetector(const PatternDescriptor &desc, const IPatternParams *params=NULL)
   : m_desc(desc), m_params(NULL)
   {
      if(params!=NULL) m_params = params.Clone();
   }

   // Copy constructor
   AbstractPatternDetector(const AbstractPatternDetector &rhs)
   : m_desc(rhs.m_desc), m_params(NULL)
   {
      if(rhs.m_params) m_params = rhs.m_params.Clone();
   }

   // Explicit copier (MQL5-friendly alternative to operator=)
void AssignFrom(const AbstractPatternDetector &rhs)
{
   if(GetPointer(this) == GetPointer(rhs))  // ✅ no &rhs
      return;

   if(m_params) { delete m_params; m_params=NULL; }
   m_desc = rhs.m_desc;
   if(rhs.m_params) m_params = rhs.m_params.Clone();
}

   virtual ~AbstractPatternDetector()
   {
      if(m_params) { delete m_params; m_params=NULL; }
   }

   // ---------------- IPatternDetector ----------------

   virtual PatternDescriptor Describe() const { return m_desc; }
   // Descriptor() uses default impl

   virtual const IPatternParams* Params() const { return m_params; }

   virtual bool SetParams(const IPatternParams* p)
   {
      if(!ValidateParams(p)) return false;
      IPatternParams *copy = (p ? p.Clone() : NULL);
      if(m_params) { delete m_params; m_params=NULL; }
      m_params = copy;
      return true;
   }

   virtual bool Validate() const
   {
      if(m_desc.name == "" || m_desc.legs <= 0) return false;
      return ValidateParams(m_params);
   }

   virtual bool Detect(const string symbol,
                       const ENUM_TIMEFRAMES timeframe,
                       const int shift,
                       const IMarketData &md,
                       PatternSignal &out) const
   {
      if(!Validate()) return false;

      const bool ok = DetectImpl(symbol, timeframe, shift, md, out);

      if(ok)
      {
         out.desc      = m_desc;
         out.timeframe = timeframe;
         out.shift     = shift;
      }
      return ok;
   }
};

#endif // PATTERNS_BASE_MQH
