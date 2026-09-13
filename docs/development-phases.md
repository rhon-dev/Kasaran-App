# Kasaran — Development Phases

**INDEX ONLY.** No phase bodies. Awaiting approval of this index before any phase is written out.

*Inputs: `requirements.md` (54 REQ IDs), `testing-plan.md` (TC IDs), `security-plan.md` (SEC IDs), `agents.md`, `decision-log.md`.*

---

## Phase index — 27 phases

> **⚠ Now one over your 20–26 cap.** Decision 2 (REQ-AI-4 gets its own phase, pulled out of the AI tail) adds phase 25, taking the index to 27. This is a second independent signal that the cap needs revisiting — see §(c), which was already unresolvable within 26.

| # | Name | Owning agent | Depends on | REQ IDs covered | One-line objective | One sitting? |
|---|---|---|---|---|---|---|
| 01 | Repo, tooling & CI skeleton | DevOps/Release | — | REQ-PLT-1 | Flutter repo, Fastlane, lint, and a CI pipeline that runs and fails correctly | yes |
| 02 | Money primitives & formatting | Backend | 01 | REQ-GEN-1, REQ-GEN-2, REQ-GEN-2A | int64 centavo type, presenter chokepoint, full and constrained ₱ forms | yes |
| 03 | Flutter app shell & navigation | Mobile/Frontend | 01 | — | Routable shell with `go_router`, Riverpod wiring, no features | yes |
| 04 | Backend shell: Supabase envs & secrets | DevOps/Release | 01 | — | Staging and prod projects, secret handling, empty `/v1/sync` surface | yes |
| 05 | Local encrypted store | Data & Sync | 03, 04 | REQ-PLT-2 | `drift` + SQLCipher opening, key in Keychain/Keystore, backup-excluded | yes |
| 06 | Shared-account auth & pairing | Security | 04, 05 | REQ-PLT-3, REQ-SE-1 | Accounts, sessions, single active plan, invite/accept pairing | yes |
| 07 | Data layer: entities, repositories, change-log writer | Data & Sync | 05 | — | All v1 tables, repository-only SQL, append-only change-log writer | **no** |
| 08 | Sync engine: transport, ordering, replay, convergence | Data & Sync | 06, 07 | REQ-SE-2, REQ-SE-3, REQ-OF-5 | Push/pull, server-assigned ordering, idempotent replay, convergence | **no** |
| 09 | Budget setup / onboarding | Mobile/Frontend | 02, 07, 08 | REQ-BS-1, REQ-BS-2, REQ-BS-3, REQ-BS-4, REQ-BS-5, REQ-BS-6 | Setup wizard: budget, date, region, cap, and non-destructive editing | **no** |
| 10 | Expense ledger | Mobile/Frontend | 09 | REQ-LG-1, REQ-LG-2, REQ-LG-3, REQ-LG-4, REQ-LG-5, REQ-LG-6 | Entries, CRUD, estimated vs actual, deposits, derived status, variance | **no** |
| 11 | Hidden-fee line items | Mobile/Frontend | 10 | REQ-HF-1, REQ-HF-2, REQ-HF-3 | Six prompted fee types with per-type forms and recorded dismissal | **no** |
| 12 | Guest math | Backend | 10 | REQ-GM-1, REQ-GM-2, REQ-GM-3, REQ-GM-4, REQ-GM-5 | RSVP/tier axes, per-head vs flat, crew separation, propagation, what-if | **no** |
| 13 | Rule-based allocation engine | Backend | 02, 09, 12 | REQ-AE-1, REQ-AE-2, REQ-AE-3, REQ-AE-4, REQ-AE-5, REQ-AE-6 | Deterministic allocation, regional index, overrides, buffer drawdown | **no** |
| 14 | Pledges module | Backend | 10, 13 | REQ-PL-1, REQ-PL-2, REQ-PL-3, REQ-PL-4, REQ-PL-5 | Pledge records, fulfillment-only net reduction, expected and exposure | **no** |
| 15 | Main dashboard (bento) | Mobile/Frontend | 09, 10, 11, 12, 13, 14 | — | Bento layout composing all figures, budget-health card, inert AI tile | yes |
| 16 | Shared-editing, conflict & lifecycle hardening | Data & Sync | 08, 15 | REQ-SE-4, REQ-SE-5, REQ-SE-6 | Visible change log, attribution, mutual removal, ownership transfer | **no** |
| 17 | Offline hardening | Data & Sync | 16 | REQ-OF-1, REQ-OF-2, REQ-OF-3, REQ-OF-4 | Full offline CRUD and computation, indicators, clock handling | **no** |
| 18 | Security hardening & SEC beta gate | Security | 17 | REQ-EX-1 | RLS coverage, at-rest verification, log hygiene, beta-tier SEC gate PASS | **no** |
| 19 | QA execution & RC sign-off | QA | 18 | — | Full suite, fixtures, sync/offline matrices, E2E both platforms, RC signed | **no** |
| 20 | Internal beta (TestFlight + Play internal) | DevOps/Release | 19 | — | Signed builds distributed to internal testers, crash reporting live | **no** |
| 21 | UAT with real couples | Product Manager | 20 | — | Real PH couples plan real weddings; findings triaged into defects | **no** |
| 22 | Production readiness & rollback rehearsal | Production Readiness | 21 | — | Every gate row PASS, restore drill and rollback rehearsed with durations | **no** |
| 23 | Store submission & launch | DevOps/Release | 22 | — | Metadata, labels, demo accounts, review notes, staged rollout to 100% | **no** |
| 24 | Post-launch monitoring & stabilisation | Production Readiness | 23 | — | Alerts observed, P1 response exercised, cost tracked, backlog groomed | **no** |
| 25 | Payments: InstaPay / QR Ph | Backend | 24 | REQ-AI-4 | In-app payment initiation and reconciliation, separate from the ledger's record-of-intent | **no** |
| 26 | AI phase 1: on-device categorisation | AI/ML | 24 | REQ-AI-2 | On-device suggestion behind `CategorySuggester`, suggestions never auto-apply | **no** |
| 27 | AI phase 2: cloud AI reasoning + OCR | AI/ML | 26 | REQ-AI-1, REQ-AI-3, REQ-AI-5 | Cloud advisories, OCR drafts, assistant — all behind documented seams | **no** |

**Phases carrying no REQ IDs** (10 of 27): 03, 04, 07, 15, and 19–24. These are infrastructure, composition, or process phases. Phase 15 (dashboard) integrates figures whose requirements are covered in 09–14 and introduces no new REQ; it is validated against the `ux-spec.md` bento layout and state matrix instead.

---

## Self-validation

### (a) REQ coverage — complete, no orphans, no duplicates

All **54** REQ IDs appear in **exactly one** phase.

| Group | Count | Phase |
|---|---|---|
| REQ-PLT-1 | 1 | 01 |
| REQ-PLT-2 | 1 | 05 |
| REQ-PLT-3 | 1 | 06 |
| REQ-GEN-1, 2, 2A | 3 | 02 |
| REQ-BS-1…6 | 6 | 09 |
| REQ-LG-1…6 | 6 | 10 |
| REQ-HF-1…3 | 3 | 11 |
| REQ-GM-1…5 | 5 | 12 |
| REQ-AE-1…6 | 6 | 13 |
| REQ-PL-1…5 | 5 | 14 |
| REQ-SE-1 | 1 | 06 |
| REQ-SE-2, 3 | 2 | 08 |
| REQ-SE-4, 5, 6 | 3 | 16 |
| REQ-OF-1…4 | 4 | 17 |
| REQ-OF-5 | 1 | 08 |
| REQ-EX-1 | 1 | 18 |
| REQ-AI-4 | 1 | 25 (payments — no longer in the AI tail) |
| REQ-AI-2 | 1 | 26 |
| REQ-AI-1, 3, 5 | 3 | 27 |
| **Total** | **54** | |

**Orphans: none. Duplicates: none.**

Two placement notes worth your eye:

- **REQ-OF-5 sits in phase 08, not 17.** Durable idempotent replay *is* the sync engine's mechanism; the remaining offline requirements (OF-1…4) can only be validated once features exist, so they land in 17.
- **REQ-AI-4 (InstaPay / QR Ph payments) is now phase 25, its own phase, outside the AI tail** (Decision 2, ADR-28). Three consequences recorded here because they cross documents:
  1. **Owner changes from AI/ML to Backend Agent** (with Security as mandatory reviewer). Payments is a financial-rail integration, not inference — it was only ever in the AI tail because it shared the "deferred" bucket.
  2. **The ID `REQ-AI-4` is retained and NOT renumbered**, per the never-reuse-or-renumber rule. Its `AI-` prefix is now a historical artifact and no longer describes its classification. Recorded in the requirements retired/merged appendix so the mismatch is documented rather than confusing.
  3. **Phase 25 has no SEC coverage yet.** `security-plan.md` §9 explicitly scopes payment-rail security (PCI and equivalent) out of v1, to be revisited "when payments enter the AI phase." Payments now has its own phase, so a new SEC block must be authored before phase 25 can start. Flagged as **OQ-10**.

### (b) SEC and TC coverage — every group lands somewhere

**SEC items (41), by group:**

| SEC group | Phase |
|---|---|
| SEC-01…04 (identity, sessions) | 06 |
| SEC-05, 06 (pairing codes) | 06 |
| SEC-07, 08, 09 (removal, revocation) | 16 |
| SEC-10, 11 (re-pair, device loss) | 06 |
| SEC-12, 13, 14 (at-rest, keys, no-passcode) | 05 (implement) → 18 (verify on hardware) |
| SEC-15, 16 (uninstall, backup exclusion) | 05 (implement) → 18 (verify) |
| SEC-17…21 (TLS, tokens, replay, queued writes) | 08 |
| SEC-22…25 (RLS, isolation, membership path) | 07 (policies authored) → 18 (adversarial verification) |
| SEC-26 (secrets) | 04 |
| SEC-27 (backup encryption, restore) | 22 |
| SEC-28 (log hygiene) | 18 |
| SEC-29…36 (DPA: basis, notice, consent, rights, erasure, breach, retention) | 18 |
| SEC-37, 38 (NPC registration, counsel review) | 22 |
| SEC-39, 40, 41 (store labels, deletion path, location) | 23 |
| **SEC gate tiers** (security-plan §7) | beta tier → 18; store-submission tier → 23; public-launch tier → 22 |
| **Payment-rail security — DOES NOT EXIST YET** | required by 25; must be authored first (OQ-10) |

**TC groups:**

| TC group | Phase |
|---|---|
| TC-GEN-01…05 | 02 |
| TC-PLT-01…03 | 01, 05, 06 |
| TC-BS-01…08 | 09 |
| TC-LG-01…13 | 10 |
| TC-HF-01…08 | 11 |
| TC-GM-01…13 | 12 |
| TC-AE-01…13, TC-FIX-A1…C2 | 13 |
| TC-PL-10…20 | 14 |
| TC-SE-20, 21, 24, 25, 27…30 | 08 |
| TC-SE-10…19, 22, 26 | 16 |
| TC-OF-01…17 | 17 |
| TC-SEC-01…10, TC-EX-01 | 18 (suite runs in CI from 01) |
| TC-API-01…05 | 04 |
| TC-MIG-01…03 | 07 |
| TC-BAK-01, 02 | 22 |
| TC-E2E-01 | 19 |

No SEC item and no TC group is unplaced.

### (c) One-sitting failures — **20 of 27 phases are marked "no", and I cannot fix this within your phase cap**

Only 7 pass: phases 01, 02, 03, 04, 05, 06, and 15.

This is the finding that needs your decision before approval.

**Two distinct reasons a phase fails the one-sitting test:**

**Reason 1 — scope too large (11 phases).** These can be split, and here is the exact split each needs:

| # | Why it fails | Proposed split |
|---|---|---|
| 07 | All v1 tables + repositories + change-log writer | 07a entities & repositories · 07b change-log writer & migrations |
| 08 | Transport + ordering + replay + convergence | 08a push/pull transport & idempotency · 08b LWW ordering & convergence |
| 09 | 6 REQs spanning capture, taxonomy, and editing | 09a budget/date capture & validation (BS-1,2,3) · 09b region, cap & non-destructive edit (BS-4,5,6) |
| 10 | 6 REQs spanning CRUD and derived money | 10a entries, CRUD, estimated vs actual (LG-1,2,3) · 10b deposits, derived status, variance (LG-4,5,6) |
| 11 | HF-2 alone is six distinct typed forms | 11a prompt framework & dismissal (HF-1,3) · 11b six typed fee forms (HF-2) |
| 12 | 5 REQs spanning model and propagation | 12a axes, per-head/flat, crew (GM-1,2,4) · 12b propagation & what-if (GM-3,5) |
| 13 | 6 REQs spanning engine core and modifiers | 13a baselines, determinism, pinning, explainability (AE-1,3,4) · 13b index, overrides, buffer (AE-2,5,6) |
| 14 | 5 REQs spanning records and D2 math | 14a pledge records (PL-1) · 14b fulfillment math, expected, exposure, traceability (PL-2,3,4,5) |
| 16 | Change log + attribution + removal + transfer | 16a change log & attribution (SE-4) · 16b lifecycle: removal & transfer (SE-5,6) |
| 17 | 4 REQs across every entity | 17a offline CRUD & computation (OF-1,2) · 17b indicators & clock handling (OF-3,4) |
| 18 | RLS + at-rest + logs + 8 DPA items + gate | 18a technical hardening (RLS, at-rest, logs) · 18b DPA compliance & beta gate |

**Reason 2 — bound by elapsed time or an external party, not scope (9 phases).** Splitting does **not** help these; a five-day beta soak is five days regardless of how the work is divided.

| # | Time constraint |
|---|---|
| 19 | Full suite + E2E on both platforms + triage; multi-day by volume |
| 20 | ≥ 5-day soak per `deployment-plan.md` §4.1 |
| 21 | Real couples planning real weddings — weeks, inherently |
| 22 | Restore drill + rollback rehearsal + counsel-gated items |
| 23 | Store review 1–3 days, then a 7-day phased rollout |
| 24 | Observation window by definition |
| 25 | **Payments.** Externally gated — rail onboarding, merchant/partner approval, and compliance review sit with third parties, not with us. Also blocked on OQ-10 (no payment-rail SEC block exists) |
| 26, 27 | Post-launch AI work, multi-sitting by scope and by gate |

**The conflict, stated plainly.** Splitting the 11 scope-bound phases yields **+11 phases → 38**, which exceeds your 20–26 cap — and the index is already at 27 after Decision 2. The two constraints — "between 20 and 26 phases" and "every phase validatable in one sitting" — are not simultaneously satisfiable for this scope. I have not resolved it by quietly marking large phases "yes."

**Three ways forward — your call:**

1. **Raise the cap to ~38** and accept the splits above. Best granularity; the index gets long.
2. **Keep the work phases and add a separate row type for time-bound gates.** The 9 Reason-2 phases become *gates* (entry/exit criteria, no sitting expectation), leaving 18 work phases of which 11 still need splitting → **29 work phases + 9 gates**.
3. **Keep the cap at 26 and redefine the column** as "validatable in one sitting *once its sub-tasks are enumerated in the phase body*." Honest only if the bodies carry the sub-splits. I do not recommend this — it moves the problem rather than solving it.

**My recommendation: option 2.** It preserves one-sitting discipline where it is meaningful (implementation work) and stops pretending a store review or a UAT window is a sitting.

### (d) Dependency graph — acyclic, no forward dependencies

Every phase depends only on lower-numbered phases, verified row by row:

```
01 ← —                          14 ← 10,13
02 ← 01                         15 ← 09,10,11,12,13,14
03 ← 01                         16 ← 08,15
04 ← 01                         17 ← 16
05 ← 03,04                      18 ← 17
06 ← 04,05                      19 ← 18
07 ← 05                         20 ← 19
08 ← 06,07                      21 ← 20
09 ← 02,07,08                   22 ← 21
10 ← 09                         23 ← 22
11 ← 10                         24 ← 23
12 ← 10                         25 ← 24
13 ← 02,09,12                   26 ← 24
                                27 ← 26
```

Phases 25 (payments) and 26 (AI on-device) both depend on 24 and **not on each other** — they are independent post-launch tracks and may proceed in either order or in parallel.

- **No cycles.** All edges point strictly backward, so the graph is a DAG by construction.
- **No forward dependencies.** Max dependency index is always < the phase's own number.
- **Sequencing constraints honoured:** foundation (01–05) precedes auth/pairing (06); data layer (07) and sync engine (08) both complete before the first feature UI (09); features run in the mandated order (09 setup → 10 ledger → 11 hidden fees → 12 guest math → 13 allocation → 14 pledges → 15 dashboard); conflict hardening (16) and offline hardening (17) are dedicated phases, not folded into any feature; security (18) → QA (19) → beta (20) → UAT (21) → readiness (22) → submission (23) → monitoring (24); AI phases (26, 27) come strictly after the completed launch phase (23) and its stabilisation (24), split as on-device then cloud/OCR. Payments (25) is a separate post-launch track, no longer part of the AI tail (ADR-28).

---

## Stopping here

Index only, as instructed.

**Decision 2 — RESOLVED.** REQ-AI-4 is phase 25, its own phase, outside the AI tail, owned by Backend with Security as mandatory reviewer (ADR-28).

**Still needed before I write any phase body:**

1. **The one-sitting vs phase-cap conflict** in (c) — options 1, 2, or 3. Decision 2 has pushed the index to 27, already over the cap, so this now needs resolving either way.
2. **OQ-10 (new):** payment-rail security has no SEC block. `security-plan.md` §9 scoped it out of v1 on the assumption payments would arrive inside the AI phase. Phase 25 cannot start until that block exists.

Also carried forward: **8 OQ items remain OPEN** in `decision-log.md`. Per the `agents.md` escalation rule, phases touching them will stop rather than decide — most relevantly OQ-04 (reference costs) against phase 13, OQ-07 (data residency) against phase 23, and OQ-01/OQ-03 (erasure, force-wipe) against phases 16 and 18.

---
---

# Phase bodies

*Batch 1 of N — phases 01–06 only. Later batches appended on request.*

**Note on Decision 1.** The one-sitting vs phase-cap conflict in §(c) is still unresolved, but every phase in this batch is marked "yes" for one sitting, so none of them is affected. It will bite from phase 07 onward, which is the first "no".

---

## Phase 01: Repo, tooling & CI skeleton

**Owning agent:** DevOps/Release

**Depends on:** — (none; this is the root phase)

**Objective:** Stand up the Flutter repository with its module skeleton, Fastlane lanes, lint configuration, and a CI pipeline that demonstrably passes on good code and fails on bad. Nothing functional ships; the point is that the gates work.

**Requirements covered:** REQ-PLT-1

**Tasks**

1. Initialise the Flutter project at the repo root; set the bundle identifier and Android package name; commit `pubspec.yaml` and `pubspec.lock`.
2. Create the module skeleton exactly per `design.md` §1.2 — `ui/` (with `ui/presenters/`), `domain/` (`allocation/`, `calculations/`, `validation/`), `data/` (`repositories/`, `db/`, `changelog/`), `sync/` (`queue/`, `clock/`, `transport/`), `platform/` (`db/`) — each containing a `README.md` stating its layering rule.
3. Add `analysis_options.yaml` with strict lints and the custom-lint plugin wiring (the money-specific rule itself is phase 02).
4. Add `.gitignore` covering Flutter/Dart build output, IDE files, `.env*`, keystores, and `*.p12`/`*.mobileprovision`.
5. Create `fastlane/Fastfile` with `build_android` and `build_ios` lanes and `fastlane/Appfile`; initialise an empty Fastlane Match repo reference (certificate generation requires Apple Developer access and is a task-level prerequisite, not an output of this phase).
6. Wire build numbering: CI run number → `--build-number`, applied identically to iOS `CFBundleVersion` and Android `versionCode` per `deployment-plan.md` §3.3.
7. Create `.github/workflows/ci.yml` with jobs: `analyze` (`flutter analyze`), `test` (`flutter test`), and `build-android` (Linux runner only; iOS build deliberately excluded per `deployment-plan.md` §3.2 cost policy).
8. Add one placeholder unit test so the `test` job has something to run and a non-zero exit is meaningful.
9. Prove the gate works: push a branch containing a deliberate lint violation, confirm CI fails, revert, confirm CI passes.

**Deliverables**

- `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.gitignore`
- `ui/`, `domain/`, `data/`, `sync/`, `platform/` skeleton with a `README.md` in each
- `fastlane/Fastfile`, `fastlane/Appfile`
- `.github/workflows/ci.yml`
- `test/placeholder_test.dart`

**Exit Criteria**

| Check | Command | Expected result |
|---|---|---|
| Static analysis clean | `flutter analyze` | Exit 0, "No issues found!" |
| Tests run | `flutter test` | Exit 0, 1 test passed |
| Android build produces an artifact | `flutter build appbundle --debug` | Exit 0, `.aab` present under `build/` |
| Fastlane lanes exist | `fastlane lanes` | Lists `build_android` and `build_ios` |
| Module skeleton matches design | `ls -d ui domain data sync platform` | All five present |
| **Gate actually fails** | Push a branch with `final double x = 1.0;` in `domain/`, observe CI | `analyze` job fails; after revert, all jobs pass |
| Build numbering wired | Inspect a CI run's build args | Build number equals the CI run number |

**TC IDs that must pass:** TC-PLT-01

**Non-goals** — must not touch:
- Any screen, widget, or navigation route (phase 03).
- Money types or formatting (phase 02).
- Supabase, any backend resource, any network call (phase 04).
- Any database, table, or migration (phases 05, 07).
- Auth or credentials (phase 06).
- iOS builds in CI (nightly/RC only, per cost policy).
- **No AI code, no AI dependencies.**

**Rollback:** Greenfield phase — revert the initialisation commits, or delete the branch. No data, no deployed resource, no external state to unwind.

**Open questions to resolve before starting:** None blocking.
*Advisory, not a blocker:* OQ-09 (name clearance) is OPEN. The bundle identifier and Android package name are set in task 1, and they are effectively immutable after first store submission. Running OQ-09 steps 1, 2, and 4 now is cheap insurance; doing it after phase 23 is not possible.

---

## Phase 02: Money primitives & formatting

**Owning agent:** Backend

**Depends on:**
- **01** — the `domain/` and `ui/presenters/` module skeleton, `analysis_options.yaml` with custom-lint wiring, and a green CI pipeline.

**Objective:** Establish integer-centavo money handling end to end and the single formatting chokepoint that renders it, so that no later phase can introduce floating-point money or leak a constrained display form outside a bento tile.

**Requirements covered:** REQ-GEN-1, REQ-GEN-2, REQ-GEN-2A

**Tasks**

1. Create `domain/money/centavos.dart` — arithmetic and parsing helpers as extensions on `int`. **No wrapper type**, per `design.md` §1.5 (Dart `int` is natively 64-bit and satisfies REQ-GEN-1 directly).
2. Create `ui/presenters/money_presenter.dart` implementing the **full form** per REQ-GEN-2: peso sign, comma thousands separators, exactly two decimals, half-up rounding away from zero, leading minus inside the format.
3. Extend the presenter with the **constrained bento form** per REQ-GEN-2A: drop centavos below ₱1,000,000; one-decimal millions shorthand at or above; truncate toward zero so a tile never overstates.
4. Add a presenter method returning the **accessibility-label form**, which is always the full form and never the constrained one (REQ-GEN-2A cl. 6).
5. Implement the custom lint rule banning `double` and `num` in monetary paths across `domain/` and `data/`; register it in `analysis_options.yaml`.
6. Write unit tests for the full form: `₱350,000.00`, `₱0.00`, `−₱1,200.00`, and half-centavo rounding `₱0.005 → ₱0.01`.
7. Write unit tests for the constrained form: `₱350,000`, `₱1.25M`, truncation cases `₱1,259,000.00 → ₱1.25M` and `₱350,999.99 → ₱350,999`, and negative `−₱1,200`.
8. Write the drift-guard test: sum 1,000 per-head line items, then compare the stored total against the displayed total across 1,000 iterations; assert zero centavos gained or lost.

**Deliverables**

- `domain/money/centavos.dart`
- `ui/presenters/money_presenter.dart`
- `tools/lint/no_float_money.dart` (or equivalent custom-lint rule location), registered in `analysis_options.yaml`
- `test/domain/money/centavos_test.dart`
- `test/ui/presenters/money_presenter_test.dart`

**Exit Criteria**

| Check | Command | Expected result |
|---|---|---|
| All money tests pass | `flutter test test/domain/money test/ui/presenters` | Exit 0, zero failures |
| Full form exact | Assert in test | `35000000` → `₱350,000.00`; `0` → `₱0.00`; `-120000` → `−₱1,200.00` |
| Rounding half-up | Assert in test | Half-centavo rounds away from zero |
| Constrained form exact | Assert in test | `125900000` → `₱1.25M`; `35099999` → `₱350,999` |
| Truncation never overstates | Assert in test | No constrained output exceeds its true value |
| A11y label is full form | Assert in test | Constrained input still yields the full form for the a11y label |
| **Float lint fires** | Add `double amountCents = 1.0;` to `domain/`, run `flutter analyze` | Fails with the no-float-money rule; passes after revert |
| Drift guard | `flutter test test/domain/money/centavos_test.dart` | 1,000-iteration sum equals displayed total exactly |

**TC IDs that must pass:** TC-GEN-01, TC-GEN-02, TC-GEN-03, TC-GEN-04, TC-GEN-05

**Non-goals** — must not touch:
- Allocation percentages or basis-point arithmetic (phase 13).
- Any ledger, pledge, or guest entity (phases 10, 12, 14).
- Any screen or widget that *uses* the presenter (phases 09+); this phase delivers the presenter, not a consumer.
- Database columns or persistence of money (phases 05, 07).
- **No AI code, no AI dependencies.**

**Rollback:** Revert the phase commits. Only two new source files plus a lint rule; nothing persisted, nothing deployed. If the lint rule proves too noisy, disable it in `analysis_options.yaml` as a temporary measure and record the suppression in `docs/tech-debt.md` — but the rule is the only verification available for REQ-GEN-1 (UT-1), so removing it permanently is not an option.

**Open questions to resolve before starting:** None blocking.

---

## Phase 03: Flutter app shell & navigation

**Owning agent:** Mobile/Frontend

**Depends on:**
- **01** — the `ui/` module skeleton and a green CI pipeline.

**Objective:** Build the routable application shell with the complete navigation tree from `ux-spec.md` §1.3, using placeholder screens only, so that later feature phases have a route to attach to and nothing has to be re-plumbed.

**Requirements covered:** — (none; this phase is structural)

**Tasks**

1. Add `go_router` and `flutter_riverpod`; wrap the app in a `ProviderScope`.
2. Create `ui/router/app_router.dart` with the exact route tree from `ux-spec.md` §1.3: `(auth)`, `(invite)/accept/[token]`, `(onboarding)` wizard steps, `(app)` tab shell, and the modal routes.
3. Create placeholder screens for **SCR-01 through SCR-19** in `ui/screens/`, each rendering only its screen ID and name — no data, no logic.
4. Build the `(app)` tab shell with the five tabs named in `ux-spec.md` §1.3: dashboard, ledger, guests, pledges, more.
5. Implement the onboarding wizard as a **distinct stack, not a tab**, so the hidden-fee completion gate cannot be escaped (`ux-spec.md` §1.3 rationale). The gate itself is phase 11.
6. Add redirect guards for unauthenticated and no-active-plan states, backed by a stubbed provider that phase 06 replaces.
7. Register the deep-link URL scheme on both platforms for the invite route.
8. Add golden tests for the tab shell.
9. Add a widget test asserting every one of SCR-01…SCR-19 is reachable by route.

**Deliverables**

- `ui/router/app_router.dart`
- `ui/screens/` containing 19 placeholder screens named for SCR-01…SCR-19
- `ui/shell/app_tab_shell.dart`
- iOS `Info.plist` and Android `AndroidManifest.xml` deep-link registration
- `test/ui/router/app_router_test.dart`
- `test/ui/golden/tab_shell_golden_test.dart` plus committed golden files

**Exit Criteria**

| Check | Command | Expected result |
|---|---|---|
| All routes resolve | `flutter test test/ui/router` | Exit 0; all 19 SCR IDs reachable |
| Golden shell matches | `flutter test test/ui/golden` | Exit 0, no golden diff |
| App launches | `flutter run` on an emulator | Lands on SCR-01 placeholder, no crash, no red screen |
| Tab navigation | Manual: tap each of the five tabs | Each shows its placeholder screen; no dead tab |
| Onboarding is not a tab | Manual: enter the wizard, attempt tab navigation | Tabs are unreachable from inside the wizard |
| Deep link opens invite route | `adb shell am start -a android.intent.action.VIEW -d "<scheme>://accept/testtoken"` | App opens on the SCR-02 placeholder |
| Analysis clean | `flutter analyze` | Exit 0 |

**TC IDs that must pass:** — (none; TC coverage for these screens arrives with their feature phases)

**Non-goals** — must not touch:
- Real authentication or session logic (phase 06); the guard provider is a stub.
- Any data fetch, repository, or database call (phases 05, 07).
- Money display (phase 02's presenter exists but is not wired here).
- Any feature behaviour behind a placeholder screen (phases 09–15).
- The bento dashboard layout (phase 15) — SCR-06 is a placeholder like the rest.
- **No AI code, no AI dependencies.** The AI insights tile (`ux-spec.md` §4.5) is not created in this phase.

**Rollback:** Revert the phase commits. No persisted state and no external resources; the only cross-platform artifacts are the deep-link manifest entries, which revert with the commit.

**Open questions to resolve before starting:** None blocking.

---

## Phase 04: Backend shell — Supabase envs & secrets

**Owning agent:** DevOps/Release

**Depends on:**
- **01** — `.github/workflows/ci.yml` to attach the new jobs to, and the repo secret-scan baseline.

**Objective:** Create the Supabase project(s), commit declarative auth and project configuration, and expose an authenticated but empty `/v1/sync` surface with contract tests, so later phases have a real backend to target and a verified secrets boundary.

**Requirements covered:** — (none; this phase is infrastructure)

**Tasks**

1. Create the **staging** Supabase project in region `ap-southeast-1` per `deployment-plan.md` §2.2. **Production project creation is blocked — see open questions.**
2. Commit `supabase/config.toml` with auth settings satisfying SEC-03: access-token TTL ≤ 1 hour, refresh-token rotation enabled.
3. Create `supabase/functions/` with `sync_push` and `sync_pull` RPC stubs matching the request and response shapes in `design.md` §2.4 — authenticate the caller, return an empty result set, assign no `server_ts` yet.
4. Wire environment configuration: anon key injected at build time via `--dart-define`; service-role key present only in CI secrets and never in a client build (SEC-26).
5. Set up the local Supabase CLI development environment (`supabase start`) so phases 05+ can work offline against a local instance.
6. Add API contract tests for the stubs covering request/response shape, auth enforcement, and rejection of malformed rows.
7. Add a CI job running the contract tests against the local Supabase instance.
8. Add a CI secret-scan job and confirm it fails on a deliberately committed dummy secret, then passes after removal (SEC-26).

**Deliverables**

- `supabase/config.toml`
- `supabase/functions/sync_push/`, `supabase/functions/sync_pull/`
- `.github/workflows/ci.yml` updated with `contract-tests` and `secret-scan` jobs
- `test/api/contract/` test suite
- `docs/deployment-plan.md` §1 environments table updated with the real staging project reference

**Exit Criteria**

| Check | Command | Expected result |
|---|---|---|
| Local backend runs | `supabase start && supabase status` | All services report healthy |
| Contract tests pass | `flutter test test/api/contract` (or the suite's runner) | Exit 0, zero failures |
| Unauthenticated call rejected | `curl` `/v1/sync/pull` with no bearer token | HTTP 401 |
| Authenticated call succeeds and is empty | `curl` with a valid staging token | HTTP 200, empty row set |
| Malformed push rejected | `curl` push with an invalid row body | 4xx, and no partial commit observable in the DB |
| Token TTL correct | Decode an issued access token | `exp − iat` ≤ 3600 s |
| **Secret scan gate works** | Commit a dummy secret, run CI; remove it, re-run | Fails, then passes |
| No service-role key in client | `strings` the built `.aab` and grep for the key prefix | Zero matches |

**TC IDs that must pass:** TC-API-01, TC-API-02, TC-API-04, TC-API-05
*(TC-API-03 idempotency is deferred to phase 08, which is where `server_ts` assignment and insert-ignore behaviour are implemented.)*

**Non-goals** — must not touch:
- Any table, schema, or migration (identity tables are phase 06; budget entities are phase 07).
- RLS policies (phase 06 for identity tables, phase 07 onward for entities).
- Real sync behaviour — ordering, `server_ts`, idempotency, replay (phase 08).
- Auth *client* integration (phase 06); this phase configures the provider only.
- The production Supabase project (blocked, below).
- **No AI code, no AI dependencies.**

**Rollback:** Delete the staging Supabase project and revert the phase commits. Because no user data exists yet and production is untouched, this is a clean teardown. Rotate any key that was created, per `deployment-plan.md` §2.5.

**Open questions to resolve before starting:**

> **⛔ OQ-07 (data residency) is OPEN and blocks part of this phase.**
>
> Creating a Supabase project requires choosing a region, and a project's region cannot be changed afterwards without a full migration — so **selecting the production region *is* the residency decision in practice.** `decision-log.md` records OQ-07 as unresolved, and `security-plan.md` SEC-30 requires the privacy notice to name the data location.
>
> Per the `agents.md` escalation rule this phase stops rather than decides. Two ways forward, your call:
>
> 1. **Decide OQ-07 now** (the deployment plan recommends accepting `ap-southeast-1` / Singapore and disclosing it), then this phase runs in full.
> 2. **Authorise a descope:** create staging only in `ap-southeast-1` and defer the production project to a later phase. Staging holds synthetic data exclusively (`deployment-plan.md` §1.1), so the residency question does not bind for it. Phase 04 would then complete with production deferred, and phase 23 (submission) inherits the blocker.
>
> I have not chosen between these.

---

## Phase 05: Local encrypted store

**Owning agent:** Data & Sync

**Depends on:**
- **03** — the running app shell, so the database can be opened within a real app lifecycle.
- **04** — the local Supabase CLI environment, so the no-network assertion can be made against a backend that exists but is deliberately not called.

**Objective:** Open an encrypted local SQLite database with its key held in platform secure storage, excluded from cloud backup, and prove that reads require no network — establishing the local-first foundation before any entity exists.

**Requirements covered:** REQ-PLT-2

**Tasks**

1. Add `drift`, `sqlite3_flutter_libs`, and `sqlcipher_flutter_libs` dependencies with pinned versions.
2. Implement `platform/db/encrypted_database.dart` — generate the SQLCipher key on first run, store it in the iOS Keychain / Android Keystore, and retrieve it on subsequent opens (SEC-13).
3. Set the Keychain accessibility to `WhenUnlockedThisDeviceOnly` and use the Android Keystore without a weakened fallback; surface a one-time warning on a device with no passcode (SEC-14).
4. Create `data/db/app_database.dart` — the `drift` database class at schema version 1 with **no application tables** (drift's internal versioning is sufficient; application entities are phases 06 and 07).
5. Exclude the database file and key from cloud backup: iOS `isExcludedFromBackup` plus `NSFileProtectionComplete`; Android `android:allowBackup="false"` or an explicit backup-rules exclusion (SEC-16).
6. Define the repository base abstraction in `data/repositories/` — interface only, no implementations.
7. Write an integration test: open the database, write and read a value through drift's internal mechanism, close, reopen with the stored key, and confirm the value survives an app restart.
8. Write a no-network assertion: run the database open-and-read path with networking disabled and confirm it succeeds with zero network calls attempted.
9. Verify encryption on a developer machine: pull the database file off an emulator and confirm `sqlite3` cannot open it and `strings` reveals no plaintext.

**Deliverables**

- `platform/db/encrypted_database.dart`
- `data/db/app_database.dart` (schema version 1, no application tables)
- `data/repositories/repository.dart` (base interface)
- iOS `Info.plist` and Android `AndroidManifest.xml` / backup-rules changes for backup exclusion
- `integration_test/db/encrypted_store_test.dart`
- `test/data/db/schema_version_test.dart`

**Exit Criteria**

| Check | Command | Expected result |
|---|---|---|
| Database opens and persists | `flutter test integration_test/db/encrypted_store_test.dart` | Exit 0; value survives close/reopen |
| Key is in secure storage, not the DB | Inspect Keychain/Keystore; grep the DB file for the key | Key present in secure storage; zero matches in the DB file |
| **File is genuinely encrypted** | `adb pull` the DB, then `sqlite3 <file> ".tables"` | Fails — "file is not a database" |
| No plaintext leakage | `strings <pulled db>` | No supplier, sponsor, or guest strings; no peso amounts |
| Reads need no network | Run the open-and-read integration test with the network disabled | Passes; zero network calls attempted |
| Backup exclusion set (iOS) | Inspect the file's resource attributes | `isExcludedFromBackup` is true; protection class is `Complete` |
| Backup exclusion set (Android) | Inspect the built manifest | `allowBackup="false"`, or the DB explicitly excluded in backup rules |
| No-passcode warning | Manual: run on an emulator with no device passcode | Warning shown exactly once |
| Schema version | `flutter test test/data/db/schema_version_test.dart` | Reports version 1 with zero application tables |

**TC IDs that must pass:** TC-PLT-02, TC-SEC-09
*(TC-SEC-07 and TC-SEC-08 are authoritative only on physical hardware per `testing-plan.md` §7.4. The developer-machine equivalents above are the phase-05 gate; the binding hardware verification belongs to phase 18 and is not claimed here.)*

**Non-goals** — must not touch:
- Any application table or entity — identity tables are phase 06, budget entities are phase 07.
- Migrations beyond establishing version 1 (phase 07).
- The change-log writer (phase 07).
- Any sync, queue, or transport code (phase 08).
- Repository *implementations* (phase 07); this phase delivers the interface only.
- **No AI code, no AI dependencies.**

**Rollback:** Revert the phase commits and delete the local database file from any test device. No production data exists. If key storage proves unreliable on a platform, the phase must be re-attempted rather than shipped with encryption disabled — SEC-12 has no fallback, and an unencrypted store cannot pass phase 18.

**Open questions to resolve before starting:** None blocking.

---

## Phase 06: Shared-account auth & pairing

**Owning agent:** Security

**Depends on:**
- **04** — the Supabase project with committed auth configuration (token TTL, refresh rotation).
- **05** — the encrypted local store and secure key storage, so session tokens can be held safely.

**Objective:** Deliver individual authenticated accounts and the invite-based pairing that links exactly two of them to one shared plan, enforcing one active plan per account. This is the account-linking model chosen in `security-plan.md` §1 over shared logins and invite-as-identity.

**Requirements covered:** REQ-PLT-3, REQ-SE-1

**Tasks**

1. Integrate Supabase Auth for sign-up, sign-in, and mandatory email verification; block plan creation and joining until the email is verified (SEC-01, SEC-02).
2. Implement session handling: store access and refresh tokens in Keychain/Keystore (SEC-19), rotate refresh tokens on use, and invalidate server-side on sign-out (SEC-03, SEC-04).
3. Write the migration creating the identity and access tables from `design.md` §4.1 — `users`, `plans`, `plan_members`, `invites`. (`lifecycle_confirmations` belongs to phase 16.)
4. Enable and force RLS on those four tables, with membership resolved through `plan_members` keyed to the authenticated user (SEC-22, SEC-23 scoped to identity tables).
5. Enforce one active plan per account (REQ-PLT-3): a database constraint or trigger, plus a client-side block whose message names the existing active plan.
6. Enforce the two-partner cap: at most two `plan_members` rows per plan, by trigger (REQ-SE-1 cl. 1).
7. Implement invite issue, accept, and revoke: 128-bit CSPRNG token, **hash only** stored in `invites.token_hash`, 7-day expiry, single-use (REQ-SE-1 cl. 3–5; SEC-05, SEC-06).
8. Deny direct client inserts into `plan_members` — membership is written only by the server-side accept flow (SEC-25).
9. Wire SCR-01 (Sign In / Sign Up) and SCR-02 (Invite Acceptance) to real behaviour, replacing the phase-03 placeholders, and replace the stubbed auth guard provider with the real one.
10. Verify re-pairing after reinstall: a reinstalled app signs in and recovers plan membership with no residual credential from the prior install (SEC-10, SEC-11).

> **At the one-sitting boundary.** This phase has exactly 10 tasks, the stated limit. If it slips in practice, the natural split is **06a auth and sessions** (tasks 1, 2, 9-partial, 10) and **06b pairing and plan membership** (tasks 3–8), which would take the index to 28. Flagged now so the split is a known option rather than a surprise.

**Deliverables**

- `supabase/migrations/0001_identity_and_access.sql` (users, plans, plan_members, invites + RLS)
- `data/repositories/auth_repository.dart`, `data/repositories/plan_membership_repository.dart`
- `ui/screens/scr_01_sign_in.dart`, `ui/screens/scr_02_invite_acceptance.dart` (real implementations)
- `ui/router/auth_guard.dart` (real, replacing the phase-03 stub)
- `platform/secure_storage/token_store.dart`
- `test/data/repositories/auth_repository_test.dart`, `test/data/repositories/plan_membership_repository_test.dart`
- `integration_test/auth/pairing_test.dart`

**Exit Criteria**

| Check | Command / steps | Expected result |
|---|---|---|
| Sign-up requires verification | Manual: sign up, then attempt to create a plan before clicking the verification link | Creation refused with a message naming email verification |
| Sign-in works | `flutter test integration_test/auth/pairing_test.dart` | Exit 0 |
| Token TTL and rotation | Decode the access token; use the refresh token twice | `exp − iat` ≤ 3600 s; the first refresh token is rejected on reuse |
| Sign-out revokes server-side | Sign out, then `curl` a refresh with the prior token | Rejected |
| Tokens in secure storage only | Grep the local DB file and shared preferences for the token prefix | Zero matches; tokens present in Keychain/Keystore |
| **One active plan per account** | Create a plan, then attempt to create a second | Blocked; message names the existing active plan |
| **Two-partner cap** | Attempt to add a third `plan_members` row by direct SQL | Rejected by trigger |
| Invite is single-use | Accept an invite, then accept the same token again | Second attempt refused, reason stated |
| Invite expires at 7 days | Set `expires_at` to the past, open the link | Refused with "invite has expired" |
| Only a hash is stored | `SELECT token_hash FROM invites` | Value is a hash; the raw token appears nowhere in the DB or logs |
| Direct membership insert denied | Client-token `INSERT INTO plan_members` | Denied by RLS |
| Re-pair after reinstall | Uninstall, reinstall, sign in | Plan membership restored; no prior credential required |
| Partner B sees the same plan | Manual: pair two accounts, sign in as each | Both see the identical plan |

**TC IDs that must pass:** TC-PLT-03, TC-SE-23

**Non-goals** — must not touch:
- Any budget entity table — ledger, pledges, guests, allocations, fee components (phase 07).
- Defensive removal, ownership transfer, or `lifecycle_confirmations` (phase 16).
- The change log or attribution (phase 07 writer, phase 16 UI).
- Sync of any kind (phase 08).
- Account deletion and the erasure flow (phase 18; blocked on OQ-01 regardless).
- Budget setup or onboarding content beyond the auth guard redirect (phase 09).
- **No AI code, no AI dependencies.**

**Rollback:** Revert the phase commits and roll back `0001_identity_and_access.sql`. The migration is purely additive — four new tables and their policies — so the down-migration drops them cleanly per `deployment-plan.md` §2.6. Staging holds synthetic data only, so no user data is at risk. Any auth keys created should be rotated.

**Open questions to resolve before starting:** None blocking this phase directly.
*Inherited:* if phase 04 was descoped to staging-only under OQ-07, this phase runs against staging only, and the production identity migration is deferred with it.
