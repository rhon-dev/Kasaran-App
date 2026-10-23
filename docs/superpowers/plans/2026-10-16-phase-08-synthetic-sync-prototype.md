# Phase 08 Synthetic Sync Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exercise logical ordered push/pull, idempotency and page-retention invariants with synthetic data; deliver no production sync.

**Architecture:** Pure synchronous Dart simulator under `sync/prototype/`; no runtime imports, network, SQLite or platform services. One server holds per-plan accepted logs and a client simulates atomic page swap. Phase 09/10 remain draft designs, not implementations.

**Tech Stack:** Dart classes, `flutter_test`, existing Flutter analyzer. No dependency additions.

## Global Constraints

- No production route or repository imports this prototype. Do not call Supabase, use real accounts, or modify hosted/local database schemas.
- Preserve unrelated uncommitted Phase 07 work. No production sync or Phase 08/09/10 exit claims.
- Source events carry raw JSON text and positive per-device counters; server sequence is assigned only by the synthetic server.
- Foreign and absent plan denial have the same reason; invalid batch fails without partial append. Duplicate IDs with different payloads fail.
- Pull page stores raw unknown additive rows with cursor atomically; page failure leaves both old log and cursor.
- Four v1 checks: deterministic, explainable, no money movement, no supplier recommendations. No AI.

---

### Task 1: Deterministic server model

**Files:** Create `lib/sync/prototype/synthetic_sync_protocol.dart`; test `test/sync/prototype/synthetic_sync_protocol_test.dart`.

**Interfaces:** `SyntheticEvent(id,planId,deviceId,deviceMonotonic,schemaVersion,entityType,fieldName,oldValue,newValue)`; `SyntheticSyncServer(memberships,maxBatchSize,supportedMajor)`; `push(actor,planId,protocolMajor,rows,{failBeforeCommit=false}) -> List<SyntheticAccepted>`; `pull(actor,planId,protocolMajor,cursor,limit) -> SyntheticPage`; `SyntheticSyncError.reason`. All operations synchronous and independent of the app DB. `SyntheticAccepted(event,sequence)` uses monotonically increasing plan sequence.

- [x] Recover existing synthetic server tests covering own/foreign/absent plans, retry identity, atomic rejection, bounded pagination and pre-commit failure. Extend raw-payload and malformed-row coverage.
- [x] Run `flutter test --no-pub test/sync/prototype/synthetic_sync_protocol_test.dart -r expanded`: observed two passing tests and four expected failures before completing validation and candidate publication. No wall-clock time, async lock or crash-durability claim.
- [x] Run the same focused command to GREEN; run `flutter analyze --no-pub --fatal-infos --fatal-warnings` and `git diff --check`.

### Task 2: Atomic client-page simulation

**Files:** Modify `lib/sync/prototype/synthetic_sync_protocol.dart`; add `test/sync/prototype/synthetic_sync_client_test.dart` alongside the server tests.

**Interfaces:** `SyntheticSyncClient(planId,deviceId)` owns pending event list, retained accepted event map and cursor. `pushQueue(server,actor,protocolMajor)`, `pullPage(server,actor,protocolMajor,limit,{beforeCommit})`. `beforeCommit` is a synchronous test fault hook called before log/cursor swap.

- [x] Write client tests before implementation: version refusal, invalid and mixed-plan queues, bounded acceptance, raw unknown-row retention, failed page swap/retry, empty pulls and two-device log convergence.
- [x] Observe the expected missing-`SyntheticSyncClient` compile failure; implement validated snapshot-copy and publish-on-success; run GREEN. Add the independent review's recursive-page regression and verify retry after `pageInProgress`.
- [x] Run service-free `flutter test --no-pub --exclude-tags=local_supabase --reporter json`, analyzer, scoped formatter check and `git diff --check`. Confirm no production prototype imports; record real-server gates and the unrelated repository-wide formatter debt below.

## Execution evidence — 2026-10-20

The final service-free run executed **248 named tests, zero failures and zero skips**, including **16 prototype tests**. The JSON report was joined by suite/test IDs rather than treating file-load events as assertions. Strict analyzer, formatting for `lib/sync/prototype` and `test/sync/prototype`, and `git diff --check` passed. Repository-wide formatter checking still reports 22 unrelated files; those files were not reformatted. The independent review reported no concrete security or logic defects. Its named-boolean suggestion was fixed, and its recursive-page test suggestion was added and passed.

`projectedRows` selects the prototype's known schema-2 `ledger_entries.estimated_cents` integer/null events only; it is not an entity projection, LWW merge or financial calculation. Unknown types/schema versions remain raw. Queue and cursor state are in memory only. Phase 07 Auth-first integration, legacy promotion, full entity/RLS/migration gates, real transport/commit concurrency, native device checks and complete Phase 08 remain open. No database service, hosted deployment, dependency addition, billing, commit or push was performed.

**No commit/PR until exact changed-file scope and independent review are checked.** Docs and code may be committed together on a separate reviewed branch without staging unrelated Phase 07 work. Phase 09/10 designs stay proposals pending their dependencies.
