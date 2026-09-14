# sync/

**Layering rule:** Orchestrates push/pull against the Supabase backend. May import
`data/` (to read the outbound queue and write inbound rows) and `platform/` (for
network availability). Must not import `ui/` or `domain/`.

Sync runs in the background — on app foreground, on reconnect, and after a debounce
following a local write. It is not real-time (design.md §2.6: no websockets).

## Sub-packages

| Package | Responsibility |
|---|---|
| `queue/` | Outbound cursor: tracks `last_pushed_server_ts`, batches unsynced rows, handles partial success. |
| `clock/` | Device monotonic counter — a per-device ever-increasing sequence, never wall-clock time (design.md §2.2). |
| `transport/` | HTTP client for `POST /sync/push` and `GET /sync/pull`, with retry and idempotency (REQ-OF-5 cl. 2). |
