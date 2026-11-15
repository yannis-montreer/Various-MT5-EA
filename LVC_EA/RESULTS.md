# LVC_EA - backtest results

Conditions: XAUUSD, M5, MT5 Strategy Tester, FundedNext demo server history (MT5 build 6320), $15,000, leverage 1:100, 0 ms delay,
costs = recorded spread plus the test server's commission and swap (no extra slippage), 1-minute OHLC unless stated.
Period: 2 Jan 2024 - 13 Nov 2026 unless stated. Run date: 15 Nov 2026. DD = max equity drawdown. Sets in `tester/sets/`
(`Expert=` lines in the `.ini` files use the local names `UserLVC.ex5` / `UserLVC_dst.ex5`).

*Template for new entries: `../docs/RESULTS_TEMPLATE.md`. Update the root `RESULTS.md` after adding results.*

## 1. Defaults (true-break setup only)
| Version | Profit | Trades | Win rate | PF | DD |
|---|---|---|---|---|---|
| `LVC_EA` as written, lot 0.10 | **-$778** | 166 | 27% | 0.75 | 7.8% |
| `LVC_EA_dst` (DST-aware offset), lot 0.10 | -$140 | 160 | 29% | 0.95 | 4.6% |
| `LVC_EA_dst`, 0.5% risk | -$196 | 160 | 29% | 0.98 | 8.9% |

The fixed UTC offset costs about $640 over the period (windows shifted in summer).

## 2. Options (`LVC_EA_dst`, 0.5% risk): train 2024-2025, then 2026
| Variant | Train profit / trades / PF / DD |
|---|---|
| True break only (default) | **+$513** / 129 / 1.08 / 6.7% |
| + retest | -$1,399 / 205 / 0.87 / 13.9% |
| + reversal | -$1,574 / 172 / 0.82 / 15.1% |
| + retest + reversal | -$2,996 / 223 / 0.73 / 20.5% |
| + bias filter alone | identical to default (no effect) |
| + all three | identical to retest + reversal |

Test on 2026 for the best (default): **-$653** / 31 trades / PF 0.63 / DD 6.6%. No option helped.

## 3. Real ticks vs OHLC (28 Aug - 13 Nov 2026, `LVC_EA_dst`, 0.5% risk, 10 trades)
Real ticks -$225, OHLC -$215. Not tick sensitive.

## What the results mean
No robust edge at default settings: break-even over 2.9 years, losing on 2026, and every extra setup made it worse. Code quality
(handles, ATR-normalised stops, logging) did not translate into profit.
