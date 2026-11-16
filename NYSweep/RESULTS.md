# NYSweep: backtest results

Prior-day high/low "sweep" fades, rules taken from a social-media promo (futures, 2021-2024, claimed 73.5% win rate and PF 1.39
for an ORB + sweeps stack). Only the sweep setups are coded here; the ORB part already exists as NYORB / NYBoxBreakout.

- Long: an M5 bar closes above the prior-day low while the previous bar closed at or below it. Short: mirror on the prior-day high.
- NY session 09:35-11:00: stop 2 x ATR, target 0.1667R (long, max 5/day) / 0.25R (short, max 1/day).
- Pre-NY 08:00-09:30: stop 4 x ATR, target 0.5R (long) / 0.3333R (short), max 1/day each.
- ATR = simple average of true range, 14 M5 bars. One position at a time, flat at 15:00 NY.
- Unknowns in the source, chosen here: M5 bars; prior-day levels = the 09:30-16:00 NY session (`InpPrevMode=0`) or the full NY
  calendar day (`InpPrevMode=1`); 0.5% risk per trade for every setup (the source used 1-4 contracts).

## Setup
NDX100, FundedNext MT5 test server, M5 chart, 1-minute OHLC model, 2 Jan 2024 - 13 Nov 2026 (after the source's 2021-2024 period),
$15,000, server commission and swap included, no extra slippage.

## Model check (all setups, 28 Aug - 13 Nov 2026)
| Model | Net profit | Trades | PF |
|---|---|---|---|
| Real ticks | -$390.33 | 29 | 0.50 |
| 1-minute OHLC | -$390.44 | 29 | 0.50 |

## Results, 2 Jan 2024 - 13 Nov 2026
| Variant | Prior-day levels | Net profit | Trades | Win rate | PF | Max DD (equity) | Avg trade |
|---|---|---|---|---|---|---|---|
| All four setups | RTH | +$1,012 | 477 | 79% | 1.14 | 4.0% | +$2.12 |
| All four setups | Full day | +$164 | 474 | 78% | 1.02 | 5.9% | +$0.35 |
| NY-session sweeps only | RTH | +$71 | 293 | 82% | 1.02 | 3.0% | +$0.24 |
| **Pre-NY sweeps only** | RTH | **+$1,081** | 208 | 76% | **1.30** | **2.0%** | +$5.20 (about 0.07R) |
| Pre-NY sweeps only | Full day | +$456 | 194 | 74% | 1.13 | 3.9% | +$2.35 |

### Pre-NY sweeps only (RTH levels), by year
| Year | Net profit | Trades | Win rate | PF | Max DD (equity) |
|---|---|---|---|---|---|
| 2024 | +$785 | 86 | 79% | 1.66 | 1.9% |
| 2025 | +$58 | 54 | 72% | 1.06 | 2.0% |
| 2026 (to 13 Nov) | +$273 | 67 | 76% | 1.24 | 2.0% |

## Conclusion
The NY-session sweeps (the bulk of the promo's stack) are break-even here. The pre-NY sweeps are positive in every year with a very
low drawdown, but the edge is small (about 0.07R per trade, about 70 trades a year), most of it comes from 2024, and it halves when the
prior-day levels are defined on the full day instead of the RTH session. The pre-NY-only variant was picked after seeing the split,
so it is in-sample. The high win rates come from targets of 0.17-0.5R against stops of 2-4 ATR and say nothing on their own.
Worth a forward test only as a small extra leg; not a replacement for NYBoxBreakout.
