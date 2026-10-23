# Phase 08 synthetic sync prototype — design for review

**Status:** Bounded synthetic implementation and independent code review completed on 2026-10-20; execution evidence is recorded in the implementation plan and `testing-plan.md` §2.0D. Local simulation only, not Phase 08 transport, an exit certificate, or permission to deploy. Phase 07 account-scoped opening, legacy publication, complete entities/RLS and migrations remain incomplete.

## Purpose and boundary

Prove a deterministic model of the ordered push/pull protocol without a network, Supabase, a real Auth session, or the production encrypted database. Source and tests live under `lib/sync/prototype/` and `test/sync/prototype/` so no production import or route can accidentally use this model. Synthetic event IDs, plan IDs and users only. No hosted schema changes, real data, billing, new UX or money movement.

The model is **not** a substitute for PostgreSQL transactional per-plan locks, committed high-water marks, authenticated membership, Drift atomic persistence, SQLCipher key isolation, or two-platform verification. It may demonstrate logical invariants only.

## Components and interfaces

- `SyntheticEvent`: immutable ID, plan ID, device ID, positive device counter, positive schema version, event type/field and raw old/new JSON values. An event has no client-authored server sequence. The same event ID has one immutable accepted payload.
- `SyntheticSyncServer`: owns plan membership and a committed per-plan log. `push(actor, planId, protocolVersion, rows)` first verifies membership, version and **every** row's plan, attribution shape and duplicate identity. The entire bounded request either appends once in assigned increasing plan sequence or fails without changing log/sequence. A retry of the same event IDs returns their original sequence. A duplicate ID with different payload fails closed. `pull(actor, planId, protocolVersion, cursor, limit)` denies foreign and nonexistent plans with the same error; returns at most `limit` committed rows ordered by assigned sequence, `nextCursor` equal to last returned sequence (or input cursor), and `hasMore` from committed rows beyond it. Limits 1–1000; cursor nonnegative. No clock time or server timestamp is invented: the simulator's `sequence` stands for the future commit-ordered `server_ts` contract, not an implementation of it.
- `SyntheticSyncClient`: isolated per-device pending events, retained accepted log and cursor. On push failure the queue remains unchanged. On pull, a complete page is validated and applied to a copy; injected failure before the copy/cursor swap retains both previous log and previous cursor. Duplicate replay does not duplicate stored events. Unknown additive event types remain raw and advance the cursor, but create no projection. It does not calculate a budget or use a production `AccountLease`.

## Error and security behavior

Unsupported major, malformed event, invalid limit/cursor, mismatched plan, unauthorised or nonexistent plan, and conflicting duplicate IDs fail before mutation. Failure messages do not reveal whether a denied plan exists. Version refusal leaves the client queue and cursor intact. A client cannot set the ordering sequence. Device clocks do not order acceptance. Sequence allocation, page response, and page persistence are synchronous, deterministic simulation steps; concurrency and process crashes are deferred to real Phase 08 infrastructure.

## Tests and exit for this prototype only

Write RED tests first. Assert own plan rows and a foreign plan with existing rows; duplicate push preserves first stamp and count; conflicting duplicate and mixed-plan batch reject with no mutation; `limit=1` pages have no skips; empty pull retains cursor; retry after injected page failure neither advances cursor nor loses raw unknown rows; unsupported major leaves pending queue. Verify focused tests, analyzer, formatting and service-free suite. No TC-SE or TC-API full verdict is claimed from simulation. Real transport requires Phase 07 exit, live membership/RLS and a disposable local server concurrency test.

**Four v1 tests:** deterministic sequence and retry; explainable cursor/error outcomes; no money movement; no supplier recommendation. No AI introduced.
