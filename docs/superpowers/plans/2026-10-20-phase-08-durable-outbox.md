# Phase 08 Durable Outbox Push Implementation Plan

> **For agentic workers:** Use subagent-driven-development and strict test-driven-development. Preserve unrelated uncommitted work. No commit/push.

**Goal:** Connect existing encrypted pending events to authenticated transport with atomic durable acknowledgment and safe retry.

**Architecture:** A counted account lease admits one explicit push batch, snapshots the current actor's pending events, releases the read transaction before HTTP, and atomically persists accepted stamps/outbox deletion after fresh authorization. The transport binds its actual session source to the coordinator's user/marker. Existing v2 tables suffice; incoming durable pages remain a later schema slice.

**Tech Stack:** Pinned Dart/Flutter, Drift/SQLite encryption and current HTTP/Supabase adapter. No new dependencies.

## Global Constraints

- Follow `docs/superpowers/specs/2026-10-20-phase-08-durable-outbox-design.md` exactly.
- Preserve account protections, original event content/counters, other devices/plans, applied migrations and unrelated dirty work.
- No hosted operations, real-user data, paid services, commits, pushes, startup scheduling or schema changes.
- Synthetic actual Edge tests may target only preserved `kasaran_p08_disposable`, with exact guard and non-destructive stop.

## Task 1: Pin push transport to admitted account identity

Files: `lib/sync/transport/sync_transport.dart`, `test/sync/transport/sync_transport_test.dart`.

Interface: immutable `SyncSessionBinding({required String userId, required Object marker})`; `HttpSyncTransport.push(String planId, List<SyncEvent> rows, {SyncSessionBinding? requiredSession})`. When provided, current transport identity must match both user and identical marker before any request. Preserve existing transport freshness checks and unbound caller compatibility.

- [x] Add failing loopback tests for mismatched user, same-user marker mismatch and matching binding.
- [x] Implement minimal binding admission and rerun focused tests/analysis.

Executed RED: focused transport tests failed to compile because `SyncSessionBinding` and `requiredSession` did not exist. GREEN: all 30 focused protocol/transport tests passed, including three new binding cases; scoped analysis and diff checks passed. Queue implementation remains in progress.

Independent binding review approved scoped spec compliance and quality/security with no blocking findings. Its two optional test suggestions were applied: the matching-binding test now asserts the exact wire envelope, and an explicitly bound push rejects same-user replacement during HTTP. The focused transport suite now passes 31 tests with clean scoped analysis. Queue wiring remains outside this approval until the separate queue review completes.

## Task 2: Account-leased durable outbox pusher

Files: new `lib/sync/queue/durable_outbox_pusher.dart`, new `test/sync/queue/durable_outbox_pusher_test.dart`; tagged Edge integration under `test/api/sync/` if needed.

Interface: `DurableOutboxPusher(AccountStoreCoordinator coordinator, HttpSyncTransport transport)` and explicit `pushOnce(LedgerActor actor)` returning a safe count result. Bind transport with the coordinator's admitted verified user/marker using Task 1. No production startup wiring.

- [x] Read writer/database/coordinator definitions and fixture conventions; create a durable findings/report file immediately.
- [x] Write and run one failing real encrypted-queue acknowledgment/reopen test before implementation. Implement just that vertical slice and rerun GREEN.
- [x] Add individual RED/GREEN regressions for partial/empty acknowledgments, original-author/device/plan ownership, malformed/lost replies, conflicting content/stamps, whole-transaction rollback and exact retry after local failure.
- [x] Prove same-user replacement, A-to-B-to-A, concurrent/new queue events, and actual COMMIT drain across account transition. Preserve identity and data on rejection.
- [x] Exercise persisted writer events through actual disposable Edge endpoints, including acceptance before lost response/local retry; no synthetic transport substitution for this test.
- [x] Report exact named counts, failures/skips, changed files and deferred scope.

## Task 3: Independent review and combined evidence

- [x] Review transport and queue changes independently; resolve concrete findings with regressions and re-review.
- [x] Update CI expected test counts only from executed named tests and actual suite identities.
- [x] Run full service-free tests with services stopped, strict full analysis, scoped format, diff checks and Android build.
- [x] Update testing/phase docs with executed evidence and next durable-pull/replay boundaries. Stop only the disposable stack with volume preservation. No full phase exit claim.

Parent checkpoint: 371 service-free named tests passed without failures/skips with services stopped; full strict analysis, 11-file scoped formatting, actionlint and diff checks passed. Android debug build succeeded with a non-fatal SDK XML warning. Actual CI scripts executed locally: Python13, contract/transport14, tenant9, all passing without skips. Exact disposable was stopped with two volumes preserved. Independent queue review remains pending; §2.0H in testing-plan records current evidence and limits.

Final review closure: independent queue/integration review approved scoped spec compliance and quality/security with no blocking findings and verified unchanged review snapshots. The recorded 55 queue, 31 protocol/transport and two real Edge cases were inspected, not independently rerun by the reviewer. Explicit unequal-counter ordering and direct in-flight ownership/group mutation tests were suggested as nonblocking future hardening; full-column snapshot comparison was approved. All acceptance tasks for this bounded push slice are complete. Earlier pending/recovery checkpoints are historical; durable incoming pages/cursors, automatic scheduling, replay/LWW and phase exit remain separate.

## Interrupted-worker recovery checkpoint

The first queue worker stopped after a provider usage limit, leaving actual source and tests but no completed Edge integration. On resumption, the parent read the early report and source, preserved all partial work, and executed the combined queue/transport selector: 84 passed and one failed. The failure is `forged actor invalid device is denied before HTTP`, which currently returns an empty success instead of rejecting the invalid device. Scoped analysis also identified three informational diagnostics; the COMMIT-drain fixture prints a multiple-database warning. No completion claim is justified from the earlier partial report.

One recovery worker owns only those unresolved corrections, final queue verification and the missing real persisted-writer/Edge integration. The independently implemented transport binding is under separate read-only review. Existing encrypted reopen, snapshot rollback, account-switch, partial acknowledgment and retry tests remain preserved rather than being restarted.
