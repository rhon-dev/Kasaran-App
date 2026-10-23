# Phase 08 Engine Completion Plan

> **For agentic workers:** Use subagent-driven-development and strict test-driven-development. The owner approved completing Phase 08; do not stop after a passing partial slice or claim unexecuted exit assertions.

**Goal:** Complete remaining durable pull, replay, compatibility, orchestration and convergence dependencies against the actual exit matrix.

**Architecture:** Account-leased push/pull retain immutable local originals and full accepted raw inbox rows. A versioned encrypted schema introduces incoming retention; deterministic replay reconciles authoritative accepted events plus local provisional overlays; a session-scoped worker schedules bounded batches. Independent review and real local-service evidence gate each dependency.

**Tech Stack:** Existing pinned Flutter/Dart/Drift/SQLite encryption/Supabase. Isolated matching generator, no new runtime dependencies.

## Global Constraints

- Follow `docs/superpowers/specs/2026-10-20-phase-08-engine-completion-design.md` and complete Phase 08 exit matrix in `docs/development-phases.md`.
- Preserve unrelated dirty work, original log/queue/counters and account/native/legacy gates. No hosted/real data/charges/commit/push.
- Local schema changes are numbered and encrypted-upgrade tested. No unversioned hidden tables or production dependency changes for generation.
- Exact disposable project only for synthetic server tests; stop with volumes preserved.

## Task 1: Exit-prerequisite audit

- [x] Map every required TC to actual implemented assertions and missing entity/writer/calculation/platform dependencies. Write scratch exit-map with source references. No guessed expected values or reduced phase exit.

Audit result: full phase exit additionally requires the missing entity schemas/writers/RLS, atomic sponsor payment/receipt acceptance/staging, independent FIX-A…E monetary calculations and actual migration/native prerequisite evidence. Ledger-only convergence is not phase exit. No unresolved owner decision blocks local synthetic core development. Durable acceptance map: `2026-10-20-phase-08-exit-matrix.md`; detailed source audit remains in scratch `kasaran-phase08-exit-map.md`. Financial engine/fixture work now runs independently of inbox and pure replay implementation.

## Task 2: Bound pull transport

Files: `lib/sync/transport/sync_transport.dart`, corresponding transport test.

- [x] Add optional `SyncSessionBinding? requiredSession` to pull admission, matching push; preserve existing API and all freshness guards.
- [x] Execute failing tests before implementation for mismatched user/marker, matching pull and replacement during HTTP. Verify no mismatched HTTP request and exact admitted envelope.

RED: focused transport compile failed because pull had no `requiredSession`. GREEN: all 35 protocol/transport tests pass, including four new matching-envelope/mismatched-user/mismatched-marker/in-flight-replacement cases; scoped analysis clean. Exit audit, encrypted inbox and disjoint pure replay workers are active. No phase completion claim.

## Task 3: v3 encrypted incoming log and single-page pull

Files: `lib/data/db/schema.drift`, `app_database.dart`, generated part via isolated tool; encrypted opener support floor; necessary migration/legacy fixture adaptations; new `lib/sync/queue/durable_inbox_puller.dart`, queue tests and tagged actual Edge test.

- [ ] Read real pinned generator/opener/migration/coordinator/writer paths. Write report before edits.
- [ ] RED real encrypted v2 fixture preserving sentinel/original key/outbox/cursors, then minimal v3 inbox migration GREEN. Inject upgrade failure and prove old version/data usable.
- [ ] RED one real HTTP accepted-page/cursor atomic reopen path, implement `DurableInboxPuller(coordinator, transport).pullOnce(actor,{limit=100})`, GREEN.
- [ ] Add individual RED/GREEN cases for unknown/raw fields, duplicates/conflicting stamps, exact integer values, stale concurrent cursors, membership/session/transport mismatch, empty pages and local rollback; preserve all unrelated state.
- [ ] Pause actual COMMIT during account switches and failure; prove original-store drain and no cross-account publication. Test original outbox entries are not removed on pull.
- [ ] Actual disposable Edge push then pull into second encrypted account/device; restart and verify durable unknown-safe page/cursor. No simulated server acceptance claim.
- [ ] Strict focused analysis/format, full affected encrypted/legacy tests and exact report.

## Task 4: Deterministic replay and atomic rebuild

- [ ] Use exit audit to enumerate supported entity snapshots/fields/groups/parents and required pair atomicity; validate against canonical design rather than invented names.
- [ ] Tests-first pure accepted replay sorted by full ordering key, field/group LWW, typed stale conflicts, full creates, tombstones/Restore and parent gates; retain losing/unknown history.
- [ ] Combine durable inbox and local originals without duplicate ID application; overlay only matching unsynced device writes, preserve unknown dependencies and source validation.
- [ ] Transactional ledger/entity projection rebuild with rollback/reopen/upgrade failure evidence and two-device convergence across alternate arrivals.

## Task 5: Automatic worker and complete exit coverage

- [ ] Account/session-bound bounded push/pull scheduling on foreground/reconnect/debounced local writes; cancellation and safe pending/error/update-required state.
- [ ] Integrate only after migration/replay review; never enable startup against incomplete projection semantics or unavailable account storage.
- [ ] Implement missing required entity/pair/engine assertions from audit; report any prerequisite that cannot be satisfied rather than fabricate a phase pass.
- [ ] Independently review each dependency and complete engine integration; fix concrete findings with regressions and re-review.
- [ ] Execute full service-free tests with services stopped, strict analysis/format/diff/build, actual CI/service/convergence/migration suites; update docs and explicit exit matrix. Preserve volumes and unrelated work.

## Interrupted work recovered — 2026-10-22

All three implementation workers stopped after provider limits, leaving real partial source. The parent recovered the actual files rather than restarting or accepting their old status. Their reports had been written into an unintended repository `scratch/` directory; all worker artifacts were preserved outside the repository in the restricted agent cache without reading or exposing service-status credentials.

Fresh recovery verification executed **463 named service-free tests with zero failures and zero skips**. Strict full analysis still identified **38 informational diagnostics** across the unfinished financial/inbox/test code. The standalone ledger reducer was formatted and independently executed **19 passing tests**, with clean scoped analysis. It is now under read-only independent review. The financial recovery worker owns finishing its source/test validation and linting; the inbox recovery worker owns final migration/pull checks and real Edge interoperability.

An unfinished tagged inbox test was discovered in the prior outbox E2E file. It attempted to push a future entity/schema through the ledger-only server and therefore cannot establish a passing Edge result. Recovery must preserve correct server refusal and test compatible additive retention or explicitly trusted synthetic historical rows, rather than weaken validation. No claim of completed v3/inbox/financial/replay acceptance or full phase exit is made at this checkpoint.

After these interrupted dependencies are verified, the full-exit matrix still requires atomic projection rebuild integrated with retained inbox and pending originals, bootstrap/automatic scheduling, remaining entity/writer/RLS and payment-pair foundations, all-entity financial convergence/compatibility tests, and actual native prerequisite evidence. Pure reducer/financial fixtures alone do not satisfy those integration assertions.

Independent replay review blocks approval on an actual wire identity mismatch: PostgreSQL pull normalizes the original event envelope's three-digit timestamp to six digits, while acknowledged-local/inbox and pending/inbox reconciliation compares source identity strictly. The correction must preserve original source envelopes in a forward migration and explicitly test any narrow compatibility for already-retained equivalent timestamp representations; changed instants, payloads or assigned stamps must still fail. A separate fixer owns this finding; the passing 19-test pure suite did not establish real producer interoperability.

## Continuation checkpoint — inbox and replay reviewed

The preceding recovery and blocking-review entries are historical checkpoints. Encrypted inbox recovery subsequently passed 181 focused tests and independent schema/security review. Additional native COMMIT rejection and encrypted-reopen assertions address the review's evidence limitations. The timestamp-wire defect is corrected by additive server migration `0006_preserve_sync_source_envelopes.sql`, narrow legacy padding compatibility and immutable retained-envelope audit output. The corrected pure ledger slice passed 23 tests and independent final spec/security review. The parent executed all 25 named live contract/sync/tenant tests without failures or skips, including three durable outbox/inbox cases and the real replay wire regression. These do not establish durable materialized convergence.

Financial review found four reproducible issues despite matching all nine canonical fixture scenarios. Corrections now have observed RED/GREEN evidence for orphan direct-pair support, exposed invalid plan operands, church-aircon singleton cardinality and exact baseline summation. The parent reran all 109 domain tests successfully and full strict analysis with no findings. Independent financial rereview is pending; the financial dependency is not yet closed.

The subsequent independent financial rereview approves the current pure-domain source for spec and quality, with no actionable findings. Its fresh native probe independently matched all nine canonical scenarios, resolved the four counterexamples and preserved exact large-integer behavior; all five fixture JSON files match the original snapshot byte-for-byte. The reviewer could not locate the four requested final frozen diff artifacts, so approval applies to the current source actually inspected, not those unavailable artifacts. The pure financial dependency is reviewed; persisted adapters and full-phase acceptance remain outstanding.

The next approved integration task implements an explicit counted-account-leased atomic ledger projection rebuild over retained inbox and local originals. Its scope is a durable bridge, not automatic startup or all-entity phase exit. Automatic scheduling remains unwired until the integration passes review. The separate CI-script rerun previously timed out awaiting approval and did not execute; do not count the hand-written live suite as verification of that exact workflow script.

## Durable ledger bridge reviewed

`DurableProjectionRebuilder(coordinator).rebuild(actor)` now performs retained accepted/local/pending reconciliation and plan-scoped ledger replacement in one encrypted SQLite transaction under a counted account lease. Independent review found a missing-create refusal discrepancy; the correction now rejects supported orphan updates with `incomplete_history` before any projection mutation, while compatible unknown history remains raw attention. Two encrypted refusal regressions and all six arrival permutations cover refusal until creation history arrives, then exact convergence. Final independent spec and quality/security review passes without blocking findings. The corrected suite has 59 rebuilder tests and 163 focused queue/replay tests. The parent executed 577 named service-free tests with zero failures/skips and full strict analysis with no issues. An earlier incorrectly tagged parent command also attempted service-backed cases and failed their service preconditions; only the corrected `--exclude-tags local_supabase` run establishes this service-free count.

The next dependency builds account/session-bound bounded orchestration over the reviewed durable services. Production startup, authoritative second-device metadata bootstrap, app lifecycle/connectivity/writer wiring, broader entities/payment pairs, full live convergence and native prerequisites remain separate acceptance items. The worker core must be tested and independently reviewed before production wiring.

## Scheduling core reviewed

The explicit `AccountSyncWorker` now composes the actual durable services in serialized bounded cycles with debounce, continuation, capped retry and terminal update/error latches. Independent review reproduced status-listener reentrancy and observer-dependent disposal defects. Both repairs have observed RED/GREEN evidence, including per-subscriber stale-delivery guards and native COMMIT draining without waiting for a paused observer to consume stream termination. Final independent spec and quality/security review passes; its frozen source/test snapshots match current files. Recorded coverage is 37 worker tests and 200 queue/replay tests; the parent reran all 37 worker tests and full strict analysis successfully. The earlier full-app checkpoint of 604 service-free tests and Android debug build predates the ten observer regressions and is not a newer full-suite claim.

Authorized initial metadata bootstrap is the next dependency. Its explicit adapter/RPC and encrypted publication are being implemented before automatic production wiring. The exact disposable local stack was verified running and handed exclusively to that worker for guarded additive migration and synthetic live tests. No hosted or real-user operations are authorized, and retained volumes must be preserved.

## Interrupted bootstrap recovery

The bootstrap worker was interrupted after applying additive server migration 0007 and executing initial Edge evidence. The parent recovered actual files and reran 57 bootstrap transport/local tests, 13 Python backend cases and 26 serial live Dart contract/sync/tenant assertions successfully. The new bootstrap case proves authoritative metadata publication into initially empty encrypted account files, then actual worker-driven ledger source equality and encrypted reopen without hand-seeded local membership. Its hard-coded development workdir was corrected to required environment selection plus the exact disposable project-ID guard and rerun successfully. Installed 0007 body/ACL and all seven migration copies were verified; the exact disposable stack is stopped with both volumes preserved.

Independent bootstrap backend spec/security review passes with no blocking findings. Bootstrap-specific lock-wait race coverage, an accepted-partner fixture and duplicated Edge forwarding maintenance are recorded non-blocking limitations, not inferred execution. Client source/unit lint recovery remains active; 36 strict-analysis diagnostics at recovery admission prevent claiming the complete dependency clean. Client independent review and production wiring remain pending.

## Bootstrap, device identity and host recovery checkpoint

Bootstrap client cleanup subsequently passed 67 tests and independent client review with no blocking findings. The parent executed 681 service-free tests, full strict analysis and an Android debug build successfully at that checkpoint. Late socket setup and malformed update-response supplemental probes passed independently; maintained coverage suggestions remain recorded in the client review.

Stable installation device identity review found that current-account-only creation could mask unopened account A's original-device queue after key loss during pristine B admission. The corrected absent-key path now requires a real sole-account registry/filesystem proof, leased-path validation and a registry lock held through retained-history inspection and secure write/readback. Its 69 device/registry tests passed in parent execution; final independent spec/security review approves the correction. No absent-key creation without that proof is authorized. Isolate/process, quiescent-writer and native persistence limitations remain explicit.

The interrupted session-host/local-plan work was recovered in place after disk exhaustion stopped its worker. Storage was later rechecked with sufficient free space; the parent performed no cleanup. The recovered host now has 52 tests and the finite encrypted-local plan reader has 18 tests; 422 focused regressions pass according to the recovery report. The parent executed 803 named service-free tests with zero failures/skips or Drift warnings, full strict analysis with no findings, diff checks and unchanged dependency pins. Independent host/local-plan review is pending. Production root, lifecycle, writer/provider and router wiring remain absent; the foreground 30-second periodic policy is not an OS connectivity-event claim. Broader entities, sponsor pairs and complete phase/native acceptance remain open.
