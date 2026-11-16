# ElasticFade: backtest results

Tick-level fade of short price bursts ("elastic"): a push of at least X $ in 3 s, then a stall (< Y $ in 1 s),
then a market entry against the push, take profit at 50% of the push, timeout exit. Rules come from a friend's
manual MGC (micro gold futures) scalping, first measured on one 3-hour Tradovate session (21 trades, +$98 gross, no costs).

## Setup
- Symbol XAUUSD (CFD), FundedNext MT5 test server, **every tick based on real ticks**, 28 Aug - 13 Nov 2026, M1 chart.
- $15,000 deposit, 0.10 lot (10 oz, same exposure as 1 MGC), execution delay 0, no extra slippage.
- Session 15:30-18:30 server (14:30-17:30 Paris); no entry 15:55-16:40 server (14:55-15:40 Paris) unless noted.
- Measured spread at entries: about $0.45-0.47 on average ($0.36-0.37 in a calm sample). Commission on gold is small (about $0.10 per trade).

## Results
| Variant | Net profit | Trades | Win rate | PF | Max DD (equity) | Avg trade | Avg trade before spread* |
|---|---|---|---|---|---|---|---|
| Replica: push $2 / 3 s, stall $0.2 / 1 s, TP 50%, timeout 30 s, no SL | -$4,547 | 206 | 45% | 0.20 | 30.4% | -$22.07 | about -$17.6 |
| Same + SL 50% of the push beyond the extreme | -$2,214 | 292 | 46% | 0.43 | 14.9% | -$7.58 | about -$3.0 |
| Push $4, stall $0.3, SL 50%, timeout 60 s | -$420 | 25 | 40% | 0.44 | 3.0% | -$16.79 | about -$12.1 |
| Replica, all day (01:00-23:00 server, no exclusion) | -$10,722 | 626 | 48% | 0.22 | 71.5% | -$17.13 | about -$12.4 |

*Before spread = avg trade + average entry spread x 10 oz. An approximation: it shows whether the rules have an edge at the mid price.

## Conclusion
No edge on XAUUSD CFD ticks, **even before the spread**. The 76% win rate seen on the single Tradovate session drops to 45-48%
over about 50 sessions. Fading 3-second bursts without a stop loses on the trades where the burst keeps going (largest loss -$200
in 30 s at 0.10 lot). Caveats: CFD quotes are not exchange trades, so tick frequency and fills differ from MGC futures; the friend's
discretionary DOM reading is not captured by these rules. This does not test his manual trading, only this mechanical translation.
