# Tools

## `NYNewsExport.mq5` (MT5 script)
Exports the MT5 economic calendar to `Terminal\Common\Files`:
- `NYNews.csv`: high-impact events as `yyyy.mm.dd hh:mi;CUR;importance;name`, in **broker server time**, corrected for
  daylight saving. Used by the news guard in the Strategy Tester (`NYBoxBreakout`).
- `NYNewsMap.csv`: every event with its MT5 event id, importance and true UTC time (`utc;id;importance;name`), used offline to
  match a broker/prop-firm restricted-event list to MT5 event ids.

Run it from the Navigator (drag it onto a chart). Inputs: currencies, date range, the broker's winter GMT offset and
whether the server follows US daylight saving.
Why the correction: MT5's calendar applies today's server offset to every historical date, so summer events come out one hour
early if exported in winter (see `../docs/TESTER_NOTES.md`).
