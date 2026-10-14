# Phase 07 Local Ledger Writer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver ADR-78's plan-scoped encrypted-local ledger repository and atomic projection/event/outbox writer, without network transport.

**Architecture:** Typed Drift `LedgerEntry` snapshots and `LedgerEntriesCompanion` patches feed a writer that verifies local plan/member/alias, validates the complete resulting row, and commits projection, immutable event content, outbox, and device counter in one Drift transaction. Repository exposes only scoped reads and create/edit/delete; an injectable UTC clock and cryptographic UUIDv7 source control attribution.

**Tech Stack:** Flutter/Dart, Drift v2, SQLCipher-backed native SQLite, flutter_test.

## Global Constraints

- Do not change applied schema/migrations, remote data, or hosted environments.
- Money is signed int64 integer centavos; event payload schema_version=1, distinct from local file version 2.
- Source fields only; no inferred price/status, HTTP client, server timestamp, or pull cursor.
- Last-known local membership is not remote authorization. Phase 07 exit and Phase 08 transport remain pending.

---

### Task 1: Typed read and create tracer

**Files:** Create `lib/data/repositories/ledger_repository.dart`, `lib/data/changelog/local_ledger_writer.dart`, `test/data/repositories/ledger_repository_test.dart`.

**Interfaces:** `LedgerRepository(AppDatabase, {LocalLedgerWriter? writer})`, `listLive(planId)`, `create(LedgerActor, LedgerDraft)`; writer accepts injectable `String Function()` UUIDv7 and `DateTime Function()` UTC clock. `LedgerActor` carries planId/userId/planMemberId/deviceId. `LedgerDraft` contains category, subtype, supplier, mode, cents, notes, provenance.

- [ ] Write an encrypted create/reopen test: seed local plan, alias and member; create with 9007199254740991 cents; assert typed row, full `$create` JSON including nulls, pending outbox and counter 1, then reopen and assert same values.
- [ ] Run `flutter test test/data/repositories/ledger_repository_test.dart -r expanded` and confirm missing repository symbols fail compilation.
- [ ] Add minimal typed repository, validation, UUIDv7 source, transaction, projection insert, event insert, outbox insert, counter increment.
- [ ] Run the same focused command and confirm pass before expanding behavior.

### Task 2: Edits, grouped mode and tombstone

**Files:** Modify `lib/data/repositories/ledger_repository.dart`, `lib/data/changelog/local_ledger_writer.dart`, `test/data/repositories/ledger_repository_test.dart`.

**Interfaces:** `edit(LedgerActor, entryId, LedgerEntriesCompanion patch)` (patch permits only source fields); `delete(LedgerActor, entryId)`; query `listLive(planId)` excludes tombstones. Reject an immutable-field patch rather than silently ignoring it.

- [ ] Add tests for independent supplier/notes/actual edits, no-op, null values, and stable increasing counters; run focused test and observe missing behavior.
- [ ] Implement full-row validation and one event per changed ordinary field in deterministic field order, then rerun focused test green.
- [ ] Add test for flat→per-head mode/rate grouped old/new snapshot plus separate estimate event; run red, implement coherent update, rerun green.
- [ ] Add test for tombstone retained in projection/history, hidden from live reads and repeated delete no-op; run red, implement, rerun green.

### Task 3: Authorization, failures, and offline regression

**Files:** Modify `test/data/repositories/ledger_repository_test.dart`, `lib/data/changelog/local_ledger_writer.dart` as required.

- [ ] Write and run failing tests for missing/revoked/cross-plan membership, foreign-plan entry, malformed entire resulting row, and ID collision occurring after projection/counter mutation; assert unchanged row/log/outbox/counter.
- [ ] Make validation and transactional rollback pass; rerun targeted suite.
- [ ] Test offline read/write in `HttpOverrides.runZoned` rejecting all client creation; exercise encrypted reopen, not only an in-memory connection.
- [ ] Run `dart format` on changed Dart paths, `flutter analyze`, and `flutter test --exclude-tags=local_supabase --reporter expanded` while Supabase is stopped. Full service-backed tests require a separately identified disposable stack; do not reset retained data. Review diff and commit only verified bounded changes.

**Self-review:** Covers design's create, independent/grouped edit, delete, UUIDv7, counter, local checks, collision rollback and offline reopen. Remote group acceptance, membership revalidation and phase exit are explicitly deferred. No placeholders or schema changes.
