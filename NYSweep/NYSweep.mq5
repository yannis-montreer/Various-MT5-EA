//+------------------------------------------------------------------+
//| NYSweep.mq5                                                       |
//| Prior-day high/low "sweep" fades (idea seen in a proplensapp reel)|
//|  PDL long : bar close > prevLow  and previous close <= prevLow    |
//|  PDH short: bar close < prevHigh and previous close >= prevHigh   |
//|  NY session 09:35-11:00: stop 2 x ATR, target 0.1667R / 0.25R     |
//|  Pre-NY     08:00-09:30: stop 4 x ATR, target 0.5R / 0.3333R      |
//|  one position at a time, flat at 15:00 NY                         |
//| ATR = simple average of true range (InpAtrPeriod bars, InpTF).    |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

input ENUM_TIMEFRAMES InpTF       = PERIOD_M5;
input int    InpPrevMode          = 0;      // prior-day levels: 0 = RTH 09:30-16:00 NY, 1 = full NY day
input bool   InpUseNY             = true;   // NY-session sweeps
input bool   InpUsePre            = true;   // pre-NY sweeps
input bool   InpUseLong           = true;
input bool   InpUseShort          = true;
input int    InpNYStartMin        = 575;    // 09:35
input int    InpNYEndMin          = 660;    // 11:00
input int    InpPreStartMin       = 480;    // 08:00
input int    InpPreEndMin         = 570;    // 09:30
input double InpNYStopATR         = 2.0;
input double InpPreStopATR        = 4.0;
input double InpTP_NYLong         = 0.1667; // R
input double InpTP_NYShort        = 0.25;
input double InpTP_PreLong        = 0.5;
input double InpTP_PreShort       = 0.3333;
input int    InpMax_NYLong        = 5;      // per day
input int    InpMax_NYShort       = 1;
input int    InpMax_PreLong       = 1;
input int    InpMax_PreShort      = 1;
input int    InpAtrPeriod         = 14;
input int    InpFlatMin           = 900;    // 15:00 NY
input double InpRiskPercent       = 0.5;
input double InpLots              = 0.10;
input long   InpMagic             = 920540;
input int    InpServerGMTOffset   = 2;
input bool   InpServerFollowsUSDST = true;
input int    InpDeviation         = 30;

CTrade   trade;
datetime lastBar = 0;
int      dayKey = 0;
double   curHi = 0, curLo = 0, prevHi = 0, prevLo = 0;
bool     curHas = false, prevOk = false;
int      nNYL = 0, nNYS = 0, nPreL = 0, nPreS = 0;

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
   return INIT_SUCCEEDED;
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

double SimpleATR()
  {
   double sum = 0;
   for(int i = 1; i <= InpAtrPeriod; i++)
     {
      double h = iHigh(_Symbol, InpTF, i), l = iLow(_Symbol, InpTF, i), pc = iClose(_Symbol, InpTF, i + 1);
      if(h == 0 || pc == 0) return 0;
      sum += MathMax(h, pc) - MathMin(l, pc);
     }
   return sum / InpAtrPeriod;
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

bool Open(int dir, double stopATR, double tpR, string tag)
  {
   double atr = SimpleATR();
   if(atr <= 0) return false;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double dist = stopATR * atr;
   if(dir > 0)
     {
      double sl = NormalizeDouble(ask - dist, digits), tp = NormalizeDouble(ask + tpR * dist, digits);
      double lots = CalcLots(ORDER_TYPE_BUY, ask, sl);
      return lots > 0 && trade.Buy(lots, _Symbol, 0.0, sl, tp, tag) && trade.ResultRetcode() == TRADE_RETCODE_DONE;
     }
   double sl = NormalizeDouble(bid + dist, digits), tp = NormalizeDouble(bid - tpR * dist, digits);
   double lots = CalcLots(ORDER_TYPE_SELL, bid, sl);
   return lots > 0 && trade.Sell(lots, _Symbol, 0.0, sl, tp, tag) && trade.ResultRetcode() == TRADE_RETCODE_DONE;
  }

void ProcessClosedBar()
  {
   datetime bt = iTime(_Symbol, InpTF, 1);
   if(bt == 0) return;
   MqlDateTime ny; TimeToStruct(ServerToNY(bt), ny);
   int key = ny.year * 10000 + ny.mon * 100 + ny.day;
   if(key != dayKey)
     {
      if(curHas) { prevHi = curHi; prevLo = curLo; prevOk = true; }
      dayKey = key; curHas = false; nNYL = nNYS = nPreL = nPreS = 0;
     }
   int m = ny.hour * 60 + ny.min;
   double h = iHigh(_Symbol, InpTF, 1), l = iLow(_Symbol, InpTF, 1);
   double c = iClose(_Symbol, InpTF, 1), pc = iClose(_Symbol, InpTF, 2);

   // trade on this bar (levels = previous day only), then update today's levels
   ulong pos;
   if(prevOk && !HasPosition(pos) && ny.day_of_week >= 1 && ny.day_of_week <= 5)
     {
      bool inNY  = InpUseNY  && m >= InpNYStartMin  && m < InpNYEndMin;
      bool inPre = InpUsePre && m >= InpPreStartMin && m < InpPreEndMin;
      bool longSig  = InpUseLong  && c > prevLo && pc <= prevLo;
      bool shortSig = InpUseShort && c < prevHi && pc >= prevHi;
      if(inNY)
        {
         if(longSig && nNYL < InpMax_NYLong && Open(1, InpNYStopATR, InpTP_NYLong, "pdl")) nNYL++;
         else if(shortSig && nNYS < InpMax_NYShort && Open(-1, InpNYStopATR, InpTP_NYShort, "pdh")) nNYS++;
        }
      else if(inPre)
        {
         if(longSig && nPreL < InpMax_PreLong && Open(1, InpPreStopATR, InpTP_PreLong, "prepdl")) nPreL++;
         else if(shortSig && nPreS < InpMax_PreShort && Open(-1, InpPreStopATR, InpTP_PreShort, "prepdh")) nPreS++;
        }
     }

   bool count = (InpPrevMode == 1) || (m >= 570 && m < 960);
   if(count)
     {
      if(!curHas) { curHi = h; curLo = l; curHas = true; }
      else { curHi = MathMax(curHi, h); curLo = MathMin(curLo, l); }
     }
  }

void OnTick()
  {
   ulong pos;
   if(HasPosition(pos))
     {
      MqlDateTime ny; TimeToStruct(ServerToNY(TimeCurrent()), ny);
      int m = ny.hour * 60 + ny.min;
      if(m >= InpFlatMin) trade.PositionClose(pos);
     }
   datetime b = iTime(_Symbol, InpTF, 0);
   if(b != lastBar) { lastBar = b; ProcessClosedBar(); }
  }
//+------------------------------------------------------------------+
