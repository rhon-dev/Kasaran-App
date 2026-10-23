# Phase 08 Local Transport Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver and exercise authenticated versioned client/server push/pull, commit ordering, idempotency and bounded pagination on disposable local infrastructure.

**Architecture:** An additive PostgreSQL migration owns authorized acceptance and commit-ordered per-plan state. Edge functions forward raw request/response text without JavaScript numeric conversion. An independent Dart HTTP adapter validates immutable wire models, session freshness and responses without touching SQLite queues/cursors or production startup.

**Tech Stack:** Existing pinned Flutter/Dart/Supabase packages, Dart `dart:io`, PostgreSQL 17, existing Supabase Edge runtime, Python standard-library local integration harness. No new package dependencies.

## Global Constraints

- Follow `docs/superpowers/specs/2026-10-20-phase-08-local-transport-design.md` for exact wire fields, limits, int64 handling and scope.
- Existing Phase 07 account protections remain enabled; native/legacy publication remains blocked. No hosted operations, real-couple data, paid services, commit or push.
- Preserve all pre-existing dirty work. Add forward migration `0004_ordered_sync_transport.sql`; do not rewrite already-applied migrations.
- New sequence state is plan-scoped with enabled/forced RLS and member-read policy. Direct client mutations remain denied.
- Client transport does not mutate queues/cursors/projections or start background sync. Server initially admits only `ledger_entries`, schema 1; it does not claim full financial replay or paired-event support.
- Only disposable project `kasaran_p08_disposable` may receive synthetic integration fixtures. Retained `kasaran` data/volumes remain untouched. Keys/tokens/passwords stay in process memory and never appear in reports/errors.

### Task 1: Authorized commit-ordered backend

**Files:** Create `supabase/migrations/0004_ordered_sync_transport.sql`; replace existing `supabase/functions/sync_push/index.ts` and `sync_pull/index.ts`; add a shared raw-text RPC handler under `supabase/functions/_shared/`; create local integration tests under `test/api/sync/` and `test/api/tenant_isolation/forged_pull_test.dart`; adapt the historical contract tests to the implemented POST protocol rather than weakening denial assertions.

**Interfaces:** Edge POST handlers call authenticated SQL `sync_push_v1(payload_text text) returns text` and `sync_pull_v1(payload_text text) returns text`. SQL owns version/schema, validation, live verified session/membership and original-author alias checks. Use exactly the spec envelopes. Uniform plan-unavailable responses deny foreign and absent plans. Structured unsupported-major responses carry `min_supported_build`.

- [x] Write a real local test for own-plan push/pull and exact retry; run RED against the existing empty/GET stubs or absent RPC.
- [x] Add the minimal migration/handlers and run the same test GREEN. Inspect local Auth catalog before referencing session columns. Hold the per-plan row lock through commit; keep sequence update and log insertion in one transaction.
- [x] Add RED/GREEN cases for conflicting duplicates, mixed-plan batch rollback, caller-authored stamps, alias forgery, removed/unverified/revoked users, large exact integer JSON and counters, unsupported version/entity/schema, limit-one paging, invalid cursor/limit and direct REST/RPC bypass.
- [x] Exercise two actual transactions with an acceptance held before commit; prove a second push cannot overtake it and pull sees only committed rows. Inject rollback and retry with original IDs. Use bounded test barriers rather than asserting from sleeps alone.
- [x] Execute new tagged local tests plus existing core isolation and updated contract tests on the disposable project. Keep CI assertion names and suite identity exact; retain no skipped acceptance assertions. Report exact results and known deferred gates.

### Task 2: Dart HTTP wire adapter

**Files:** Create `lib/sync/transport/sync_protocol.dart`, `lib/sync/transport/sync_transport.dart`, `test/sync/transport/sync_protocol_test.dart` and `test/sync/transport/sync_transport_test.dart`; update `lib/sync/transport/README.md` to the versioned POST contract.

**Interfaces:** Immutable `SyncProtocolVersion(major,minor)`, `SyncEvent.fromJson(Map<String,Object?>)`, push acknowledgment and pull-page models. `SyncAuthSession(userId,marker,accessToken)` is transient; `SyncSessionSource.capture()` returns a fresh verified identity or null, with production Supabase adapter. `HttpSyncTransport(baseUrl,anonKey,sessions,...)` exposes `push(planId,rows)` and `pull(planId,cursor,limit)` and `close()`. Models retain compatible unknown additive values and signed-int64 JSON integers. Never send `server_ts` on push.

- [x] Write the first failing protocol round-trip test with exact `9007199254740993` cents, decimal-string int64 metadata and unknown additive payload. Implement immutable validated models and run GREEN.
- [x] Test loopback HTTP POST paths, bearer/anon headers and canonical versioned bodies. Verify client rejection of bad UUID/version/counter/page/ack structures, foreign-plan rows, invalid cursor advancement and unexpected event IDs before returning a successful response.
- [x] Test missing session, A→B→A and silent same-user marker changes during requests and retry waits. Require identical retry payloads, bounded attempts/timeouts, no redirects and sanitized errors containing neither credentials nor financial/raw server payloads. The production source rejects unverified sessions; its real issued-session interoperability remains part of Task 3.
- [x] Test HTTP 426 update-required with minimum build, permanent auth/validation refusal without retry, transient/network retry bounds, response-size bounds and closed-client behavior. Run focused tests, strict analyzer and scoped formatter.

**Client review checkpoint (2026-10-20):** Independent review approved scoped spec compliance and code quality/security with no findings, independently reran all 25 focused tests and scoped analysis, and confirmed its five-file snapshot matched the working tree. Parent combined verification executed 310 service-free named tests with zero failures/skips, strict full analysis and Android debug build successfully. Backend and actual Edge interoperability remain pending; this is not phase exit.

### Task 3: Combined verification and evidence

**Files:** Update `docs/testing-plan.md`, `docs/development-phases.md`, the design/plan and relevant sync README boundaries. Touch CI only for executable local gates and the new exact forged-pull suite.

- [x] Independently review backend authorization/commit ordering and client session/numeric boundaries; fix concrete findings using regressions and re-review.
- [x] Exercise Dart transport against the actual disposable local Edge endpoints with synthetic issued sessions. Verify acceptance stamps, retries and pull pages without exposing keys or mutating any production local queue.
- [x] Run all service-free Flutter tests, strict analysis, scoped formatting, `git diff --check`, Android debug build and local service-backed suites. Count named assertions by test/suite IDs; report failures and skips separately.
- [x] Stop only the identified disposable stack with data preservation. Record real results, no full Phase 08 or Phase 07 exit claim. Leave hosted deployment, automatic worker, durable cursor persistence, LWW/rebuild and further entities explicit.

## Corrective verification checkpoint

Independent backend review found a real cross-plan duplicate-ID false acknowledgment, a Dart mismatch for approved zero counters/non-v7 group UUIDs, and transaction-clock expiry checks after waits. Tests reproduced all three before fixes. Additive migration `0005_sync_publication_authority.sql` corrects publication arbitration and current-clock authorization without changing applied `0004`; Dart now follows the approved counter/group contract. The alternate uncommitted collision already returned 409, not the initially suspected 503. A further regression preserves allocation-free exact retries at exhausted sequence high-water.

Final implementer suites: Python 13, live Flutter 21, focused client 27, all zero failures/skips. Parent executed the actual updated CI test scripts: Python 13, contract/transport 12, tenant 9, all passing without skips. Parent strict full analysis, scoped formatting (10 files unchanged), `actionlint`, `git diff --check` and Android debug build passed. Parent then stopped only the exact disposable stack, verified zero remaining disposable containers and two preserved volumes, and reran all 312 named service-free tests with zero failures/skips while services were stopped. Final independent re-review approved all three corrections for spec compliance and quality/security with no remaining findings. It independently confirmed unchanged 0004, finalized/applied 0005 function bodies and all 27 focused client tests. This bounded local transport slice is complete; remote CI and full phase exit remain unverified.
