# domain/calculations/

**Layering rule:** Pure Dart. No Flutter, no drift, no I/O.

Computes all figures that are derived from ledger rows and never stored (design.md §1.4,
REQ-LG-5 clause 6):

- Gross event total
- Net out-of-pocket (gross minus fulfilled pledges)
- Outstanding pledge exposure
- Buffer remaining
- Category variance (allocated vs effective)
- Per-head derived amounts
- Budget adequacy (when reference costs are populated — OQ-04)

All inputs are `int` centavos or basis-point `int` multipliers. No `double` at any step.
Payment status (`paid` / `pending` / `overdue`) is also computed here and never stored.
