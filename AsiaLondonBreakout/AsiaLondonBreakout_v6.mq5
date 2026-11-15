//+------------------------------------------------------------------+
//|                                    AsianRangeBreakout_v7.mq5    |
//|             Asian Session Range / London Breakout for XAUUSD    |
//|               Fixed range build + breakout buffer + ATR SL      |
//+------------------------------------------------------------------+
#property copyright "Asian Range Breakout EA v7"
#property version   "8.00"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "=== Server Time Settings ==="
input int    InpWinterOffset        = 2;      // Server GMT offset in WINTER (e.g. 2 for GMT+2)
input int    InpSummerOffset        = 1;      // Server GMT offset in SUMMER (e.g. 1 for GMT+1)

input group "=== Asian Session (GMT Hours) ==="
input int    InpAsianStartHour      = 0;      // Asian Session Start Hour (GMT)
input int    InpAsianEndHour        = 6;      // Asian Session End Hour (GMT)

input group "=== London Breakout Window (GMT Hours) ==="
input int    InpLondonStartHour     = 7;      // London Breakout Start Hour (GMT)
input int    InpLondonEndHour       = 11;     // No new entries after this hour (GMT)

input group "=== Trade Settings ==="
input double InpLotSize             = 0.10;   // Lot Size
input double InpSLMultiplier        = 0.50;   // Base Stop Loss (x Asian range)
input double InpTPMultiplier        = 1.75;   // Take Profit (x Asian range)
input int    InpSlippage            = 50;     // Slippage in points
input ulong  InpMagicNumber         = 112233; // Magic Number
input bool   InpTradeLongs          = true;   // Trade Long (buy) setups
input bool   InpTradeShorts         = false;  // Trade Short (sell) setups

input group "=== Breakout Quality Filter ==="
input double InpBreakoutBuffer      = 0.50;   // Breakout buffer in dollars / price units
input double InpMaxSpreadDollars    = 1.50;   // Max allowed spread in dollars / price units

input group "=== Range Quality Filter ==="
input bool   InpUseFixedRangeFilter = false;   // Use absolute min/max Asian range filter
input double InpMinRangeDollars     = 3.0;    // Min Asian Range in dollars
input double InpMaxRangeDollars     = 100.0;  // Max Asian Range in dollars
input bool   InpUseATRRangeFilter   = true;   // Compare Asian range to ATR x multiplier
input ENUM_TIMEFRAMES InpRangeATRTimeframe = PERIOD_H1; // ATR timeframe used for range filter
input int    InpRangeATRPeriod      = 14;     // ATR period used for range filter
input double InpMaxRangeATRMultiplier = 2.0; // Skip if Asian range > ATR x multiplier

input group "=== Asia Positioning Filter ==="
input bool   InpUseAsiaPositionFilter = false; // Filter entries by where Asia closes inside its range
input double InpAsiaBullPositionMin = 0.70;    // Allow longs when Asia close position >= this value
input double InpAsiaBearPositionMax = 0.30;    // Allow shorts when Asia close position <= this value

input group "=== Retest Filter ==="
input bool   InpRequireRetest       = false;  // Require price to retest breakout level before entry
input double InpRetestDollars       = 3.0;    // Max retest distance in dollars
input int    InpRetestMaxBars       = 3;      // Max closed bars to wait for the retest

input group "=== Adaptive SL with ATR ==="
input bool   InpUseAdaptiveSL       = true;   // Use max(range SL, ATR SL)
input ENUM_TIMEFRAMES InpSLATRTimeframe = PERIOD_M5; // ATR timeframe used for stop calculation
input int    InpSLATRPeriod         = 14;     // ATR period used for stop calculation
input double InpSLATRMultiplier     = 1.20;   // Stop Loss = max(range SL, ATR x multiplier)

input group "=== H1 ATR Volatility Filter ==="
input bool   InpUseATRFilter        = false;  // Enable H1 ATR expansion filter
input int    InpATRPeriod           = 14;     // ATR Period
input int    InpATRMAPeriod         = 20;     // ATR MA Period
input double InpATRThresholdMultiplier = 1.00; // Filter passes when ATR > ATR_MA x multiplier

input group "=== Market Condition Filter ==="
input bool   InpUseTrendFilter      = false;  // Enable higher-timeframe trend filter
input ENUM_TIMEFRAMES InpTrendTimeframe = PERIOD_H1; // Timeframe used for trend filter
input int    InpTrendFastMAPeriod   = 20;     // Fast EMA period
input int    InpTrendSlowMAPeriod   = 50;     // Slow EMA period

input group "=== Diagnostics / Analysis ==="
input bool   InpLogTradeContext     = true;   // Print weekday / range bucket / SL context

input group "=== Visual Settings ==="
input bool   InpShowRangeLines      = true;
input color  InpHighLineColor       = clrDodgerBlue;
input color  InpLowLineColor        = clrOrangeRed;

//--- Global Variables
CTrade   trade;

double   g_asianHigh         = 0.0;
double   g_asianLow          = 0.0;
double   g_lockedRange       = 0.0;
bool     g_rangeReady        = false;
bool     g_longTriggered     = false;
bool     g_shortTriggered    = false;
datetime g_lastBarTime       = 0;
int      g_lastRangeDay      = -1;

int      g_atrH1Handle       = INVALID_HANDLE;
int      g_slAtrHandle       = INVALID_HANDLE;
int      g_rangeAtrHandle    = INVALID_HANDLE;
int      g_fastMaHandle      = INVALID_HANDLE;
int      g_slowMaHandle      = INVALID_HANDLE;

bool     g_pendingLongRetest = false;
bool     g_pendingShortRetest= false;
int      g_longRetestBars    = 0;
int      g_shortRetestBars   = 0;
string   g_tradeDayName      = "";
string   g_tradeRangeBucket  = "";
double   g_asiaClosePosition = -1.0;

//+------------------------------------------------------------------+
//| Returns the last Sunday of a given month/year                    |
//+------------------------------------------------------------------+
datetime LastSundayOf(int year, int month)
  {
   int daysInMonth;
   if(month == 2)
      daysInMonth = ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) ? 29 : 28;
   else if(month == 4 || month == 6 || month == 9 || month == 11)
      daysInMonth = 30;
   else
      daysInMonth = 31;

   MqlDateTime dt;
   dt.year  = year;
   dt.mon   = month;
   dt.day   = daysInMonth;
   dt.hour  = 2;
   dt.min   = 0;
   dt.sec   = 0;

   datetime d = StructToTime(dt);
   TimeToStruct(d, dt);

   while(dt.day_of_week != 0)
     {
      d -= 86400;
      TimeToStruct(d, dt);
     }
   return d;
  }

//+------------------------------------------------------------------+
//| Returns true if the given server datetime is in European Summer  |
//+------------------------------------------------------------------+
bool IsEuropeanSummerTime(datetime serverTime)
  {
   MqlDateTime st;
   TimeToStruct(serverTime, st);
   int year = st.year;

   datetime dstStart = LastSundayOf(year, 3);
   datetime dstEnd   = LastSundayOf(year, 10);

   return (serverTime >= dstStart && serverTime < dstEnd);
  }

//+------------------------------------------------------------------+
//| Returns the correct GMT offset for the given server time         |
//+------------------------------------------------------------------+
int GetGMTOffset(datetime serverTime)
  {
   return IsEuropeanSummerTime(serverTime) ? InpSummerOffset : InpWinterOffset;
  }

//+------------------------------------------------------------------+
//| Convert server time to GMT struct                                |
//+------------------------------------------------------------------+
void ServerToGMT(datetime serverTime, MqlDateTime &gmt)
  {
   int gmtOffset = GetGMTOffset(serverTime);
   datetime gmtTime = serverTime - (datetime)(gmtOffset * 3600);
   TimeToStruct(gmtTime, gmt);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   g_atrH1Handle = iATR(_Symbol, PERIOD_H1, InpATRPeriod);
   if(g_atrH1Handle == INVALID_HANDLE)
     {
      Print("ERROR: Could not create H1 ATR handle.");
      return INIT_FAILED;
     }

   g_slAtrHandle = iATR(_Symbol, InpSLATRTimeframe, InpSLATRPeriod);
   if(g_slAtrHandle == INVALID_HANDLE)
     {
      Print("ERROR: Could not create SL ATR handle.");
      return INIT_FAILED;
     }

   g_rangeAtrHandle = iATR(_Symbol, InpRangeATRTimeframe, InpRangeATRPeriod);
   if(g_rangeAtrHandle == INVALID_HANDLE)
     {
      Print("ERROR: Could not create range ATR handle.");
      return INIT_FAILED;
     }

   g_fastMaHandle = iMA(_Symbol, InpTrendTimeframe, InpTrendFastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_fastMaHandle == INVALID_HANDLE)
     {
      Print("ERROR: Could not create fast EMA handle.");
      return INIT_FAILED;
     }

   g_slowMaHandle = iMA(_Symbol, InpTrendTimeframe, InpTrendSlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_slowMaHandle == INVALID_HANDLE)
     {
      Print("ERROR: Could not create slow EMA handle.");
      return INIT_FAILED;
     }

   datetime now = TimeCurrent();
   int currentOffset = GetGMTOffset(now);
   Print("=== AsianRangeBreakout v6 Init ===");
   Print("Symbol           : ", _Symbol);
   Print("Winter Offset    : GMT+", InpWinterOffset);
   Print("Summer Offset    : GMT+", InpSummerOffset);
   Print("Current DST      : ", IsEuropeanSummerTime(now) ? "SUMMER (GMT+" + IntegerToString(InpSummerOffset) + ")"
                                                          : "WINTER (GMT+" + IntegerToString(InpWinterOffset) + ")");
   Print("Active Offset    : GMT+", currentOffset);
   Print("Breakout Buffer  : $", DoubleToString(InpBreakoutBuffer, 2));
   Print("Max Spread       : $", DoubleToString(InpMaxSpreadDollars, 2));
   Print("Adaptive SL      : ", InpUseAdaptiveSL ? "ON" : "OFF");
   Print("ATR Filter       : ", InpUseATRFilter ? "ON" : "OFF");
   Print("Trend Filter     : ", InpUseTrendFilter ? "ON" : "OFF");
   Print("Fixed Range Filt : ", InpUseFixedRangeFilter ? "ON" : "OFF");
   Print("ATR Range Filt   : ", InpUseATRRangeFilter ? "ON" : "OFF");
   Print("Asia Pos Filter  : ", InpUseAsiaPositionFilter ? "ON" : "OFF");
   Print("Min Range        : $", DoubleToString(InpMinRangeDollars, 2));
   Print("Max Range        : $", DoubleToString(InpMaxRangeDollars, 2));
   Print("Max Range ATR x  : ", DoubleToString(InpMaxRangeATRMultiplier, 2));

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_atrH1Handle != INVALID_HANDLE) IndicatorRelease(g_atrH1Handle);
   if(g_slAtrHandle != INVALID_HANDLE) IndicatorRelease(g_slAtrHandle);
   if(g_rangeAtrHandle != INVALID_HANDLE) IndicatorRelease(g_rangeAtrHandle);
   if(g_fastMaHandle != INVALID_HANDLE) IndicatorRelease(g_fastMaHandle);
   if(g_slowMaHandle != INVALID_HANDLE) IndicatorRelease(g_slowMaHandle);
   ObjectDelete(0, "AR_High");
   ObjectDelete(0, "AR_Low");
  }

//+------------------------------------------------------------------+
//| Main tick                                                        |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime currentBar = iTime(_Symbol, PERIOD_M5, 0);
   if(currentBar == g_lastBarTime)
      return;
   g_lastBarTime = currentBar;

   BuildAsianRange();
   CheckBreakoutEntry();
  }

//+------------------------------------------------------------------+
//| Helper: weekday name                                             |
//+------------------------------------------------------------------+
string WeekdayName(const int dow)
  {
   switch(dow)
     {
      case 1: return "Mon";
      case 2: return "Tue";
      case 3: return "Wed";
      case 4: return "Thu";
      case 5: return "Fri";
      case 6: return "Sat";
      default: return "Sun";
     }
  }

//+------------------------------------------------------------------+
//| Helper: range bucket                                             |
//+------------------------------------------------------------------+
string GetRangeBucket(const double rangeDollars)
  {
   if(rangeDollars < 5.0)   return "03-05";
   if(rangeDollars < 10.0)  return "05-10";
   if(rangeDollars < 15.0)  return "10-15";
   if(rangeDollars < 20.0)  return "15-20";
   if(rangeDollars < 30.0)  return "20-30";
   return "30+";
  }

//+------------------------------------------------------------------+
//| Reset intraday session state                                     |
//+------------------------------------------------------------------+
void ResetSessionState(const int todayDay)
  {
   g_asianHigh          = 0.0;
   g_asianLow           = 0.0;
   g_lockedRange        = 0.0;
   g_rangeReady         = false;
   g_longTriggered      = false;
   g_shortTriggered     = false;
   g_pendingLongRetest  = false;
   g_pendingShortRetest = false;
   g_longRetestBars     = 0;
   g_shortRetestBars    = 0;
   g_tradeDayName       = "";
   g_tradeRangeBucket   = "";
   g_asiaClosePosition  = -1.0;
   g_lastRangeDay       = todayDay;
  }

//+------------------------------------------------------------------+
//| Build Asian Range from the last CLOSED M5 candle                 |
//+------------------------------------------------------------------+
void BuildAsianRange()
  {
   datetime closedBarTime = iTime(_Symbol, PERIOD_M5, 1);
   if(closedBarTime <= 0)
      return;

   MqlDateTime gmt;
   ServerToGMT(closedBarTime, gmt);

   int todayDay = gmt.day_of_year;

   if(gmt.hour == InpAsianStartHour && g_lastRangeDay != todayDay)
     {
      ResetSessionState(todayDay);
      Print("--- New Asian session | GMT day: ", todayDay,
            " | Closed bar server time: ", TimeToString(closedBarTime));
     }

   if(g_lastRangeDay != todayDay)
      return;

   if(gmt.hour >= InpAsianStartHour && gmt.hour < InpAsianEndHour)
     {
      double hi = iHigh(_Symbol, PERIOD_M5, 1);
      double lo = iLow(_Symbol, PERIOD_M5, 1);

      if(g_asianHigh == 0.0 || hi > g_asianHigh) g_asianHigh = hi;
      if(g_asianLow  == 0.0 || lo < g_asianLow)  g_asianLow  = lo;
      return;
     }

   if(gmt.hour >= InpAsianEndHour && !g_rangeReady && g_asianHigh > 0.0 && g_asianLow > 0.0)
     {
      double rangeDollars = g_asianHigh - g_asianLow;

      Print("Asian Range LOCK CHECK | High=", DoubleToString(g_asianHigh, _Digits),
            " Low=", DoubleToString(g_asianLow, _Digits),
            " Range=$", DoubleToString(rangeDollars, 2));

      if(InpUseFixedRangeFilter)
        {
         if(rangeDollars < InpMinRangeDollars)
           {
            Print("SKIP: Too small ($", DoubleToString(rangeDollars, 2), ")");
            return;
           }
         if(rangeDollars > InpMaxRangeDollars)
           {
            Print("SKIP: Too large absolute ($", DoubleToString(rangeDollars, 2), " > $", DoubleToString(InpMaxRangeDollars, 2), ")");
            return;
           }
        }

      if(InpUseATRRangeFilter)
        {
         double rangeATR = GetRangeATRValue();
         if(rangeATR > 0.0)
           {
            double maxAllowedRange = rangeATR * InpMaxRangeATRMultiplier;
            if(InpLogTradeContext)
               PrintFormat("RANGE ATR FILTER: range=%.2f, atr=%.2f, multiplier=%.2f, maxAllowed=%.2f",
                           rangeDollars, rangeATR, InpMaxRangeATRMultiplier, maxAllowedRange);

            if(rangeDollars > maxAllowedRange)
              {
               PrintFormat("SKIP: Too large vs ATR (range=%.2f > maxAllowed=%.2f)", rangeDollars, maxAllowedRange);
               return;
              }
           }
        }

      double asiaClose = iClose(_Symbol, PERIOD_M5, 1);
      g_asiaClosePosition = (rangeDollars > 0.0) ? ((asiaClose - g_asianLow) / rangeDollars) : -1.0;
      g_asiaClosePosition = MathMax(0.0, MathMin(1.0, g_asiaClosePosition));

      g_lockedRange      = rangeDollars;
      g_rangeReady       = true;
      g_tradeDayName     = WeekdayName(gmt.day_of_week);
      g_tradeRangeBucket = GetRangeBucket(rangeDollars);

      Print("Range LOCKED: $", DoubleToString(rangeDollars, 2),
            " | Weekday=", g_tradeDayName,
            " | Bucket=", g_tradeRangeBucket,
            " | AsiaClosePos=", DoubleToString(g_asiaClosePosition, 2));

      if(InpShowRangeLines)
         DrawRangeLines();
     }
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Get latest ATR value for Asian range filter                      |
//+------------------------------------------------------------------+
double GetRangeATRValue()
  {
   if(g_rangeAtrHandle == INVALID_HANDLE)
      return 0.0;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_rangeAtrHandle, 0, 1, 1, buf) <= 0)
      return 0.0;

   return buf[0];
  }

//| Get latest ATR value for stop sizing                             |
//+------------------------------------------------------------------+
double GetSLATRValue()
  {
   if(g_slAtrHandle == INVALID_HANDLE)
      return 0.0;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_slAtrHandle, 0, 1, 1, buf) <= 0)
      return 0.0;

   return buf[0];
  }

//+------------------------------------------------------------------+
//| Build stop distance                                               |
//+------------------------------------------------------------------+
double GetStopDistance(const double range)
  {
   double rangeStop = range * InpSLMultiplier;
   if(!InpUseAdaptiveSL)
      return rangeStop;

   double atrStop = GetSLATRValue() * InpSLATRMultiplier;
   return MathMax(rangeStop, atrStop);
  }

//+------------------------------------------------------------------+
//| Can we trade now?                                                |
//+------------------------------------------------------------------+
bool IsWithinLondonWindow(const MqlDateTime &gmt)
  {
   return (gmt.hour >= InpLondonStartHour && gmt.hour < InpLondonEndHour);
  }

//+------------------------------------------------------------------+
//| Enter long                                                       |
//+------------------------------------------------------------------+
void ExecuteLong(const double ask, const double slDist, const double tpDist, const string reason)
  {
   double sl = NormalizeDouble(ask - slDist, _Digits);
   double tp = NormalizeDouble(ask + tpDist, _Digits);
   string comment = StringFormat("ARL %s %s", g_tradeDayName, g_tradeRangeBucket);

   if(trade.Buy(InpLotSize, _Symbol, ask, sl, tp, comment))
     {
      g_longTriggered     = true;
      g_pendingLongRetest = false;
      g_longRetestBars    = 0;

      if(InpLogTradeContext)
         Print("BUY | Reason=", reason,
               " | Ask=", DoubleToString(ask, _Digits),
               " | SL=", DoubleToString(sl, _Digits),
               " | TP=", DoubleToString(tp, _Digits),
               " | Range=$", DoubleToString(g_lockedRange, 2),
               " | Bucket=", g_tradeRangeBucket,
               " | Weekday=", g_tradeDayName,
               " | Comment=", comment);
     }
   else
      Print("BUY FAILED: ", trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
//| Enter short                                                      |
//+------------------------------------------------------------------+
void ExecuteShort(const double bid, const double slDist, const double tpDist, const string reason)
  {
   double sl = NormalizeDouble(bid + slDist, _Digits);
   double tp = NormalizeDouble(bid - tpDist, _Digits);
   string comment = StringFormat("ARS %s %s", g_tradeDayName, g_tradeRangeBucket);

   if(trade.Sell(InpLotSize, _Symbol, bid, sl, tp, comment))
     {
      g_shortTriggered     = true;
      g_pendingShortRetest = false;
      g_shortRetestBars    = 0;

      if(InpLogTradeContext)
         Print("SELL | Reason=", reason,
               " | Bid=", DoubleToString(bid, _Digits),
               " | SL=", DoubleToString(sl, _Digits),
               " | TP=", DoubleToString(tp, _Digits),
               " | Range=$", DoubleToString(g_lockedRange, 2),
               " | Bucket=", g_tradeRangeBucket,
               " | Weekday=", g_tradeDayName,
               " | Comment=", comment);
     }
   else
      Print("SELL FAILED: ", trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
//| Asia positioning filter                                          |
//+------------------------------------------------------------------+
bool PassesAsiaPositionFilter(const bool isLong)
  {
   if(!InpUseAsiaPositionFilter)
      return true;

   if(g_asiaClosePosition < 0.0)
      return true;

   bool pass = isLong ? (g_asiaClosePosition >= InpAsiaBullPositionMin)
                      : (g_asiaClosePosition <= InpAsiaBearPositionMax);

   if(InpLogTradeContext)
      PrintFormat("ASIA POSITION FILTER [%s]: pos=%.2f bullMin=%.2f bearMax=%.2f => %s",
                  isLong ? "LONG" : "SHORT", g_asiaClosePosition,
                  InpAsiaBullPositionMin, InpAsiaBearPositionMax,
                  pass ? "PASS" : "FAIL");

   return pass;
  }

//+------------------------------------------------------------------+
//| Check London Breakout Entry                                      |
//+------------------------------------------------------------------+
void CheckBreakoutEntry()
  {
   if(!g_rangeReady)
      return;

   datetime closedBarTime = iTime(_Symbol, PERIOD_M5, 1);
   if(closedBarTime <= 0)
      return;

   MqlDateTime gmt;
   ServerToGMT(closedBarTime, gmt);

   if(!IsWithinLondonWindow(gmt))
      return;

   if(HasOpenPosition())
      return;

   if(InpUseATRFilter && !IsH1ATRExpanding())
      return;

   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;

   if(spread > InpMaxSpreadDollars)
     {
      if(InpLogTradeContext)
         Print("SKIP: Spread too wide | Spread=$", DoubleToString(spread, 2),
               " > Max=$", DoubleToString(InpMaxSpreadDollars, 2));
      return;
     }

   double range  = g_lockedRange;
   double slDist = GetStopDistance(range);
   double tpDist = range * InpTPMultiplier;

   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   double high1  = iHigh(_Symbol, PERIOD_M5, 1);
   double low1   = iLow(_Symbol, PERIOD_M5, 1);

   bool longBreakout  = (close1 > (g_asianHigh + InpBreakoutBuffer));
   bool shortBreakout = (close1 < (g_asianLow  - InpBreakoutBuffer));
   bool longTrendOk   = PassesTrendFilter(true);
   bool shortTrendOk  = PassesTrendFilter(false);
   bool longAsiaOk    = PassesAsiaPositionFilter(true);
   bool shortAsiaOk   = PassesAsiaPositionFilter(false);

   //--- LONG immediate entry or arm retest mode
   if(InpTradeLongs && !g_longTriggered)
     {
      if(!InpRequireRetest && longBreakout && longTrendOk && longAsiaOk)
         ExecuteLong(ask, slDist, tpDist, "BreakoutClose");
      else if(longBreakout && !longTrendOk && InpLogTradeContext)
         Print("SKIP: Long breakout failed trend filter.");
      else if(longBreakout && !longAsiaOk && InpLogTradeContext)
         Print("SKIP: Long breakout failed Asia position filter.");
      else if(InpRequireRetest)
        {
         if(!g_pendingLongRetest && longBreakout && longTrendOk && longAsiaOk)
           {
            g_pendingLongRetest = true;
            g_longRetestBars    = 0;
            if(InpLogTradeContext)
               Print("LONG breakout detected - waiting retest | Close=", DoubleToString(close1, _Digits),
                     " | Trigger=", DoubleToString(g_asianHigh + InpBreakoutBuffer, _Digits));
           }
         else if(g_pendingLongRetest)
           {
            g_longRetestBars++;
            bool retestTouched = (low1 <= (g_asianHigh + InpRetestDollars));
            bool retestHeld    = (close1 > g_asianHigh);

            if(retestTouched && retestHeld && longTrendOk && longAsiaOk)
               ExecuteLong(ask, slDist, tpDist, "RetestHold");
            else if(g_longRetestBars > InpRetestMaxBars)
              {
               g_pendingLongRetest = false;
               g_longRetestBars    = 0;
               if(InpLogTradeContext)
                  Print("LONG retest expired.");
              }
           }
        }
     }

   //--- SHORT immediate entry or arm retest mode
   if(InpTradeShorts && !g_shortTriggered)
     {
      if(!InpRequireRetest && shortBreakout && shortTrendOk && shortAsiaOk)
         ExecuteShort(bid, slDist, tpDist, "BreakoutClose");
      else if(shortBreakout && !shortTrendOk && InpLogTradeContext)
         Print("SKIP: Short breakout failed trend filter.");
      else if(shortBreakout && !shortAsiaOk && InpLogTradeContext)
         Print("SKIP: Short breakout failed Asia position filter.");
      else if(InpRequireRetest)
        {
         if(!g_pendingShortRetest && shortBreakout && shortTrendOk && shortAsiaOk)
           {
            g_pendingShortRetest = true;
            g_shortRetestBars    = 0;
            if(InpLogTradeContext)
               Print("SHORT breakout detected - waiting retest | Close=", DoubleToString(close1, _Digits),
                     " | Trigger=", DoubleToString(g_asianLow - InpBreakoutBuffer, _Digits));
           }
         else if(g_pendingShortRetest)
           {
            g_shortRetestBars++;
            bool retestTouched = (high1 >= (g_asianLow - InpRetestDollars));
            bool retestHeld    = (close1 < g_asianLow);

            if(retestTouched && retestHeld && shortTrendOk && shortAsiaOk)
               ExecuteShort(bid, slDist, tpDist, "RetestHold");
            else if(g_shortRetestBars > InpRetestMaxBars)
              {
               g_pendingShortRetest = false;
               g_shortRetestBars    = 0;
               if(InpLogTradeContext)
                  Print("SHORT retest expired.");
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Higher-timeframe trend filter                                    |
//+------------------------------------------------------------------+
bool PassesTrendFilter(const bool isLong)
  {
   if(!InpUseTrendFilter)
      return true;

   if(g_fastMaHandle == INVALID_HANDLE || g_slowMaHandle == INVALID_HANDLE)
      return true;

   double fastBuf[];
   double slowBuf[];
   ArraySetAsSeries(fastBuf, true);
   ArraySetAsSeries(slowBuf, true);

   if(CopyBuffer(g_fastMaHandle, 0, 1, 1, fastBuf) <= 0)
      return true;
   if(CopyBuffer(g_slowMaHandle, 0, 1, 1, slowBuf) <= 0)
      return true;

   double tfClose = iClose(_Symbol, InpTrendTimeframe, 1);
   if(tfClose <= 0.0)
      return true;

   double fast = fastBuf[0];
   double slow = slowBuf[0];
   bool pass = isLong ? (tfClose > fast && fast > slow)
                      : (tfClose < fast && fast < slow);

   if(InpLogTradeContext)
      PrintFormat("TREND FILTER [%s]: tfClose=%.2f fastEMA=%.2f slowEMA=%.2f => %s",
                  isLong ? "LONG" : "SHORT", tfClose, fast, slow, pass ? "PASS" : "FAIL");

   return pass;
  }

//+------------------------------------------------------------------+
//| H1 ATR Expansion Check                                           |
//+------------------------------------------------------------------+
bool IsH1ATRExpanding()
  {
   if(g_atrH1Handle == INVALID_HANDLE)
      return true;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atrH1Handle, 0, 0, InpATRMAPeriod + 5, buf) <= 0)
      return true;

   double sum = 0.0;
   for(int i = 1; i <= InpATRMAPeriod; i++)
      sum += buf[i];

   double atrMA = (sum / InpATRMAPeriod);
   double threshold = atrMA * InpATRThresholdMultiplier;

   if(InpLogTradeContext)
      PrintFormat("ATR FILTER: current=%.2f, atrMA=%.2f, multiplier=%.2f, threshold=%.2f",
                  buf[0], atrMA, InpATRThresholdMultiplier, threshold);

   return (buf[0] > threshold);
  }

//+------------------------------------------------------------------+
//| Check for existing EA position                                   |
//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber)
            return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Draw range lines                                                 |
//+------------------------------------------------------------------+
void DrawRangeLines()
  {
   datetime t1 = TimeCurrent();
   datetime t2 = t1 + 20 * 3600;

   ObjectDelete(0, "AR_High");
   ObjectCreate(0, "AR_High", OBJ_TREND, 0, t1, g_asianHigh, t2, g_asianHigh);
   ObjectSetInteger(0, "AR_High", OBJPROP_COLOR,     InpHighLineColor);
   ObjectSetInteger(0, "AR_High", OBJPROP_STYLE,     STYLE_DASH);
   ObjectSetInteger(0, "AR_High", OBJPROP_WIDTH,     2);
   ObjectSetInteger(0, "AR_High", OBJPROP_RAY_RIGHT, false);

   ObjectDelete(0, "AR_Low");
   ObjectCreate(0, "AR_Low", OBJ_TREND, 0, t1, g_asianLow, t2, g_asianLow);
   ObjectSetInteger(0, "AR_Low", OBJPROP_COLOR,     InpLowLineColor);
   ObjectSetInteger(0, "AR_Low", OBJPROP_STYLE,     STYLE_DASH);
   ObjectSetInteger(0, "AR_Low", OBJPROP_WIDTH,     2);
   ObjectSetInteger(0, "AR_Low", OBJPROP_RAY_RIGHT, false);

   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
