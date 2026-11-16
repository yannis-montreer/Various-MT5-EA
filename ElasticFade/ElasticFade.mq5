//+------------------------------------------------------------------+
//| ElasticFade.mq5                                                   |
//| Tick-level "elastic" fade (friend's MGC scalping idea):           |
//|  1. push   : net move >= InpPushUsd within InpPushMs (sliding)    |
//|  2. stall  : net move <  InpStallUsd within InpStallMs            |
//|  3. entry  : market order AGAINST the push                        |
//|  4. exit   : TP at InpTPFrac of the push (0.5 = mid of the push), |
//|              timeout InpTimeoutSec, optional SL beyond extreme    |
//| Session / exclusion windows are in SERVER time.                   |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

input double InpLots        = 0.10;   // lots (0.10 XAUUSD = 10 oz = 1 MGC)
input long   InpMagic       = 920510;
input double InpPushUsd     = 2.0;    // push threshold ($ net move)
input int    InpPushMs      = 3000;   // push window (ms)
input double InpStallUsd    = 0.2;    // stall threshold ($ net move)
input int    InpStallMs     = 1000;   // stall window (ms)
input int    InpMaxWaitMs   = 15000;  // max wait for stall after push (ms)
input double InpTPFrac      = 0.5;    // TP = fraction of push retraced
input double InpSLFrac      = 0.0;    // SL beyond extreme, fraction of push (0 = none)
input int    InpTimeoutSec  = 30;     // max holding time (0 = none)
input int    InpSessStart   = 930;    // session start, server minutes (15:30 = 14:30 Paris)
input int    InpSessEnd     = 1110;   // session end, server minutes (18:30 = 17:30 Paris)
input int    InpExclStart   = 955;    // no-entry window start (15:55 = 14:55 Paris)
input int    InpExclEnd     = 1000;   // no-entry window end   (16:40 = 15:40 Paris)
input bool   InpUseExcl     = true;
input double InpMaxSpread   = 1.0;    // skip entry if spread > this ($)

CTrade trade;
long   g_t[];          // tick times (ms)
double g_b[];          // bids
int    g_head = 0;     // first valid index

enum EState { ST_IDLE, ST_PUSH, ST_REARM };
EState g_state = ST_IDLE;
int    g_dir   = 0;        // +1 push up, -1 push down
double g_start = 0, g_ext = 0;
long   g_pushMs = 0;
datetime g_openTime = 0;

// stats
int    s_trades = 0, s_push = 0, s_noStall = 0, s_badTP = 0, s_spreadSkip = 0;
double s_spreadSum = 0, s_pushSum = 0;

int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(50);
   ArrayResize(g_t, 0, 20000);
   ArrayResize(g_b, 0, 20000);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   PrintFormat("ELASTIC STATS trades=%d pushes=%d noStall=%d badTP=%d spreadSkip=%d avgSpread=%.3f avgPush=%.3f",
               s_trades, s_push, s_noStall, s_badTP, s_spreadSkip,
               s_trades > 0 ? s_spreadSum / s_trades : 0.0,
               s_trades > 0 ? s_pushSum / s_trades : 0.0);
  }

int MinutesOfDay(datetime t)
  {
   MqlDateTime d; TimeToStruct(t, d);
   return d.hour * 60 + d.min;
  }

bool InSession(datetime t)
  {
   int m = MinutesOfDay(t);
   if(m < InpSessStart || m >= InpSessEnd) return false;
   if(InpUseExcl && m >= InpExclStart && m < InpExclEnd) return false;
   return true;
  }

// bid of the oldest stored tick whose time >= now - win
double BidAtWindowStart(long now, int win)
  {
   int n = ArraySize(g_b);
   long from = now - win;
   for(int i = g_head; i < n; i++)
      if(g_t[i] >= from) return g_b[i];
   return g_b[n - 1];
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

void OnTick()
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   long now = tk.time_msc;

   // store tick, trim buffer older than max window
   int n = ArraySize(g_b);
   ArrayResize(g_t, n + 1, 20000); ArrayResize(g_b, n + 1, 20000);
   g_t[n] = now; g_b[n] = tk.bid; n++;
   long keep = now - (MathMax(InpPushMs, InpStallMs) + 500);
   while(g_head < n - 1 && g_t[g_head] < keep) g_head++;
   if(g_head > 5000)
     {
      ArrayRemove(g_t, 0, g_head); ArrayRemove(g_b, 0, g_head);
      g_head = 0; n = ArraySize(g_b);
     }

   // manage open position: timeout
   ulong pos;
   if(HasPosition(pos))
     {
      if(InpTimeoutSec > 0 && TimeCurrent() - g_openTime >= InpTimeoutSec)
         trade.PositionClose(pos);
      return;
     }

   double move3 = tk.bid - BidAtWindowStart(now, InpPushMs);

   if(g_state == ST_REARM)
     {
      if(MathAbs(move3) < InpPushUsd) g_state = ST_IDLE;   // same push no longer active
      return;
     }

   if(g_state == ST_IDLE)
     {
      if(MathAbs(move3) >= InpPushUsd && InSession(TimeCurrent()))
        {
         g_state  = ST_PUSH;
         g_dir    = move3 > 0 ? 1 : -1;
         g_start  = BidAtWindowStart(now, InpPushMs);
         g_ext    = tk.bid;
         g_pushMs = now;
         s_push++;
        }
      return;
     }

   // ST_PUSH: track extreme, wait for stall
   if(g_dir > 0 && tk.bid > g_ext) g_ext = tk.bid;
   if(g_dir < 0 && tk.bid < g_ext) g_ext = tk.bid;

   if(now - g_pushMs > InpMaxWaitMs) { s_noStall++; g_state = ST_REARM; return; }
   if(now - g_pushMs < InpStallMs) return;

   double move1 = tk.bid - BidAtWindowStart(now, InpStallMs);
   if(MathAbs(move1) >= InpStallUsd) return;

   if(!InSession(TimeCurrent())) { g_state = ST_REARM; return; }

   double amp    = MathAbs(g_ext - g_start);
   double spread = tk.ask - tk.bid;
   if(spread > InpMaxSpread) { s_spreadSkip++; g_state = ST_REARM; return; }

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   bool ok = false;
   if(g_dir > 0)   // push up -> SELL
     {
      double tp = NormalizeDouble(g_ext - InpTPFrac * amp, digits);
      double sl = InpSLFrac > 0 ? NormalizeDouble(g_ext + InpSLFrac * amp + spread, digits) : 0.0;
      if(tp >= tk.ask - spread * 0.5) { s_badTP++; g_state = ST_REARM; return; }
      ok = trade.Sell(InpLots, _Symbol, 0.0, sl, tp, "elastic");
     }
   else            // push down -> BUY
     {
      double tp = NormalizeDouble(g_ext + InpTPFrac * amp, digits);
      double sl = InpSLFrac > 0 ? NormalizeDouble(g_ext - InpSLFrac * amp - spread, digits) : 0.0;
      if(tp <= tk.bid + spread * 0.5) { s_badTP++; g_state = ST_REARM; return; }
      ok = trade.Buy(InpLots, _Symbol, 0.0, sl, tp, "elastic");
     }
   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)
     {
      g_openTime = TimeCurrent();
      s_trades++; s_spreadSum += spread; s_pushSum += amp;
     }
   g_state = ST_REARM;
  }
//+------------------------------------------------------------------+
