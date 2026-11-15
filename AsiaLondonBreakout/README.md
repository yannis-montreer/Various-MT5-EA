# AsiaLondonBreakout

Asian-session range, London-session breakout on XAUUSD (M5). Two files:
- `AsiaLondonBreakout_v6.mq5`: the original EA (file name when written: `Claude_Asia_range_London_breakout_v6.mq5`), unchanged.
- `AsiaLondonBreakout_v6_Risk.mq5`: the same EA with **risk management added** (entry and exit rules unchanged).

Results: [RESULTS.md](RESULTS.md).

## Rules (original)
- **Asian range:** high/low from `InpAsianStartHour` to `InpAsianEndHour` (GMT, default 00:00-06:00).
- **Entry:** during the London window (`InpLondonStartHour`-`InpLondonEndHour` GMT, default 07:00-11:00), the first M5 close beyond the range
  plus `InpBreakoutBuffer` ($0.50). **Longs only by default** (`InpTradeShorts = false`). One long and one short trigger per day.
- **Stop:** max(`InpSLMultiplier` x range, `InpSLATRMultiplier` x M5 ATR). **Target:** `InpTPMultiplier` x range (1.75).
- **Filters** (most off by default): spread limit, range size vs H1 ATR (on), Asia close position, retest, H1 ATR expansion, EMA trend.
- Lot is **fixed** (`InpLotSize` 0.10): risk per trade varies a lot with the range size.

## What the Risk copy adds
- `InpUseRiskPercent` / `InpRiskPercent` (0.5): lot from the real stop distance (skips the trade if below the minimum lot).
- `InpMaxDailyLossPercent` (3): no new trades for the rest of the day after that loss.
- `InpMaxDrawdownPercent` (10): no new trades after that drawdown from peak equity, **until the EA is restarted** (meant for human review).
  At 0.5% risk this EA's normal drawdown (about 11%) exceeds 10%, so the halt fires; use 0.25% risk or raise the limit.

## Before you run it
- **Server time offsets.** Set `InpWinterOffset` and `InpSummerOffset` to the broker's real GMT offsets (for a GMT+2/+3 broker: 2 and 3).
  The default summer offset is 1, which is inconsistent with a winter offset of 2. The summer switch uses **European** DST dates.
- Shorts are off by default; the tests that were positive had them on (see RESULTS).
