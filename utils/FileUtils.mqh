#ifndef UTILS_FILE_UTILS_MQH
#define UTILS_FILE_UTILS_MQH
#property strict

#include <Arrays/ArrayString.mqh>
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| File and symbol utilities                                        |
//| - Generic file helpers                                           |
//| - Symbol list population (majors + minors)                       |
//+------------------------------------------------------------------+
class FileUtils
{
public:
   // ----------------------------------------------------------------
   // Return upper-cased version of a string (safe wrapper)
   // ----------------------------------------------------------------
   static string ToUpper(const string s)
   {
      string copy = s;
      StringToUpper(copy);
      return copy;
   }

   // ----------------------------------------------------------------
   // Read all lines of a file in MQL5/Files/<path>
   // ----------------------------------------------------------------
   static int ReadAllLines(const string relPath, string &outLines[])
   {
      ResetLastError();
      int fh = FileOpen(relPath, FILE_READ | FILE_TXT | FILE_ANSI);
      if(fh == INVALID_HANDLE)
      {
         LOG.Warn(StringFormat("FileUtils: cannot open %s (err=%d)", relPath, GetLastError()));
         return 0;
      }

      ArrayResize(outLines, 0);
      while(!FileIsEnding(fh))
      {
         string line = FileReadString(fh);
         if(line != "")
         {
            int n = ArraySize(outLines);
            ArrayResize(outLines, n + 1);
            outLines[n] = line;
         }
      }
      FileClose(fh);
      return ArraySize(outLines);
   }

   // ----------------------------------------------------------------
   // Write a single line to a file (append)
   // ----------------------------------------------------------------
   static bool AppendLine(const string relPath, const string line)
   {
      ResetLastError();
      int fh = FileOpen(relPath, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_READ);
      if(fh == INVALID_HANDLE)
      {
         LOG.Warn(StringFormat("FileUtils: cannot write %s (err=%d)", relPath, GetLastError()));
         return false;
      }
      FileSeek(fh, 0, SEEK_END);
      FileWrite(fh, line);
      FileClose(fh);
      return true;
   }

   // ----------------------------------------------------------------
   // Auto-populate major + minor Forex pairs (omit metals, crypto, etc.)
   // ----------------------------------------------------------------
   static void MajorsAndMinors(string &outSymbols[])
   {
      ArrayResize(outSymbols, 0);

      const string majors[] = {
         "EURUSD","GBPUSD","USDJPY","USDCHF","USDCAD","AUDUSD","NZDUSD"
      };

      const string minors[] = {
         "EURGBP","EURJPY","EURCHF","EURAUD","EURNZD",
         "GBPJPY","GBPCHF","GBPAUD","GBPNZD",
         "AUDJPY","AUDNZD","AUDCHF",
         "NZDJPY","NZDCHF",
         "CHFJPY","CADJPY","CADCHF"
      };

      const int m1 = ArraySize(majors);
      const int m2 = ArraySize(minors);
      ArrayResize(outSymbols, m1 + m2);
      for(int i=0;i<m1;i++) outSymbols[i] = majors[i];
      for(int j=0;j<m2;j++) outSymbols[m1+j] = minors[j];

      // Verify they exist in MarketWatch; remove invalid ones
      int n = 0;
      for(int i=0;i<ArraySize(outSymbols);++i)
      {
         string sym = outSymbols[i];
         if(SymbolSelect(sym, true))
         {
            outSymbols[n++] = sym;
         }
      }
      ArrayResize(outSymbols, n);

      LOG.Info(StringFormat("FileUtils: loaded %d symbols (majors+minors)", n));
   }
};

#endif // UTILS_FILE_UTILS_MQH
