//+------------------------------------------------------------------+
//| NYMeanRevert.mq5                                                  |
//| Midday mean reversion to a session reference (US index CFDs).     |
//|  reference (InpRefType):                                          |
//|    0 = VWAP anchored at 09:30 NY, weighted by TICK volume         |
//|    1 = TWAP anchored at 09:30 NY (every M1 bar weighs the same)   |
//|    2 = EMA(InpEmaPeriod) on M1 closes                             |
//|  entry : M1 close beyond ref +/- InpEntryATR x ATR(M5) during     |
//|          InpEntryStartMin..InpEntryEndMin NY, fade the deviation  |
//|  target: the reference value at entry time                        |
//|  stop  : InpStopATR x ATR beyond the entry                        |
//|  exit  : flat at InpFlatMin NY; max InpMaxTrades per day          |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

input int    InpRefType           = 0;      // 0 VWAP(tick vol), 1 TWAP, 2 EMA
input int    InpEmaPeriod         = 100;    // EMA period on M1 (ref type 2)
input double InpEntryATR          = 2.0;    // deviation from ref to enter, in ATR(M5)
input double InpStopATR           = 1.5;    // stop distance beyond entry, in ATR(M5)
input int    InpAtrPeriod         = 14;
input int    InpAnchorMin         = 570;    // 09:30 NY: VWAP/TWAP anchor
input int    InpEntryStartMin     = 690;    // 11:30 NY
input int    InpEntryEndMin       = 840;    // 14:00 NY
input int    InpFlatMin           = 900;    // 15:00 NY: close any position
input int    InpMaxTrades         = 1;      // trades per day
input double InpRiskPercent       = 0.5;    // % of balance at the stop (0 = fixed lots)
input double InpLots              = 0.10;
input long   InpMagic             = 920530;
input int    InpServerGMTOffset   = 2;
input bool   InpServerFollowsUSDST = true;
input int    InpDeviation         = 30;

CTrade   trade;
int      hAtr = INVALID_HANDLE, hEma = INVALID_HANDLE;
datetime lastBar = 0;
int      dayKey = 0, tradesToday = 0;
double   sumPV = 0, sumV = 0, sumP = 0;
int      nBars = 0;

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
   hAtr = iATR(_Symbol, PERIOD_M5, InpAtrPeriod);
   if(hAtr == INVALID_HANDLE) return INIT_FAILED;
   if(InpRefType == 2)
     {
      hEma = iMA(_Symbol, PERIOD_M1, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(hEma == INVALID_HANDLE) return INIT_FAILED;
     }
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(hAtr != INVALID_HANDLE) IndicatorRelease(hAtr);
   if(hEma != INVALID_HANDLE) IndicatorRelease(hEma);
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

double Reference()
  {
   if(InpRefType == 0) return sumV > 0 ? sumPV / sumV : 0.0;
   if(InpRefType == 1) return nBars > 0 ? sumP / nBars : 0.0;
   double e[1];
   if(CopyBuffer(hEma, 0, 1, 1, e) != 1) return 0.0;
   return e[0];
  }

void ProcessClosedBar()
  {
   datetime bt = iTime(_Symbol, PERIOD_M1, 1);
   if(bt == 0) return;
   MqlDateTime ny; TimeToStruct(ServerToNY(bt), ny);
   int key = ny.year * 10000 + ny.mon * 100 + ny.day;
   if(key != dayKey) { dayKey = key; sumPV = 0; sumV = 0; sumP = 0; nBars = 0; tradesToday = 0; }
   int m = ny.hour * 60 + ny.min;

   double h = iHigh(_Symbol, PERIOD_M1, 1), l = iLow(_Symbol, PERIOD_M1, 1), c = iClose(_Symbol, PERIOD_M1, 1);
   if(m >= InpAnchorMin)
     {
      double tp = (h + l + c) / 3.0;
      double v  = (double)iVolume(_Symbol, PERIOD_M1, 1);   // tick volume
      sumPV += tp * v; sumV += v; sumP += tp; nBars++;
     }

   if(m < InpEntryStartMin || m >= InpEntryEndMin) return;
   if(tradesToday >= InpMaxTrades) return;
   ulong pos;
   if(HasPosition(pos)) return;
   if(nBars < 30) return;

   double ref = Reference();
   double a[1];
   if(ref <= 0 || CopyBuffer(hAtr, 0, 1, 1, a) != 1 || a[0] <= 0) return;
   double atr = a[0];
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(c > ref + InpEntryATR * atr)          // stretched up -> SELL back to ref
     {
      double sl = NormalizeDouble(bid + InpStopATR * atr, digits);
      double tp = NormalizeDouble(ref, digits);
      if(tp >= bid) return;
      double lots = CalcLots(ORDER_TYPE_SELL, bid, sl);
      if(lots > 0 && trade.Sell(lots, _Symbol, 0.0, sl, tp, "meanrev") && trade.ResultRetcode() == TRADE_RETCODE_DONE)
         tradesToday++;
     }
   else if(c < ref - InpEntryATR * atr)     // stretched down -> BUY back to ref
     {
      double sl = NormalizeDouble(ask - InpStopATR * atr, digits);
      double tp = NormalizeDouble(ref, digits);
      if(tp <= ask) return;
      double lots = CalcLots(ORDER_TYPE_BUY, ask, sl);
      if(lots > 0 && trade.Buy(lots, _Symbol, 0.0, sl, tp, "meanrev") && trade.ResultRetcode() == TRADE_RETCODE_DONE)
         tradesToday++;
     }
  }

void OnTick()
  {
   ulong pos;
   if(HasPosition(pos))
     {
      MqlDateTime ny; TimeToStruct(ServerToNY(TimeCurrent()), ny);
      if(ny.hour * 60 + ny.min >= InpFlatMin) trade.PositionClose(pos);
     }
   datetime b = iTime(_Symbol, PERIOD_M1, 0);
   if(b != lastBar) { lastBar = b; ProcessClosedBar(); }
  }
//+------------------------------------------------------------------+
