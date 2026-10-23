# sync/transport/

**Layering rule:** HTTP only. No business logic, SQL, queue acknowledgment,
cursor persistence, financial replay, or background scheduling. Production startup
does not start this adapter. See the approved local transport contract in
`docs/superpowers/specs/2026-10-20-phase-08-local-transport-design.md`.

Endpoints:

```
POST /functions/v1/sync_push
  { protocol_version: {major:1, minor:0}, plan_id, rows: ChangeLogRow[] }
  { protocol_version, accepted: [{id, server_ts}], server_ts_high }

POST /functions/v1/sync_pull
  { protocol_version: {major:1, minor:0}, plan_id, cursor, limit }
  { protocol_version, rows: ChangeLogRow[], next_cursor, has_more }
```

These implement the logical `/sync/push` and `/sync/pull` operations. Both use
POST; the historical GET pull stub is no longer the wire contract.

Responsibilities:
- Attach the injected Supabase anon key and a fresh verified session's bearer.
  Never persist or log credentials. Production uses HTTPS; literal loopback HTTP
  is allowed for disposable local tests. Redirects are refused.
- Capture the actual session marker at admission. Recheck before attaching
  credentials, after network operations and retry waits, and before returning
  accepted results. A same-user session replacement invalidates the request.
  Account-leased callers supply `requiredSession: SyncSessionBinding(...)` to
  `push()` so an independently configured transport cannot send one account's
  queued data using another account's user or session marker. A mismatched binding
  fails before HTTP admission. Existing unbound transport callers remain supported.
- Retry transient network errors and HTTP 429/500/502/503/504 with identical
  request bytes, at most three attempts, and 100/200 ms backoff. Each attempt has
  a finite timeout (15 seconds by default). Permanent refusals are not retried.
- Bound requests to 1 MiB and responses to 2 MiB by default. Sanitize errors;
  never expose raw server payloads. HTTP 426 produces `SyncUpdateRequired` only
  after validating `min_supported_build`.
- Preserve exact native signed-int64 JSON values and compatible unknown additive
  fields. Counters, cursors and stamps use canonical decimal strings on the wire.
  No browser numeric-precision guarantee is made.
- Validate push batches (at most 100 rows), returned IDs and high-water stamps.
  The initial backend accepts `ledger_entries`, schema 1. Exact retries receive
  original stamps; conflicting duplicate IDs reject the whole batch.
- Fetch one bounded pull page per call, with limit 1–1000. Validate plan identity,
  unique events, strictly increasing stamps and exact next cursor. Preserve
  unknown entity/schema rows without projecting them. The caller owns pagination
  and later durable queue/cursor transactions.

`SupabaseSyncSessionSource` adapts the pinned GoTrue client. `HttpSyncTransport`
owns its `HttpClient`, including an injected client; call `close()` when finished.
Phase 07 native/publication gates and later Phase 08 replay/worker work remain open.
