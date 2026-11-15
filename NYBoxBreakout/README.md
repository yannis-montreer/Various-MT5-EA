# NYBoxBreakout (`NYBoxBreakoutNews.mq5`)

Breakout of the New York pre-market box, with a trend filter, risk-based sizing and an optional news guard.
Tested on XAUUSD and NDX100 (M5 chart). Results: [RESULTS.md](RESULTS.md).

## Rules (all times New York time)
1. **Box:** high and low (wicks included) of the six M5 candles that open 09:00-09:25 (the 09:00-09:30 window).
2. **Breakout:** the first M5 candle that **closes** outside the box among candles opening 09:30-10:25
   (the last one closes at 10:30). Only the first breakout of the day counts.
3. **Trend filter:** M15 EMA50 vs EMA200 on the last closed M15 candle. Long only if EMA50 > EMA200, short only if
   EMA50 < EMA200. If the first breakout goes against the trend, there is no trade that day.
4. **Entry:** market order on the first tick after the breakout candle closes.
5. **Stop:** the opposite side of the box. **Target:** `InpRR` x R (default 3R, R = entry-to-stop distance).
6. **Exit:** stop, target, or forced close at 16:55 NY (retried once per M5 candle if it fails).
7. **Size:** fixed lots, or `InpRiskPercent` of the balance risked per trade from the real stop distance. If the
   risk budget is below the broker's minimum lot, the trade is **skipped** (never rounded up).
8. At most one trade per symbol per day. No trade if the box is incomplete or there is no breakout by 10:30.

## Inputs (main ones)
| Input | Default | Meaning |
|---|---|---|
| `InpLots` | 0.1 | Fixed lot when `InpRiskPercent` is 0 |
| `InpRiskPercent` | 0.0 | Risk per trade, % of balance (0 = use fixed lots) |
| `InpRR` | 3.0 | Take profit in R multiples |
| `InpServerGMTOffset` | 2 | Broker server GMT offset in winter |
| `InpServerFollowsUSDST` | true | Server shifts +1h while US daylight saving is active |
| `InpBoxStartMin` / `InpBoxEndMin` / `InpLastBreakoutMin` / `InpCloseMin` | 540 / 570 / 630 / 1015 | NY time in minutes after midnight (09:00 / 09:30 / 10:30 / 16:55) |
| `InpUseTrendFilter` | true | M15 EMA50/EMA200 filter |
| `InpUseNewsGuard` | false | Prop-firm news rule: no trade opened or closed within +/- N minutes of a high-impact event |
| `InpNewsBeforeMin` / `InpNewsAfterMin` | 6 / 6 | Window around an event (5 minutes + 1 minute buffer) |
| `InpNewsFlatten` | false | Close an open trade just before a news window starts |
| `InpNewsCurrencies` | USD | Currencies tied to the symbol |
| `InpNewsFile` / `InpNewsIdsFile` | NYNews.csv / NYNewsIds.txt | Event file for the tester / event-id list for live use (generated with `tools/NYNewsExport.mq5`) |
| `InpMagic` | 920503 | Magic number |

## Before you run it
- **Server time:** NY time = server time minus 7 hours for a GMT+2 (winter) / GMT+3 (summer) broker. Other brokers
  differ. Set `InpServerGMTOffset` / `InpServerFollowsUSDST` and confirm that the box candles open 09:00-09:25 NY.
- **Symbol names** differ between brokers (the tests used `XAUUSD` and `NDX100`).
- **Small accounts:** the minimum lot sets a floor on risk. Gold with a 0.01 lot risks $15-45 per typical box.
- The news guard is **off by default**. Its tester mode needs `NYNews*.csv` files built with the export tool; the live mode
  (MT5 calendar plus an event-id list) has not been verified in a running terminal.

## Known limits
- No account-level safety stop (daily loss / drawdown halt) yet.
- Edge is small: about 0.15R per trade on NDX100 and 0.07R on gold over 2024-2026. Backtests have no commissions.
- Real NDX100 ticks on the test broker exist only from 6 Nov 2026, so long runs use the 1-minute model.
