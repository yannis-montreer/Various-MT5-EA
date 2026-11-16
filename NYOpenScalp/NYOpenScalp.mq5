//+------------------------------------------------------------------+
//| NYOpenScalp.mq5                                                   |
//| M1 scalp of the New York cash open:                               |
//|  range  = high/low of the M1 bars 09:30-09:35 NY (wicks included) |
//|  entry  = first M1 close outside the range before InpLastEntryMin |
//|  stop   = other side of the range (or range middle)               |
//|  target = InpRR x risk; time exit after InpExitAfterMin minutes   |
//|  one trade per day; optional M15 EMA50/200 trend filter           |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

input double InpLots              = 0.10;   // fixed lots if InpRiskPercent = 0
input double InpRiskPercent       = 0.5;    // % of balance lost at the stop (0 = fixed lots)
input long   InpMagic             = 920520;
input int    InpServerGMTOffset   = 2;      // server GMT offset in US winter
input bool   InpServerFollowsUSDST = true;  // server moves +1h with US DST
input int    InpRangeStartMin     = 570;    // 09:30 NY
input int    InpRangeEndMin       = 575;    // 09:35 NY (exclusive)
input int    InpLastEntryMin      = 600;    // 10:00 NY: no entry on bars opening at or after this
input double InpRR                = 1.0;    // take profit in R
input int    InpSLMode            = 0;      // 0 = other side of the range, 1 = range middle
input int    InpExitAfterMin      = 15;     // close after N minutes (0 = no time exit)
input int    InpForceCloseMin     = 960;    // 16:00 NY: hard close
input double InpMinRangePts       = 0;      // skip if range smaller (points, 0 = off)
input double InpMaxRangePts       = 0;      // skip if range larger  (points, 0 = off)
input bool   InpUseTrendFilter    = false;
input ENUM_TIMEFRAMES InpTrendTF  = PERIOD_M15;
input int    InpFastEMA           = 50;
input int    InpSlowEMA           = 200;
input int    InpDeviation         = 30;

CTrade   trade;
int      hFast = INVALID_HANDLE, hSlow = INVALID_HANDLE;
datetime lastBar = 0;
int      dayKey  = 0;
double   rHi = 0, rLo = 0;
int      rCount = 0;
bool     decided = false;
datetime openTime = 0;

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
   MqlDateTime d; TimeToStruct(utc, d);
   datetime start = SundayOfMonth(d.year, 3, 2)  + 7 * 3600;
   datetime end   = SundayOfMonth(d.year, 11, 1) + 6 * 3600;
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

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   if(InpUseTrendFilter)
     {
      hFast = iMA(_Symbol, InpTrendTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
      hSlow = iMA(_Symbol, InpTrendTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE) return INIT_FAILED;
     }
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(hFast != INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow != INVALID_HANDLE) IndicatorRelease(hSlow);
  }

bool HasPosition(ulong &ticket)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
        { ticket = tk; return true; }
     }
   return false;
  }

int TrendDirection()
  {
   double f[1], s[1];
   if(CopyBuffer(hFast, 0, 1, 1, f) != 1) return 0;
   if(CopyBuffer(hSlow, 0, 1, 1, s) != 1) return 0;
   if(f[0] > s[0]) return 1;
   if(f[0] < s[0]) return -1;
   return 0;
  }

double CalcLots(ENUM_ORDER_TYPE type, double entry, double sl)
  {
   if(InpRiskPercent <= 0.0) return InpLots;
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = minV;
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   double profit = 0.0;
   if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, profit) || profit >= 0.0) return 0.0;
   double lots = MathFloor(riskMoney / (-profit) / step) * step;
   double margin = 0.0, freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(lots > 0.0 && OrderCalcMargin(type, _Symbol, lots, entry, margin) && margin > freeMargin && margin > 0.0)
      lots = MathFloor(lots * freeMargin / margin / step) * step;
   if(lots < minV) return 0.0;
   return NormalizeDouble(MathMin(lots, maxV), 8);
  }

void OpenTrade(int dir)
  {
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double mid = (rHi + rLo) / 2.0;
   if(dir > 0)
     {
      double sl = NormalizeDouble(InpSLMode == 1 ? mid : rLo, digits);
      if(ask - sl < 5 * point) { Print("Skip buy: entry too close to stop"); return; }
      double tp = NormalizeDouble(ask + InpRR * (ask - sl), digits);
      double lots = CalcLots(ORDER_TYPE_BUY, ask, sl);
      if(lots <= 0) return;
      if(trade.Buy(lots, _Symbol, 0.0, sl, tp, "nyopen") && trade.ResultRetcode() == TRADE_RETCODE_DONE)
         openTime = TimeCurrent();
     }
   else
     {
      double sl = NormalizeDouble(InpSLMode == 1 ? mid : rHi, digits);
      if(sl - bid < 5 * point) { Print("Skip sell: entry too close to stop"); return; }
      double tp = NormalizeDouble(bid - InpRR * (sl - bid), digits);
      double lots = CalcLots(ORDER_TYPE_SELL, bid, sl);
      if(lots <= 0) return;
      if(trade.Sell(lots, _Symbol, 0.0, sl, tp, "nyopen") && trade.ResultRetcode() == TRADE_RETCODE_DONE)
         openTime = TimeCurrent();
     }
  }

void ProcessClosedBar()
  {
   datetime bt = iTime(_Symbol, PERIOD_M1, 1);
   if(bt == 0) return;
   MqlDateTime ny; TimeToStruct(ServerToNY(bt), ny);
   int key = ny.year * 10000 + ny.mon * 100 + ny.day;
   if(key != dayKey) { dayKey = key; rHi = 0; rLo = 0; rCount = 0; decided = false; }
   int m = ny.hour * 60 + ny.min;
   double h = iHigh(_Symbol, PERIOD_M1, 1), l = iLow(_Symbol, PERIOD_M1, 1), c = iClose(_Symbol, PERIOD_M1, 1);

   if(m >= InpRangeStartMin && m < InpRangeEndMin)
     {
      if(rCount == 0) { rHi = h; rLo = l; }
      else { rHi = MathMax(rHi, h); rLo = MathMin(rLo, l); }
      rCount++;
      return;
     }
   if(decided || m < InpRangeEndMin) return;
   if(m >= InpLastEntryMin) { decided = true; return; }
   if(rCount < (InpRangeEndMin - InpRangeStartMin)) { decided = true; return; }   // incomplete range

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double rangePts = (rHi - rLo) / point;
   if((InpMinRangePts > 0 && rangePts < InpMinRangePts) || (InpMaxRangePts > 0 && rangePts > InpMaxRangePts))
     { decided = true; return; }

   int dir = 0;
   if(c > rHi) dir = 1; else if(c < rLo) dir = -1;
   if(dir == 0) return;
   decided = true;                                   // first breakout only
   if(InpUseTrendFilter && TrendDirection() != dir) return;
   ulong pos;
   if(HasPosition(pos)) return;
   OpenTrade(dir);
  }

void OnTick()
  {
   ulong pos;
   if(HasPosition(pos))
     {
      MqlDateTime ny; TimeToStruct(ServerToNY(TimeCurrent()), ny);
      int m = ny.hour * 60 + ny.min;
      bool timeUp = InpExitAfterMin > 0 && TimeCurrent() - openTime >= InpExitAfterMin * 60;
      if(timeUp || m >= InpForceCloseMin) trade.PositionClose(pos);
     }
   datetime b = iTime(_Symbol, PERIOD_M1, 0);
   if(b != lastBar) { lastBar = b; ProcessClosedBar(); }
  }
//+------------------------------------------------------------------+
