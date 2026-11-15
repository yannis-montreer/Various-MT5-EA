//+------------------------------------------------------------------+
//|                                                NYNewsExport.mq5  |
//|  Exports high-impact economic calendar events to a CSV file in   |
//|  Common\Files so the Strategy Tester can use the news guard.     |
//|  Format: "yyyy.mm.dd hh:mi;CUR;importance;event name"            |
//|  Times are SERVER time, as returned by the MT5 calendar.         |
//+------------------------------------------------------------------+
#property copyright "NYNewsExport"
#property version   "1.00"
#property script_show_inputs

input string   InpFile       = "NYNews.csv";        // Output file (Common\Files)
input string   InpMapFile    = "NYNewsMap.csv";     // Event-id map (utc;id;importance;name)
input string   InpCurrencies = "USD";               // Currencies, comma separated
input datetime InpFrom       = D'2023.12.01 00:00'; // Start (server time)
input datetime InpTo         = D'2026.12.31 00:00'; // End (server time)
input int      InpServerGMTOffset    = 2;           // Broker server GMT offset in winter
input bool     InpServerFollowsUSDST = true;        // Server shifts +1h while US DST is active

// The terminal returns calendar times using the server offset in force TODAY for every date,
// so summer events come out 1h early when exported in winter (and vice versa).
// We convert to real UTC with today's offset, then to the server time that applied on that date.
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
   datetime start = SundayOfMonth(d.year, 3, 2)  + 7 * 3600;
   datetime end   = SundayOfMonth(d.year, 11, 1) + 6 * 3600;
   return (utc >= start && utc < end);
  }

void OnStart()
  {
   int todayOff = (int)MathRound((double)(TimeTradeServer() - TimeGMT()) / 3600.0);
   PrintFormat("NYNewsExport: server offset today = GMT%+d", todayOff);

   string cur[];
   int nc = StringSplit(InpCurrencies, ',', cur);
   if(nc <= 0) { Print("No currencies given"); return; }

   int h = FileOpen(InpFile, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ';');
   if(h == INVALID_HANDLE)
     {
      PrintFormat("Cannot open %s for writing (error %d)", InpFile, GetLastError());
      return;
     }

   // Map file: every event of any importance with its MT5 event id and the true UTC time.
   // Used offline to find which MT5 event ids correspond to a broker/prop-firm restricted list.
   int hm = FileOpen(InpMapFile, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ';');

   int written = 0;
   for(int c = 0; c < nc; c++)
     {
      string code = cur[c];
      StringTrimLeft(code); StringTrimRight(code); StringToUpper(code);

      MqlCalendarValue v[];
      int n = CalendarValueHistory(v, InpFrom, InpTo, NULL, code);
      if(n < 0) { PrintFormat("CalendarValueHistory failed for %s (error %d)", code, GetLastError()); continue; }

      for(int i = 0; i < n; i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(v[i].event_id, ev)) continue;
         if(v[i].time <= 0) continue;

         string name = ev.name;
         StringReplace(name, ";", ",");
         datetime utc = v[i].time - todayOff * 3600;
         if(hm != INVALID_HANDLE && (int)ev.importance >= 1)
            FileWrite(hm, TimeToString(utc, TIME_DATE | TIME_MINUTES), (string)v[i].event_id, (int)ev.importance, name);
         if(ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;
         int histOff = InpServerGMTOffset + ((InpServerFollowsUSDST && IsUSDST(utc)) ? 1 : 0);
         datetime srv = utc + histOff * 3600;
         FileWrite(h, TimeToString(srv, TIME_DATE | TIME_MINUTES), code, (int)ev.importance, name);
         written++;
        }
      PrintFormat("%s: %d calendar values scanned", code, n);
     }
   FileClose(h);
   if(hm != INVALID_HANDLE) FileClose(hm);
   PrintFormat("NYNewsExport: %d high-impact events written to Common\\Files\\%s", written, InpFile);
  }
//+------------------------------------------------------------------+
