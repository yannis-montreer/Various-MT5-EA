# NYBoxBreakout - backtest results

EA: `NYBoxBreakoutNews.mq5` (news guard off unless stated). Settings used are in `tester/sets/`, Tester configs in `tester/configs/`.
Common conditions: MT5 Strategy Tester, FundedNext demo server history (MT5 build 6320), $15,000, leverage 1:100,
recorded spread only (no commission), 0 ms delay. "OHLC" = 1-minute OHLC model. PF = profit factor. DD = max equity drawdown.
Period unless stated: 2 Jan 2024 - 13 Nov 2026 (about 2.9 years). Trend filter on. Run dates: 15 Nov 2026.

*Template for new entries: `../docs/RESULTS_TEMPLATE.md`. Update the root `RESULTS.md` index after adding results.*

## 1. Risk-based sizing (OHLC)
Profit / DD / PF / trades. Sets: `Risk025_*`, `Risk05_*`, `Risk1_*` (`RR3` and `RR4` variants).
| Symbol | TP | Risk 0.25% | Risk 0.5% | Risk 1.0% |
|---|---|---|---|---|
| XAUUSD | 3R | +$699 / 4.2% / 1.12 / 351 | +$1,483 / 10.1% / 1.12 / 361 | +$2,852 / 20.2% / 1.10 / 361 |
| XAUUSD | 4R | +$977 / 4.2% / 1.17 | +$2,176 / 9.9% / 1.17 | +$4,959 / 20.2% / 1.16 |
| NDX100 | 3R | +$1,433 / 4.2% / 1.18 / 370 | +$2,851 / 9.1% / 1.16 / 370 | +$6,045 / 18.1% / 1.15 / 370 |
| NDX100 | 4R | +$1,810 / 5.2% / 1.22 | +$3,729 / 10.9% / 1.20 | +$8,163 / 21.1% / 1.18 |

Win rate at 0.5% / 3R: XAUUSD 44% (158 of 361), NDX100 36% (134 of 370); NDX100 4R: 35% (129 of 370).
Drawdown is roughly 8-20 times the risk percentage. Gold at 0.25% skips about 10 trades (budget below the minimum lot).
Lowest margin level in these runs was never close to a margin call at 0.5% risk.

## 2. Year by year (fixed 0.1 lot, 3R / 4R)
| | 2024 | 2025 | 2026 to 13 Nov |
|---|---|---|---|
| XAUUSD | +$1,184 / +$1,384 | +$1,172 / +$1,543 | +$757 / +$1,706 |
| NDX100 | +$2,370 / +$2,488 | -$27 / +$575 | +$2,311 / +$2,340 |

About 120-140 trades per year per symbol. A single year can be flat.

## 3. Trend filter on vs off (fixed 0.1 lot, 3R, 2 Jan 2025 - 13 Nov 2026)
| | Filter on | Filter off |
|---|---|---|
| XAUUSD | +$1,929, PF 1.10, DD 24.4%, 234 trades | -$1,089, PF 0.97, DD 39.5%, 452 trades |
| NDX100 | +$2,284, PF 1.16, DD 11.5%, 253 trades | +$4,942, PF 1.19, DD 12.1%, 479 trades |

The filter is what makes gold work; on NDX100 it mostly halves the number of trades.

## 4. Take-profit multiple (fixed lot, filter on, 2 Jan 2025 - 13 Nov 2026)
| | 1.5R | 2R | 3R | 4R |
|---|---|---|---|---|
| XAUUSD | +$357 | +$2,906 | +$1,929 | +$3,249 |
| NDX100 | +$54 | +$652 | +$2,284 | +$2,915 |

Gold is noisy; NDX100 improves with larger targets. In-sample: expect less out of sample.

## 5. News guard (FundedNext funded-account rule: +/- 6 minutes, 0.5% risk, 3R)
Sets: `News_off`, `FN_on`, `FN_flat` (FundedNext restricted-event list; `News_on`/`News_flat` use MT5's broader list).
| Mode | XAUUSD | NDX100 |
|---|---|---|
| Guard off | +$1,483 / 361 trades | +$2,851 / 370 trades |
| FundedNext list, guard on | +$1,472 / 346 | +$2,608 / 363 |
| FundedNext list, guard + flatten | +$1,197 / 346 | +$1,966 / 363 |
| MT5 "high" list, guard on (for comparison) | +$715 / 326 | +$2,860 / 357 |

The guard skips 2-4% of trades with the FundedNext list; flatten costs real profit. MT5's own "high" list is much
broader (107 vs 42 events in the same 73 days) and skips more trades than needed.

## 6. Real ticks vs OHLC (0.5% risk, 3R, guard off)
| Window | Real ticks | OHLC |
|---|---|---|
| XAUUSD 28 Aug - 13 Nov 2026 (24 trades) | +$273.80, DD 3.84%, PF 1.34 | +$254.93, DD 3.85%, PF 1.32 |
| NDX100 6 - 13 Nov 2026 (2 trades) | +$13.80 | +$13.81 |

The OHLC model matches real ticks for this EA (entries on M5 closes, stops far away). Real NDX100 ticks exist only
from 6 Nov 2026 on the test broker, so this check covers little NDX100 history.

## What the results mean
Small positive edge (about 0.15R per trade on NDX100, 0.07R on gold) over 360-370 trades per symbol, roughly two
standard errors from zero on NDX100. No commissions. Variants (filter, TP multiple, risk level) were compared on the same data,
so the best-looking values are optimistic. A forward test is needed before drawing conclusions.
