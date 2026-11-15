# Results template (copy into an EA's `RESULTS.md` for every run or group of runs)

```markdown
## <Short title of the test> - <YYYY-MM-DD>

**EA / version:** <file name, version, commit hash>
**Question tested:** <e.g. risk 0.5% vs 1%, filter on vs off, real ticks vs OHLC>
**Inputs:** <link to tester/sets/<file>.set, plus anything changed by hand>

| Item | Value |
|---|---|
| Symbol / timeframe | |
| Period | <from - to> |
| Tick model | real ticks / every tick / 1-minute OHLC / open prices |
| Deposit / leverage | |
| Costs assumed | spread recorded; commission <x>; slippage <x>; swaps <included/not> |
| Data source | <broker/server, MT5 build> |
| Date run | |

| Statistic | Value |
|---|---|
| Net profit ($ and % of deposit) | |
| Trades (long / short) | |
| Win rate (wins / trades) | |
| Profit factor | |
| Expected payoff | |
| Average win / average loss | |
| Max drawdown - balance (% and $) | |
| Max drawdown - equity (% and $) | |
| Recovery factor | |
| Sharpe ratio | |
| Longest losing streak (trades) | |
| Lowest margin level | |

**Cross-check (if the EA is tick-sensitive):** same window on real ticks vs 1-minute OHLC: <numbers>.
**What this shows:** <one or two sentences>.
**Caveats:** <sample size, in-sample selection, costs not modelled (slippage), limited tick history, anything odd in the logs>.
```

Keep failed and inconclusive runs. After adding results, update `RESULTS.md` (root) and the EA table in `README.md`.
