//+------------------------------------------------------------------+
//|                                                      NYORB.mq5   |
//|  Classic ORB: opening range 09:30-09:45 NY, breakout on M5       |
//|  closes until 10:30 NY, M15 EMA50/EMA200 trend filter,           |
//|  SL = opposite side of the range, TP = 3R, flat by 16:55 NY.     |
//+------------------------------------------------------------------+
#property copyright "NYORB"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- inputs
input double InpLots              = 0.1;    // Fixed lot size (used when risk % = 0)
input double InpRiskPercent       = 0.0;    // Risk per trade, % of balance (0 = use fixed lots)
input long   InpMagic             = 920502; // Magic number (different from NYBoxBreakout)
input double InpRR                = 3.0;    // Take profit in R multiples

input group "Server time"
input int    InpServerGMTOffset   = 2;      // Broker server GMT offset (winter)
input bool   InpServerFollowsUSDST= true;   // Server shifts +1h when US DST is active

input group "Session (New York time, HH*60+MM)"
input int    InpBoxStartMin       = 570;    // 09:30 range start (cash open)
input int    InpBoxEndMin         = 585;    // 09:45 range end
input int    InpLastBreakoutMin   = 630;    // 10:30 last breakout candle must close by
input int    InpCloseMin          = 1015;   // 16:55 force close (gold/indices pause at 17:00 NY)

input group "Trend filter (M15)"
input bool   InpUseTrendFilter    = true;   // Use EMA trend filter
input ENUM_TIMEFRAMES InpTrendTF  = PERIOD_M15;
input int    InpEmaFast           = 50;
input int    InpEmaSlow           = 200;

input int    InpDeviation         = 30;     // Max slippage (points)

//--- globals
CTrade   trade;
int      hFast = INVALID_HANDLE, hSlow = INVALID_HANDLE;
datetime lastBarTime = 0;
datetime lastCloseTry = 0;   // M5 bar of the last close attempt (retry at most once per bar)

int      curDay    = -1;
double   boxHigh   = 0, boxLow = 0;
int      boxCount  = 0;
bool     decided   = false;

//+------------------------------------------------------------------+
//| Time helpers                                                     |
//+------------------------------------------------------------------+
datetime SundayOfMonth(int year, int month, int nth)
  {
   MqlDateTime d;
   d.year = year; d.mon = month; d.day = 1; d.hour = 0; d.min = 0; d.sec = 0;
   datetime t = StructToTime(d);
   TimeToStruct(t, d);
   int firstSun = 1 + (7 - d.day_of_week) % 7;
   d.day = firstSun + 7 * (nth - 1);
   return StructToTime(d);
  }

bool IsUSDST(datetime utc)
  {
   MqlDateTime d;
   TimeToStruct(utc, d);
   datetime start = SundayOfMonth(d.year, 3, 2)  + 7 * 3600; // 02:00 EST = 07:00 UTC
   datetime end   = SundayOfMonth(d.year, 11, 1) + 6 * 3600; // 02:00 EDT = 06:00 UTC
   return (utc >= start && utc < end);
  }

datetime ServerToNY(datetime serverTime)
  {
   datetime utcWinter = serverTime - InpServerGMTOffset * 3600;
   bool dst = IsUSDST(utcWinter);
   int srvOff = InpServerGMTOffset + ((InpServerFollowsUSDST && dst) ? 1 : 0);
   datetime utc = serverTime - srvOff * 3600;
   return utc + (dst ? -4 : -5) * 3600;
  }

int DayKey(const MqlDateTime &d) { return d.year * 10000 + d.mon * 100 + d.day; }

//+------------------------------------------------------------------+
int OnInit()
  {
   hFast = iMA(_Symbol, InpTrendTF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(_Symbol, InpTrendTF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE)
     {
      Print("Failed to create EMA handles");
      return INIT_FAILED;
     }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(hFast != INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow != INVALID_HANDLE) IndicatorRelease(hSlow);
  }

//+------------------------------------------------------------------+
bool HasPosition(ulong &ticket)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagic)
        { ticket = tk; return true; }
     }
   return false;
  }

void CheckEndOfDayClose()
  {
   ulong tk;
   if(!HasPosition(tk)) return;

   MqlDateTime nowNY, posNY;
   TimeToStruct(ServerToNY(TimeCurrent()), nowNY);
   TimeToStruct(ServerToNY((datetime)PositionGetInteger(POSITION_TIME)), posNY);

   int nowMin = nowNY.hour * 60 + nowNY.min;
   if(DayKey(nowNY) != DayKey(posNY) || nowMin >= InpCloseMin)
     {
      datetime bar = iTime(_Symbol, PERIOD_M5, 0);
      if(bar == lastCloseTry) return;   // already tried on this M5 bar
      lastCloseTry = bar;
      if(trade.PositionClose(tk))
         PrintFormat("End-of-day close done (NY %02d:%02d)", nowNY.hour, nowNY.min);
      else
         PrintFormat("End-of-day close failed: %d", GetLastError());
     }
  }

// returns +1 uptrend, -1 downtrend, 0 none/unavailable
int TrendDirection()
  {
   double f[1], s[1];
   if(CopyBuffer(hFast, 0, 1, 1, f) != 1) return 0;
   if(CopyBuffer(hSlow, 0, 1, 1, s) != 1) return 0;
   if(f[0] > s[0]) return 1;
   if(f[0] < s[0]) return -1;
   return 0;
  }

// Lot size: fixed, or sized so that a stop-out loses InpRiskPercent of balance.
// Returns 0 if the trade must be skipped (risk budget below the minimum lot).
double CalcLots(ENUM_ORDER_TYPE type, double entry, double sl)
  {
   if(InpRiskPercent <= 0.0) return InpLots;

   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = minV;

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   double profit = 0.0;
   if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, profit) || profit >= 0.0)
     {
      Print("Skip: cannot compute loss per lot");
      return 0.0;
     }
   double lots = MathFloor(riskMoney / (-profit) / step) * step;

   // cap by free margin
   double margin = 0.0, freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(lots > 0.0 && OrderCalcMargin(type, _Symbol, lots, entry, margin) && margin > freeMargin && margin > 0.0)
      lots = MathFloor(lots * freeMargin / margin / step) * step;

   if(lots < minV)
     {
      PrintFormat("Skip: risk budget %.2f too small for min lot %.2f", riskMoney, minV);
      return 0.0;
     }
   return NormalizeDouble(MathMin(lots, maxV), 8);
  }

void OpenTrade(int dir)
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   if(dir > 0)
     {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = NormalizeDouble(boxLow, digits);
      double r = entry - sl;
      if(r <= minDist) { Print("Skip BUY: stop distance too small: ", r); return; }
      double tp = NormalizeDouble(entry + InpRR * r, digits);
      double lots = CalcLots(ORDER_TYPE_BUY, entry, sl);
      if(lots <= 0.0) return;
      if(!trade.Buy(lots, _Symbol, entry, sl, tp, "NYBox buy"))
         PrintFormat("Buy failed: %d (%s)", trade.ResultRetcode(), trade.ResultRetcodeDescription());
      else
         PrintFormat("BUY %.2f lots @%.5f SL %.5f TP %.5f", lots, entry, sl, tp);
     }
   else
     {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = NormalizeDouble(boxHigh, digits);
      double r = sl - entry;
      if(r <= minDist) { Print("Skip SELL: stop distance too small: ", r); return; }
      double tp = NormalizeDouble(entry - InpRR * r, digits);
      double lots = CalcLots(ORDER_TYPE_SELL, entry, sl);
      if(lots <= 0.0) return;
      if(!trade.Sell(lots, _Symbol, entry, sl, tp, "NYBox sell"))
         PrintFormat("Sell failed: %d (%s)", trade.ResultRetcode(), trade.ResultRetcodeDescription());
      else
         PrintFormat("SELL %.2f lots @%.5f SL %.5f TP %.5f", lots, entry, sl, tp);
     }
  }

//+------------------------------------------------------------------+
//| Process the M5 candle that just closed                           |
//+------------------------------------------------------------------+
void ProcessClosedBar()
  {
   MqlRates r[];
   if(CopyRates(_Symbol, PERIOD_M5, 1, 1, r) != 1) return;

   MqlDateTime ny;
   TimeToStruct(ServerToNY(r[0].time), ny);   // NY time of candle OPEN
   int key = DayKey(ny);
   int openMin = ny.hour * 60 + ny.min;

   if(key != curDay)
     {
      curDay = key;
      boxHigh = -DBL_MAX; boxLow = DBL_MAX; boxCount = 0; decided = false;
     }

   // 1) build the box
   if(openMin >= InpBoxStartMin && openMin < InpBoxEndMin)
     {
      boxHigh = MathMax(boxHigh, r[0].high);
      boxLow  = MathMin(boxLow,  r[0].low);
      boxCount++;
      return;
     }

   // 2) breakout window: candle opens in [boxEnd, lastBreakout) i.e. closes by 10:30
   if(decided) return;
   if(openMin < InpBoxEndMin || openMin >= InpLastBreakoutMin) return;

   int expected = (InpBoxEndMin - InpBoxStartMin) / 5;
   if(boxCount < expected)
     {
      decided = true; // incomplete box -> no trade today
      PrintFormat("%04d-%02d-%02d: incomplete box (%d/%d bars), no trade", ny.year, ny.mon, ny.day, boxCount, expected);
      return;
     }

   int dir = 0;
   if(r[0].close > boxHigh) dir = 1;
   else if(r[0].close < boxLow) dir = -1;
   if(dir == 0) return;

   decided = true;  // first breakout is the only candidate (rule 5B)

   int trend = TrendDirection();
   PrintFormat("%04d-%02d-%02d NY %02d:%02d breakout %s | box %.5f-%.5f | trend %d",
               ny.year, ny.mon, ny.day, ny.hour, ny.min, dir > 0 ? "UP" : "DOWN", boxLow, boxHigh, trend);

   if(InpUseTrendFilter && trend != dir)
     {
      Print("Filtered out by trend, no trade today");
      return;
     }
   ulong tk;
   if(HasPosition(tk)) return;
   OpenTrade(dir);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   CheckEndOfDayClose();

   datetime t0 = iTime(_Symbol, PERIOD_M5, 0);
   if(t0 == 0 || t0 == lastBarTime) return;
   lastBarTime = t0;
   ProcessClosedBar();
  }
//+------------------------------------------------------------------+
