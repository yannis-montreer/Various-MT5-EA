//+------------------------------------------------------------------+
//| VwapEma9.mq5                                                      |
//| Rules from a social-media reel ("VWAP + 9 EMA", 5-minute Nasdaq): |
//|  1. EMA 9 crosses the session VWAP                                |
//|  2. a bar closes on the cross side of the EMA -> enter            |
//|  3. stay in                                                       |
//|  4. a bar closes back through the EMA -> exit                     |
//| Gaps filled here (not in the reel): shorts mirrored, VWAP anchored|
//| at 09:30 NY with tick volume, entries 09:30-15:30 NY, flat at     |
//| 15:55 NY, one entry per cross, risk sized on a swing stop.        |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

input ENUM_TIMEFRAMES InpTF       = PERIOD_M5;
input int    InpEmaPeriod         = 9;
input int    InpAnchorMin         = 570;    // 09:30 NY: VWAP anchor
input int    InpFirstEntryMin     = 575;    // 09:35 NY: first bar that may trigger
input int    InpLastEntryMin      = 930;    // 15:30 NY
input int    InpFlatMin           = 955;    // 15:55 NY
input int    InpMaxTradesPerDay   = 0;      // 0 = no limit
input bool   InpUseLong           = true;
input bool   InpUseShort          = true;
input int    InpSLBars            = 10;     // swing stop: lowest low / highest high of the last N bars
input double InpSLBufATR          = 0.1;
input bool   InpUseHardSL         = true;   // false = exit on EMA only; an emergency stop sits at InpEmergencyMult x the swing distance
input double InpEmergencyMult     = 3.0;
input double InpRiskPercent       = 0.5;    // risk on the swing stop distance
input double InpLots              = 0.10;
input long   InpMagic             = 920560;
input int    InpServerGMTOffset   = 2;
input bool   InpServerFollowsUSDST = true;
input int    InpDeviation         = 30;

CTrade   trade;
int      hEma = INVALID_HANDLE, hAtr = INVALID_HANDLE;
datetime lastBar = 0;
int      dayKey = 0, tradesToday = 0;
double   sumPV = 0, sumV = 0;
int      armed = 0;          // +1 after EMA crossed above VWAP, -1 below, 0 none / used
int      prevSide = 0;       // sign(EMA - VWAP) on the previous bar
int      posDir = 0;

datetime SundayOfMonth(int year, int month, int nth)
  {
   MqlDateTime d; d.year = year; d.mon = month; d.day = 1; d.hour = 0; d.min = 0; d.sec = 0;
   datetime t = StructToTime(d); TimeToStruct(t, d);
   int firstSun = 1 + (7 - d.day_of_week) % 7;
   d.day = firstSun + 7 * (nth - 1);
   return StructToTime(d);
  }
bool IsUSDST(datetime utc)
  {
   MqlDateTime d; TimeToStruct(utc, d);
   return utc >= SundayOfMonth(d.year, 3, 2) + 7 * 3600 && utc < SundayOfMonth(d.year, 11, 1) + 6 * 3600;
  }
datetime ServerToNY(datetime s)
  {
   bool dst = IsUSDST(s - InpServerGMTOffset * 3600);
   int off = InpServerGMTOffset + ((InpServerFollowsUSDST && dst) ? 1 : 0);
   return s - off * 3600 + (dst ? -4 : -5) * 3600;
  }

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   hEma = iMA(_Symbol, InpTF, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hAtr = iATR(_Symbol, InpTF, 14);
   if(hEma == INVALID_HANDLE || hAtr == INVALID_HANDLE) return INIT_FAILED;
   return INIT_SUCCEEDED;
  }
void OnDeinit(const int r) { IndicatorRelease(hEma); IndicatorRelease(hAtr); }

bool HasPosition(ulong &ticket)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
        { ticket = tk; return true; }
     }
   return false;
  }

double CalcLots(ENUM_ORDER_TYPE type, double entry, double sl)
  {
   if(InpRiskPercent <= 0.0) return InpLots;
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); if(step <= 0) step = minV;
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0, profit = 0;
   if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, profit) || profit >= 0) return 0;
   double lots = MathFloor(riskMoney / (-profit) / step) * step;
   double margin = 0, fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(lots > 0 && OrderCalcMargin(type, _Symbol, lots, entry, margin) && margin > fm && margin > 0)
      lots = MathFloor(lots * fm / margin / step) * step;
   if(lots < minV) return 0;
   return NormalizeDouble(MathMin(lots, maxV), 8);
  }

void Open(int dir)
  {
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double a[1]; if(CopyBuffer(hAtr, 0, 1, 1, a) != 1) return;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(dir > 0)
     {
      double lo = iLow(_Symbol, InpTF, iLowest(_Symbol, InpTF, MODE_LOW, InpSLBars, 1)) - InpSLBufATR * a[0];
      double dist = ask - lo; if(dist <= 0) return;
      double lots = CalcLots(ORDER_TYPE_BUY, ask, lo); if(lots <= 0) return;
      double sl = NormalizeDouble(InpUseHardSL ? lo : ask - InpEmergencyMult * dist, digits);
      if(trade.Buy(lots, _Symbol, 0, sl, 0, "vwapema") && trade.ResultRetcode() == TRADE_RETCODE_DONE) { posDir = 1; tradesToday++; }
     }
   else
     {
      double hi = iHigh(_Symbol, InpTF, iHighest(_Symbol, InpTF, MODE_HIGH, InpSLBars, 1)) + InpSLBufATR * a[0];
      double dist = hi - bid; if(dist <= 0) return;
      double lots = CalcLots(ORDER_TYPE_SELL, bid, hi); if(lots <= 0) return;
      double sl = NormalizeDouble(InpUseHardSL ? hi : bid + InpEmergencyMult * dist, digits);
      if(trade.Sell(lots, _Symbol, 0, sl, 0, "vwapema") && trade.ResultRetcode() == TRADE_RETCODE_DONE) { posDir = -1; tradesToday++; }
     }
  }

void OnTick()
  {
   ulong pos;
   bool has = HasPosition(pos);
   MqlDateTime nyNow; TimeToStruct(ServerToNY(TimeCurrent()), nyNow);
   if(has && nyNow.hour * 60 + nyNow.min >= InpFlatMin) { trade.PositionClose(pos); has = false; }

   datetime b = iTime(_Symbol, InpTF, 0);
   if(b == lastBar) return;
   lastBar = b;

   datetime bt = iTime(_Symbol, InpTF, 1);
   MqlDateTime ny; TimeToStruct(ServerToNY(bt), ny);
   int key = ny.year * 10000 + ny.mon * 100 + ny.day;
   if(key != dayKey) { dayKey = key; sumPV = sumV = 0; tradesToday = 0; armed = 0; prevSide = 0; }
   int m = ny.hour * 60 + ny.min;
   if(m < InpAnchorMin) return;

   double h = iHigh(_Symbol, InpTF, 1), l = iLow(_Symbol, InpTF, 1), c = iClose(_Symbol, InpTF, 1);
   double v = (double)iVolume(_Symbol, InpTF, 1);
   sumPV += (h + l + c) / 3.0 * v; sumV += v;
   if(sumV <= 0) return;
   double vwap = sumPV / sumV;
   double e[1]; if(CopyBuffer(hEma, 0, 1, 1, e) != 1) return;
   double ema = e[0];

   // exit: close back through the EMA
   if(has)
     {
      if((posDir > 0 && c < ema) || (posDir < 0 && c > ema)) { trade.PositionClose(pos); has = false; }
     }
   else posDir = 0;

   // crosses of EMA vs VWAP arm one entry in that direction
   int side = ema > vwap ? 1 : (ema < vwap ? -1 : 0);
   if(prevSide != 0 && side != 0 && side != prevSide) armed = side;
   if(side != 0) prevSide = side;
   if(armed != 0 && side != armed) armed = 0;          // crossed back before entering

   if(has || armed == 0) return;
   if(m < InpFirstEntryMin || m >= InpLastEntryMin) return;
   if(InpMaxTradesPerDay > 0 && tradesToday >= InpMaxTradesPerDay) return;
   if(armed > 0 && InpUseLong && c > ema)  { Open(1);  armed = 0; }
   else if(armed < 0 && InpUseShort && c < ema) { Open(-1); armed = 0; }
  }
//+------------------------------------------------------------------+
