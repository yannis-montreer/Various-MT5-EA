# LVC_EA

Asian range / London breakout on XAUUSD (M5) with three switchable setups: **true breakout** (default on), **breakout-retest** and
**breakout-reversal**, plus a recent-extreme bias filter. Files:
- `LVC_EA.mq5`: the EA as written (UTF-8 copy of the original UTF-16 file).
- `LVC_EA_dst.mq5`: the same EA with **one change**: the UTC offset follows US daylight saving instead of being a fixed `InpUtcOffsetMinutes`.

Results: [RESULTS.md](RESULTS.md).

## Notes
- ATR is read correctly (one `iATR` handle, `CopyBuffer`), stops and filters are ATR-normalised, optional risk-% sizing, one trade per day,
  debug logging (`InpDebugMode`, turn it off for tests).
- **The original uses a fixed UTC offset** (`InpUtcOffsetMinutes = 120`). On a broker that moves to GMT+3 in summer, the Asian and London
  windows are off by one hour for about eight months a year. `LVC_EA_dst.mq5` fixes that for a broker following US DST.
- Risk sizing rounds the lot **up** to the minimum lot, so risk can exceed the setting on small accounts.
- 53 inputs: a large search space, so beware of over-fitting.
