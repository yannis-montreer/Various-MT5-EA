# Backtest results index

Headline statistics for every EA. **Claude / AI assistants: update this file whenever you test an EA** (see the
instructions in `README.md`). Details and every run live in each EA's own `RESULTS.md`.

Common conditions unless the row says otherwise: MT5 Strategy Tester, broker server history of a FundedNext demo
server (MT5 build 6320), $15,000 deposit, leverage 1:100, no commissions (recorded spread only), 0 ms delay,
1-minute OHLC model, 2 Jan 2024 - 13 Nov 2026 (about 2.9 years).

## Comparable headline table (0.5% risk per trade, 3R unless noted, trend filter on)
| EA | Symbol | TP | Net profit | Trades | Win rate | PF | Max DD (equity) | Model | Notes |
|---|---|---|---|---|---|---|---|---|---|
| NYBoxBreakout | NDX100 | 3R | +$2,851 | 370 | 36% | 1.16 | 9.1% | OHLC | Best EA here on NDX100. Real-tick check: matches. |
| NYBoxBreakout | NDX100 | 4R | +$3,729 | 370 | 35% | 1.20 | 10.9% | OHLC | In-sample best of several TP values |
| NYBoxBreakout | XAUUSD | 3R | +$1,483 | 361 | 44% | 1.12 | 10.1% | OHLC | Real ticks 28 Aug - 13 Nov 2026: +$273.80 vs OHLC +$254.93 |
| NYBoxBreakout | XAUUSD | 4R | +$2,176 | 361 | 44% | 1.17 | 9.9% | OHLC | |
| NYORB | NDX100 | 3R | +$1,274 | 334 | 45% | 1.10 | 9.5% | OHLC | Worse than the pre-market box |
| NYORB | NDX100 | 4R | +$1,523 | 334 | 45% | 1.12 | 9.2% | OHLC | |
| NYORB | XAUUSD | 3R | +$2,112 | 355 | 43% | 1.16 | 11.8% | OHLC | Tie with the box on gold |
| NYORB | XAUUSD | 4R | +$2,040 | 355 | 42% | 1.15 | 12.5% | OHLC | |

Win rate = winning trades / trades, from the Tester report.

## Other runs worth knowing
- Risk scaling, yearly splits, filter on/off, TP multiples, news guard, real-tick checks: see [NYBoxBreakout/RESULTS.md](NYBoxBreakout/RESULTS.md).
- Small edge: about 0.15R per trade on NDX100, 0.07R on gold. About 120-140 trades a year per symbol.
  A single year can be flat (NDX100 2025 was about zero with a fixed lot).
- Account-size limit: gold at about $3,900 with a 0.01 minimum lot risks $15-45 per trade, so tiny accounts cannot
  size it at 0.5-1% risk.
