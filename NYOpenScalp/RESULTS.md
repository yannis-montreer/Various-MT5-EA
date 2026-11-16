# NYOpenScalp: backtest results

M1 scalp of the New York cash open: range = high/low (wicks) of the M1 bars 09:30-09:35 NY; entry on the first M1 close
outside the range before 10:00 NY; stop at the other side of the range (or its middle); target in R; time exit; hard close 16:00 NY.
One trade per day, first breakout only.

## Setup
- FundedNext MT5 test server, M1 chart, $15,000 deposit, 0.5% risk per trade, server commission and swap included, no extra slippage.
- Main period 2 Jan 2024 - 13 Nov 2026, 1-minute OHLC model. Real-tick check on 28 Aug - 13 Nov 2026.

## Model check (NDX100, base settings, 28 Aug - 13 Nov 2026)
| Model | Net profit | Trades | PF |
|---|---|---|---|
| Real ticks | +$336.47 | 54 | 1.35 |
| 1-minute OHLC | +$336.08 | 54 | 1.35 |

The OHLC model matches real ticks here, so the long OHLC runs below are usable.

## Results, 2 Jan 2024 - 13 Nov 2026, 1-minute OHLC
| Symbol | Variant | Net profit | Trades | Win rate | PF | Max DD (equity) | Avg trade |
|---|---|---|---|---|---|---|---|
| NDX100 | Base: TP 1R, stop other side, exit after 15 min | +$866 | 716 | 53% | 1.05 | 9.0% | +$1.21 (about 0.02R) |
| NDX100 | TP 2R, exit after 30 min | +$1,624 | 716 | 48% | 1.07 | 11.1% | +$2.27 (about 0.03R) |
| NDX100 | TP 1R, stop at range middle, 15 min | +$822 | 716 | 52% | 1.04 | 9.8% | +$1.15 |
| NDX100 | Base + M15 EMA50/200 trend filter | +$173 | 356 | 53% | 1.02 | 6.6% | +$0.49 |
| XAUUSD | Base | -$921 | 733 | 48% | 0.95 | 13.1% | -$1.26 |

## Conclusion
No usable edge. On NDX100 every variant is close to break-even (about 0.02-0.03R per trade, drawdown 9-11%), against about
0.15R per trade for NYBoxBreakout on the same symbol and period. The trend filter, which helps NYBoxBreakout, does not help here.
Gold loses. The 2.5-month real-tick window was positive (PF 1.35, 54 trades) but is too short to override the 3-year result.
