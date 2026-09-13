# Kasaran — Development Phases

**INDEX ONLY.** No phase bodies. Awaiting approval of this index before any phase is written out.

*Inputs: `requirements.md` (54 REQ IDs), `testing-plan.md` (TC IDs), `security-plan.md` (SEC IDs), `agents.md`, `decision-log.md`.*

---

## Phase index — 26 phases

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
| 25 | AI phase 1: on-device categorisation | AI/ML | 24 | REQ-AI-2 | On-device suggestion behind `CategorySuggester`, suggestions never auto-apply | **no** |
| 26 | AI phase 2: cloud AI reasoning + OCR | AI/ML | 25 | REQ-AI-1, REQ-AI-3, REQ-AI-4, REQ-AI-5 | Cloud advisories, OCR drafts, payments, assistant — all behind documented seams | **no** |

**Phases carrying no REQ IDs** (10 of 26): 03, 04, 07, 15, and 19–24. These are infrastructure, composition, or process phases. Phase 15 (dashboard) integrates figures whose requirements are covered in 09–14 and introduces no new REQ; it is validated against the `ux-spec.md` bento layout and state matrix instead.

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
| REQ-AI-2 | 1 | 25 |
| REQ-AI-1, 3, 4, 5 | 4 | 26 |
| **Total** | **54** | |

**Orphans: none. Duplicates: none.**

Two placement notes worth your eye:

- **REQ-OF-5 sits in phase 08, not 17.** Durable idempotent replay *is* the sync engine's mechanism; the remaining offline requirements (OF-1…4) can only be validated once features exist, so they land in 17.
- **REQ-AI-4 (InstaPay / QR Ph payments) is bundled into phase 26.** It is neither on-device inference nor cloud reasoning/OCR, so it fits the two mandated AI phases only loosely. It may warrant its own phase 27; flagged rather than silently absorbed.

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

### (c) One-sitting failures — **19 of 26 phases are marked "no", and I cannot fix this within your phase cap**

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

**Reason 2 — bound by elapsed time, not scope (8 phases).** Splitting does **not** help these; a five-day beta soak is five days regardless of how the work is divided.

| # | Time constraint |
|---|---|
| 19 | Full suite + E2E on both platforms + triage; multi-day by volume |
| 20 | ≥ 5-day soak per `deployment-plan.md` §4.1 |
| 21 | Real couples planning real weddings — weeks, inherently |
| 22 | Restore drill + rollback rehearsal + counsel-gated items |
| 23 | Store review 1–3 days, then a 7-day phased rollout |
| 24 | Observation window by definition |
| 25, 26 | Post-launch AI work, multi-sitting by scope and by gate |

**The conflict, stated plainly.** Splitting the 11 scope-bound phases yields **+11 phases → 37**, which exceeds your 20–26 cap. The two constraints — "between 20 and 26 phases" and "every phase validatable in one sitting" — are not simultaneously satisfiable for this scope. I have not resolved it by quietly marking large phases "yes."

**Three ways forward — your call:**

1. **Raise the cap to ~37** and accept the splits above. Best granularity; the index gets long.
2. **Keep the work phases and add a separate row type for time-bound gates.** The 8 Reason-2 phases become *gates* (entry/exit criteria, no sitting expectation), leaving 18 work phases of which 11 still need splitting → **29 work phases + 8 gates**.
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
13 ← 02,09,12                   26 ← 25
```

- **No cycles.** All edges point strictly backward, so the graph is a DAG by construction.
- **No forward dependencies.** Max dependency index is always < the phase's own number.
- **Sequencing constraints honoured:** foundation (01–05) precedes auth/pairing (06); data layer (07) and sync engine (08) both complete before the first feature UI (09); features run in the mandated order (09 setup → 10 ledger → 11 hidden fees → 12 guest math → 13 allocation → 14 pledges → 15 dashboard); conflict hardening (16) and offline hardening (17) are dedicated phases, not folded into any feature; security (18) → QA (19) → beta (20) → UAT (21) → readiness (22) → submission (23) → monitoring (24); AI phases (25, 26) come strictly after the completed launch phase (23) and its stabilisation (24), split as on-device then cloud/OCR.

---

## Stopping here

Index only, as instructed. **Two things need your decision before I write any phase body:**

1. **The one-sitting vs 26-phase conflict** in (c) — options 1, 2, or 3.
2. **REQ-AI-4** (payments) — leave it bundled in phase 26, or give it its own phase?

Also carried forward: **8 OQ items remain OPEN** in `decision-log.md`. Per the `agents.md` escalation rule, phases touching them will stop rather than decide — most relevantly OQ-04 (reference costs) against phase 13, OQ-07 (data residency) against phase 23, and OQ-01/OQ-03 (erasure, force-wipe) against phases 16 and 18.
