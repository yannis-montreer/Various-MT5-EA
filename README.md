# Various MT5 EAs

A collection of MetaTrader 5 Expert Advisors, each with its source, its Strategy Tester settings and its
**backtest statistics**. Every EA lives in its own folder. Results are recorded, including the negative ones.

> **Disclaimer.** Research code, shared as is, not financial advice. Backtests do not guarantee future results,
> and trading leveraged products can lose more than you expect. Test on a demo account first.

## EAs in this repository
| EA | Idea | Symbols tested | Status | Headline result* | Details |
|---|---|---|---|---|---|
| [NYBoxBreakout](NYBoxBreakout/) (`NYBoxBreakoutNews.mq5`) | Breakout of the 09:00-09:30 New York pre-market box, M15 EMA trend filter, 3R target, flat at 16:55 NY | XAUUSD, NDX100 | Backtested; live forward test being prepared | NDX100: +$2,851, PF 1.16, DD 9.1%, 370 trades; XAUUSD: +$1,483, PF 1.12, DD 10.1%, 361 trades | [README](NYBoxBreakout/README.md), [results](NYBoxBreakout/RESULTS.md) |
| [NYORB](NYORB/) (`NYORB.mq5`) | Same engine, but with the 09:30-09:45 opening range as the box | XAUUSD, NDX100 | Backtested; not better than the pre-market box | NDX100: +$1,274, PF 1.10; XAUUSD: +$2,112, PF 1.16 | [README](NYORB/README.md), [results](NYORB/RESULTS.md) |

\*0.5% risk per trade, 3R, trend filter on, MT5 1-minute OHLC model, 2 Jan 2024 - 13 Nov 2026, $15,000 start.
Full table with every run: [RESULTS.md](RESULTS.md).

| Folder | Content |
|---|---|
| `tools/` | Helper scripts (for example the economic-calendar exporter used by the news guard) |
| `docs/` | `RESULTS_TEMPLATE.md` (how to record results) and `TESTER_NOTES.md` (Strategy Tester pitfalls and MQL5 lessons) |
| `RESULTS.md` | Index of the headline backtest statistics for every EA |

Each EA folder contains: the `.mq5` source, `README.md` (rules, inputs, how to run), `RESULTS.md` (full backtest
statistics), and `tester/` (`sets/` = input files `.set`, `configs/` = Strategy Tester `.ini` files).

## Build and run
1. Copy the EA's `.mq5` into `<MT5 data folder>\MQL5\Experts\` (File > Open Data Folder in MT5), compile it in MetaEditor.
2. **Refresh the Navigator** (right-click > Refresh) after every compile. Otherwise the Strategy Tester may keep using an older build.
3. Copy the `.set` files from the EA's `tester/sets/` to `<MT5 data folder>\MQL5\Profiles\Tester\` and load one in the Tester's Inputs tab.
4. Check the broker's **server time offset** against the EA's inputs before trusting any result (see each EA's README).

---

## Instructions for Claude and other AI assistants (read this first, follow it every time)

When you work in this repository you **must record backtest statistics**. A change to an EA, or a new EA, is not
finished until its results are written down. Do this every time:

1. **Record every backtest you run or rely on** in the EA's `RESULTS.md`, using `docs/RESULTS_TEMPLATE.md`.
   Record the **negative and inconclusive** results too, not only the good ones. Never delete a bad result.
2. **Required statistics** for each run (take them from the Strategy Tester report, never from memory):
   EA name and version/commit, symbol, chart timeframe, **period**, **tick model** (real ticks / every tick /
   1-minute OHLC / open prices), deposit, leverage, the **inputs used** (link the `.set` file), **net profit and %
   return**, **number of trades**, **win rate**, **profit factor**, **expected payoff**, **max drawdown (balance and
   equity, in % and money)**, recovery factor, Sharpe ratio, longest losing streak, average win and average loss,
   **lowest margin level**, costs assumed (spread, commission, slippage, swaps), MT5 build, data source (broker and
   server), and the date you ran it.
3. **State the model fidelity.** If a strategy is sensitive to tick order (trailing stops, scalpers, tight stops), run the
   same window on real ticks and on 1-minute OHLC and record both. Never present a 1-minute-model result as proof
   for such an EA.
4. **Update the index.** Add or refresh the EA's headline row in `RESULTS.md` (root) and in the EA table of this README.
   Keep the headline row comparable (same risk, period and model) so EAs can be compared; say clearly when they cannot.
5. **Say what the result means and what it does not.** Include sample size (number of trades), the period
   covered, and caveats (small sample, in-sample selection among variants, missing commissions, limited tick history).
   Do not oversell: a small edge over a few hundred trades is not proof.
6. **Keep the repo reproducible.** Save the `.set` and `.ini` files used (`tester/`), and record the exact EA file and commit.
   Change the EA file name or version when its behaviour changes, and note it in the results.
7. **Never commit** API keys, MCP keys, passwords, account numbers, broker credentials, MT5 settings files, compiled
   `.ex5`, logs, or third-party code and binaries you do not have the right to publish. This repository is public.
8. **Do not commit or push unless the human asks you to.**
9. Before you end a task, check: results recorded in `RESULTS.md` (EA folder), index updated (root `RESULTS.md` and
   README table), `.set`/`.ini` saved, caveats written. Tell the human what you recorded.

## Adding a new EA
Create `<EAName>/` with the `.mq5`, a `README.md` (idea, rules, inputs, how to run, known limits), a `RESULTS.md` (from
the template) and `tester/sets|configs/`. Add it to the table above and to the root `RESULTS.md`.
