# domain/validation/

**Layering rule:** Pure Dart. No Flutter, no drift, no I/O.

Contains all field-level validation rules referenced in requirements:

- REQ-BS-2 — budget setup field constraints (budget > 0, guest cap ≥ 0, valid region,
  future wedding date).
- REQ-LG-1 — ledger entry field rules (estimated ≥ 0, deposit ≤ effective amount,
  per-head rate required when pricing mode is `per_head`).

Validators return typed result objects (valid / invalid + reason), not exceptions, so
the UI layer can display errors without try/catch at the call site.
