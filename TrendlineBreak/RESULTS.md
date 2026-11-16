# TrendlineBreak: backtest results

Mechanical version of a manual trendline-break swing strategy (Tori Trades style), as the owner trades it: 3-touch line on H4,
entry at the close of the breaking candle, exit when the new line that forms in the trade direction is broken.

## Rules coded (`TrendlineBreak2.mq5`)
- Swing point: H4 bar higher (lower) than the 3 bars on each side.
- Action line: falling line through swing highs (long on its break) or rising line through swing lows (short). At least 3 touches
  within 0.3 ATR, touches at least 6 bars apart, first touch at least 90 bars (about 3 weeks) before the break, slope at most
  0.5 ATR per bar, no close through the line and no swing point cutting it before the break. Several valid lines: most touches,
  then the most recent. One attempt per line. Lines searched over the last 400 bars (about 13 weeks).
- Entry: market, right after the H4 close through the line.
- Initial stop: last confirmed opposite swing point -/+ 0.25 ATR; skipped if farther than 8 ATR.
- Exit (`InpTrailMode=1`): a line anchored at the stop swing, through swing points formed after the entry, at the flattest slope so all
  later swings stay on the trend side; active from 2 touches; an H4 close through it closes the trade. Optional fixed target in R.
- 1% risk per trade. The EA draws the action line (blue/orange) and the trailing line (gold) for the visual tester.

## Setup
XAUUSD, FundedNext MT5 test server, H4 chart, 1-minute OHLC model, 2 Jan 2024 - 13 Nov 2026 (H4 history starts in Jan 2024),
$15,000, server commission and swap included, no extra slippage. Results are in-sample and the samples are small (about 50-60 trades).

## Results
| Exit | Net profit | Trades | Win rate | PF | Max DD (equity) | Avg trade | Largest win |
|---|---|---|---|---|---|---|---|
| Trailing line only (the owner's exit) | -$517 | 50 | 48% | 0.76 | 7.5% | -$10.34 (-0.07R) | $483 (about 3.2R) |
| Trailing line + hard stop moved along the line | -$512 | 54 | 46% | 0.77 | 7.4% | -$9.48 | $467 |
| Trailing line + 2R target | +$754 | 58 | 50% | 1.32 | 5.5% | +$13.01 (about 0.09R) | $300 |
| **Trailing line + 3R target** | **+$938** | 56 | 50% | **1.42** | 5.5% | +$16.75 (about 0.11R) | $451 |
| Trailing line + 4R target | +$57 | 53 | 47% | 1.02 | 5.8% | +$1.08 | $510 |
| 3R target, no trailing line | -$509 | 30 | 23% | 0.82 | 8.9% | -$16.97 | $380 |
| First version (line through the last two swings, hard stop trailed to each swing) | +$305 | 66 | 47% | 1.13 | 4.8% | +$4.62 | $286 |

Runs of the first file made after adding inputs were discarded: the tester kept the old input list (see docs/TESTER_NOTES.md).

## Touch tolerance (`InpTouchTolATR`; the owner says touches are approximate: price comes near the line and leaves)
| Tolerance | Exit | Net profit | Trades | Win rate | PF | Max DD (equity) | Avg trade |
|---|---|---|---|---|---|---|---|
| 0.3 ATR | trailing line only | -$517 | 50 | 48% | 0.76 | 7.5% | -$10.34 |
| 0.5 ATR | trailing line only | -$243 | 54 | 46% | 0.90 | 11.1% | -$4.50 |
| 0.75 ATR | trailing line only | +$7,946 | 8 | 50% | 29.2 | **40.3%** | one long held through the gold rally: +$8,157 (about 54R) |
| 1.0 ATR | trailing line only | +$7,814 | 10 | 50% | 19.8 | **40.4%** | same trade |
| 0.3 ATR | trailing line + 3R | +$938 | 56 | 50% | 1.42 | 5.5% | +$16.75 |
| 0.5 ATR | trailing line + 3R | +$1,329 | 64 | 48% | 1.48 | 4.9% | +$20.76 |
| 0.75 ATR | trailing line + 3R | +$1,406 | 73 | 48% | 1.43 | 4.5% | +$19.26 |
| 1.0 ATR | trailing line + 3R | +$1,865 | 79 | 48% | 1.51 | 4.4% | +$23.61 (about 0.16R) |

With the trailing exit alone, the anchored line becomes very flat in a strong trend: one trade made about 54R but gave back about
$15,000 of open profit before exiting (40% equity drawdown) and blocked all other trades. With the 3R cap, every tolerance from
0.3 to 1.0 ATR is positive (PF 1.42-1.51), which is more stable than the target choice (2R 1.32, 3R 1.42, 4R 1.02 at 0.3 ATR).

## "Snail" exit (`InpTrailMode=2`): chain of ever steeper lines
From the stop swing, take the flattest line under the later swing points; when swings form after its touch point, start a steeper
line from that point; the last segment (ending at the latest swing) is the active line, and an H4 close through it exits.
This is the lower hull of the swing lows for a long (upper hull of the swing highs for a short).

| Tolerance | Target | Net profit | Trades | Win rate | PF | Max DD (equity) | Avg trade | Largest win |
|---|---|---|---|---|---|---|---|---|
| 0.3 ATR | none | -$213 | 60 | 50% | 0.91 | 5.2% | -$3.56 | $286 |
| 0.5 ATR | none | +$447 | 67 | 48% | 1.15 | 6.3% | +$6.67 | $1,128 (about 7.5R) |
| **1.0 ATR** | **none** | **+$1,171** | 78 | 49% | **1.32** | 6.5% | +$15.01 (about 0.10R) | $814 (about 5.4R) |
| 1.0 ATR | 3R | +$1,057 | 80 | 50% | 1.29 | 6.4% | +$13.22 | $454 |

Sanity check: rerunning "trailing line + 3R, 1.0 ATR" (mode 1) after recompiling gave the same +$1,865.48 as before.

The snail exit fixes the give-back of the flat anchored line (equity drawdown 6.5% instead of 40%) and, with loose touches, makes the
owner's exit positive on its own (PF 1.32) without a target. Its largest wins are about 5-7R, still short of the 10-20R the owner reports.

## Trend filter (`TrendlineBreak3.mq5`): bull snail only in an uptrend, bear only in a downtrend
The owner picks the direction from the trend. Coded as: last daily close above the daily EMA -> only longs (breaks of falling
lines), below -> only shorts. Same entry line choice (most touches), touch tolerance 1.0 ATR, snail exit, no target.
Daily history also starts in Jan 2024, so the 200-day EMA is unreliable for the first months.

| Trend filter | Net profit | Trades | Win rate | PF | Max DD (equity) | Avg trade | Longs / shorts |
|---|---|---|---|---|---|---|---|
| None (same as TrendlineBreak2 snail, 1.0 ATR: +$1,170.74, check passed) | +$1,171 | 78 | 49% | 1.32 | 6.5% | +$15.01 (about 0.10R) | 32 / 46 |
| **Daily close vs EMA 50** | **+$1,195** | 40 | 60% | **1.77** | 5.4% | +$29.88 (about 0.20R) | 28 (19 won) / 12 (5 won) |
| Daily close vs EMA 200 | +$567 | 26 | 62% | 1.61 | 4.4% | +$21.79 | 21 / 5 |

The filter halves the number of trades for the same profit: the trades it removes were about break-even. Over 2024-2026 gold
rose strongly, so the filter mostly keeps longs; part of the improvement may be "long gold in a bull market". Samples of 26-40
trades are too small to conclude.

## H1 timeframe (`TrendlineBreak3.mq5`, `InpTF=H1`)
Same settings in bars as on H4 (3 touches, 6 bars between touches, first touch at least 90 bars before the break, 400-bar search,
tolerance 1.0 ATR, snail exit, no target), so lines are about 4 days long instead of 3 weeks. Trend filter still on the daily chart.
These settings were chosen on H4, so H1 is a check of them on a timeframe they were not tuned on. 1% risk of the current balance
(compounding).

| Variant | Period | Net profit | Trades | Win rate | PF | Max DD (equity) | Longs / shorts |
|---|---|---|---|---|---|---|---|
| No trend filter | 2024 - 13 Nov 2026 | +$7,005 | 381 | 42% | 1.32 | 11.2% | 180 / 201 |
| **Daily EMA 50 filter** | 2024 - 13 Nov 2026 | **+$6,676** | 162 | 46% | **1.73** | 8.1% | 120 (57 won) / 42 (17 won) |
| Daily EMA 50 filter | 2024 (from $15,000) | +$1,909 | 50 | 46% | 1.65 | 5.5% | 46 / 4 |
| Daily EMA 50 filter | 2025 (from $15,000) | +$1,434 | 56 | 48% | 1.56 | 5.4% | 55 / 1 |
| Daily EMA 50 filter | 2026 to 13 Nov (from $15,000) | +$2,253 | 56 | 43% | 1.87 | 7.6% | 19 (8 won) / 37 (16 won) |

Model check (daily EMA 50 filter, 28 Aug - 13 Nov 2026): real ticks +$533.86, 1-minute OHLC +$534.08, 19 trades each.

On H1 the strategy is positive every year, with about three times the trades of H4. In 2026 the filter switched mostly to shorts
(gold fell in the autumn) and stayed profitable, so the result is not only "long gold in a bull market".

## EURUSD (`TrendlineBreak3.mq5`, same settings as on gold)
EURUSD, same server, 1-minute OHLC model, 2 Jan 2024 - 13 Nov 2026, $15,000, 1% risk, tolerance 1.0 ATR, snail exit, no target.

| Timeframe | Trend filter | Net profit | Trades | Win rate | PF | Max DD (equity) | Largest win |
|---|---|---|---|---|---|---|---|
| H1 | daily EMA 50 | +$917 | 157 | 36% | 1.09 | 17.4% | $1,905 (about 12R; more than the whole net profit) |
| H1 | none | -$4,412 | 445 | 39% | 0.80 | 34.0% | $1,403 |
| H4 | daily EMA 50 | -$283 | 54 | 39% | 0.88 | 7.9% | $224 |
| H4 | none | +$230 | 94 | 45% | 1.05 | 12.4% | $467 |

No edge on EURUSD: the only positive filtered run depends on one 12R trade, with a 17% drawdown. The rules work on gold but not
on EURUSD, so the gold result may owe a lot to gold's strong 2024-2026 trends rather than to a general trendline edge.

## UKOUSD (Brent), H1 (`TrendlineBreak3.mq5`, same settings)
UKOUSD, same server, H1, 1-minute OHLC model, 2 Jan 2024 - 13 Nov 2026, $15,000, 1% risk, tolerance 1.0 ATR, snail exit, no target.

| Trend filter | Net profit | Trades | Win rate | PF | Max DD (equity) | Largest win |
|---|---|---|---|---|---|---|
| Daily EMA 50 | -$1,752 | 131 | 40% | 0.77 | 20.9% | $332 |
| None | -$2,673 | 359 | 42% | 0.86 | 30.7% | $643 |

Losing on Brent, with or without the filter. This matches the IDFX study, where oil (WTI) was also negative.

## NDX100, H1 (`TrendlineBreak3.mq5`, same settings)
NDX100, same server, H1, 1-minute OHLC model, 2 Jan 2024 - 13 Nov 2026, $15,000, 1% risk, tolerance 1.0 ATR, snail exit, no target.

| Trend filter | Net profit | Trades | Win rate | PF | Max DD (equity) | Longs / shorts |
|---|---|---|---|---|---|---|
| Daily EMA 50 | +$113 | 121 | 41% | 1.02 | 17.1% | 92 (40 won) / 29 (10 won) |
| None | -$2,481 | 366 | 40% | 0.88 | 26.9% | 155 / 211 |

Break-even with the filter, losing without it. Unlike the IDFX study (NAS100 4H positive), these rules do not carry over to NDX100.

## Summary across markets (H1, daily EMA 50 filter, same settings)
| Market | Net profit | Trades | PF | Max DD (equity) |
|---|---|---|---|---|
| XAUUSD | +$6,676 | 162 | 1.73 | 8.1% |
| EURUSD | +$917 | 157 | 1.09 | 17.4% (one 12R trade) |
| NDX100 | +$113 | 121 | 1.02 | 17.1% |
| UKOUSD | -$1,752 | 131 | 0.77 | 20.9% |

Only gold works. Either gold respects trendlines better than other markets, or 2024-2026 was an unusually good period for gold
trends; with three years of data it is not possible to tell which.

## News guard (`TrendlineBreak4.mq5`)
On H1 the EA acts at the first tick of each bar, i.e. on the hour, when many US releases come out (10:00 NY = 17:00 server).
Checked against FundedNext's high-impact USD list (998 events, 2024-2026, server time), the unguarded run (XAUUSD H1, daily EMA 50
filter, 0.5% risk, 149 trades) opened 6 trades and closed 2 within 30 seconds of an event (for example an entry at 17:00:00 on the
ISM release), and touched 10 trades within 5 minutes.

The guard postpones the bar's decision (entry on a break, exit on the snail line) until the window is over; it does not skip the trade.
Stops and targets already on the server can still fill inside a window. Tester: events from `NYNews_FN.csv` (Common\Files);
live: MT5 calendar filtered by `NYNewsIds.txt`, reloaded every 6 hours.

| Guard window | Net profit | Trades | PF | Max DD (equity) | Opens / closes within 30 s of news | within 5 min |
|---|---|---|---|---|---|---|
| None (TrendlineBreak3) | +$2,666 | 149 | 1.76 | 2.9% | 6 / 2 | 6 / 4 |
| +/-30 s | +$2,680 | 149 | 1.76 | 2.9% | **0 / 0** | 6 / 4 |
| +/-5 min | +$2,721 | 149 | 1.77 | 2.9% | 0 / 0 | **0 / 2** (two stop-losses filled by the market) |

The guard costs nothing here: same trades, slightly better result.

## Conclusion
At 0.3 ATR tolerance no 10-20R trades appear (largest win about 3.4R); with looser touches one 54R trade appears, but the exit
gives back most of the open profit. The owner's exit alone is either losing or dominated by that one trade. A capped target
with the trailing line as an early exit is positive (best 3R: PF 1.42), but results swing from PF 1.42 at 3R to 1.02 at 4R on about
55 trades, so this is fragile and in-sample. The gap with the owner's manual results most likely comes from discretion in drawing and
redrawing lines, which these rules do not capture. Next step: compare the EA's drawn lines with the owner's lines in the visual tester.
