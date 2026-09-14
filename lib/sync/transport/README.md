# sync/transport/

**Layering rule:** HTTP only. No business logic. No SQL. Wraps the two sync endpoints
(design.md §2.4) with retry and idempotency handling.

Endpoints:

```
POST /sync/push  { plan_id, rows: ChangeLogRow[] }
                 → { accepted: [{ id, server_ts }], server_ts_high }

GET  /sync/pull  ?plan_id&since_server_ts&limit
                 → { rows: ChangeLogRow[], next_cursor, has_more }
```

Responsibilities:
- Attach the Supabase anon key (from `--dart-define=SUPABASE_ANON_KEY`, never hardcoded).
- Retry on transient network errors with exponential backoff.
- Idempotency: push is safe to retry because the server does insert-ignore on the
  UUIDv7 primary key (REQ-OF-5 cl. 2).
- Pull is cursor-paged on `server_ts`; transport iterates pages until `has_more` is
  false or the batch limit is reached.
