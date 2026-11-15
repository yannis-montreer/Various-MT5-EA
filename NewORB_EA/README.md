# NewORB_EA (`NewORB_EA_v6.mq5`)

Opening-range breakout on gold. The range is built from `StartHour:StartMinute` (default 16:30 **server time**, which is 09:30 New York for a
GMT+2/+3 broker) for `MonitorDuration` minutes (15). Breakout detected on ticks, entry on the first M5 close beyond the range, **stop at the
opposite side of the range, no take profit**, then a break-even and trailing routine. Fixed lot (`LotSize`, default 0.01).

Results: [RESULTS.md](RESULTS.md). It is the same idea as [NYORB](../NYORB/), without a target or an end-of-day exit.

## Known issues (from reading the code)
- No take profit and no end-of-day close: positions can run for days.
- The break-even level for buys uses `range x 1.5 x BEthreshold`; for sells it moves the stop to the range low, not to the entry.
  The trailing threshold is measured in account currency (`LotSize x RiskRatio`), which depends on the lot.
- Hard-coded time of day and magic number; very verbose `Print` output.
