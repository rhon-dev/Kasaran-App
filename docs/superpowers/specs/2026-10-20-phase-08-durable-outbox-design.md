# Phase 08 durable outbox push

## Approval and boundary

The owner approved continuing Phase 08 after local transport closure. Implement the next independently testable vertical slice: send persisted ledger outbox events through the verified HTTP adapter and durably acknowledge only matching accepted events in the original account's encrypted store. This is not approval to deploy hosted services, use real-couple data, spend money, publish legacy stores, bypass Phase 07 gates, or enable unreviewed automatic production sync.

Use the existing v2 `outbox`, `change_log` and `sync_state` schema. Do not change local schema/version, generated Drift code, backend wire policy or dependency manifests. Durable incoming pages/cursors require retained unknown-row storage and a separately verified schema migration; pull persistence, replay/LWW/rebuild, automatic scheduling and UI progress remain subsequent slices. Do not claim this slice completes the phase.

## Account and transport authority

The account coordinator owns database selection. A push operation runs under a counted account lease through its full network and final database transaction, including COMMIT. No raw database production constructor or global fallback is permitted. Capture the fresh verified session marker and user, validate active local plan/member/original-author alias and requested device, and recheck identity after every awaited boundary. The server remains authoritative for live authorization.

The transport must be explicitly pinned to that same user and opaque session marker at admission, not merely checked against its own independently configured session source. Add an optional wire-only session-binding value to push admission, preserving existing callers. The durable pusher must always supply it. A mismatched transport source sends no request. A same-user replacement or A-to-B-to-A switch rejects stale work. Never copy a queued event into another account/device/plan, retag its original author, or reset counters.

## Snapshot and push

Expose an explicit single-batch push operation for a ledger actor through a new account-leased queue service. Production startup must not instantiate or schedule it yet. Select at most 100 pending rows for exactly the current actor's plan/device and original alias in stable device-counter/event-ID order. Queued rows resolving to another author/device remain untouched. Reject malformed matching rows before network; do not silently drop corrupt rows. Do not use an inner join that silently hides a corrupt dangling matching queue entry.

Convert persisted `old_value`/`new_value` JSON without floating-point conversion. Keep UUIDs, timestamps, nulls, typed snapshots, device counters and original event IDs unchanged. Retain the exact persisted snapshot for acknowledgment comparison. No SQLite transaction is held across network I/O. New events queued while the batch is in flight are not included in its acknowledgment.

## Atomic acknowledgment and retries

After HTTP acceptance, enter one local database transaction under the same lease. Reauthorize local membership/session and compare each acknowledged queued event against the admitted complete original snapshot. Reject unexpected IDs, conflicting assigned stamps, changed content/ownership or invalid acknowledgment structure without deleting any queued event or partially updating stamps.

For each acknowledged matching event, assign its immutable `server_ts` only if unset or already identical, then remove exactly its matching outbox row. Preserve `old_value`, `new_value`, author, device counter, financial projection and all unrelated rows. Concurrent identical acknowledgment may be an idempotent no-op only when the stored complete event still matches and its assigned stamp is identical. A missing queue entry alone is not proof of acceptance.

Update `sync_state.last_pushed_server_ts` monotonically from acknowledged stamps in the same transaction, preserving `device_monotonic`, `last_pulled_server_ts` and other device/plan state. Never infer acknowledgment from the server's high-water mark or remove unacknowledged rows. Empty/partial acknowledgments retain pending rows. An empty batch sends no HTTP request.

Network refusal, unsupported protocol, malformed reply, lost response after server acceptance and local transaction failure retain pending events for exact-ID/payload retry. If acceptance succeeds but acknowledgment rolls back, restarting and retrying must recover the original server stamp without another server event. Results/errors contain only safe counts/codes, not payloads or credentials.

## Verification

Use strict RED/GREEN with real encrypted SQLite reopen and actual HTTP boundaries. Prove successful acknowledgment survives reopen; partial/empty acceptance preserves queues; membership/author/device/plan forgery is denied; unsupported or malformed replies preserve state; changed queued payload and conflicting stamps roll back the entire acknowledgment; injected local failure rolls back both stamp assignment and queue deletion; and simultaneous/newly queued work remains safe.

Reproduce silent same-user replacement, A-to-B-to-A and transport/coordinator identity mismatch. Pause actual Drift COMMIT to prove account transitions drain through acknowledgment into only the original account file. Exercise server acceptance followed by a lost response/local failure and exact retry. Where needed, resume only the identified preserved `kasaran_p08_disposable` stack with exact guard, then stop it preserving volumes.

Run independent review, all service-free tests with local services stopped, strict analysis, scoped formatting, diff checks and Android debug build. Run tagged actual Edge integration for persisted local writer events and lost-response/idempotent recovery. Preserve unrelated dirty work; no commit or push.
