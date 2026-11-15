# NewORB_EA - backtest results

EA: `NewORB_EA_v6.mq5`, lot 0.10 (`tester/sets/U_ORB.set`; the EA's default lot is 0.01).
Conditions: XAUUSD, M5, MT5 Strategy Tester, FundedNext demo server history (MT5 build 6320), $15,000, leverage 1:100, 0 ms delay,
costs = recorded spread plus the test server's commission and swap (no extra slippage). Run date: 15 Nov 2026. DD = max equity drawdown.
(`Expert=` lines in the `.ini` files use the local name `UserNewORBv6.ex5`.)

*Template for new entries: `../docs/RESULTS_TEMPLATE.md`. Update the root `RESULTS.md` after adding results.*

## 2 Jan 2024 - 13 Nov 2026, 1-minute OHLC
-$482 / 737 trades / win rate 70% (516) / PF 0.98 / DD 35.7% (balance DD 22.2%). Shorts 357, longs 380.

## Real ticks vs OHLC (28 Aug - 13 Nov 2026, 55 trades)
| Model | Profit | PF |
|---|---|---|
| Real ticks | **-$1,039** | 0.43 |
| 1-minute OHLC | -$492 | 0.85 |

## What the results mean
Many small wins and a few large losses (stop at the far side of the range, no target). Break-even over 2.9 years on the 1-minute model
with a 36% equity drawdown, and twice as bad on real ticks: the trailing/break-even logic is sensitive to tick order. Not usable as is.
