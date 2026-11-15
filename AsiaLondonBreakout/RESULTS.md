# AsiaLondonBreakout - backtest results

EA: `AsiaLondonBreakout_v6.mq5` (fixed lot 0.10) and `AsiaLondonBreakout_v6_Risk.mq5` (risk-based lot).
Conditions: XAUUSD, M5, MT5 Strategy Tester, FundedNext demo server history (MT5 build 6320), $15,000, leverage 1:100, 0 ms delay,
costs = recorded spread plus the test server's commission and swap (no extra slippage). Winter offset 2, summer offset 3.
Period: 2 Jan 2024 - 13 Nov 2026 unless stated. Run date: 15 Nov 2026. DD = max equity drawdown. The `.set` files used are in `tester/sets/`
(the `Expert=` line of the `.ini` files uses the local test file names `UserAsiaLondonV6.ex5` / `UserAsiaLondonV6_Risk.ex5`).

*Template for new entries: `../docs/RESULTS_TEMPLATE.md`. Update the root `RESULTS.md` after adding results.*

## 1. Defaults (lot 0.10, longs only) - 1-minute OHLC
-$87 over 108 trades, win rate 25% (27 of 108), PF 0.99, DD 18.2%.

## 2. Options tested (lot 0.10), train 2024-2025 then one test on 2026
Six switch combinations chosen in advance; the best on the training period was tested once on 2026.
| Variant (set file) | Train 2024-2025: profit / trades / PF / DD |
|---|---|
| Defaults, longs only (`U_V6`) | +$1,285 / 85 / 1.39 / 7.4% |
| **Shorts on** (`V6_B_shorts`) | **+$1,933 / 151 / 1.30 / 6.2%** |
| Shorts + trend filter | +$839 / 93 / 1.22 / 7.8% |
| Shorts + retest | -$415 / 130 / 0.93 / 12.2% |
| Shorts + trend + ATR expansion filter | +$428 / only 10 trades / 1.72 / 3.8% |
| Shorts + Asia-position filter | +$65 / 70 / 1.02 / 6.8% |

Test on 2026 (1 Jan - 13 Nov): shorts on **+$2,443** / 45 trades / PF 1.35 / DD 15.4% (shorts won 10 of 23, longs 2 of 22);
longs only -$1,371 / 23 trades / PF 0.71 / DD 19.6%.
A single winning trade of $1,919 makes most of the 2026 profit (about +$525 without it). 2026 was a falling gold year.

## 3. Risk-based copy (shorts on), 1-minute OHLC
| Risk | Period | Profit | Trades | PF | DD (equity) |
|---|---|---|---|---|---|
| 0.5% (no halt or daily stop only) | 2024-2026 | **+$845** | 196 | 1.08 | 11.3% |
| 0.5% with 10% drawdown halt | 2024-2026 | -$896 | 39 | 0.63 | 10.2% (halted 11 Apr 2024) |
| 0.5% | train 2024-2025 | +$399 | 151 | 1.05 | 11.3% |
| 0.5% | test 2026 | +$535 | 45 | 1.24 | 4.3% |
| 0.25% (daily 3%, DD halt 10%) | 2024-2026 | **+$307** | 193 | 1.06 | 5.6% |
| 0.25% | train 2024-2025 | +$127 | 151 | 1.03 | 5.6% |
| 0.25% | test 2026 | +$180 | 42 | 1.19 | 2.0% |

At 0.5% risk the daily stop (3%) never fires (one trade a day). The gain at fixed lot (PF 1.30) shrank to PF 1.05 once risk per trade was equalised:
the big winners came from wide-range days where a fixed lot risked far more.

## 4. Real ticks vs 1-minute OHLC (28 Aug - 13 Nov 2026)
| Run | Real ticks | OHLC |
|---|---|---|
| Defaults, 5 trades | -$762 | -$760 |
| Shorts on, lot 0.10, 13 trades | +$214 | +$215 |
| Risk copy 0.5%, 13 trades | +$43 | +$44 |

This EA is not sensitive to tick order.

## What the results mean
Positive on both periods only with shorts enabled, and only weakly once risk per trade is equalised (PF 1.03-1.08, about 190 trades over 2.9 years).
At equal risk it earns less than the NYBoxBreakout EA on gold (see root `RESULTS.md`). Variants were chosen on the same data family; 6 switches tested.
