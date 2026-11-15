# Strategy Tester notes and MQL5 lessons

Practical lessons from building and testing the EAs in this repository.

## Strategy Tester
1. **Check the tick model.** Run the same window on real ticks and on 1-minute OHLC before trusting a long backtest.
   Entries on candle closes with wide stops are insensitive; scalpers with trailing stops are not (one EA showed +$933 on
   OHLC and -$1,976 on tick-level data for the same weeks).
2. **Tick history is limited.** On the test broker, real gold ticks exist from late August 2026 and real NDX100 ticks only
   from 6 Nov 2026. A "real ticks" run over earlier dates mixes real and generated data. Check the Tester journal line
   "ticks data begins from ...".
3. **MT5 caches builds and inputs.** After compiling, refresh the Navigator. If the Tester still shows an old input list,
   compile under a new file name. Confirm the build that ran from the inputs printed at the start of the Tester journal.
4. **Tester dates have daily granularity**, and `to_date` must be at least one day after `from_date`.
5. **Compare like with like.** Same period, model, deposit, risk and costs, or say they differ.

## Time zones and calendars
6. MT5 uses broker **server time**. Convert to New York time with the server GMT offset and US daylight-saving dates
   (the US and Europe switch on different dates, so the gap to a European-hours broker changes by an hour for a few weeks).
7. MT5's economic calendar returns times using **today's** server offset for every historical date. Exported in winter,
   summer events come out one hour early. Convert to UTC with today's offset, then to the server time that applied on that date.
8. MT5's "high impact" list is broader than a prop firm's restricted-event list. Use the firm's own list for rules.

## MQL5 pitfalls found in code review
9. `iATR(symbol, timeframe, period)` (like `iRSI`, `iMA`) returns an **indicator handle**, not a value. Create the handle once
   in `OnInit`, read it with `CopyBuffer`, release it in `OnDeinit`. Creating handles on every tick leaks memory.
10. Never count a **rejected order** as a trade or a loss. Check the result of `trade.Buy/Sell` before setting "trade active".
11. Use a **magic number** and detect your own positions by magic and symbol, not `PositionsTotal()`.
12. **Risk-based lots** must come from the real stop distance (`OrderCalcProfit` for 1 lot), be rounded down to the volume
    step, skip the trade if below the minimum lot (do not round up), and be capped by free margin.
13. Sizing every trade to the maximum free margin, or a "35% daily loss limit", is not risk management.

## Account size
14. The minimum lot sets a floor on risk per trade. Gold at about $3,900 with a 0.01 lot (1 oz) risks $15-45 for a typical
    box: tiny accounts cannot trade it at 0.5-1% risk. Compute the risk at the minimum lot before choosing symbols.

## Statistics
15. A small edge over a few hundred trades is within noise. Selecting the best of several variants on the same data
    overstates the edge. Prefer a forward test and say so in the results.
