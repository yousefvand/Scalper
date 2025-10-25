#ifndef UTILS_LOGGER_MQH
#define UTILS_LOGGER_MQH
#property strict

class Logger
{
private:
   static Logger *s_instance;
   bool  debugMode;
   bool  logToFile;
   int   handle;

   Logger() { debugMode=false; logToFile=false; handle=INVALID_HANDLE; }

public:
   // Singleton accessor (pointer version)
   static Logger* Get()
   {
      if(s_instance == NULL)
         s_instance = new Logger;
      return s_instance;
   }

   // Settings
   void SetDebug(const bool v){ debugMode=v; }
   void SetLogToFile(const bool v)
   {
      logToFile=v;
      if(logToFile && handle==INVALID_HANDLE)
         handle=FileOpen("Scalper\\log.txt", FILE_WRITE|FILE_TXT|FILE_COMMON);
   }

   bool DebugEnabled() const { return debugMode; }

   // Core log methods
   void Info(const string msg)   { Print("[info]  ", msg);  if(logToFile) FileWrite(handle, TimeToString(TimeCurrent()), " [info] ",  msg); }
   void Warn(const string msg)   { Print("[warn]  ", msg);  if(logToFile) FileWrite(handle, TimeToString(TimeCurrent()), " [warn] ",  msg); }
   void Error(const string msg)  { Print("[error] ", msg);  if(logToFile) FileWrite(handle, TimeToString(TimeCurrent()), " [error] ", msg); }
   void Debug(const string msg)
   {
      if(!debugMode) return;
      Print("[debug] ", msg);
      if(logToFile) FileWrite(handle, TimeToString(TimeCurrent()), " [debug] ", msg);
   }
};

Logger* Logger::s_instance = NULL;
#define LOG (*Logger::Get())

#endif // UTILS_LOGGER_MQH
