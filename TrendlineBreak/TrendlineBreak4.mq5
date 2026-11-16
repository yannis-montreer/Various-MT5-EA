//+------------------------------------------------------------------+
//| TrendlineBreak.mq5                                                |
//| Mechanical version of a trendline-break swing strategy            |
//| (Tori Trades style), H4.                                          |
//|                                                                   |
//| Lines are drawn automatically from confirmed swing points:        |
//|  - falling "action line" through swing highs (long on its break), |
//|    rising action line through swing lows (short on its break)     |
//|  - valid line: >= InpMinTouches swing points within InpTouchTolATR|
//|    x ATR, touches >= InpMinSpacing bars apart, first touch at     |
//|    least InpMinDurBars before the break, slope limited, no close  |
//|    through the line before the break, no swing point cutting it   |
//|  - several valid lines: most touches, then the most recent        |
//| Entry : market, at the open after an H4 close through the line.   |
//|         One attempt per line.                                     |
//| Stop  : last confirmed opposite swing point -/+ InpStopBufATR*ATR |
//| Exit  : a new line in the trade direction is built from the stop  |
//|         swing and the later swing points (higher lows for a long);|
//|         an H4 close through it closes the trade. Optional R target|
//| Lines are drawn on the chart (visual tester) for checking.        |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

input ENUM_TIMEFRAMES InpTF   = PERIOD_H4;
input int    InpSwingN        = 3;      // swing point: bars on each side
input int    InpLookback      = 400;    // bars searched for lines (~13 weeks of gold H4)
input int    InpMinTouches    = 3;
input double InpTouchTolATR   = 1.0;    // touch tolerance, x ATR (touches are approximate)
input int    InpMinSpacing    = 6;      // bars between counted touches
input int    InpMinDurBars    = 90;     // first touch to break (~3 weeks of gold H4)
input double InpMaxSlopeATR   = 0.5;    // max |slope| in ATR per bar
input double InpStopBufATR    = 0.25;
input double InpMaxStopATR    = 8.0;    // skip if the stop is farther than this
input double InpTargetR       = 0.0;    // 0 = no target (exit on the trailing line only)
input bool   InpTrailHardSL   = true;   // also move the hard stop to each new swing (never loosened)
input int    InpTrailMode     = 2;      // 0 = last two swings, 1 = anchored at the stop swing, 2 = "snail": ever steeper chained lines
input int    InpTrailMinTouch = 2;      // trailing line becomes active once it has this many touches (stop swing included)
input bool   InpUseTrend      = true;   // trade only with the trend: close above the EMA -> longs only, below -> shorts only
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_D1;
input int    InpTrendEMA      = 50;
input bool   InpUseLong       = true;
input bool   InpUseShort      = true;
input int    InpAtrPeriod     = 14;
input double InpRiskPercent   = 1.0;
input double InpLots          = 0.10;
input long   InpMagic         = 920553;
input bool   InpDraw          = true;
input group "News guard: no entry or line exit near high-impact news"
input bool   InpUseNewsGuard  = false;  // enable news guard (off by default; FundedNext funded accounts: on)
input int    InpNewsBeforeSec = 30;     // seconds before the event
input int    InpNewsAfterSec  = 30;     // seconds after the event
input string InpNewsCurrencies = "USD"; // currencies tied to the symbol, comma separated
input string InpNewsFile      = "NYNews_FN.csv"; // tester: "yyyy.mm.dd hh:mi;CUR;importance;name" in Common\Files (server time)
input string InpNewsIdsFile   = "NYNewsIds.txt"; // live: MT5 event ids to guard (Common\Files); missing = all high-impact

//--- news guard (same approach as NYBoxBreakoutNews) ---
datetime g_news[];
int      g_newsCount = 0;
string   g_cur[];
ulong    g_ids[];
datetime g_newsLoadedAt = 0;
int      s_deferred = 0;
datetime g_deferBar = 0;

bool CurrencyWanted(string c)
  {
   StringTrimLeft(c); StringTrimRight(c); StringToUpper(c);
   for(int i = 0; i < ArraySize(g_cur); i++) if(g_cur[i] == c) return true;
   return false;
  }

void AddNews(datetime t) { ArrayResize(g_news, g_newsCount + 1, 1024); g_news[g_newsCount++] = t; }

bool LoadNewsFile()
  {
   int h = FileOpen(InpNewsFile, FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON, ';');
   if(h == INVALID_HANDLE) return false;
   g_newsCount = 0; ArrayResize(g_news, 0);
   while(!FileIsEnding(h))
     {
      string ts = FileReadString(h), cur = FileReadString(h), imp = FileReadString(h), nm = FileReadString(h);
      if(StringLen(ts) < 10 || StringToInteger(imp) < 3 || !CurrencyWanted(cur)) continue;
      datetime t = StringToTime(ts);
      if(t > 0) AddNews(t);
     }
   FileClose(h);
   ArraySort(g_news);
   return true;
  }

void LoadIdsFile()
  {
   ArrayResize(g_ids, 0);
   int h = FileOpen(InpNewsIdsFile, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE) return;
   while(!FileIsEnding(h))
     {
      string s = FileReadString(h); StringTrimLeft(s); StringTrimRight(s);
      ulong id = (ulong)StringToInteger(s);
      if(id == 0) continue;
      int k = ArraySize(g_ids); ArrayResize(g_ids, k + 1); g_ids[k] = id;
     }
   FileClose(h);
  }

bool IdWanted(ulong id)
  {
   for(int i = 0; i < ArraySize(g_ids); i++) if(g_ids[i] == id) return true;
   return false;
  }

void LoadNewsLive()
  {
   g_newsCount = 0; ArrayResize(g_news, 0);
   datetime from = TimeCurrent() - 86400, to = TimeCurrent() + 4 * 86400;
   bool useIds = ArraySize(g_ids) > 0;
   for(int c = 0; c < ArraySize(g_cur); c++)
     {
      MqlCalendarValue v[];
      int cnt = CalendarValueHistory(v, from, to, NULL, g_cur[c]);
      for(int i = 0; i < cnt; i++)
        {
         if(useIds) { if(!IdWanted(v[i].event_id)) continue; }
         else
           {
            MqlCalendarEvent ev;
            if(!CalendarEventById(v[i].event_id, ev) || ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;
           }
         AddNews(v[i].time);
        }
     }
   ArraySort(g_news);
   g_newsLoadedAt = TimeCurrent();
  }

// true if a listed event lies in [t - after, t + before]
bool InNewsWindow(datetime t)
  {
   int lo = 0, hi = g_newsCount;
   datetime from = t - InpNewsAfterSec;
   while(lo < hi) { int mid = (lo + hi) / 2; if(g_news[mid] < from) lo = mid + 1; else hi = mid; }
   return lo < g_newsCount && g_news[lo] <= t + InpNewsBeforeSec;
  }

bool InitNews()
  {
   if(!InpUseNewsGuard) return true;
   string parts[];
   int k = StringSplit(InpNewsCurrencies, ',', parts);
   ArrayResize(g_cur, k);
   for(int i = 0; i < k; i++) { string c = parts[i]; StringTrimLeft(c); StringTrimRight(c); StringToUpper(c); g_cur[i] = c; }
   if(MQLInfoInteger(MQL_TESTER))
     {
      if(!LoadNewsFile()) { PrintFormat("News guard: cannot open '%s' in Common\\Files", InpNewsFile); return false; }
      PrintFormat("News guard: %d events loaded from %s", g_newsCount, InpNewsFile);
     }
   else
     {
      LoadIdsFile(); LoadNewsLive();
      PrintFormat("News guard (live calendar): %d events loaded", g_newsCount);
     }
   return true;
  }

CTrade   trade;
datetime lastBar = 0;
string   usedKeys[];
// open-trade state
int      tDir = 0;
datetime tAnchorTime = 0;   // swing point that set the initial stop
datetime tEntryTime  = 0;
double   tRisk = 0;

MqlRates R[];
int      n = 0;
double   atr = 0;

int hTrend = INVALID_HANDLE;

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(50);
   ArraySetAsSeries(R, false);
   if(InpUseTrend)
     {
      hTrend = iMA(_Symbol, InpTrendTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(hTrend == INVALID_HANDLE) return INIT_FAILED;
     }
   if(!InitNews()) return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

// +1 up (last closed trend-TF bar above its EMA), -1 down, 0 unknown
int TrendDir()
  {
   double e[1];
   if(CopyBuffer(hTrend, 0, 1, 1, e) != 1) return 0;
   double c = iClose(_Symbol, InpTrendTF, 1);
   if(c > e[0]) return 1;
   if(c < e[0]) return -1;
   return 0;
  }

void OnDeinit(const int reason)
  {
   if(InpUseNewsGuard) PrintFormat("NEWS GUARD bars postponed: %d", s_deferred);
   if(!MQLInfoInteger(MQL_TESTER)) ObjectsDeleteAll(0, "TLB_");
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

bool IsSwingHigh(int k)
  {
   if(k - InpSwingN < 0 || k + InpSwingN > n - 1) return false;
   for(int m = 1; m <= InpSwingN; m++)
      if(R[k - m].high >= R[k].high || R[k + m].high > R[k].high) return false;
   return true;
  }

bool IsSwingLow(int k)
  {
   if(k - InpSwingN < 0 || k + InpSwingN > n - 1) return false;
   for(int m = 1; m <= InpSwingN; m++)
      if(R[k - m].low <= R[k].low || R[k + m].low < R[k].low) return false;
   return true;
  }

double CalcATR(int at)
  {
   double s = 0;
   for(int k = at - InpAtrPeriod + 1; k <= at; k++)
     {
      double pc = R[k - 1].close;
      s += MathMax(R[k].high, pc) - MathMin(R[k].low, pc);
     }
   return s / InpAtrPeriod;
  }

bool KeyUsed(string key)
  {
   for(int i = ArraySize(usedKeys) - 1; i >= 0; i--) if(usedKeys[i] == key) return true;
   return false;
  }

void DrawLine(string name, datetime t1, double p1, datetime t2, double p2, color c)
  {
   if(!InpDraw) return;
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
  }

// Best action line broken by the last closed bar (index n-1).
// dir = +1: falling line through swing highs (long). dir = -1: rising line through swing lows (short).
bool FindBrokenLine(int dir, int &bi, int &bj, int &bTouches)
  {
   int last = n - 1;
   int sw[]; ArrayResize(sw, 0, 256);
   for(int k = MathMax(0, last - InpLookback); k <= last - 1; k++)
      if(dir > 0 ? IsSwingHigh(k) : IsSwingLow(k)) { int s = ArraySize(sw); ArrayResize(sw, s + 1); sw[s] = k; }
   int ns = ArraySize(sw);
   double tol = InpTouchTolATR * atr;
   bi = -1; bj = -1; bTouches = 0;

   for(int a = 0; a < ns; a++)
     {
      int i = sw[a];
      if(last - i < InpMinDurBars) break;               // sw[] ascending
      double pi = dir > 0 ? R[i].high : R[i].low;
      for(int b = a + 1; b < ns; b++)
        {
         int j = sw[b];
         if(j - i < InpMinSpacing) continue;
         double pj = dir > 0 ? R[j].high : R[j].low;
         if(dir > 0 && pj >= pi) continue;               // must fall
         if(dir < 0 && pj <= pi) continue;               // must rise
         double slope = (pj - pi) / (j - i);
         if(MathAbs(slope) > InpMaxSlopeATR * atr) continue;

         bool ok = true;
         // no close through the line before the break bar
         for(int x = i + 1; x <= last - 1 && ok; x++)
           {
            double lv = pi + slope * (x - i);
            if(dir > 0 && R[x].close > lv) ok = false;
            if(dir < 0 && R[x].close < lv) ok = false;
           }
         if(!ok) continue;
         // break on the last closed bar
         double lvLast = pi + slope * (last - i);
         if(dir > 0 && R[last].close <= lvLast) continue;
         if(dir < 0 && R[last].close >= lvLast) continue;
         // swing points must not cut the line; count spaced touches
         int touches = 0, lastTouch = -100000;
         for(int c = a; c < ns && ok; c++)
           {
            int k = sw[c];
            double lv = pi + slope * (k - i);
            double p  = dir > 0 ? R[k].high : R[k].low;
            if(dir > 0 && p > lv + tol) ok = false;
            if(dir < 0 && p < lv - tol) ok = false;
            if(ok && MathAbs(p - lv) <= tol && k - lastTouch >= InpMinSpacing) { touches++; lastTouch = k; }
           }
         if(!ok || touches < InpMinTouches) continue;
         string key = (string)(long)R[i].time + "_" + (string)(long)R[j].time + "_" + (string)dir;
         if(KeyUsed(key)) continue;
         if(touches > bTouches || (touches == bTouches && j > bj)) { bi = i; bj = j; bTouches = touches; }
        }
     }
   return bi >= 0;
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

int IndexOfTime(datetime t)
  {
   for(int k = n - 1; k >= 0; k--) if(R[k].time == t) return k;
   return -1;
  }

void TryEntry()
  {
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int last = n - 1;
   int trend = InpUseTrend ? TrendDir() : 0;
   for(int d = 0; d < 2; d++)
     {
      int dir = d == 0 ? 1 : -1;
      if(dir > 0 && !InpUseLong) continue;
      if(dir < 0 && !InpUseShort) continue;
      if(InpUseTrend && trend != dir) continue;     // bull snail only in an uptrend, bear only in a downtrend
      int i, j, touches;
      if(!FindBrokenLine(dir, i, j, touches)) continue;
      string key = (string)(long)R[i].time + "_" + (string)(long)R[j].time + "_" + (string)dir;
      int s = ArraySize(usedKeys); ArrayResize(usedKeys, s + 1); usedKeys[s] = key;   // one attempt per line

      // stop: last confirmed opposite swing point
      int anchor = -1;
      for(int k = last - InpSwingN; k >= MathMax(0, last - InpLookback); k--)
         if(dir > 0 ? IsSwingLow(k) : IsSwingHigh(k)) { anchor = k; break; }
      if(anchor < 0) continue;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double entry = dir > 0 ? ask : bid;
      double sl = dir > 0 ? R[anchor].low - InpStopBufATR * atr : R[anchor].high + InpStopBufATR * atr;
      sl = NormalizeDouble(sl, digits);
      double risk = MathAbs(entry - sl);
      if((dir > 0 && sl >= entry) || (dir < 0 && sl <= entry)) continue;
      if(risk > InpMaxStopATR * atr) { PrintFormat("Skip: stop %.2f ATR away", risk / atr); continue; }
      double tp = 0;
      if(InpTargetR > 0) tp = NormalizeDouble(entry + dir * InpTargetR * risk, digits);
      ENUM_ORDER_TYPE type = dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double lots = CalcLots(type, entry, sl);
      if(lots <= 0) continue;
      bool ok = dir > 0 ? trade.Buy(lots, _Symbol, 0.0, sl, tp, "tl " + (string)touches)
                        : trade.Sell(lots, _Symbol, 0.0, sl, tp, "tl " + (string)touches);
      if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)
        {
         tDir = dir; tAnchorTime = R[anchor].time; tRisk = risk; tEntryTime = R[last].time;
         double pi = dir > 0 ? R[i].high : R[i].low, pj = dir > 0 ? R[j].high : R[j].low;
         double lvLast = pi + (pj - pi) / (j - i) * (last - i);
         DrawLine("TLB_act_" + key, R[i].time, pi, R[last].time, lvLast, dir > 0 ? clrDodgerBlue : clrOrangeRed);
         PrintFormat("ENTRY dir=%d touches=%d risk=%.2f (%.2f ATR) line %s -> %s",
                     dir, touches, risk, risk / atr, TimeToString(R[i].time), TimeToString(R[j].time));
         return;
        }
     }
  }

// Trailing line in the trade direction: from the stop swing through the later swing points.
void ManagePosition(ulong pos)
  {
   int last = n - 1;
   int a = IndexOfTime(tAnchorTime);
   if(a < 0) { PrintFormat("WARN stop swing %s out of history", TimeToString(tAnchorTime)); return; }
   int e = IndexOfTime(tEntryTime);
   if(e < 0) e = a;
   double va = tDir > 0 ? R[a].low : R[a].high;
   // the stop swing, then swing points formed AFTER the entry, on the trend side, spaced out
   int pts[]; ArrayResize(pts, 1); pts[0] = a;
   for(int k = e + 1; k <= last - InpSwingN; k++)
     {
      if(!(tDir > 0 ? IsSwingLow(k) : IsSwingHigh(k))) continue;
      double v = tDir > 0 ? R[k].low : R[k].high;
      if((tDir > 0 && v <= va) || (tDir < 0 && v >= va)) continue;
      if(k - pts[ArraySize(pts) - 1] < InpMinSpacing) continue;
      int s = ArraySize(pts); ArrayResize(pts, s + 1); pts[s] = k;
     }
   int np = ArraySize(pts);
   if(np < 2) return;

   int p1, p2;
   if(InpTrailMode == 1)
     {
      // anchored line: from the stop swing to the swing giving the flattest slope,
      // so every later swing point stays on the trend side of the line
      p1 = a; p2 = -1;
      double best = 0;
      for(int q = 1; q < np; q++)
        {
         double vq = tDir > 0 ? R[pts[q]].low : R[pts[q]].high;
         double sl = (vq - va) / (pts[q] - a);
         if(p2 < 0 || (tDir > 0 && sl < best) || (tDir < 0 && sl > best)) { best = sl; p2 = pts[q]; }
        }
     }
   else if(InpTrailMode == 2)
     {
      // "snail": chain of ever steeper lines (lower hull of the swing lows for a long).
      // From the stop swing take the flattest line; if swings formed after its touch point,
      // start a steeper line from that point; the last segment is the active line.
      int ai = 0;                                   // index in pts of the current anchor
      p1 = pts[0]; p2 = -1;
      while(true)
        {
         int bestq = -1; double best = 0;
         double vA = tDir > 0 ? R[pts[ai]].low : R[pts[ai]].high;
         for(int q = ai + 1; q < np; q++)
           {
            double vq = tDir > 0 ? R[pts[q]].low : R[pts[q]].high;
            double sl = (vq - vA) / (pts[q] - pts[ai]);
            if(bestq < 0 || (tDir > 0 && sl <= best) || (tDir < 0 && sl >= best)) { best = sl; bestq = q; }
           }
         if(bestq < 0) break;
         p1 = pts[ai]; p2 = pts[bestq];
         if(bestq >= np - 1) break;                 // no swing after the touch point: this is the active line
         ai = bestq;                                // steeper line from the touch point
        }
      if(p2 < 0) return;
     }
   else { p1 = pts[np - 2]; p2 = pts[np - 1]; }

   double v1 = tDir > 0 ? R[p1].low : R[p1].high, v2 = tDir > 0 ? R[p2].low : R[p2].high;
   double slope = (v2 - v1) / (p2 - p1);
   // touches on the line (stop swing included); the line is active only with enough touches
   double tol = InpTouchTolATR * atr;
   int touches = 0;
   for(int q = 0; q < np; q++)
     {
      double vq = tDir > 0 ? R[pts[q]].low : R[pts[q]].high;
      if(MathAbs(vq - (v1 + slope * (pts[q] - p1))) <= tol) touches++;
     }
   if(InpTrailMode == 0 || InpTrailMode == 2) touches = MathMax(touches, 2);
   if(touches < InpTrailMinTouch) return;

   double lv = v1 + slope * (last - p1);
   DrawLine("TLB_trail_" + (string)(long)tAnchorTime, R[p1].time, v1, R[last].time, lv, clrGold);
   if((tDir > 0 && R[last].close < lv) || (tDir < 0 && R[last].close > lv))
     {
      trade.PositionClose(pos);
      PrintFormat("EXIT trailing line broken at %s (%.1fR)", TimeToString(R[last].time),
                  tRisk > 0 ? tDir * (R[last].close - PositionGetDouble(POSITION_PRICE_OPEN)) / tRisk : 0.0);
      return;
     }
   if(InpTrailHardSL && PositionSelectByTicket(pos))
     {
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double cur = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
      double nsl = NormalizeDouble(tDir > 0 ? lv - InpStopBufATR * atr : lv + InpStopBufATR * atr, digits);
      if((tDir > 0 && nsl > cur) || (tDir < 0 && (cur == 0 || nsl < cur)))
         trade.PositionModify(pos, nsl, tp);
     }
  }

void OnTick()
  {
   datetime b = iTime(_Symbol, InpTF, 0);
   if(b == lastBar) return;
   if(InpUseNewsGuard)
     {
      if(!MQLInfoInteger(MQL_TESTER) && TimeCurrent() - g_newsLoadedAt > 6 * 3600) LoadNewsLive();
      // inside a news window: postpone this bar's entry / line-exit decision until the window is over
      if(InNewsWindow(TimeCurrent()))
        {
         if(g_deferBar != b) { g_deferBar = b; s_deferred++; }
         return;
        }
     }
   lastBar = b;
   int need = InpLookback * 5 + InpAtrPeriod + 5;   // long history so an open trade keeps its stop swing
   int avail = Bars(_Symbol, InpTF) - 1;
   if(avail < InpLookback + InpAtrPeriod + 5) return;
   int got = CopyRates(_Symbol, InpTF, 1, MathMin(need, avail), R);
   if(got < InpLookback + InpAtrPeriod + 5) return;
   n = got;
   atr = CalcATR(n - 1);
   if(atr <= 0) return;
   ulong pos;
   if(HasPosition(pos)) ManagePosition(pos);
   else { tDir = 0; TryEntry(); }
  }
//+------------------------------------------------------------------+
