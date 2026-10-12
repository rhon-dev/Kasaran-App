# Phase 07 Core Schema and RLS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver ADR-77's first, synthetic-local Phase 07 schema slice: two new protected server tables, matching encrypted local plan/ledger/log/device tables, and executable migration/isolation tests.

**Architecture:** Extend `0001` only with an additive `0002` for server ledger and log, both read-only to authenticated plan members and immutable where required. Generate typed Drift tables from a local SQL schema at version 2, using the already fail-closed encrypted opener. Validate schema and authentication via real local Supabase, and validate local migration on encrypted files; neither path talks to hosted projects.

**Tech Stack:** Supabase local CLI/Postgres/PostgREST/Auth; Dart/Flutter tests; pinned app `drift` 2.35.1 and `sqlite3` 3.5.0 with sqlite3mc; **isolated Dart-only code generator** with `drift_dev` 2.35.1 / `build_runner` 2.16.2; GitHub Actions existing tenant-isolation job.

## Global Constraints

- Read the approved `docs/superpowers/specs/2026-10-12-phase-07-core-schema-rls-design.md`, ADR-77, `docs/design.md` §4.1/4.4/4.6, `docs/requirements.md` REQ-LG-1, and `docs/development-phases.md` Phase 07 before each affected task. No new product behavior or ID renumbering. `0001_identity_and_access.sql` remains unchanged.
- No hosted `db push`, migration, `config push`, billing, real data, account-deletion outcome, payment rail, ruleset cost, legal checklist date, sync endpoint, or plan-setup UI persistence. PR #16's Phase 04 evidence is already merged, not a dependency. Preserve local Supabase volumes with plain `supabase stop`; never reset the user's retained stack.
- Money is signed int64 centavos; all ratios use integer basis points. Do not add a remote ruleset/category table or foreign key to an unpublished asset. Stable six category codes only. No derived money/status, stored conflict flag, or synthetic benchmark.
- Add forced RLS and membership policy **with** each server table. Direct clients cannot mutate them. Server service-role material stays in local test process memory, not repo, stdout, failure messages, or app. Synthetic identities are cleaned up. Tests that cannot run are blocked, never counted PASS.
- Only claim the ledger/log subset of TC-SEC-01/04/05/06, TC-MIG-01/02 and TC-SE-26 when actually executed; full Phase 07, full tenant matrix, writer/queue, and hosted CI gates remain open. Review v1 four tests: deterministic, explainable, no money movement, no supplier recommendation.

## File map

- `supabase/migrations/0002_core_schema.sql`: additive ledger/log constraints, authorization grants/policies, immutability trigger, indexes; no existing table rewrite.
- `test/api/tenant_isolation/core_schema_isolation_test.dart`: real local two-account/two-plan REST and privileged immutability tests, policy inventory; no hard-coded secrets.
- `lib/data/db/schema.drift`: typed SQLite plan/member/alias, ledger, raw log, sync state and outbox tables with integer money and foreign keys.
- `lib/data/db/app_database.dart` and generated `lib/data/db/app_database.g.dart`: Drift-generated schema version 2, atomic upgrade, fail-closed future-version behavior.
- `tool/drift_codegen/pubspec.yaml`, `tool/drift_codegen/.gitignore`, `tool/drift_codegen/generate.sh`: reproducible isolated code generation without changing the Flutter app's `pubspec.yaml` or `pubspec.lock`. `tool/drift_codegen/pubspec.lock` is committed after generation.
- `test/data/db/schema_version_test.dart`, `test/data/db/encrypted_database_test.dart`, `test/data/db/core_schema_test.dart`: update v1 expectation and add encrypted upgrade/constraints/round-trip tests.
- `.github/workflows/ci.yml`: make the existing tenant job execute the new subset without a skip; do not replace its required future forged-pull check with a pretend PASS.
- `docs/development-phases.md`, `docs/testing-plan.md`, `docs/security-plan.md`: describe observed subset, policy/privacy inventory and remaining gates, without modifying REQ/TC/SEC IDs.

---

### Task 1: Server ledger and log schema, protected from the first migration

**Interfaces:** Consumes `public.plans(id)`, `public.plan_member_aliases(plan_id,plan_member_id)` and `public.identity_member(uuid)` from migration `0001`. Produces `ledger_entries` and append-only `change_log` with indexed plan-scoped reads. No client write API.

**Files:** Create `supabase/migrations/0002_core_schema.sql`; test `test/api/tenant_isolation/core_schema_isolation_test.dart` (Task 2).

- [ ] **Step 1 — RED:** Start only a **fresh disposable** local Supabase stack under a separate project ID, or run a read-only preflight against a preserved stack and apply new migration forward without reset. Write the first `core_schema_isolation_test.dart` test to query local PostgREST `ledger_entries` as a verified synthetic member and assert a non-error response. Obtain local URL/keys dynamically from `supabase status -o json`, parse in memory, do not print the response or credentials. Run `flutter test --no-pub test/api/tenant_isolation/core_schema_isolation_test.dart --plain-name 'own ledger read'`; expected FAIL with missing relation. Do not mark it skipped when local services are unavailable.
- [ ] **Step 2 — GREEN:** Write `0002_core_schema.sql` with complete fields from §4.4 and §4.6: `ledger_entries(id uuid PK, plan_id FK, category_code constrained to catering_venue/photo_video/attire_styling/coordination/entourage_misc/buffer, entry_type constrained to standard/crew_meals/oot_fees/church_aircon/corkage/overtime/venue_power, supplier_name length 1..200 after trim, estimated_cents bigint, actual_cents bigint, pricing_mode per_head/flat, per_head_rate_cents bigint, manually_valued boolean default false, notes text <=2000, template_suggestion_id, checklist_item_id, created_at timestamptz, deleted_at timestamptz)`; `(flat AND estimated_cents >= 0 AND rate IS NULL) OR (per_head AND estimated_cents IS NULL AND rate >= 0)`, actual nullable or >=0. `change_log(id uuid PK, plan_id FK, entity_type, entity_id, field_name, change_group_id, schema_version >0, old_value jsonb, new_value jsonb, server_ts bigint nullable, device_monotonic bigint >=0, device_id uuid, plan_member_id uuid, created_at timestamptz)` with composite `(plan_id,plan_member_id)` FK to aliases. Add plan/category and field-order indexes. Use an immutable trigger whose function unconditionally raises on update or delete. `ENABLE` **and** `FORCE` RLS on both; `SELECT ... USING (public.identity_member(plan_id)) TO authenticated`; revoke table mutations from public/anon/authenticated and grant only select to authenticated. Keep RLS and grants inside this migration, not a later PR.
  Core SQL to put in the migration (adapt only syntax failures shown by RED; never relax authorization):

  ```sql
  create table public.ledger_entries (
    id uuid primary key, plan_id uuid not null references public.plans(id),
    category_code text not null check (category_code in
      ('catering_venue','photo_video','attire_styling','coordination','entourage_misc','buffer')),
    entry_type text not null check (entry_type in
      ('standard','crew_meals','oot_fees','church_aircon','corkage','overtime','venue_power')),
    supplier_name text not null check (char_length(btrim(supplier_name)) between 1 and 200),
    estimated_cents bigint, actual_cents bigint check (actual_cents >= 0),
    pricing_mode text not null check (pricing_mode in ('flat','per_head')),
    per_head_rate_cents bigint, manually_valued boolean not null default false,
    notes text check (char_length(notes) <= 2000),
    template_suggestion_id text, checklist_item_id text,
    created_at timestamptz not null, deleted_at timestamptz,
    check ((pricing_mode='flat' and estimated_cents is not null
      and estimated_cents >= 0 and per_head_rate_cents is null)
      or (pricing_mode='per_head' and estimated_cents is null
      and per_head_rate_cents is not null and per_head_rate_cents >= 0))
  );
  create index ledger_entries_plan_idx on public.ledger_entries(plan_id,id);
  create table public.change_log (
    id uuid primary key, plan_id uuid not null references public.plans(id),
    entity_type text not null check (length(entity_type)>0),
    entity_id uuid not null, field_name text not null check (length(field_name)>0),
    change_group_id uuid, schema_version integer not null check (schema_version>0),
    old_value jsonb, new_value jsonb, server_ts bigint,
    device_monotonic bigint not null check (device_monotonic>=0),
    device_id uuid not null, plan_member_id uuid not null,
    created_at timestamptz not null,
    foreign key (plan_id,plan_member_id)
      references public.plan_member_aliases(plan_id,plan_member_id)
  );
  create index change_log_field_idx on public.change_log
    (plan_id,entity_type,entity_id,field_name,server_ts desc,device_monotonic desc,device_id desc);
  create function public.reject_change_log_mutation() returns trigger
    language plpgsql set search_path = '' as $$
  begin raise exception 'change log is immutable'; end; $$;
  create trigger reject_change_log_mutation before update or delete on public.change_log
    for each row execute function public.reject_change_log_mutation();
  alter table public.ledger_entries enable row level security;
  alter table public.ledger_entries force row level security;
  alter table public.change_log enable row level security;
  alter table public.change_log force row level security;
  create policy ledger_member_read on public.ledger_entries
    for select to authenticated using (public.identity_member(plan_id));
  create policy log_member_read on public.change_log
    for select to authenticated using (public.identity_member(plan_id));
  revoke all on public.ledger_entries,public.change_log from public,anon,authenticated;
  grant select on public.ledger_entries,public.change_log to authenticated;
  revoke all on function public.reject_change_log_mutation() from public,anon,authenticated;
  ```

- [ ] **Step 3 — Verify GREEN:** Apply only to local/disposable development DB. Run the focused own-read test; expected success and no skip. Run `supabase migration list --local` (do not print local connection strings) and assert `0001` plus `0002` applied. If startup fails, fix the local setup rather than weakening RLS or going hosted. Commit `feat(db): add protected core ledger and log schema` after a clean `git diff --check`.

### Task 2: Executable tenant/security negative matrix (server subset)

**Interfaces:** Test against Task 1's migrations. Provision two unique synthetic verified Auth users, use existing `create_plan` RPC (with distinct valid UUIDv7 plan IDs) and seed two ledger/log rows with a local service-role test client. Delete created accounts/rows in `tearDownAll` or use an isolated disposable stack. Do not use hosted keys. Expected foreign and nonexistent reads: identical empty/404 behavior.

**Files:** Complete `test/api/tenant_isolation/core_schema_isolation_test.dart`; keep `.github/workflows/ci.yml`'s future forged-pull condition explicit while adding the core subset as its own blocking job.

- [ ] **Step 1 — RED:** Add a test named `cross-tenant read hides foreign ledger and log rows` that uses A/B access tokens to GET each table filtered by B's plan, then compares its status/body shape with a nonexistent plan and asserts A sees no B rows. Before fixture seeding, it must fail because the own-row precondition is absent (not pass vacuously). Add distinct tests for `cross-tenant write denies forged plan and alias`, `cross-tenant delete denies foreign rows`, `removed member loses ledger and log read`, `privileged log update and delete rejected`, and `policy catalog covers every public plan-scoped table`. For each, first verify the fixture/precondition that proves the assertion can fail. Run the focused test after writing it and observe the expected failure before making the fixture/policy behavior green. Never check in a key or print full HTTP responses on assertion failure.
- [ ] **Step 2 — GREEN:** Seed via the local Auth admin and REST service-role routes; obtain tokens by password grant. Use `try/finally` cleanup. Query Postgres catalogs with a test-only direct local DB session or a disposable SQL assertion file: for every public base table with a `plan_id` column, require `relrowsecurity=true`, `relforcerowsecurity=true` and an authenticated SELECT policy tied to membership. Include existing `plans`, `plan_members`, `plan_member_aliases`, `invites` and new `ledger_entries`, `change_log`; `users` has self-only RLS and is checked separately. To verify privileged immutability, attempt UPDATE and DELETE on the log using the local service-role route, assert denial and the original row unchanged. Check direct unauthenticated and authenticated mutation denials on both new tables; no forged alias/plan binding may insert via trusted fixture path.
- [ ] **Step 3 — Verify GREEN:** Run `flutter test --no-pub test/api/tenant_isolation/ --reporter=json` against local Supabase; parse all non-hidden `testDone` events and require zero skips/fails plus expected case names. The existing CI job currently requires the older `forged plan_id pull` case, which is Phase 08; **do not remove that gate merely to make CI green**. If it prevents a bounded subset from running as a separate gate, add a distinct blocking core-schema sub-job and leave the full tenant job's future condition explicit rather than claiming the future API passed. Stop the disposable local stack with plain `supabase stop`. Commit `test(security): exercise core two-plan isolation`.

### Task 3: Typed encrypted local v2 schema and migration

**Interfaces:** `AppDatabase` retains constructor `AppDatabase(super.executor)` so `EncryptedDatabaseOpener` remains unchanged. Produced tables are plan-scoped and accessed only from the encrypted database. No repository writer/transport.

**Files:** `lib/data/db/schema.drift`, `lib/data/db/app_database.dart`, generated `lib/data/db/app_database.g.dart`, `tool/drift_codegen/pubspec.yaml`, `tool/drift_codegen/pubspec.lock`, `tool/drift_codegen/generate.sh`; tests in Task 4.

- [ ] **Step 1 — RED:** Change `test/data/db/schema_version_test.dart` to expect schemaVersion 2, actual plan/alias/member/ledger/log/sync-state/outbox tables, and no FLOAT/REAL money columns. Run `flutter test --no-pub test/data/db/schema_version_test.dart`; expected failure at version 1/empty table list.
- [ ] **Step 2 — GREEN:** Do **not** add `drift_dev` to the Flutter app: a real `flutter pub add --dev drift_dev:2.35.1 build_runner:^2.10.0 --dry-run` failed because Flutter 3.41.6 pins `test_api` 0.7.10 while its `test` graph needs analyzer <11 and `drift_dev` requires analyzer 13–14. Downgrading `drift_dev` below 2.35 conflicts with pinned runtime `drift` 2.35.1. An isolated Dart-only probe using `drift: 2.35.1`, `drift_dev: 2.35.1`, `build_runner: ^2.16.1` resolved and generated `@DriftDatabase(include: {'schema.drift'})` successfully. Commit that tool package and a safe generator script which copies **exact** `app_database.dart` and `schema.drift` into its own `lib/`, runs `dart pub get` and `dart run build_runner build`, then copies generated `app_database.g.dart` into the app. Keep copied tool `lib/` build outputs ignored; run generation twice and compare bytes for reproducibility. The generated part has `part of 'app_database.dart'` and no package-specific import.
  A scratch-only isolated generator probe parsed the seven-table `schema.drift`, generated `app_database.g.dart`, passed `dart analyze`, and opened an in-memory Drift DB with seven tables at `user_version=2`. That is feasibility evidence for code generation, **not** an encrypted upgrade, RLS or implementation test. `tool/drift_codegen/pubspec.yaml`:

  ```yaml
  name: kasaran_drift_codegen
  publish_to: none
  environment:
    sdk: ^3.11.4
  dependencies:
    drift: 2.35.1
  dev_dependencies:
    drift_dev: 2.35.1
    build_runner: 2.16.2
  ```

  `tool/drift_codegen/.gitignore`:

  ```gitignore
  /lib/
  /.dart_tool/
  /build/
  ```

  `tool/drift_codegen/generate.sh` (execute with `bash tool/drift_codegen/generate.sh`):

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  root="$(cd "$(dirname "$0")/../.." && pwd)"
  tool="$root/tool/drift_codegen"
  mkdir -p "$tool/lib"
  cp "$root/lib/data/db/app_database.dart" "$tool/lib/app_database.dart"
  cp "$root/lib/data/db/schema.drift" "$tool/lib/schema.drift"
  (cd "$tool" && dart pub get >/dev/null && dart run build_runner build)
  cp "$tool/lib/app_database.g.dart" "$root/lib/data/db/app_database.g.dart"
  ```

- [ ] **Step 3 — GREEN:** Use a generated Drift database (`part 'app_database.g.dart'; @DriftDatabase(include: {'schema.drift'})`) with `schemaVersion => 2`. In `schema.drift`, define the seven named tables from the design with primary keys and foreign keys: plans, aliases, members, ledger_entries, change_log, sync_state, outbox. Mirror existing plan source fields and live alias/membership keys; raw log JSON is lossless TEXT, nullable server stamp, and outbox references an event ID. Use INTEGER cents/counters and explicit nullable fields. Add SQLite CHECKs for six categories, entry subtypes, flat/per-head coherence, supplier length, notes length, and nonnegative amounts. No stored derived/payment fields. Enable `PRAGMA foreign_keys=ON` before open and use a versioned `MigrationStrategy`: `onCreate => m.createAll()`, `onUpgrade(from=1,to=2) => m.createAll()` because v1 had no application tables; reject every other version transition explicitly. Reject a SQLite `user_version > 2` **before Drift modifies the file** on open. Do not replace SQLCipher with plaintext.
  `lib/data/db/app_database.dart` starting point (imported by the isolated tool unchanged):

  ```dart
  import 'package:drift/drift.dart';
  part 'app_database.g.dart';

  @DriftDatabase(include: {'schema.drift'})
  class AppDatabase extends _$AppDatabase {
    AppDatabase(super.executor);
    @override
    int get schemaVersion => 2;
    @override
    MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from != 1 || to != 2) {
          throw StateError('Unsupported local schema transition');
        }
        await transaction(() => m.createAll());
      },
      beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
    );
  }
  ```

  `lib/data/db/schema.drift` must name the seven tables exactly and include these complete source columns; dates/times are stored as ISO strings, UUIDs as canonical TEXT, booleans as constrained INTEGER, and raw JSON as TEXT (do not coerce unknown events):

  ```sql
  CREATE TABLE plans (
    id TEXT NOT NULL PRIMARY KEY, creator_user_id TEXT NOT NULL,
    wedding_date TEXT NOT NULL, total_budget_cents INTEGER NOT NULL CHECK (total_budget_cents > 0),
    guest_cap INTEGER NOT NULL CHECK (guest_cap >= 0), region_code TEXT NOT NULL,
    ceremony_type TEXT, venue_type TEXT,
    reminder_enabled INTEGER NOT NULL DEFAULT 1 CHECK (reminder_enabled IN (0,1)),
    reminder_window_days INTEGER NOT NULL DEFAULT 7 CHECK (reminder_window_days >= 0),
    reminder_days_before TEXT NOT NULL DEFAULT '[7,1]',
    reminder_overdue INTEGER NOT NULL DEFAULT 1 CHECK (reminder_overdue IN (0,1)),
    ruleset_version TEXT NOT NULL, driving_rsvp_status TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    setup_completed_at TEXT, created_at TEXT NOT NULL, deleted_at TEXT
  );
  CREATE TABLE plan_member_aliases (
    plan_member_id TEXT NOT NULL PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
    user_id TEXT, UNIQUE(plan_id,plan_member_id), UNIQUE(plan_id,user_id,plan_member_id)
  );
  CREATE TABLE plan_members (
    plan_id TEXT NOT NULL REFERENCES plans(id), user_id TEXT NOT NULL,
    plan_member_id TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('creator','partner')),
    joined_at TEXT NOT NULL, PRIMARY KEY(plan_id,user_id),
    FOREIGN KEY(plan_id,user_id,plan_member_id)
      REFERENCES plan_member_aliases(plan_id,user_id,plan_member_id)
  );
  CREATE TABLE ledger_entries (
    id TEXT NOT NULL PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
    category_code TEXT NOT NULL CHECK (category_code IN
      ('catering_venue','photo_video','attire_styling','coordination','entourage_misc','buffer')),
    entry_type TEXT NOT NULL CHECK (entry_type IN
      ('standard','crew_meals','oot_fees','church_aircon','corkage','overtime','venue_power')),
    supplier_name TEXT NOT NULL CHECK (length(trim(supplier_name)) BETWEEN 1 AND 200),
    estimated_cents INTEGER, actual_cents INTEGER CHECK (actual_cents >= 0),
    pricing_mode TEXT NOT NULL CHECK (pricing_mode IN ('flat','per_head')),
    per_head_rate_cents INTEGER, manually_valued INTEGER NOT NULL DEFAULT 0
      CHECK (manually_valued IN (0,1)),
    notes TEXT CHECK (length(notes)<=2000),
    template_suggestion_id TEXT, checklist_item_id TEXT,
    created_at TEXT NOT NULL, deleted_at TEXT,
    CHECK ((pricing_mode='flat' AND estimated_cents IS NOT NULL
      AND estimated_cents >= 0 AND per_head_rate_cents IS NULL)
      OR (pricing_mode='per_head' AND estimated_cents IS NULL
      AND per_head_rate_cents IS NOT NULL AND per_head_rate_cents >= 0))
  );
  CREATE TABLE change_log (
    id TEXT NOT NULL PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
    entity_type TEXT NOT NULL CHECK(length(entity_type)>0), entity_id TEXT NOT NULL,
    field_name TEXT NOT NULL CHECK(length(field_name)>0), change_group_id TEXT,
    schema_version INTEGER NOT NULL CHECK(schema_version>0),
    old_value TEXT, new_value TEXT, server_ts INTEGER,
    device_monotonic INTEGER NOT NULL CHECK(device_monotonic>=0),
    device_id TEXT NOT NULL, plan_member_id TEXT NOT NULL, created_at TEXT NOT NULL,
    FOREIGN KEY(plan_id,plan_member_id)
      REFERENCES plan_member_aliases(plan_id,plan_member_id),
    UNIQUE(id,plan_id)
  );
  CREATE TABLE sync_state (
    device_id TEXT NOT NULL, plan_id TEXT NOT NULL REFERENCES plans(id),
    last_pushed_server_ts INTEGER, last_pulled_server_ts INTEGER,
    device_monotonic INTEGER NOT NULL DEFAULT 0 CHECK(device_monotonic>=0),
    PRIMARY KEY(device_id,plan_id)
  );
  CREATE TABLE outbox (
    event_id TEXT NOT NULL PRIMARY KEY,
    plan_id TEXT NOT NULL REFERENCES plans(id), device_id TEXT NOT NULL,
    queued_at TEXT NOT NULL,
    FOREIGN KEY(event_id,plan_id) REFERENCES change_log(id,plan_id)
  );
  ```

  On the encrypted production opener's raw `NativeDatabase.setup`, after applying the key and **before** Drift can inspect or modify the file, read `PRAGMA user_version` and throw `StateError` when greater than 2. Do not log key or file contents. The v1→v2 path creates only the new tables and must preserve any unrelated existing user table. Do not add a plaintext fallback.

- [ ] **Step 4 — Verify GREEN:** Re-run focused schema test; expected table inventory/version pass. Check generated file is committed, analyzer clean, and neither Flutter app package file changed. Commit `feat(db): add encrypted local core schema v2`.

### Task 4: Local upgrade, preservation and constraint tests

**Interfaces:** Uses Task 3's `AppDatabase` and `EncryptedDatabaseOpener` with an in-memory test key store. Test files are deleted only under their own disposable test directory.

**Files:** Add `test/data/db/core_schema_test.dart`; extend `test/data/db/encrypted_database_test.dart` and `test/data/db/schema_version_test.dart`.

- [ ] **Step 1 — RED:** Create a v1 encrypted database fixture at a unique temporary file with its original key and `PRAGMA user_version=1`, plus an unrelated sentinel row. Open through v2 and assert the sentinel is intact and v2 tables exist; first run fails until migration logic handles the file. Add a second test inserting two synthetic plan IDs, aliases, one ledger value at a large exact int64 centavo magnitude, a raw typed log JSON string, and a pending outbox reference; close and reopen with the same key, then assert exact value, JSON bytes and queue identity. Test a foreign alias/log FK failure, negative amount failure, and a newer schema version rejection without file writes. Use SQLite foreign keys, never a synthetic plaintext production opener.
- [ ] **Step 2 — GREEN:** Fix only migration/schema defects shown by RED: wrap upgrade in Drift's transaction boundary, enable FK checks, preserve `user_version` and original cipher key, and fail closed on future versions before any write. Avoid destructive recreation. Repeat each focused test until it passes; follow each with full `flutter test --no-pub test/data/db/` and `flutter analyze --no-pub`.
- [ ] **Step 3 — Verify GREEN:** Run the full Flutter suite with local Supabase started only if contract tests require it; count actual successes/skips from JSON output, never call skipped tests PASS. Retain the original local data volumes with plain `supabase stop`. Commit `test(db): verify core schema migration and encrypted reopen`.

### Task 5: CI, privacy inventory and evidence

**Interfaces:** Consumes actual Task 1–4 outputs. Does not convert subset evidence into full release-gate certification.

**Files:** `.github/workflows/ci.yml` as necessary; `docs/development-phases.md`, `docs/testing-plan.md`, `docs/security-plan.md`.

- [ ] **Step 1:** Require non-skipped, non-vacuous local server isolation tests on every PR when migrations exist, while retaining a clearly distinct future forged-pull/full-matrix gate. Inventory new `ledger_entries` and `change_log` in SEC-22/23/24/policy checks and supplier names, notes, old/new payloads in the privacy-data inventory. Search all docs for the previous five-table-only evidence; change only current evidence prose, not historical ADRs or stable IDs. Do not write requirements or UX changes because this sitting introduces no new requirement or screen.
- [ ] **Step 2:** Record exact local test counts, migration/cipher evidence, any CI execution gap and missing Phase 07 entities/writer in `docs/testing-plan.md` and `docs/development-phases.md`. Explicitly distinguish TC-SEC subset from full TC-SEC-01/04/05/06 and TC-SE-26, and migration v1→v2 from full TC-MIG-01…03. Run `git diff --check`, `flutter analyze --no-pub`, the full Flutter suite, and Gitleaks on changed sources/docs. A scan of ignored build-cache files is not a branch finding; never print matches or secrets.
- [ ] **Step 3:** Recheck `origin/main`, head/base, `git status`, local tests, and actual branch diff. Commit with Conventional Commits; push and open/update draft PR to `main`. Read back PR head/base/body and GitHub jobs/step counts. Zero-step failures or skipped jobs are not CI evidence. No hosted Supabase writes, real data, Pro charge or full Phase 07 PASS.
