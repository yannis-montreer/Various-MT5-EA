# VwapEma9: backtest results

Rules from a social-media reel ("VWAP + 9 EMA" on a 5-minute Nasdaq chart): the 9 EMA crosses the VWAP, a candle closes on that
side of the EMA -> enter, stay in, a candle closes back through the EMA -> exit. The reel showed a backtest (Sep 2023 - Sep 2025):
396 trades, 56.6% win rate, PF 1.84, max drawdown -22%, +300%, and claimed an "85% prop firm pass rate".

Gaps filled here (not in the reel): shorts mirrored; VWAP anchored at 09:30 NY with tick volume; entries 09:35-15:30 NY, flat at
15:55 NY; one entry per EMA/VWAP cross; risk sized at 0.5% on a swing stop (lowest low / highest high of the last 10 bars).

## Setup
NDX100, FundedNext MT5 test server, M5, 1-minute OHLC model, 2 Jan 2024 - 13 Nov 2026, $15,000, server commission and swap included,
no extra slippage.

## Results
| Variant | Net profit | Trades | Win rate | PF | Max DD (equity) | Worst losing streak |
|---|---|---|---|---|---|---|
| Exit on the EMA only (as in the reel), emergency stop at 3x the swing distance | -$2,858 | 1,817 | 33% | 0.89 | 22.9% | 12 |
| Same + hard stop at the swing point | -$2,767 | 1,817 | 33% | 0.89 | 22.3% | 12 |
| Exit on the EMA only, at most 1 trade a day | -$135 | 676 | 34% | 0.99 | 8.4% | 21 |

The swing stop is almost never reached before the EMA exit, so the two first rows have the same trades.

## Conclusion
Not reproduced: a 33% win rate instead of 56.6%, and losing or break-even in every variant. The reel's result likely depends on
settings it does not show (session, filters, exit details, data and costs). No edge found here.
