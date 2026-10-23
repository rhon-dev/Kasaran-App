# Phase 08 local client and backend transport

## Approval and scope

The owner approved proceeding with local client and backend development while deferring the outstanding Phase 07 gates. Existing account readiness, lease, encryption and migration protections remain enabled. This slice replaces the empty sync stubs with a real authenticated immutable-log transport and implements the Dart HTTP adapter. It does not enable background production sync, claim full Phase 08 completion, publish legacy stores, deploy hosted resources, use real-couple data or incur paid services.

## Wire contract

Both operations use POST to Supabase Edge Functions `/functions/v1/sync_push` and `/functions/v1/sync_pull`, implementing design.md §2.4's logical `/sync/push` and `/sync/pull` operations. Every envelope includes `protocol_version: {"major":1,"minor":0}` and a UUID `plan_id`. Compatible minor responses may add fields. Unsupported majors return HTTP 426 with `error: "unsupported_protocol"` and a positive integer `min_supported_build`.

A push includes at most 100 `rows`. Event fields are `id`, `plan_id`, `entity_type`, `entity_id`, `field_name`, nullable `change_group_id`, positive `schema_version`, required nullable typed JSON `old_value` and `new_value`, `device_monotonic`, `device_id`, `plan_member_id`, and `created_at`. Event and ledger entity IDs are canonical lowercase UUIDv7; plan/member/device identifiers are UUIDs. The caller supplies no `server_ts` and no trusted actor-user identifier. The server resolves the alias to the authenticated user and live membership. Counters, cursors and server stamps use canonical nonnegative decimal strings within signed int64; accepted stamps are positive. Schema versions remain positive JSON integers.

Responses are `{protocol_version, accepted:[{id,server_ts}], server_ts_high}` and `{protocol_version, rows, next_cursor, has_more}`. Pull requests contain string `cursor` and integer `limit` in 1–1000. Returned event rows include `server_ts`. Empty pages retain the input cursor and have `has_more:false`; nonempty pages have strictly increasing stamps and `next_cursor` exactly equal to the last row's stamp. Unknown additive row fields/types remain represented in client event data without being projected.

Integer money inside typed JSON remains exact: Edge handlers forward raw request text inside an RPC text argument; PostgreSQL parses the JSON itself. The RPC returns serialized response text, and Edge returns that text without JavaScript parsing/re-encoding financial numbers. The Dart native client parses integer JSON without converting values through `double`. No browser/web numeric-precision claim is made.

## Backend boundary

An additive migration adds protected per-plan sequence state and SECURITY DEFINER RPCs with an empty fixed search_path and restricted execution grants. Authenticated callers must be verified active members, with their live session checked against the actual local Auth schema. Every submitted alias must belong to that same authenticated user and plan. Anonymous, foreign, nonexistent, removed, unverified and revoked-session requests fail without exposing whether a foreign plan exists. Client table mutations remain denied; every new plan-scoped table has enabled and forced RLS and a membership read policy.

The server takes a per-plan row lock through transaction commit before assigning stamps. It checks the entire bounded push before publication, inserts new immutable rows once and returns original stamps for exact retries. Conflicting duplicate IDs fail the whole request. Failed transactions consume no committed sequence. Pull reads committed rows in strict plan order with bounded pagination and rejects cursor/limit/version errors without mutation.

This first server slice accepts only `ledger_entries` events with schema version 1, the entity currently owned by the Phase 07 writer. It validates complete event structure and attribution, not a new financial projection. Unsupported entity types/schema versions are refused before acceptance, retaining client queues; payment/receipt pairs cannot be half-accepted because neither event type is admitted. Full financial payload validation, additional entities, entity replay/LWW, projection rebuilding, automatic scheduling and durable local page/cursor persistence are later Phase 08 slices.

## Client boundary

`lib/sync/transport/` contains HTTP transport and immutable wire models only: no SQL, projection mutation, queue acknowledgment or cursor writes. It reads a fresh verified session before sending and rechecks its user plus opaque marker after token acquisition, retry delays and network awaits. Session replacement, including same-user replacement, rejects stale responses. Credentials and payloads never appear in errors/logs. Production uses HTTPS; explicit literal loopback HTTP supports disposable local tests. Redirects are refused so bearer material cannot move to another origin.

Requests and responses are bounded, timeouts are finite, transient retries are bounded, unsupported versions produce typed update-required errors, and malformed responses/acknowledgments cannot be mistaken for acceptance. Retry uses identical event IDs/payloads. Production startup does not instantiate or start the adapter until the later leased queue/persistence worker is verified.

## Verification

Use tests-first client loopback/fake-session cases and disposable local Supabase tests for live Auth/membership, idempotency, exact large integers, batch atomicity, original-author aliases, revoked/unverified users, foreign/nonexistent indistinguishability, limit-one pagination, concurrent transactions held before commit, rollback, protocol refusal and direct REST bypass denial. Require non-skipped forged-plan pull coverage from its actual test file in the existing tenant CI gate. Preserve retained Supabase volumes and unrelated uncommitted work. Record local evidence separately from remote CI, native runtime and full phase exit.
