#ifndef ENGINE_POSITION_MANAGER_MQH
#define ENGINE_POSITION_MANAGER_MQH

//+------------------------------------------------------------------+
//| engine/PositionManager.mqh                                       |
//| Tracks exposure, counts, and session PnL for our symbol+magic    |
//| - Fast counters (long/short/total)                               |
//| - Exposure lots and average price                                |
//| - Session PnL & streak hints                                     |
//| - Reacts to trade transactions                                   |
//+------------------------------------------------------------------+

#property strict
#include <Trade\PositionInfo.mqh>
#include "../utils/Config.mqh"
#include "../utils/Logger.mqh"
#include "EventDispatcher.mqh"

class PositionManager : public IEventListener
{
private:
   EAConfig       m_ea;
   CPositionInfo  m_pos;

   // Cached snapshot (for m_ea.symbol only)
   int     m_longCount;
   int     m_shortCount;
   int     m_totalCount;
   double  m_longLots;
   double  m_shortLots;
   double  m_longAvgPrice;
   double  m_shortAvgPrice;

   // Session stats
   double  m_sessionClosedPnL;  // closed PnL since EA init
   int     m_wins;
   int     m_losses;

public:
   PositionManager()
   : m_longCount(0), m_shortCount(0), m_totalCount(0),
     m_longLots(0.0), m_shortLots(0.0),
     m_longAvgPrice(0.0), m_shortAvgPrice(0.0),
     m_sessionClosedPnL(0.0), m_wins(0), m_losses(0) {}

   bool Init(const EAConfig &ea)
   {
      m_ea = ea;
      Refresh();
      return true;
   }

   // ----------------- IEventListener -----------------
   virtual void OnEAInit()
   {
      Refresh();
   }

   virtual void OnEATradeTransaction(const MqlTradeTransaction &trans,
                                     const MqlTradeRequest &/*request*/,
                                     const MqlTradeResult  &/*result*/)
   {
      // Update counters on positions add/remove and track PnL when deals close
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      {
         long entry = -1;
         if(trans.deal > 0)
            entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

         if(entry == (long)DEAL_ENTRY_OUT)
         {
            // Closed deal PnL for our magic/symbol
            string sym = (string)HistoryDealGetString(trans.deal, DEAL_SYMBOL);
            long   mag = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
            if(sym == m_ea.symbol && mag == (long)m_ea.magic)
            {
               double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                             + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                             + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
               m_sessionClosedPnL += profit;
               if(profit >= 0) m_wins++; else m_losses++;
               (*Logger::Get()).Debug(StringFormat("PM: closed PnL=%.2f | session=%.2f (W:%d L:%d)",
                                        profit, m_sessionClosedPnL, m_wins, m_losses));
            }
         }
      }

      // After any transaction, refresh live exposure snapshot for m_ea.symbol
      Refresh();
   }

   // ----------------- Public Queries (snapshot for m_ea.symbol) ----
   int     LongCount()     const { return m_longCount;  }
   int     ShortCount()    const { return m_shortCount; }
   int     TotalCount()    const { return m_totalCount; }
   double  LongLots()      const { return m_longLots;   }
   double  ShortLots()     const { return m_shortLots;  }
   double  LongAvgPrice()  const { return m_longAvgPrice;  }
   double  ShortAvgPrice() const { return m_shortAvgPrice; }
   double  SessionClosedPnL() const { return m_sessionClosedPnL; }
   int     Wins() const { return m_wins; }
   int     Losses() const { return m_losses; }
   // Net exposure (long minus short) in lots for m_ea.symbol
   double  NetExposureLots() const { return m_longLots - m_shortLots; }

   // ----------------- Convenience helpers (symbol+magic filtered) --
   // Returns true if there is at least one BUY position for 'sym' with our magic
   bool HasLong(const string sym)
   {
      return CountForSymbolAndType_(sym, POSITION_TYPE_BUY) > 0;
   }
   // Returns true if there is at least one SELL position for 'sym' with our magic
   bool HasShort(const string sym)
   {
      return CountForSymbolAndType_(sym, POSITION_TYPE_SELL) > 0;
   }
   // Returns true if there is any position (either side) for 'sym' with our magic
   bool HasPosition(const string sym)
   {
      return CountForSymbolAndType_(sym, POSITION_TYPE_BUY) > 0
          || CountForSymbolAndType_(sym, POSITION_TYPE_SELL) > 0;
   }

   // Force a recalc of the cached snapshot for m_ea.symbol (fast)
   void Refresh()
   {
      m_longCount = m_shortCount = m_totalCount = 0;
      m_longLots = m_shortLots = 0.0;
      m_longAvgPrice = m_shortAvgPrice = 0.0;

      double longNotional=0.0, shortNotional=0.0;

      const int total = (int)PositionsTotal();
      for(int i=0;i<total;i++)
      {
         if(!m_pos.SelectByIndex(i)) continue;
         if(m_pos.Symbol() != m_ea.symbol) continue;
         if((long)m_pos.Magic() != (long)m_ea.magic) continue;

         const double vol   = m_pos.Volume();
         const double price = m_pos.PriceOpen();

         m_totalCount++;
         if(m_pos.PositionType() == POSITION_TYPE_BUY)
         {
            m_longCount++;
            m_longLots += vol;
            longNotional += vol * price;
         }
         else if(m_pos.PositionType() == POSITION_TYPE_SELL)
         {
            m_shortCount++;
            m_shortLots += vol;
            shortNotional += vol * price;
         }
      }

      if(m_longLots  > 0.0) m_longAvgPrice  = longNotional  / m_longLots;
      if(m_shortLots > 0.0) m_shortAvgPrice = shortNotional / m_shortLots;
   }

private:
   // Count positions for given symbol+magic filtered by type (BUY/SELL)
   int CountForSymbolAndType_(const string sym, const long posType)
   {
      int cnt = 0;
      const int total = (int)PositionsTotal();
      for(int i=0;i<total;i++)
      {
         if(!m_pos.SelectByIndex(i)) continue;
         if(m_pos.Symbol() != sym) continue;
         if((long)m_pos.Magic() != (long)m_ea.magic) continue;
         if(m_pos.PositionType() == posType)
            cnt++;
      }
      return cnt;
   }
};

#endif // ENGINE_POSITION_MANAGER_MQH
