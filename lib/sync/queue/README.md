# sync/queue/

**Layering rule:** May import `data/` and `sync/clock/`. Must not import `ui/`.

Owns the outbound sync cursor for each `(device_id, plan_id)` pair:

- Reads `change_log` rows where `server_ts IS NULL`, ordered by `device_monotonic`.
- Batches them up to the configured cap (deployment-plan §2.4 — partial success is
  fine; retry is idempotent on the UUIDv7 primary key).
- On a successful push response, records the returned `server_ts` values back onto
  each accepted row and updates `sync_state.last_pushed_server_ts`.

The cursor survives app restarts because state is persisted in `sync_state` (design.md
§2.4), not held in memory.
