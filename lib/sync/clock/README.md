# sync/clock/

**Layering rule:** Pure Dart. No Flutter, no drift, no network. May persist its counter
via `platform/db/` only.

Provides the device monotonic counter described in design.md §2.2. This counter:

- Is a per-device integer that only ever increases — it carries no wall-clock meaning.
- Is recorded on every `change_log` write as `device_monotonic`.
- Is used as a tiebreaker when two rows share the same `server_ts`, and to order a
  device's own not-yet-synced rows locally before `server_ts` is assigned.

**Device wall time is never used for ordering.** A phone with a wrong clock must not
win a conflict (design.md §2.2, Decision D1). The server assigns `server_ts` as the
authoritative ordering timestamp at sync time.
