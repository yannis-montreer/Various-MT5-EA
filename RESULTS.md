# Backtest results index

Headline statistics for every EA. **Claude / AI assistants: update this file whenever you test an EA** (see the
instructions in `README.md`). Details and every run live in each EA's own `RESULTS.md`.

Common conditions unless the row says otherwise: MT5 Strategy Tester, broker server history of a FundedNext demo
server (MT5 build 6320), $15,000 deposit, leverage 1:100, costs = recorded spread plus the test server's own commission and swap settings (small: about -$34 commission and
-$81 swap over 351 gold trades at 0.25% risk; no extra slippage), 0 ms delay,
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
| [NYOpenScalp](NYOpenScalp/RESULTS.md) | NDX100 | 1R | +$866 | 716 | 53% | 1.05 | 9.0% | OHLC | M1 scalp of 09:30-09:35 range, 15 min exit, no trend filter. 2R/30 min: +$1,624, PF 1.07. Real ticks match OHLC |
| NYOpenScalp | XAUUSD | 1R | -$921 | 733 | 48% | 0.95 | 13.1% | OHLC | |
| [NYSweep](NYSweep/RESULTS.md) | NDX100 | 0.17-0.5R | +$1,012 | 477 | 79% | 1.14 | 4.0% | OHLC | Prior-day high/low sweep fades, all four setups. Pre-NY sweeps only: +$1,081, PF 1.30, DD 2.0%, positive each year. Real ticks match OHLC |
| [NYMeanRevert](NYMeanRevert/RESULTS.md) | NDX100 | to ref | -$3,730 | 704 | 38% | 0.86 | 30.3% | OHLC | Midday fade to tick-volume VWAP, 2 ATR entry. TWAP -$4,062, EMA100 -$1,419; every variant loses |

Win rate = winning trades / trades, from the Tester report.

## Other EAs on XAUUSD (same period and model; not strictly comparable: different rules and sizing)
| EA | Setup | Net profit | Trades | Win rate | PF | Max DD (equity) | Notes |
|---|---|---|---|---|---|---|---|
| [AsiaLondonBreakout v6 Risk](AsiaLondonBreakout/RESULTS.md) | shorts on, 0.5% risk | +$845 | 196 | 24% | 1.08 | 11.3% | Positive on 2024-25 (+$399) and 2026 (+$535); a 10% DD halt would stop it in Apr 2024 |
| AsiaLondonBreakout v6 Risk | shorts on, **0.25% risk** | +$307 | 193 | 24% | 1.06 | 5.6% | Same EA at the risk that fits a 10% drawdown limit |
| [LVC_EA (DST-aware)](LVC_EA/RESULTS.md) | default, 0.5% risk | -$196 | 160 | 29% | 0.98 | 8.9% | Original with fixed UTC offset: -$778. Options made it worse |
| [NewORB_EA v6](NewORB_EA/RESULTS.md) | lot 0.10, no TP | -$482 | 737 | 70% | 0.98 | 35.7% | Real ticks -$1,039 on 28 Aug - 13 Nov vs OHLC -$492 |
| [TrendlineBreak](TrendlineBreak/RESULTS.md) | H4 3-touch trendline break, 1% risk | -$517 | 50 | 48% | 0.76 | 7.5% | Exit on the new trend line (owner's exit). With a 3R target: +$938, PF 1.42; 4R: PF 1.02. 3R with looser touches (1.0 ATR): +$1,865, PF 1.51, 79 trades. "Snail" exit (ever steeper lines), 1.0 ATR, no target: +$1,171, PF 1.32, 78 trades; + daily EMA50 trend filter: +$1,195, PF 1.77, 40 trades. **H1 with the same settings: +$6,676, PF 1.73, DD 8.1%, 162 trades, positive each year; real ticks match.** EURUSD with the same settings: no edge (H1 filtered +$917, PF 1.09, DD 17.4%, carried by one 12R trade). UKOUSD H1: loses (filtered -$1,752, PF 0.77). NDX100 H1: break-even (filtered +$113, PF 1.02). Works on gold only |
| [ElasticFade](ElasticFade/RESULTS.md) | tick scalp, 0.10 lot, replica rules | -$4,547 | 206 | 45% | 0.20 | 30.4% | **Real ticks, 28 Aug - 13 Nov 2026 only.** Loses even before spread; best variant (with SL) -$2,214 |

## Portfolio: combining strategies (each leg at 0.25% risk per trade, 2 Jan 2024 - 13 Nov 2026, OHLC)
Built by merging the per-trade lists of the Strategy Tester reports (closed-trade balance basis, $15,000 start). Daily P&L correlations
are about zero (NYBox gold vs NYBox NDX100 0.00, NYBox gold vs AsiaLondon 0.05, NYBox NDX100 vs AsiaLondon 0.07).
| Combination | Net profit | Trades | PF | Closed-trade max DD |
|---|---|---|---|---|
| NYBoxBreakout XAUUSD alone | +$699 | 351 | 1.12 | 3.9% |
| NYBoxBreakout NDX100 alone | +$1,433 | 370 | 1.18 | 4.1% |
| AsiaLondonBreakout v6 Risk XAUUSD alone | +$307 | 193 | 1.06 | 5.1% |
| **NYBox XAUUSD + NYBox NDX100** | **+$2,131** | 721 | 1.16 | **4.2%** |
| NYBox XAUUSD + AsiaLondon | +$1,006 | 544 | 1.10 | 4.4% |
| NYBox NDX100 + AsiaLondon | +$1,740 | 563 | 1.13 | 6.8% |
| All three | +$2,439 | 914 | 1.13 | 6.3% |

Running the NY box on both symbols doubles the profit with no extra drawdown. Adding the London EA adds profit but raises drawdown
(4.2% to 6.3%), so it is less efficient. Caveats: in-sample, closed-trade drawdown ignores floating losses, simultaneous positions add risk,
and the combination assumes each leg keeps its own sizing.

## Head to head at 1% risk: TrendlineBreak gold H1 vs NYBoxBreakout NDX100 (2 Jan 2024 - 13 Nov 2026, 1-minute OHLC, $15,000)
| Strategy | Net profit | Trades | Win rate | PF | Max DD (equity) | Recovery factor | Max losing streak |
|---|---|---|---|---|---|---|---|
| TrendlineBreak3, XAUUSD H1, daily EMA 50 filter, snail exit | +$6,676 | 162 | 46% | 1.73 | 8.1% | 3.90 | 8 |
| NYBoxBreakoutNews, NDX100 M5, 3R, M15 trend filter, 1% risk | +$6,045 | 370 | 36% | 1.15 | 18.1% | 1.72 | 8 |

Similar profit; the trendline strategy has less than half the drawdown. But it works on gold only (EURUSD, NDX100 and UKOUSD
fail with the same settings), while the NY box is positive on both NDX100 and gold.

## Portfolio: TrendlineBreak gold H1 + NYBoxBreakout NDX100, each at 0.5% risk
Merged from the per-trade lists of both Tester reports (2 Jan 2024 - 13 Nov 2026, 1-minute OHLC, $15,000, closed-trade basis).
At 0.5% risk the trendline EA skips some gold trades whose stop is too wide for the 0.01 minimum lot (149 trades instead of 162 at 1%).

| Portfolio | Trades | Net profit | PF | Win rate | Closed-trade max DD | Net / DD | Worst losing streak |
|---|---|---|---|---|---|---|---|
| TrendlineBreak3 XAUUSD H1 alone | 149 | +$2,666 | 1.76 | 47% | $375 (2.2%) | 7.1 | 10 |
| NYBoxBreakoutNews NDX100 alone | 370 | +$2,851 | 1.16 | 36% | $1,506 (8.8%) | 1.9 | 8 |
| **Both** | 519 | **+$5,517** | 1.26 | 39% | **$1,649 (9.0%)** | **3.3** | 8 |

| Year | Trendline gold | NY box NDX100 | Both |
|---|---|---|---|
| 2024 | +$885 | +$2,023 | +$2,909 |
| 2025 | +$713 | -$684 | +$28 |
| 2026 (to 13 Nov) | +$1,068 | +$1,512 | +$2,580 |

Correlation of daily P&L -0.01, monthly -0.03. Losing months: 11 of 35 (trendline), 14 (NY box), 13 (both). At most 2 positions open
at once (1% total risk); 63 of the 370 NY box trades opened while a trendline trade was open. Worst combined day -$204 (1.4%).
Adding the trendline leg nearly doubles the profit for almost the same drawdown, and covered the NY box's losing 2025. Caveats:
in-sample, closed-trade drawdown ignores floating losses of multi-day gold trades (the trendline EA alone had a 2.9% equity drawdown),
and the trendline result depends on gold only.

## Correction (15 Nov 2026)
Earlier versions of these docs said the tests had "no commissions". The Tester reports include the test server's commission and swap
(for example gold, 351 trades: -$33.81 commission, -$80.64 swap; NDX100: no commission, -$58.57 swap). Results above already include them;
extra slippage is not modelled.

## Other runs worth knowing
- Risk scaling, yearly splits, filter on/off, TP multiples, news guard, real-tick checks: see [NYBoxBreakout/RESULTS.md](NYBoxBreakout/RESULTS.md).
- Small edge: about 0.15R per trade on NDX100, 0.07R on gold. About 120-140 trades a year per symbol.
  A single year can be flat (NDX100 2025 was about zero with a fixed lot).
- Account-size limit: gold at about $3,900 with a 0.01 minimum lot risks $15-45 per trade, so tiny accounts cannot
  size it at 0.5-1% risk.
