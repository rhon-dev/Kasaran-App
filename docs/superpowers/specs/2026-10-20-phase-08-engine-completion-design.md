# Phase 08 engine completion continuation

## Approved objective

The owner explicitly requested finishing Phase 08. The existing local transport and durable outbox push are complete, but they do not satisfy the phase exit. Continue through durable incoming-page persistence, deterministic replay, automatic orchestration, compatibility/failure recovery and convergence verification. Keep the complete exit matrix in `docs/development-phases.md` as the acceptance authority; do not silently replace it with a ledger-only exit. Inventory missing Phase 07 entity and native prerequisites separately and report any remaining unmet criteria honestly.

Existing constraints continue: synthetic/local disposable services only, no charges, hosted operations, real-couple data, commit or push. Preserve unrelated dirty work and Phase 07 account/native/legacy publication barriers. No fallback store or fabricated migration success. No new runtime dependencies without need and explicit review.

## First dependency: durable incoming pages

Advance the numbered local schema from v2 to v3, adding a retained raw accepted-event table. Use `sync_inbox` with event ID primary key, plan ID referencing the local plan, positive accepted server stamp, full raw event JSON text, and unique plan/stamp. Do not require an author alias foreign key: compatible unknown events and another member's history must be retained before projection without inventing local authorization metadata. Keep existing seven tables and values unchanged. Preserve every additive event field and native exact integers. Reject newer unsupported encrypted versions before Drift migrates. Reproduce real encrypted v2-to-v3 upgrade, failure rollback, reopen and retained sentinels/outbox/counters/cursors. Use the isolated pinned Drift generator; do not solve generator conflicts by changing production dependency pins.

Keep legacy source v2 authorization explicit. New schema must not accidentally reinterpret a v3 file as a supported legacy v2 source, weaken canonical layout checks or enable publication. Update private staging/version fixtures only when required and test the real canonical source version; do not relabel every fixture to make failures disappear.

## Account-bound pull contract

Add optional `SyncSessionBinding? requiredSession` to `HttpSyncTransport.pull`, with the same initial user/identical-marker check as push and unchanged existing after-await checks. The new account-leased `DurableInboxPuller.pullOnce(LedgerActor actor, {int limit = 100})` always supplies this binding. It returns only safe counts/cursor/has-more metadata. Production startup remains unwired until replay and orchestration are reviewed.

Under a counted account lease, capture verified session and matching active local plan/member/alias. Read this device/plan's cursor in a short transaction, defaulting to zero only when the device has no prior sync_state. Do not overwrite an existing counter/push watermark when creating absent device state. Fetch one page outside any SQLite transaction. After response, reauthorize and compare the persisted cursor with the admitted cursor inside one write transaction; reject a stale/concurrent different page without moving it backward. Persist all page rows and the exact next cursor atomically, with session checks after awaits and through the complete COMMIT future.

Reject changed duplicate event content, a changed stamp for an existing event, or reuse of a plan/stamp for another ID. Exact retries are idempotent only when the complete retained raw event matches. An already-committed identical page may be a no-op only after verifying every row and current cursor; otherwise fail safely and retry from a fresh read. Unknown entity types/schema versions/fields remain raw, not projected, while advancing past the entirely committed page. Empty pages preserve the current cursor. Network/protocol/local failure preserves prior inbox, cursor, outbox, financial rows and other device/account state.

The inbox stores authoritative accepted events separately from original locally authored events. Do not delete pending outbox entries on pull. Later replay must combine inbox events and acknowledged local events by immutable ID/content, detect conflicts, and overlay only this account/device's still-pending provisional writes in device-counter order. The presence of a matching accepted inbox ID must not apply that pending event twice.

## Subsequent dependencies

Replay follows design §2.2–2.3 exactly: order by `(server_ts, device_monotonic, device_id)`, atomic full creates/groups, typed old-value mismatch derivation, tombstone suppression and explicit Restore reopening pre-delete state, parent-gated children, unknown retention without financial projection, and exact source integer values. Preserve losing events. Validate source invariants without computing or storing derived totals. Rebuild and cursor publication must be transactional with rollback to the prior usable schema/projection on failure.

Orchestration must use the same leased identity and durable push/pull services, debounce local writes, retry on foreground/reconnect without a button, stop stale work on session/membership change, retain pending work and expose safe status. Do not invent unsupported cross-entity semantics. Sponsor payment/receipt atomicity, further entity convergence and upgrade paths require their actual schema/writer/calculation prerequisites; implement or explicitly identify each unmet exit assertion rather than declaring success from generic simulations.

## Verification

Tests-first with real encrypted reopen, actual COMMIT fault/switch interception, full rollback assertions, concurrent pull cursors, exact large integers, raw unknown events and per-account/device isolation. Execute actual local Edge round trips and two-device arrival-order/restart convergence. Review schema/security and replay/orchestration independently. Run all service-free tests with services stopped, strict analysis, formatting, diff checks, Android build and actual CI scripts. Preserve disposable volumes. No full phase completion claim until every applicable exit assertion is mapped to executed evidence or an explicitly documented unmet prerequisite.
