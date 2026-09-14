# data/repositories/

**Layering rule:** May import `drift`. Must not be imported by `domain/` or `ui/`.

One repository class per aggregate root (plan, ledger entry, guest, pledge, allocation,
sync state). Each repository:

- Accepts and returns plain value types or domain model classes — no raw `drift` row
  types leak out.
- Exposes `Stream`-based queries so the UI rebuilds reactively when a row changes
  (design.md §1.1 — Riverpod providers wrapping drift reactive queries).
- Routes every write through `data/changelog/` first, then applies to the projection
  table, in a single transaction.

No derived values are stored (design.md §1.4): payment status, totals, and adequacy
are computed by `domain/calculations/` at read time, not persisted here.
