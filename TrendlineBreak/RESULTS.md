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

## Conclusion
No 10-20R trades appear in the mechanical version: the largest win is about 3.4R. The owner's exit alone loses here. A capped target
with the trailing line as an early exit is positive (best 3R: PF 1.42), but results swing from PF 1.42 at 3R to 1.02 at 4R on about
55 trades, so this is fragile and in-sample. The gap with the owner's manual results most likely comes from discretion in drawing and
redrawing lines, which these rules do not capture. Next step: compare the EA's drawn lines with the owner's lines in the visual tester.
