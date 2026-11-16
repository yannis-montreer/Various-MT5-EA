# NYMeanRevert: backtest results

Midday mean reversion on a US index: between 11:30 and 14:00 NY, when an M1 bar closes more than K x ATR(M5) away from a
session reference, fade the move with the target at the reference (value at entry) and the stop S x ATR(M5) beyond the entry.
Flat at 15:00 NY, one trade per day.

Three references, selected with `InpRefType`:
- `0` VWAP anchored at 09:30 NY, weighted by **tick volume** (CFDs have no exchange volume; this server's bars carry only tick volume);
- `1` TWAP anchored at 09:30 NY (every M1 bar weighs the same);
- `2` EMA(100) on M1 closes.

## Setup
NDX100, FundedNext MT5 test server, M1 chart, 1-minute OHLC model, 2 Jan 2024 - 13 Nov 2026, $15,000, 0.5% risk per trade,
server commission and swap included, no extra slippage. Spread observed on NDX100: about 1.76 points.

## Results
| Reference | K (entry, ATR) | S (stop, ATR) | Net profit | Trades | Win rate | PF | Max DD (equity) | Avg trade |
|---|---|---|---|---|---|---|---|---|
| VWAP (tick volume) | 2 | 1.5 | -$3,730 | 704 | 38% | 0.86 | 30.3% | -$5.30 |
| TWAP | 2 | 1.5 | -$4,062 | 698 | 37% | 0.85 | 32.8% | -$5.82 |
| EMA(100) M1 | 2 | 1.5 | -$1,419 | 625 | 40% | 0.94 | 18.6% | -$2.27 |
| VWAP (tick volume) | 3 | 2 | -$2,394 | 554 | 40% | 0.88 | 18.6% | -$4.32 |
| VWAP (tick volume) | 4 | 2 | -$774 | 386 | 40% | 0.94 | 13.3% | -$2.01 |

No real-tick check: every variant loses on the 1-minute model, and for NYOpenScalp the two models matched closely on NDX100.

## Conclusion
No edge. Tick-volume VWAP and TWAP give almost the same result (-$3,730 vs -$4,062), so the missing exchange volume is not
what decides the outcome. Fading midday stretches on NDX100 loses with every reference and every entry distance tested;
wider entries only lose less because they trade less. The index tends to keep trending away from its session mean.
