# NYORB (`NYORB.mq5`)

Same engine as [NYBoxBreakout](../NYBoxBreakout/), but the box is the **09:30-09:45 New York opening range** (three M5
candles) instead of the pre-market box. Breakouts count from 09:45 until 10:30 NY. Trend filter, stop at the opposite
side of the range, 3R target, flat at 16:55 NY, risk-based sizing: all as in NYBoxBreakout.

- Inputs differ only in `InpBoxStartMin` = 570 (09:30) and `InpBoxEndMin` = 585 (09:45), and magic number 920502.
- No news guard (use the `NYBoxBreakout` EA for that).
- Results: [RESULTS.md](RESULTS.md). On the tested data it is **not better** than the pre-market box (clearly worse on NDX100,
  a tie on gold).
- Same server-time requirement as NYBoxBreakout: set the broker GMT offset inputs and confirm the box times.
