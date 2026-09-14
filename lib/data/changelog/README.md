# data/changelog/

**Layering rule:** Append-only. No UPDATE, no DELETE on `change_log` rows, enforced
by code convention and database permission (design.md §4.6).

The change log is the sync unit (design.md §2.1). Every user edit that mutates plan
content produces one `change_log` row per changed field before touching the projection
table. This package owns that write path.

Key invariants:
- One row per `(entity_type, entity_id, field_name)` change event, with `old_value`
  and `new_value` as JSON (REQ-SE-4 clause 3).
- Client-generated UUIDv7 primary key (design.md §2.3) — idempotency key for push.
- `device_monotonic` is set here from `sync/clock/`; `server_ts` is null until the
  row is accepted by the server (design.md §2.2, Decision D1).
- Superseded status is derivable at read time; it is never stored as a column
  (design.md §4.6).
