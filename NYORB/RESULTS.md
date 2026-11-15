# NYORB - backtest results

EA: `NYORB.mq5`. Sets: `tester/sets/ORB_Risk05_RR3.set`, `ORB_Risk05_RR4.set`. Configs: `tester/configs/ORB_*_all.ini`.
Conditions: MT5 Strategy Tester, FundedNext demo server history (MT5 build 6320), 1-minute OHLC model, 2 Jan 2024 - 13 Nov 2026,
$15,000, leverage 1:100, 0.5% risk per trade, trend filter on, costs = recorded spread plus the test server's commission and swap. Run date: 15 Nov 2026.

*Template for new entries: `../docs/RESULTS_TEMPLATE.md`. Update the root `RESULTS.md` index after adding results.*

## ORB 09:30-09:45 vs the pre-market box
Profit / PF / max equity drawdown / trades.
| | Box 3R | Box 4R | ORB 3R | ORB 4R |
|---|---|---|---|---|
| XAUUSD | +$1,483 / 1.12 / 10.1% / 361 | +$2,176 / 1.17 / 9.9% | +$2,112 / 1.16 / 11.8% / 355 | +$2,040 / 1.15 / 12.5% |
| NDX100 | +$2,851 / 1.16 / 9.1% / 370 | +$3,729 / 1.20 / 10.9% | +$1,274 / 1.10 / 9.5% / 334 | +$1,523 / 1.12 / 9.2% |

Win rate (3R): ORB XAUUSD 43% (151 of 355), ORB NDX100 45% (150 of 334).

## What this shows
The pre-market box is clearly better on NDX100 (more than twice the profit at about the same drawdown). On gold the two versions
are within noise of each other. Possible reason on NDX100: the pre-market range absorbs the overnight and 08:30 news move
before the cash open, while a box built after the open has noisier first minutes.

## Caveats
One period, one run per setting, no extra slippage, OHLC model only (no real-tick cross-check for ORB). The comparison
is in-sample.
