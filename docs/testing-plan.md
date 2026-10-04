# Kasaran — Testing Plan

*Inputs: [requirements.md](./requirements.md), [mvp-user-stories.md](./mvp-user-stories.md), [design.md](./design.md), [ux-spec.md](./ux-spec.md), [security-plan.md](./security-plan.md), [decision-log.md](./decision-log.md). No test code — this specifies what is tested, how, and with what data.*

**ID policy.** TC IDs are stable and never reused. This revision **preserves** all previously assigned IDs (TC-SE-10…22, TC-PL-10…12, TC-SEC-01…03) and allocates new ones in non-overlapping ranges.

---

## 0. Platform decision

**Flutter on iOS and Android is decided** by ADR-12 and required by REQ-PLT-1. The local store uses SQLite via `drift` or `sqflite` (REQ-PLT-2). The tooling below targets this decided platform only.

§1 specifies the Flutter tooling; the traceability, fixtures, sync matrix, backend checks, and exit criteria below apply to both iOS and Android builds.

---

## 1. Tooling decision

### 1.1 Flutter stack (per REQ-PLT-1, ADR-12)

| Layer | Choice | Justification |
|---|---|---|
| Unit runner | `flutter_test` (bundled) + `mocktail` for doubles | No third-party runner needed. The `domain/` layer imports neither Flutter nor `drift` (design §1.2), so calculation tests run as plain Dart — fast, no emulator, no DB. This is where every fixture in §3 is asserted. |
| Component / widget testing | `flutter_test`'s `WidgetTester` + `golden_toolkit` for golden snapshots | Widget tests are the Flutter equivalent of a component testing library. Goldens catch bento-tile layout and money-format regressions (REQ-GEN-2A) that assertions miss. |
| Integration (in-process) | `integration_test` package | Drives the real widget tree against a real SQLite DB on device/emulator. Covers offline CRUD and sync replay where a unit test cannot. |
| E2E driver | **Maestro** | Declarative YAML flows run against iOS simulators and Android emulators without in-app instrumentation; E2E exercises the shipped binary, not a test build. |
| Static analysis | `dart analyze` + custom lint rule banning `double` in money paths | REQ-GEN-1 forbids floating-point money. That is not observable at runtime once a value is already wrong; it must be caught statically. See TC-GEN-01. |
| DB migration harness | `drift` schema-version tests with generated fixtures | Forward and backward migration (§7). |

### 1.2 How E2E runs on iOS and Android

One Maestro flow set, two targets. Flows live in `e2e/flows/` and are parameterised only by platform-specific selectors where unavoidable.

- **iOS:** iPhone 15 simulator, latest−1 iOS, on a macOS CI runner.
- **Android:** Pixel 6 API 34 emulator, on a Linux CI runner.
- The full MVP scenario (§8) runs on **both** as a required gate. Platform-specific flows (backup exclusion, Keychain vs Keystore) run only where meaningful.

### 1.3 Where each suite runs, and why

| Suite | CI (every PR) | CI (nightly) | Local only | Real device only | Why |
|---|---|---|---|---|---|
| Domain unit tests (incl. all §3 fixtures) | ✅ | | | | Pure Dart, seconds, no device. The fixtures are the fastest highest-value signal in the project. |
| Widget tests | ✅ | | | | Headless, fast. |
| Golden snapshots | ✅ (verify) | | ✅ (update) | | Updating goldens is a human judgement; verification is automatic. |
| `integration_test` | ✅ Android emulator | ✅ iOS simulator | | | Android emulators are cheap on Linux runners; macOS runners are expensive, so iOS runs nightly. |
| Maestro E2E — MVP scenario | | | ✅ both platforms at RC | | Too slow for every PR; required for release candidates on both platforms, not nightly macOS. |
| API contract + tenant isolation (§7) | ✅ | | | | **TC-SEC-01 is a release gate-blocker** (SEC-24). Must run on every PR. |
| Migration forward/backward | ✅ | | | | Cheap, and a bad migration is unrecoverable in the field. |
| Backup/restore drill | | | ✅ monthly and before each release | | Needs a real scratch restore target; measured, not simulated. |
| SQLCipher file extraction (SEC-12) | | | | ✅ | Requires pulling the DB file off a real device and running `strings`. Simulators do not reproduce real file protection. |
| Keychain / Keystore key protection (SEC-13) | | | | ✅ | Simulator keychains do not enforce real protection classes. |
| Cloud auto-backup exclusion (SEC-16) | | | | ✅ | Requires triggering a genuine iCloud / Android Auto Backup and inspecting its contents. Not reproducible on a simulator — this is the single most important real-device test. |
| No-passcode device behaviour (SEC-14) | | | | ✅ | Cannot configure a simulator into a realistic no-passcode state. |
| Airplane-mode long-duration + OS restart queue durability | | | ✅ | ✅ | Emulator network toggling does not faithfully model radio loss; OS restart durability must be seen on real hardware. |

---

## 2. Traceability matrix

Every **70 currently defined** REQ ID in `requirements.md` appears. Levels: **U** unit, **I** integration, **E** E2E, **M** manual/review, **S** static analysis. Test cases below are planned assertions, not executed results; v1.1 attachment rows are design/backlog gates, not executed upload tests.

| REQ ID | Test IDs | Level |
|---|---|---|
| REQ-PLT-1 | TC-PLT-01 | M (build inspection) |
| REQ-PLT-2 | TC-PLT-02, TC-OF-09 | I |
| REQ-PLT-3 | TC-PLT-03 | I |
| REQ-GEN-1 | TC-GEN-01 | S (see §2.1 — runtime-untestable) |
| REQ-GEN-2 | TC-GEN-02 | U |
| REQ-GEN-2A | TC-GEN-03, TC-GEN-04 | U + widget |
| REQ-BS-1 | TC-BS-01, TC-BS-10, TC-BS-11, TC-BS-12, TC-FIX-E1 | U + I + widget |
| REQ-BS-2 | TC-BS-02 | U + I |
| REQ-BS-3 | TC-BS-03 | I |
| REQ-BS-4 | TC-BS-04, TC-BS-09 | U + I |
| REQ-BS-5 | TC-BS-05, TC-GM-06 | U |
| REQ-BS-6 | TC-BS-06 | I |
| REQ-LG-1 | TC-LG-01, TC-LG-02, TC-LG-14, TC-LG-15, TC-LG-41 | U + I + widget |
| REQ-LG-2 | TC-LG-03, TC-LG-04 | I |
| REQ-LG-3 | TC-LG-05 | U |
| REQ-LG-4 | TC-LG-06, TC-LG-07, TC-LG-16 … TC-LG-20 | U + I |
| REQ-LG-5 | TC-LG-08, TC-LG-09, TC-LG-10, TC-LG-21 … TC-LG-28 | U + I |
| REQ-LG-6 | TC-LG-11, TC-LG-12 | U |
| REQ-LG-7 | TC-LG-29 … TC-LG-32 | U + I |
| REQ-LG-8 | TC-LG-13, TC-LG-33 … TC-LG-36 | U + I |
| REQ-LG-9 | TC-LG-37 … TC-LG-40 | I + widget |
| REQ-HF-1 | TC-HF-01, TC-HF-02, TC-HF-03, TC-HF-04 | U + I |
| REQ-HF-2 | TC-HF-05, TC-HF-06, TC-HF-09 | U + widget |
| REQ-HF-3 | TC-HF-07, TC-HF-08, TC-BS-09 | U + I |
| REQ-PL-1 | TC-PL-13, TC-PL-21, TC-PL-22 | U + I |
| REQ-PL-2 | TC-PL-10, TC-PL-11, TC-PL-14, TC-PL-20, TC-PL-23 … TC-PL-29, TC-FIX-E1 | U + I |
| REQ-PL-3 | TC-PL-12, TC-PL-15, TC-PL-30 … TC-PL-35 | U |
| REQ-PL-4 | TC-PL-16, TC-PL-17, TC-PL-36 … TC-PL-38 | U |
| REQ-PL-5 | TC-PL-18, TC-PL-39 … TC-PL-41 | U + widget |
| REQ-PL-6 | TC-PL-42 … TC-PL-45 | U + I |
| REQ-PL-7 | TC-PL-46 … TC-PL-50 | U + I |
| REQ-GF-1 | TC-GF-01 … TC-GF-03 | U + I |
| REQ-GF-2 | TC-GF-04, TC-GF-05 | U + widget |
| REQ-GM-1 | TC-GM-01, TC-GM-02, TC-GM-03, TC-GM-14, TC-GM-15 | U + I |
| REQ-GM-2 | TC-GM-04, TC-GM-05 | U |
| REQ-GM-3 | TC-GM-07 | U |
| REQ-GM-4 | TC-GM-08 | U |
| REQ-GM-5 | TC-GM-09, TC-GM-10, TC-FIX-E1 | U + I |
| REQ-GM-6 [v1] | TC-GM-16 … TC-GM-20 | U + widget |
| REQ-AE-1 | TC-AE-01, TC-AE-02, TC-AE-03, TC-AE-04 | U |
| REQ-AE-2 | TC-AE-05, TC-AE-06, **TC-AE-07 (BLOCKED)** | U |
| REQ-AE-3 | TC-AE-08 | U |
| REQ-AE-4 | TC-AE-09, TC-AE-14 | U + widget |
| REQ-AE-5 | TC-AE-10, TC-AE-11, TC-AE-15 | U + I |
| REQ-AE-6 | TC-AE-12 | U |
| REQ-AE-7 [v1] | TC-AE-16 … TC-AE-20 | U + I + widget |
| REQ-TM-1 [v1] | TC-TM-01 … TC-TM-04 | U + I + widget |
| REQ-CK-1 [v1; preset gate OQ-11] | TC-CK-01 … TC-CK-05; verified preset oracle BLOCKED | U + I + widget |
| REQ-EX-2 [v1] | TC-EX-02 … TC-EX-08 | U + I + widget + M |
| REQ-LO-1 [v1.1] | TC-LO-01 … TC-LO-04 | U + widget (deferred) |
| REQ-AT-1 [v1.1 backlog stub] | TC-AT-01 … TC-AT-04 | I + M (deferred design gates, no v1 upload) |
| REQ-SE-1 | TC-SE-23, TC-SE-42, TC-SE-45 | I + E |
| REQ-SE-2 | TC-SE-20, TC-SE-21, TC-SE-24, TC-SE-27 … TC-SE-28, TC-SE-33 … TC-SE-35, TC-SE-39 | U + I |
| REQ-SE-3 | TC-SE-25, TC-SE-36, TC-SE-39 | U + I |
| REQ-SE-4 | TC-SE-15, TC-SE-26, TC-SE-28, TC-SE-37 … TC-SE-41 | U + I + E |
| REQ-SE-5 | TC-SE-16, TC-SE-18, TC-SE-31 | I |
| REQ-SE-6 | TC-SE-10, TC-SE-11, TC-SE-12, TC-SE-13, TC-SE-14, TC-SE-17, TC-SE-19, TC-SE-22, TC-SE-32 | I + E |
| REQ-OF-1 | TC-OF-01 … TC-OF-08, TC-OF-19 … TC-OF-21 | I |
| REQ-OF-2 | TC-OF-09, TC-OF-22, TC-OF-26 | U + I |
| REQ-OF-3 | TC-OF-10 | I |
| REQ-OF-4 | TC-OF-11 | U + I |
| REQ-OF-5 | TC-OF-12, TC-OF-15, TC-OF-18, TC-OF-23 … TC-OF-25, TC-SE-13, TC-SE-43 … TC-SE-44, TC-API-06 … TC-API-09, TC-MIG-04 … TC-MIG-05 | I |
| REQ-AI-1 | — | Out of v1 scope (AI phase) |
| REQ-AI-2 | — | Out of v1 scope (AI phase) |
| REQ-AI-3 | — | Out of v1 scope (AI phase) |
| REQ-AI-4 | — | Out of v1 scope (post-launch payments, ADR-28; ID retained) |
| REQ-AI-5 | — | Out of v1 scope (AI phase) |
| REQ-EX-1 | TC-EX-01 | M (see §2.1) |
| REQ-MT-1 [v1] | TC-MT-01 … TC-MT-07 | U + I + M |
| REQ-SV-1 [v1] | TC-SV-01 … TC-SV-03 | I + widget + M |

**Coverage (specified, not executed):** the older 48/54 claim is superseded by the audited totals below. The two Prompt 5 REQs are now defined: **62 v1 REQ IDs have mapped test specifications** (60 pre-Prompt-5 + REQ-MT-1 + REQ-SV-1); two v1.1 IDs have deferred cases, five REQ-AI-1…5 are out of v1, and REQ-EX-1 is review-only: **62 + 2 + 5 + 1 = 70 distinct REQ IDs**. REQ-SE-1 gains a clause and an additional test but no new REQ ID. All 46 previously mapped-but-undefined IDs now have rows in §4.6A. REQ-CK-1's unverified legal/church preset oracle is **BLOCKED (OQ-11)**, not counted as a passing case. Five tracked historical limitations remain (UT-1, UT-2, UT-7…9); UT-3…6 and UT-10…11 have executable redirects. Authored cases are not passing implementation tests until code exists.

### 2.0 Phase 06 evidence ledger — scoped, not a release verdict

| Existing TC / gate | Source-level implementation and possible local evidence | What is **not** established by that evidence |
|---|---|---|
| TC-SE-45 (REQ-SE-1 cl. 9) | `auth_repository_test.dart` uses a fake gateway for the unchecked 18+ block; SCR-01 widget tests exercise form behaviour. `test/api/identity/test_identity.py` models verified-email RPC denial using synthetic local Auth accounts. | A checked declaration does not prove legal consent; the SCR-01 notice is a synthetic-only placeholder. No counsel review, production confirmation setting, platform accessibility verdict or real verification email round trip is established. |
| TC-PLT-03 (REQ-PLT-3) | Local synthetic identity test rejects a second membership. Async client membership lookup and loading/error guards replace the constant-false stub; focused router tests passed. | SCR-03 remains a placeholder and there is no client-side named-existing-plan message. Full TC-PLT-03 remains open. |
| TC-SE-23 and TC-SE-42 (REQ-SE-1 cl. 3–8) | Eleven local synthetic identity tests passed after a clean disposable-local migration replay, including hash-only issue, seven-day expiry, accept/revoke/single-use and concurrent joins. SCR-02 parser uses the matching 32-character lowercase-hex format; focused fake-backed widget/router tests cover Decline without mutation and blocking invitation acceptance when membership exists or is unknown. | Start/Join is reachable, but Start cannot yet create a plan; invitation summary, distinct server-error UI parity, first replay/identical overrides, verified post-accept dashboard navigation, and re-pair after reinstall are unproven. A fake-widget parity check is not an end-to-end invite verdict. |
| TC-SEC-01/04/05/06 and TC-API-05 (identity subset) | Local identity tests exercised forced RLS on five identity tables, denied direct mutation and foreign-plan list reads. A rebuilt disposable-local instance applied migration `0001` from an empty volume and all 11 tests passed afterward. | No full v1 table inventory, sync-endpoint negative matrix, proven equivalence between foreign and nonexistent list responses, or deployed CI. **No TC-SEC-01 gate PASS.** |

**Execution evidence rule:** A TC row is a specified oracle, a test file present in the working tree is runnable coverage, and a dated command log with exit status is an execution result. The results in this ledger cover 11 local synthetic identity tests (also rerun after clean local migration replay), 126 Flutter tests including the older Edge stub contracts and new router/invite widgets, and clean analysis. Record command, environment (fake widget vs local Supabase vs physical device vs staging), migration version and exercised clauses for each run. These local results do not establish stage/prod email confirmation, hardware secure storage/backup, cross-platform E2E, full tenant isolation or real-couple beta.

### 2.1 Untestable-as-written and resolved testability gaps

UT-1, UT-2, and UT-7…9 remain static/manual, unresolved, or meta-level limitations. UT-3…6 and UT-10…11 have been resolved without reusing their IDs and now redirect to executable tests (UT-10…11 in §4.4/§4.7). None is silently dropped.

| # | Requirement | Limitation or resolution | Verification / next action |
|---|---|---|---|
| UT-1 | **REQ-GEN-1** | "SHALL NOT use binary floating-point" is not observable at runtime — by the time a value is wrong, the type is already gone. No behavioural assertion exists. | Reword as a static-analysis obligation. Covered by TC-GEN-01 (lint), which is the only honest verification. |
| UT-2 | **REQ-AE-2 cl. 3** (budget adequacy indicator) | Depends on `reference_costs`, which is **unpopulated** (OQ-04). Expected total cost is not computable, so no expected value can be asserted. | Populate reference costs per region tier. **TC-AE-07 is authored but BLOCKED with no assertion** — same discipline as ADR-26. |
| UT-3 | **REQ-LG-1 cl. 8** | **Resolved (ADR-33).** Hard 2,000-character limit; input stops and live counter displays. | TC-LG-14. |
| UT-4 | **REQ-SE-5 cl. 7** | **Resolved (ADR-32, OQ-05 closed).** Seven-day expiry. | TC-SE-31. |
| UT-5 | **REQ-GM-1 cl. 6** | **Resolved (ADR-31).** New plans default the driving RSVP status to `invited`. | TC-GM-14. |
| UT-6 | **REQ-SE-6 cl. 7** | **Resolved (ADR-34).** Local wipe offer is mandatory on learning of removal; enforceable force-wipe remains open (OQ-03). | TC-SE-32. |
| UT-7 | **REQ-OF-1 cl. 4** ("IF an operation cannot complete offline, THEN it is a defect") | Meta-statement about the process, not system behaviour. Not a testable assertion. | Move to the testing/defect policy (it now lives in §9). |
| UT-8 | **REQ-PLT-2 cl. 4** (engine is SQLite via drift/sqflite) | A build fact, not a behaviour. | Verify by dependency inspection (folded into TC-PLT-01). |
| UT-9 | **REQ-EX-1** (no marketplace/directory/reviews/booking) | Proving the *absence* of a feature cannot be done by automated test; a passing suite proves nothing about what is not there. | TC-EX-01 is a structured code/UI review checklist, explicitly manual. |

---

## 3. Calculation fixtures

**These are the authority for expected values.** Tests assert against these hand-computed numbers, never against whatever the implementation returns.

**Specified here, not yet committed as test data.** In phase 07, implement `test/fixtures/FIX-A.json` through `FIX-E.json` as version-controlled, human-readable inputs for the domain tests. No JSON fixture or test code is created by this spec-only revision. **Changing any FIX-A/B/C expected value requires an explicit justification in the PR description**, naming the requirement or ADR that changed. The figures in this document are the authority; code conforms to them.

### 3.0 Rules applied to all five fixtures

Stated once here, applied identically everywhere (this is the rounding-drift guard of §4):

1. **Storage:** all money as integer centavos (REQ-GEN-1). ₱2,400.00 → `240000`.
2. **Rounding:** half-up to 2 dp, applied **only at display** (REQ-GEN-2). Intermediate arithmetic never rounds.
3. **Allocation:** baseline percentages from ADR-10 — Catering & Venue 40, Photo & Video 15, Attire & Styling 10, Coordination 10, Entourage & Misc 5, Buffer 20. Rounding remainder → Buffer (REQ-AE-1 cl. 6).
4. **Regional index does NOT change allocation shares** (ADR-11, REQ-AE-2 cl. 1). Metro 1.00 / Provincial 0.85 / Destination 1.20 affect *expected total cost* and *rate suggestions* only. Per-category skew defaults to 1.0, so **all five fixtures produce identical allocation percentages despite different regions.** A naive implementation that scales shares by the index will fail TC-AE-05 — that is the point.
5. **Net out-of-pocket = gross − eligible receipt amounts** (ADR-22 / D2, ADR-37–39); partial and withdrawn pledges' received portions count. The unreceived remainder of active tentative/confirmed pledges is *expected*; confirmed remaining is exposure. Gifts reduce only the separate net-after-gifts figure.
6. **Crew meals never scale with guest count** (REQ-GM-4). They scale with crew headcount only.
7. **Buffer remaining** = Buffer allocation − Σ overruns of non-Buffer categories. Under-spend in one category does **not** offset an overrun in another (REQ-AE-6 cl. 3).
8. **Category mapping of hidden fees (REQ-HF-2 cl. 9):** crew meals, church aircon, corkage, venue power → Catering & Venue. OOT fees, overtime → Coordination. Category labels are read-only.
9. **Expected total cost / budget adequacy is NOT asserted in any fixture** — `reference_costs` is unpopulated (OQ-04, UT-2).
10. Earlier fixtures' displayed `received` statuses are interpreted as exactly one receipt of the listed value, not an editable status; they contain no schedule and therefore use a virtual undated balance. If old fixture data includes a deposit, translate it to one payment row of the same amount. Their numeric expected outputs stay unchanged. Ceremony and venue labels are optional hints only.

---

### 3.1 FIX-A — NCR church + hotel reception

| Input | Value |
|---|---|
| Region | NCR (Metro tier, index 1.00) |
| Total budget | ₱800,000.00 |
| Guest count (driving) | 150 |
| Guest cap | 160 |
| Ceremony | Church (aircon) |
| Venue | Hotel |
| OOT | Dismissed (all suppliers metro-based) |

**Allocation** (₱800,000 × baselines; no remainder):

| Category | % | Allocated |
|---|---|---|
| Catering & Venue | 40 | ₱320,000.00 |
| Photo & Video | 15 | ₱120,000.00 |
| Attire & Styling | 10 | ₱80,000.00 |
| Coordination | 10 | ₱80,000.00 |
| Entourage & Misc | 5 | ₱40,000.00 |
| Buffer | 20 | ₱160,000.00 |
| **Total** | **100** | **₱800,000.00** |

**Line items**

| Item | Mode | Rate / amount | Amount | Category |
|---|---|---|---|---|
| Reception catering | **per-head** | ₱2,400 × 150 | ₱360,000.00 | Catering & Venue |
| Guest favors | **per-head** | ₱120 × 150 | ₱18,000.00 | Entourage & Misc |
| Invitations | **per-head** | ₱80 × 150 | ₱12,000.00 | Entourage & Misc |
| Church fee | flat | — | ₱15,000.00 | Catering & Venue |
| **Church aircon fee** (HF) | flat | — | ₱8,000.00 | Catering & Venue |
| Photo & video package | flat | — | ₱95,000.00 | Photo & Video |
| HMUA | flat | — | ₱25,000.00 | Attire & Styling |
| Gown + suit | flat | — | ₱45,000.00 | Attire & Styling |
| Coordination (on-the-day) | flat | — | ₱55,000.00 | Coordination |
| Lights & sound | flat | — | ₱30,000.00 | Coordination |
| Cake | flat | — | ₱12,000.00 | Entourage & Misc |
| **Corkage** (HF) | flat | cake ₱3,000 + wine ₱2,500 | ₱5,500.00 | Catering & Venue |
| **Crew meals** (HF) | flat | 18 crew × ₱350 | ₱6,300.00 | Catering & Venue |
| Overtime (HF) | — | dismissed | ₱0.00 | — |
| Venue power (HF) | — | dismissed (hotel) | ₱0.00 | — |

**Crew-meal headcount rollup** — photo/video 6 + HMUA 3 + coordination 5 + lights & sound 4 = **18 crew**.

**Pledges**

| Sponsor | Role | Amount | State |
|---|---|---|---|
| Ninong Ramon | Ninong | ₱50,000.00 | **received** (one ₱50,000 receipt) |
| Ninang Cora | Ninang | ₱30,000.00 | confirmed |
| Tita Mila | family | ₱20,000.00 | tentative |

**Expected outputs — FIX-A @ 150 guests**

| Figure | Expected |
|---|---|
| Gross event total | **₱686,800.00** |
| Net out-of-pocket | **₱636,800.00** |
| Expected pledge support | **₱50,000.00** |
| Outstanding exposure | **₱30,000.00** |
| Per-head cost | **₱4,578.67** |
| Buffer remaining | **₱78,200.00** (48.9%) |
| Over budget? | No — ₱113,200.00 under |
| Over cap? | No (150 ≤ 160) |

**Category variance @ 150**

| Category | Allocated | Actual | Variance |
|---|---|---|---|
| Catering & Venue | ₱320,000.00 | ₱394,800.00 | **+₱74,800.00 over** |
| Photo & Video | ₱120,000.00 | ₱95,000.00 | −₱25,000.00 under |
| Attire & Styling | ₱80,000.00 | ₱70,000.00 | −₱10,000.00 under |
| Coordination | ₱80,000.00 | ₱85,000.00 | **+₱5,000.00 over** |
| Entourage & Misc | ₱40,000.00 | ₱42,000.00 | **+₱2,000.00 over** |
| Buffer | ₱160,000.00 | ₱0.00 | −₱160,000.00 |

#### FIX-A worked arithmetic — check this by hand

```
PER-HEAD SUBTOTAL (150 guests)
  catering      2,400 × 150 = 360,000
  favors          120 × 150 =  18,000
  invitations      80 × 150 =  12,000
                              -------
                              390,000
  (sum of per-head rates = 2,400 + 120 + 80 = 2,600 /guest)

FLAT SUBTOTAL
  church fee                   15,000
  church aircon                 8,000
  photo & video                95,000
  HMUA                         25,000
  attire                       45,000
  coordination                 55,000
  lights & sound               30,000
  cake                         12,000
  corkage (3,000 + 2,500)       5,500
  crew meals (18 × 350)         6,300
                              -------
                              296,800

GROSS = 390,000 + 296,800 = 686,800

CATEGORY ROLLUP
  Catering & Venue  360,000 + 15,000 + 8,000 + 5,500 + 6,300 = 394,800
  Photo & Video                                                 95,000
  Attire & Styling  45,000 + 25,000                           =  70,000
  Coordination      55,000 + 30,000                           =  85,000
  Entourage & Misc  18,000 + 12,000 + 12,000                  =  42,000
  Buffer                                                            0
  check: 394,800 + 95,000 + 70,000 + 85,000 + 42,000 = 686,800  ✓

BUFFER DRAWDOWN (under-spend does NOT offset)
  overruns = 74,800 (Catering) + 5,000 (Coordination) + 2,000 (Entourage)
           = 81,800
  buffer remaining = 160,000 − 81,800 = 78,200
  as % of buffer   = 78,200 / 160,000 = 0.48875 → 48.9%

PLEDGE MATH (D2: only 'received' reduces net)
  received  = 50,000
  net       = 686,800 − 50,000 = 636,800
  expected  = 30,000 (confirmed) + 20,000 (tentative) = 50,000
  exposure  = 30,000 (confirmed, not received)

PER-HEAD COST (display metric)
  686,800 / 150 = 4,578.6666… → half-up → 4,578.67
```

**Expected outputs — FIX-A after "add 25 guests" (150 → 175)**

| Figure | Expected | Δ |
|---|---|---|
| Gross event total | **₱751,800.00** | +₱65,000.00 |
| Net out-of-pocket | **₱701,800.00** | +₱65,000.00 |
| Marginal cost per added guest | **₱2,600.00** | = sum of per-head rates |
| Per-head cost | **₱4,296.00** | exact, no rounding |
| Buffer remaining | **₱13,200.00** (8.25%) | −₱65,000.00 |
| Crew meals | **₱6,300.00 — UNCHANGED** | REQ-GM-4 |
| Over cap? | **YES** (175 > 160) | over-cap indicator fires |

```
  catering    2,400 × 175 = 420,000
  favors        120 × 175 =  21,000
  invitations    80 × 175 =  14,000   → per-head 455,000
  flat unchanged                       → 296,800
  GROSS = 455,000 + 296,800 = 751,800
  Δgross = 751,800 − 686,800 = 65,000 ; 65,000 / 25 = 2,600 /guest ✓
  per-head cost = 751,800 / 175 = 4,296.00 exactly ✓
  overruns: Catering 454,800−320,000 = 134,800 ; Coordination 5,000 ; Entourage 7,000
  buffer remaining = 160,000 − 146,800 = 13,200
```

---

### 3.2 FIX-B — Boracay destination with OOT fees

| Input | Value |
|---|---|
| Region | Boracay / Aklan (**Destination** tier, index 1.20) |
| Total budget | ₱1,400,000.00 |
| Guest count (driving) | 80 |
| Guest cap | 100 |
| Ceremony | Beach (church aircon **dismissed**) |
| OOT | **Enabled** — 4 Manila-based suppliers |

**Allocation** — identical percentages to FIX-A despite the 1.20 index (rule 4):

| Category | % | Allocated |
|---|---|---|
| Catering & Venue | 40 | ₱560,000.00 |
| Photo & Video | 15 | ₱210,000.00 |
| Attire & Styling | 10 | ₱140,000.00 |
| Coordination | 10 | ₱140,000.00 |
| Entourage & Misc | 5 | ₱70,000.00 |
| Buffer | 20 | ₱280,000.00 |

**Line items**

| Item | Mode | Rate / amount | Amount | Category |
|---|---|---|---|---|
| Resort reception catering | **per-head** | ₱3,800 × 80 | ₱304,000.00 | Catering & Venue |
| Guest favors | **per-head** | ₱250 × 80 | ₱20,000.00 | Entourage & Misc |
| Invitations | **per-head** | ₱150 × 80 | ₱12,000.00 | Entourage & Misc |
| Resort venue fee | flat | — | ₱180,000.00 | Catering & Venue |
| Photo & video | flat | — | ₱150,000.00 | Photo & Video |
| HMUA | flat | — | ₱45,000.00 | Attire & Styling |
| Attire | flat | — | ₱120,000.00 | Attire & Styling |
| Coordination | flat | — | ₱90,000.00 | Coordination |
| Lights & sound | flat | — | ₱60,000.00 | Coordination |
| Cake | flat | — | ₱20,000.00 | Entourage & Misc |
| **Corkage** (HF) | flat | wine ₱8,000 + lechon ₱5,000 | ₱13,000.00 | Catering & Venue |
| **Church aircon** (HF) | — | **dismissed** (beach) | ₱0.00 | — |
| **Venue power** (HF) | flat | genset for beach setup | ₱35,000.00 | Catering & Venue |
| **Crew meals** (HF) | flat | 22 crew × ₱500 | ₱11,000.00 | Catering & Venue |
| **OOT fees** (HF) | flat | 4 suppliers, see below | ₱137,500.00 | Coordination |

**Crew rollup** — photo/video 6 + HMUA 4 + coordination 6 + lights & sound 6 = **22 crew** × ₱500 = ₱11,000.

**OOT breakdown** (travel / lodging / per-diem per supplier)

| Supplier | Travel | Lodging | Per-diem | Subtotal |
|---|---|---|---|---|
| Photo & video | ₱24,000 | ₱16,000 | ₱6,000 | ₱46,000.00 |
| HMUA | ₱12,000 | ₱8,000 | ₱3,000 | ₱23,000.00 |
| Coordination | ₱18,000 | ₱12,000 | ₱4,500 | ₱34,500.00 |
| Lights & sound | ₱20,000 | ₱10,000 | ₱4,000 | ₱34,000.00 |
| **Total** | | | | **₱137,500.00** |

**Pledges**

| Sponsor | Role | Amount | State |
|---|---|---|---|
| Ninong Eduardo | Ninong | ₱150,000.00 | **received** (one ₱150,000 receipt) |
| Ninang Rosa | Ninang | ₱100,000.00 | confirmed |
| Groom's parents | family | ₱200,000.00 | **received** (one ₱200,000 receipt) |

**Expected outputs — FIX-B**

| Figure | @ 80 guests | @ 105 (+25) |
|---|---|---|
| Gross event total | **₱1,197,500.00** | **₱1,302,500.00** |
| Net out-of-pocket | **₱847,500.00** | **₱952,500.00** |
| Expected pledge support | **₱100,000.00** | ₱100,000.00 |
| Outstanding exposure | **₱100,000.00** | ₱100,000.00 |
| Per-head cost | **₱14,968.75** | **₱12,404.76** |
| Buffer remaining | **₱107,500.00** (38.4%) | **₱29,500.00** (10.5%) |
| Marginal per added guest | — | **₱4,200.00** |
| OOT total | ₱137,500.00 | **₱137,500.00 — UNCHANGED** |
| Crew meals | ₱11,000.00 | **₱11,000.00 — UNCHANGED** |
| Over cap? | No | **YES** (105 > 100) |

Category actuals @ 80: Catering & Venue ₱543,000 (under 17,000) · Photo & Video ₱150,000 (under 60,000) · Attire & Styling ₱165,000 (**over 25,000**) · Coordination ₱287,500 (**over 147,500**) · Entourage & Misc ₱52,000 (under 18,000). Overruns 172,500 → buffer 280,000 − 172,500 = **107,500**.

**Why FIX-B matters:** OOT fees push Coordination to 205% of its allocation while three other categories sit under. It is the fixture that proves under-spend does not offset overrun in buffer drawdown (rule 7), and that OOT is per-supplier and therefore guest-count-invariant.

---

### 3.3 FIX-C — Province wedding, heavy Ninong/Ninang pledges

| Input | Value |
|---|---|
| Region | Iloilo (**Provincial** tier, index 0.85) |
| Total budget | ₱500,000.00 |
| Guest count (driving) | 300 |
| Guest cap | 320 |
| Ceremony | Church (aircon) |
| Venue | Garden (genset needed) |
| OOT | Dismissed (local suppliers) |

**Allocation:** Catering & Venue ₱200,000 · Photo & Video ₱75,000 · Attire & Styling ₱50,000 · Coordination ₱50,000 · Entourage & Misc ₱25,000 · Buffer ₱100,000. (Again: same percentages, 0.85 index does not alter shares.)

**Line items**

| Item | Mode | Rate / amount | Amount | Category |
|---|---|---|---|---|
| Catering | **per-head** | ₱850 × 300 | ₱255,000.00 | Catering & Venue |
| Guest favors | **per-head** | ₱60 × 300 | ₱18,000.00 | Entourage & Misc |
| Invitations | **per-head** | ₱40 × 300 | ₱12,000.00 | Entourage & Misc |
| Church fee | flat | — | ₱8,000.00 | Catering & Venue |
| **Church aircon fee** (HF) | flat | — | ₱12,000.00 | Catering & Venue |
| Photo & video | flat | — | ₱55,000.00 | Photo & Video |
| HMUA | flat | — | ₱18,000.00 | Attire & Styling |
| Attire | flat | — | ₱35,000.00 | Attire & Styling |
| Coordination | flat | — | ₱30,000.00 | Coordination |
| Lights & sound | flat | — | ₱25,000.00 | Coordination |
| Cake | flat | — | ₱8,000.00 | Entourage & Misc |
| **Corkage** (HF) | flat | lechon ₱4,000 + cake ₱2,000 | ₱6,000.00 | Catering & Venue |
| **Crew meals** (HF) | flat | 15 crew × ₱250 | ₱3,750.00 | Catering & Venue |
| **Venue power** (HF) | flat | garden genset | ₱10,000.00 | Catering & Venue |

**Crew rollup** — photo/video 5 + HMUA 2 + coordination 4 + lights & sound 4 = **15 crew** × ₱250 = ₱3,750.

**Pledges — 7 pledges, ₱305,000 total pledged, mixed states**

| Sponsor | Role | Amount | State |
|---|---|---|---|
| Ninong Pedro | Ninong | ₱80,000.00 | **received** (one ₱80,000 receipt) |
| Ninong Andres | Ninong | ₱60,000.00 | confirmed |
| Ninang Luz | Ninang | ₱50,000.00 | **received** (one ₱50,000 receipt) |
| Ninang Baby | Ninang | ₱40,000.00 | tentative |
| Bride's uncle | family | ₱30,000.00 | **received** (one ₱30,000 receipt) |
| Groom's aunt | family | ₱25,000.00 | confirmed |
| Cousin (item: mobile bar) | family | ₱20,000.00 | tentative |

Received ₱160,000 · Confirmed ₱85,000 · Tentative ₱60,000 · **Total pledged ₱305,000**

**Expected outputs — FIX-C**

| Figure | @ 300 guests | @ 325 (+25) |
|---|---|---|
| Gross event total | **₱495,750.00** | **₱519,500.00** |
| Net out-of-pocket | **₱335,750.00** | **₱359,500.00** |
| Expected pledge support | **₱145,000.00** | ₱145,000.00 |
| Outstanding exposure | **₱85,000.00** | ₱85,000.00 |
| Per-head cost | **₱1,652.50** | **₱1,598.46** |
| Buffer remaining | **−₱15,750.00 (−15.75%) → BREACH** | **−₱39,500.00 (−39.5%) → BREACH** |
| Over budget? | No (₱4,250 under) | **YES — over by ₱19,500.00** |
| Marginal per added guest | — | **₱950.00** |
| Over cap? | No | **YES** (325 > 320) |

**FIX-C is the D2 regression fixture.** Three plausible implementations give three different answers; only one is correct:

```
  gross = 495,750

  ✗ WRONG (all pledges count):        495,750 − 305,000 = 190,750
  ✗ WRONG (pre-D2: confirmed+received): 495,750 − 245,000 = 250,750
  ✓ CORRECT (D2: received only):       495,750 − 160,000 = 335,750
```

A ₱145,000 spread between the correct answer and the pre-D2 answer. If TC-PL-19 asserts 335,750 and the code returns 250,750, the D2 decision was not implemented. This is the highest-value single assertion in the suite.

**FIX-C also exercises the budget-breach path.** Overruns @ 300: Catering & Venue +94,750, Attire & Styling +3,000, Coordination +5,000, Entourage & Misc +13,000 = 115,750 against a ₱100,000 buffer → buffer remaining **−₱15,750**, so REQ-AE-6 cl. 5 breach indicator must fire. It is the only fixture with a negative buffer.

### 3.4 FIX-D — Batangas garden wedding; money-flow regression

**All prices below are couple-supplied illustrative fixture inputs, not regional benchmarks or app recommendations.** Fixed evaluation date **2026-10-02**; budget ₱350,000.00; Batangas / Provincial 0.85; garden/beach officiant and garden venue supply hint copy only. All six fee prompts explicitly dismissed in this fixture (zero gross contribution). Guest count 100; cap 120. No cost-adequacy assertion (OQ-04).

| Category | Allocated (₱350,000 × baseline) | Live ledger entries and effective cost |
|---|---:|---|
| Catering & Venue | ₱140,000.00 | Garden venue ₱120,000.00; catering ₱80,000.00 |
| Photo & Video | ₱52,500.00 | Photo ₱50,000.00 |
| Attire & Styling | ₱35,000.00 | Attire ₱40,000.00 |
| Coordination | ₱35,000.00 | Coordination ₱15,000.00 |
| Entourage & Misc | ₱17,500.00 | Favors ₱5,000.00 |
| Buffer | ₱70,000.00 | No entry |

The **garden venue** estimate is ₱125,000.00, actual ₱120,000.00 after a ₱5,000.00 discount; the actual, not a negative ledger adjustment, sets effective cost. Three dated schedule items total its effective ₱120,000.00:

| Item (due-date allocation order) | Due | Scheduled | Allocated from net venue payment ₱60,000 | Derived item state @ 2026-10-02 |
|---|---:|---:|---:|---|
| Reservation | 2026-07-01 | ₱20,000.00 | ₱20,000.00 | Paid |
| Downpayment | 2026-08-01 | ₱40,000.00 | ₱40,000.00 | Paid |
| Balance | 2026-09-01 | ₱60,000.00 | ₱0.00 | Overdue (₱60,000 outstanding) |

Venue payment rows: partner A pays ₱30,000.00 on July 1 (attributed to reservation); partner B pays ₱35,000.00 on August 1 (attributed to balance, **but allocation still follows due-date order**); a ₱5,000.00 positive `refund` row on August 15 reverses paid amount. Separate attire entry ₱40,000.00 is paid directly by its sponsor on September 1 through **one atomic ₱40,000 receipt + ₱40,000 payment pair**; receipt.payment_id uniquely identifies the payment, which also has paid_by_pledge_id. Other entries have no schedule and a virtual undated balance.

Pledges: confirmed cash ₱50,000.00 with one ₱20,000.00 cash receipt (partial); withdrawn cash ₱30,000.00 with one earlier ₱10,000.00 cash receipt (history retained, ₱20,000.00 promise excluded); confirmed in-kind attire ₱40,000.00 with one linked ₱40,000.00 sponsor-direct receipt/payment pair, derived received. Day-of gifts: sobre ₱25,000.00 and money dance ₱15,000.00, separate from pledges.

**Expected outputs (integer-centavo arithmetic, shown here as whole pesos with .00):**

| Figure | Expected |
|---|---:|
| Gross | **₱310,000.00** |
| Derived deposits paid (all entries) | **₱100,000.00** |
| Outstanding balance due | **₱210,000.00** |
| Net out-of-pocket | **₱240,000.00** |
| Remaining expected pledge support | **₱30,000.00** |
| Outstanding confirmed exposure | **₱30,000.00** |
| Gifts total | **₱40,000.00** |
| Net after gifts | **₱200,000.00** |
| Gift total less outstanding balances | **−₱170,000.00** (shortfall) |
| Buffer remaining | **₱5,000.00** (₱65,000 non-Buffer overruns) |
| Budget position | **₱40,000.00 under** |

```
Allocation: 350,000 × (40%, 15%, 10%, 10%, 5%, 20%)
          = 140,000 + 52,500 + 35,000 + 35,000 + 17,500 + 70,000 = 350,000.
Gross: (120,000 + 80,000) + 50,000 + 40,000 + 15,000 + 5,000 = 310,000.
Venue deposit paid: 30,000 + 35,000 − 5,000 refund = 60,000;
  20,000 reservation + 40,000 downpayment paid; 60,000 balance overdue.
Sponsor-paid attire: 40,000 payment reduces attire balance to zero;
  paired 40,000 receipt reduces net once; it is NOT another 40,000 net subtraction.
All deposit paid: 60,000 venue + 40,000 attire = 100,000.
Balance due: (120,000 − 60,000) + 80,000 + 50,000 + (40,000 − 40,000)
           + 15,000 + 5,000 = 210,000.
Eligible pledge receipts: 20,000 partial cash + 10,000 withdrawn-history cash
                        + 40,000 in-kind = 70,000.
Net: 310,000 − 70,000 = 240,000 (not 200,000 by double-subtracting sponsor payment).
Expected/exposure: (50,000 − 20,000) + 0 withdrawn + (40,000 − 40,000) = 30,000.
Gifts: 25,000 + 15,000 = 40,000; net after gifts = 240,000 − 40,000 = 200,000.
Reconcile: 40,000 gifts − 210,000 remaining balances = −170,000 (shortfall).
Buffer: 70,000 − max(0, 200,000 − 140,000) − max(0, 40,000 − 35,000)
        = 70,000 − 60,000 − 5,000 = 5,000.
Budget headroom: 350,000 − 310,000 = 40,000.
```

### 3.4A FIX-E — sub-₱30K civil wedding (new additive fixture)

**All rates and amounts are couple-entered illustrative test operands, not a price recommendation or reference-cost benchmark.** Civil ceremony; 20 invited driving guests, guest cap 25; regional selection NCR (index 1.00). Budget **₱28,000.00 = 2,800,000 centavos**, accepted without a minimum-price warning (REQ-BS-1 cl. 3). Ceremony civil only changes church-aircon hint copy. All six hidden-fee decisions are explicitly dismissed with actor/time, each contributes zero; no prompt was silently initialized to ₱0. There is no expected-total-cost or legal-fee assertion (OQ-04/OQ-11). No starter-template suggestion creates an amount.

| Category | Allocation (centavos) | Peso display | Live entries (centavos) |
|---|---:|---:|---|
| Catering & Venue | 1,120,000 | ₱11,200.00 | User-entered catering rate 35,000 × 20 guests = 700,000; venue 200,000 |
| Photo & Video | 420,000 | ₱4,200.00 | Photo 300,000 |
| Attire & Styling | 280,000 | ₱2,800.00 | Attire 250,000 |
| Coordination | 280,000 | ₱2,800.00 | Coordination 200,000 |
| Entourage & Misc | 140,000 | ₱1,400.00 | Favors rate 5,000 × 20 guests = 100,000 |
| Buffer | 560,000 | ₱5,600.00 | None |
| **Total** | **2,800,000** | **₱28,000.00** | **Gross 1,750,000** |

One confirmed cash pledge has value **300,000 centavos / ₱3,000.00**, with one recorded partial receipt **100,000 centavos / ₱1,000.00**. No other pledge, gift, deposit or payment. A pledge receipt is not a fabricated payment. The remaining confirmed portion is expected support and exposure; it does not reduce net until received.

| Expected figure | 20 guests | After preview/commit +5 → 25 guests |
|---|---:|---:|
| Gross | **1,750,000 / ₱17,500.00** | **1,950,000 / ₱19,500.00** |
| Net out-of-pocket | **1,650,000 / ₱16,500.00** | **1,850,000 / ₱18,500.00** |
| Remaining expected / confirmed exposure | **200,000 / ₱2,000.00** each | **200,000 / ₱2,000.00** each |
| Per-head cost | **87,500 / ₱875.00** | **78,000 / ₱780.00** |
| Marginal per added guest | — | **40,000 / ₱400.00** |
| Buffer remaining | **560,000 / ₱5,600.00 (100%)** | **560,000 / ₱5,600.00 (100%)** |
| Under budget | **1,050,000 / ₱10,500.00** | **850,000 / ₱8,500.00** |
| Over cap | No (20 ≤ 25) | No (25 ≤ 25) |

```text
All amounts below are integer centavos; divide by 100 ONLY for peso display.
allocation = 2,800,000 × [40,15,10,10,5,20] / 100
           = [1,120,000,420,000,280,000,280,000,140,000,560,000]; sum 2,800,000.
base gross = (35,000×20 + 200,000) + 300,000 + 250,000 + 200,000 + 5,000×20
           = 900,000 + 300,000 + 250,000 + 200,000 + 100,000 = 1,750,000.
net = 1,750,000 − 100,000 eligible receipt = 1,650,000.
expected = exposure = 300,000 − 100,000 = 200,000.
overruns = sum(max(0, live_category − allocation_category)) = 0;
buffer = 560,000 − 0 = 560,000; headroom = 2,800,000 − 1,750,000 = 1,050,000.
+5 gross = (35,000×25 + 200,000) + 300,000 + 250,000 + 200,000 + 5,000×25
         = 1,075,000 + 300,000 + 250,000 + 200,000 + 125,000 = 1,950,000.
+5 net = 1,950,000 − 100,000 = 1,850,000; delta gross = 200,000;
marginal = 200,000 / 5 = 40,000; per-head = 1,950,000 / 25 = 78,000.
All five categories remain within allocation; buffer stays 560,000.
```

### 3.5 Fixture test IDs

| TC ID | Asserts | Level |
|---|---|---|
| TC-FIX-A1 | FIX-A @ 150: all figures in the expected table | U |
| TC-FIX-A2 | FIX-A @ 175 after +25 guests, incl. crew meals unchanged | U |
| TC-FIX-B1 | FIX-B @ 80: all figures, incl. identical allocation % to FIX-A | U |
| TC-FIX-B2 | FIX-B @ 105, incl. OOT and crew meals unchanged | U |
| TC-FIX-C1 | FIX-C @ 300: all figures, incl. negative buffer / breach | U |
| TC-FIX-C2 | FIX-C @ 325, incl. over-budget and over-cap | U |
| TC-FIX-D1 | FIX-D all expected figures, three schedule allocations, refund, overdue balance, partial/withdrawn/in-kind receipts, and gifts at the fixed evaluation date | U |
| TC-FIX-E1 | FIX-E @ 20 and @ 25: exact centavo allocation, gross/net, remaining support/exposure, per-head and marginal cost, buffer/headroom, no invented price or fee; civil hints never dismiss a fee automatically | U + I |
| TC-PL-19 | FIX-C net = ₱335,750.00 exactly; explicitly not 250,750 or 190,750 | U |
| TC-AE-05 | FIX-A / FIX-B / FIX-C / FIX-D / FIX-E allocation percentages are identical | U |

### 3.6 Prompt 4 worked examples — append-only overlays (not edits to FIX-A/B/C/D)

These are **planned test oracles**, evaluated on a copy of the named fixture. None changes the original fixture inputs or expected tables above; in particular a rebalance preview never changes original FIX-C's negative buffer result until the couple explicitly applies overrides. Values below are integer centavos; displayed pesos are merely formatting.

**Overlay P4-C: explicit FIX-C rebalance at 300 guests (TC-AE-16).** Original allocation in category order = `[20,000,000, 7,500,000, 5,000,000, 5,000,000, 2,500,000, 10,000,000]` centavos; corresponding committed effective costs = `[29,475,000, 5,500,000, 5,300,000, 5,500,000, 3,800,000, 0]`. No override is locked. Unlocked recipient needs = `[9,475,000, 0, 300,000, 500,000, 1,300,000]` = `11,575,000` centavos; Buffer first contributes `10,000,000` in category order: Catering `9,475,000`, Attire `300,000`, Coordination `225,000`; remaining Coordination `275,000` + Entourage `1,300,000` = `1,575,000`. Photo has `2,000,000` slack and is the only unlocked donor, so supplies all `1,575,000`. Final allocations = `[29,475,000, 5,925,000, 5,300,000, 5,500,000, 3,800,000, 0]` centavos = **₱294,750 / ₱59,250 / ₱53,000 / ₱55,000 / ₱38,000 / ₱0**, summing exactly **₱500,000**. After Apply, each category meets its commitment; Buffer remaining is ₱0. Original gross ₱495,750 and net ₱335,750 remain unchanged. Preview/cancel leaves original FIX-C allocation and original −₱15,750 buffer remaining unchanged.

**Overlay P4-C-lock: feasible partial, not a false fit (TC-AE-17/18).** On a fresh FIX-C copy, manually lock Photo at its original ₱75,000. All allocations still sum to ₱500,000. Buffer supplies ₱100,000 as above; Photo cannot donate. Preview final `[29,475,000, 7,500,000, 5,300,000, 5,225,000, 2,500,000, 0]` centavos (sum `50,000,000`) and identifies uncovered Coordination `275,000` + Entourage `1,300,000` = **1,575,000 centavos / ₱15,750**. Applying this feasible partial leaves the locked Photo amount unchanged and the breach visible. If instead all six locked overrides sum to `50,000,001` centavos for a ₱500,000 budget, Apply is disabled, with the one-cent discrepancy shown; no normalization or override write occurs.

**Overlay P4-cent: largest remainder and stable tie (TC-AE-19).** Synthetic integer-centavo algorithm probe (not a suggested budget, price, fee or benchmark): input total `10,000`, allocations `[4000,1500,1000,1000,500,2000]` centavos; committed Catering `6003`, all other categories `0`. Buffer supplies `2000`, remaining need `3`; donor slacks Photo `1500`, Attire `1000`, Coordination `1000`, Entourage `500`, total `4000`. Proportional exact centavo quotas are `1.125, 0.75, 0.75, 0.375`; floors `1,0,0,0` leave two cents. Largest remainders award Attire then Coordination (their tie follows ADR-10 order): donor transfers `[1,1,1,0]`. Final allocations `[6003,1499,999,999,500,0]` = **10,000 centavos**, none below a committed amount. These are arithmetic test operands only, never app defaults.

**Overlay P4-A: FIX-A gross affordability, not pledged affordability (TC-GM-16/17).** Live flat effective sum = `29,680,000` centavos (₱296,800, including `630,000` crew-meal centavos); active guest rates = `240,000 + 12,000 + 8,000 = 260,000` centavos/guest (₱2,600). At buffer `0`: `floor((80,000,000 − 29,680,000)/260,000) = floor(50,320,000/260,000) = 193` remainder `140,000` centavos; gross for 193 = `79,860,000` (₱798,600), for 194 = `80,120,000` (₱801,200 > budget). With buffer-to-keep `16,000,000` centavos (₱160,000): `floor(34,320,000/260,000) = 132` exactly; gross for 132 = `64,000,000` (₱640,000), plus buffer = ₱800,000; 133 costs ₱642,600 + buffer = ₱802,600. The original cap is 160: 193 gets a separate over-cap warning rather than a ceiling of 160, while 132 does not. ₱50,000 realized and ₱50,000 expected pledges do not change either answer. FIX-A's original totals remain unchanged.

**P4 guest boundary overlays (TC-GM-18/19/20).** Starting from a copied FIX-A, set the selected buffer to `60,400,001` centavos (₱604,000.01): `80,000,000 − 29,680,000 − 60,400,001 = −10,080,001` centavos, so display ceiling `0` and zero-guest shortfall **₱100,800.01** even though no guest fits. For a distinct user-entered plan with budget `10,000` centavos, flat committed `2,000`, buffer `1,000`, and **all live per-head rates zero**, say “No per-head costs; no finite budget-based guest limit”; if flat cost is instead `10,001` centavos, also show `1,001` centavos / ₱10.01 zero-guest shortfall with that buffer. Changing a formerly per-head entry to manually valued actual moves its effective amount into flat and removes its rate from the active denominator; deleting a per-head entry does the same for the rate without inventing another. Preview only, no event or payment write.

---

## 4. Unit test areas

All run as pure Dart in `domain/` — no widget tree, no database, no network.

### 4.1 Rounding policy — stated once, applied everywhere

**Policy:** money is int64 centavos. Arithmetic never rounds. Rounding is half-up to 2 dp and happens **only** in `ui/presenters/` at the moment a value becomes a string.

**Consequence to test:** totals must never drift. A total computed as `Σ(items)` must equal the same total computed as `Σ(rounded display values)` **only when every item is already whole centavos** — and where it cannot (per-head division), the *stored* total is authoritative and the display figure is derived, never the reverse.

| TC ID | Asserts |
|---|---|
| TC-GEN-01 | Static analysis: no `double`/`num` in any money path; lint fails the build on violation (REQ-GEN-1, UT-1) |
| TC-GEN-02 | Format: `₱350,000.00`, `₱0.00`, `−₱1,200.00`; half-centavo rounds away from zero (REQ-GEN-2) |
| TC-GEN-03 | Constrained bento form: `₱350,000` below ₱1M; exactly two decimals in millions at/above — `₱1,000,000` → `₱1.00M`, `₱1,200,000` → `₱1.20M`, `₱1,259,000` → `₱1.25M` (never `₱1.26M`), and `₱999,999.99` → `₱999,999`. Negative counterparts `−₱1,259,000` → `−₱1.25M` and `−₱999,999.99` → `−₱999,999`; truncation toward zero (REQ-GEN-2A). |
| TC-GEN-04 | Constrained form never leaks: ledger rows, editors, change log, and every a11y label use the full form (REQ-GEN-2A cl. 4, 6) |
| TC-GEN-05 | **Drift guard:** summing 1,000 per-head line items then displaying equals displaying the stored total; no cent lost or gained across 1,000 iterations |

### 4.2 Allocation, normalization, overrides

| TC ID | Asserts |
|---|---|
| TC-AE-01 | Determinism: identical inputs + ruleset version → byte-identical output, 100 consecutive runs |
| TC-AE-02 | Ruleset validation: baselines summing to anything other than 10000 bp are **rejected at load** (REQ-AE-1 cl. 4) |
| TC-AE-03 | Rounding remainder assigned entirely to Buffer; Σ allocations == total budget **exactly**, tested across budgets ₱1 … ₱9,999,999 in a property test |
| TC-AE-04 | Worked example: ₱350,000 NCR → 140,000 / 52,500 / 35,000 / 35,000 / 17,500 / 70,000 |
| TC-AE-05 | **Regional index does not alter shares** — FIX-A/B/C/D/E percentages identical (ADR-11) |
| TC-AE-06 | Per-category skew *does* alter shares, and renormalises so Σ == budget exactly |
| TC-AE-07 | **BLOCKED — budget adequacy.** No assertion. `reference_costs` unpopulated (OQ-04, UT-2). Authored so the gap is visible; must not be given a guessed expected value. |
| TC-AE-08 | Ruleset pinning: publishing a new ruleset leaves existing plans numerically unchanged (REQ-AE-3 cl. 2) |
| TC-AE-09 | Every allocated figure carries a rule id + inputs; a figure with no explanation payload is not returned at all (REQ-AE-4 cl. 4) |
| TC-AE-14 | Inspect a default-skew allocation: plain-language explanation gives rule id, input budget, category baseline %, skew 1.0, and resulting amount; regional index is identified as affecting expected cost/rate suggestions, **not** allocation %. Repeat with non-default skew and assert the displayed skew and renormalised share (REQ-AE-4 cl. 2). |
| TC-AE-10 | Override preserved across recompute; revert restores engine value; reverting one does not affect another |
| TC-AE-11 | **Overrides not summing to 100%:** if Σ overrides > budget → over-allocation warning naming the excess, **and no override is silently clamped or scaled** (REQ-AE-5 cl. 4). If Σ overrides < budget, non-overridden categories absorb the remainder; if *all* six are overridden and sum < budget, the shortfall is surfaced, not silently added to Buffer |
| TC-AE-12 | Buffer drawdown incl. the FIX-C negative case; under-spend does not offset overrun |
| TC-AE-15 | With identical synced inputs, override cents and pinned bundled ruleset, two devices derive identical `engine_cents` and explanations on read; inspect log/server schema to verify neither engine output nor explanation is authoritative or synced. Reverting writes only a null override (REQ-AE-5 cl. 7, ADR-46). |

### 4.3 Per-head vs flat-rate, crew rollups

| TC ID | Asserts |
|---|---|
| TC-GM-04 | Per-head entry derives `rate × driving count`; flat entry invariant to every guest count |
| TC-GM-05 | Setting `actual` on a per-head entry sets `manually_valued` and stops recomputation (REQ-GM-2 cl. 5) |
| TC-GM-07 | Guest-count change propagates to gross, net, and every category variance **in one operation** — no figure lags |
| TC-GM-08 | Crew meals invariant to guest count; change only via crew headcount or per-meal rate |
| TC-GM-03 | Crew headcount never appears in any guest tier total |
| TC-GM-11 | Crew-meal rollup: per-supplier headcounts sum correctly (18 / 22 / 15 across the fixtures); removing a supplier reduces the rollup by exactly that supplier's contribution |
| TC-GM-14 | Create a plan with invited, confirmed, and tentative guests: driving RSVP status defaults to `invited`, its count drives every derived per-head amount, and the designation is visible; changing the designation recomputes (REQ-GM-1 cl. 6–7, ADR-31). |
| TC-GM-15 | Tier 1 and Tier 2 invited guests both multiply the same entry's single per-head rate; priority-tier edits do not change derived costs, and no tier-specific rate input exists in v1. A guest-reduction preview removes Tier 2 before Tier 1 (REQ-GM-1 cl. 9, ADR-35). |

### 4.4 Pledge offset math

| TC ID | Asserts |
|---|---|
| TC-PL-10 | Confirmed pledge leaves net unchanged, appears in expected figure (existing) |
| TC-PL-11 | Confirmed pledge with one full-value receipt derives received and reduces net and expected by the receipt amount (existing ID, updated assertion) |
| TC-PL-12 | Tentative pledge with no receipts is expected-only and absent from net breakdown (existing ID) |
| TC-PL-14 | Gross never changes on any pledge status change |
| TC-PL-16 | Exposure = confirmed pledge's remaining unreceived portion; TC-PL-17 renders ₱0.00 not blank |
| TC-PL-18 | Net breakdown sums exactly to gross − net and contains eligible receipt rows, including partial support |
| TC-PL-19 | FIX-C net = ₱335,750.00 (D2 regression, §3.3) |
| TC-PL-20 | Three cash pledges with receipts totalling ₱600,000 against a ₱500,000 gross → net = **−₱100,000.00**, displayed as `−₱100,000.00` (REQ-GEN-2 cl. 4); no zero floor |

**Historical gaps resolved by this revision (IDs retained, not reused):**

| # | Gap | Consequence |
|---|---|---|
| **UT-10** | **Resolved (ADR-37):** insert-only partial receipt rows; net moves on receipt, derived received at threshold. | TC-PL-23, TC-PL-42…44, FIX-D. |
| **UT-11** | **Resolved (ADR-38):** explicit withdrawn state excludes unreceived promise while retaining prior receipts. | TC-PL-35, TC-PL-38, TC-PL-45, FIX-D. |

The old findings are retained for provenance; both now have testable expected results.

### 4.5 Boundary cases

| TC ID | Case | Expected |
|---|---|---|
| TC-BS-07 | Budget ₱0 | **Rejected** at setup (REQ-BS-2 cl. 1) — budget must be > 0. Allocation never runs. |
| TC-BS-08 | Budget ₱1 | Accepted. Allocation: rounding sends nearly everything to Buffer; Σ == ₱1 exactly |
| TC-GM-12 | Zero guests | Every per-head entry = ₱0.00; flat entries unchanged; gross = Σ flat; per-head cost display **suppressed, not division-by-zero** |
| TC-GM-06 | Guest count above cap | Full calculation still returned **plus** over-cap indicator naming both numbers (REQ-BS-5 cl. 2, 3); nothing is blocked |
| TC-GM-13 | Guest count reduced below existing per-head actuals | `manually_valued` entries unchanged; derived entries scale down; no negative amounts |
| TC-PL-20 | Pledges exceed budget | See §4.4 — net goes negative, not floored |
| TC-LG-13 | Refund / discount path | A negative `actual` or payment amount is rejected; a positive `refund` row lowers derived deposit and can reopen balance; a discount lowers non-negative `actual` (REQ-LG-4, REQ-LG-8) |
| TC-AE-13 | All six categories overridden to ₱0 | Σ overrides = 0 < budget; shortfall surfaced; no divide-by-zero in variance percent (REQ-LG-6 cl. 3) |

### 4.6 Setup, notes, and hidden-fee regression cases

| TC ID | Asserts |
|---|---|
| TC-BS-09 | Selecting Bohol resolves to Provincial index 0.85 for cost indexing **but** `is_destination = true` enables the unfilled OOT prompt. Boracay/Palawan/Siargao resolve to Destination 1.20 and enable it; NCR 1.00 does not default it. No selection writes a fee amount. Assert the selected index/flag and prompt state, **not** expected total cost while benchmarks remain unpopulated (OQ-04; REQ-BS-4 cl. 4, REQ-HF-3, ADR-29). |
| TC-LG-14 | Notes live counter advances on every edit, accepts exactly 2,000 characters, refuses the 2,001st typed/pasted character without truncating existing text, and allows editing after deletion. Persisted value is at most 2,000 characters (REQ-LG-1 cl. 8, ADR-33). |
| TC-HF-09 | Each of six hidden fees maps to its fixed category: crew meals/church aircon/corkage/venue power → Catering & Venue, OOT/overtime → Coordination. Every fee has a read-only category label; attempts to reclassify fail. Entries remain separate attributable lines, not merged into a single category entry (REQ-HF-2 cl. 7, 9). |

### 4.6A Previously mapped but undefined cases (planned)

These stable IDs were already present in §2; this table supplies their missing decidable definitions. Levels: U unit, I integration, E E2E, M manual/review, S static. No row is an executed test.

| ID | Asserts | Level | REQ clause |
|---|---|---|---|
| TC-PLT-01 | Inspect iOS and Android artifacts built from one Flutter codebase; web-only build cannot satisfy either target. | M | REQ-PLT-1 cl. 1–3 |
| TC-PLT-02 | Offline local write commits before network replay; offline local read needs no request; SQLite integer column round-trips signed centavos; dependency inspection confirms drift/sqflite. | I + M | REQ-PLT-2 cl. 1–4 |
| TC-PLT-03 | Existing active plan blocks a second creation and names the existing plan; joining as second partner does not consume an additional account plan. | I | REQ-PLT-3 cl. 1–3 |
| TC-BS-01 | Four mandatory fields reject omission; accepts ₱28,000 and above ₱500,000 without warning, any calendar date and cap zero; valid setup allocates and routes to six fee prompts. | I + widget | REQ-BS-1 cl. 1–7 |
| TC-BS-02 | For 0, -5000 and abc budget, inline reason names budget; date/cap/region retained; no completed plan persists. | I | REQ-BS-2 cl. 1–5 |
| TC-BS-03 | With fixed device date, past wedding date warns with date; confirm saves, decline restores prior date; overdue schedule still evaluates. | I | REQ-BS-3 cl. 1–4 |
| TC-BS-04 | Every configured region maps once to Metro 1.00, Provincial 0.85 or Destination 1.20; index and destination flag versioned independently; selecting region creates no ledger row and never changes shares. | U + I | REQ-BS-4 cl. 1–6 |
| TC-BS-05 | Cap is never a rate multiplier; count above cap displays both counts without blocking edits; cap can change after setup. | U + widget | REQ-BS-5 cl. 1–4 |
| TC-BS-06 | Changing setup preserves overrides, ledger, fees, pledges and guests; multi-category preview cancel writes nothing; Apply recomputes and attributes change. | I | REQ-BS-6 cl. 1–5 |
| TC-LG-01 | Validate category taxonomy, supplier 1–200 characters, nonnegative flat estimate and optional actual, entry subtype, and required/nullable fields. | U + I | REQ-LG-1 cl. 1–4, 7 |
| TC-LG-02 | Reject blank/201-character supplier and negative estimate/actual; retain valid notes up to 2,000 and reject overflow per TC-LG-14. | U + widget | REQ-LG-1 cl. 2–4, 8 |
| TC-LG-03 | Each partner can create/read/update a ledger entry offline; each write attributed in activity; no field is partner-read-only. | I | REQ-LG-2 cl. 1–2 |
| TC-LG-04 | Delete requires confirmation; cancel leaves entry and totals intact; confirm tombstones it and removes all live contribution immediately with actor attribution. | I | REQ-LG-2 cl. 2–4 |
| TC-LG-05 | Estimate ₱50,000 contributes gross until actual ₱62,000 replaces it; clearing actual restores ₱50,000; detail labels both and non-colour cue marks difference. | U + widget | REQ-LG-3 cl. 1–5 |
| TC-LG-06 | Positive payment rows minus refund rows derive deposit; never update a cumulative field; balance=max(0,effective−deposit); plan paid and outstanding totals follow immediately. | U + I | REQ-LG-4 cl. 1–3 |
| TC-LG-07 | Overpayment preserves paid sum, shows warning and zero balance; refund/discount distinction leaves gross unchanged for payments but changes actual/gross for discount; no transfer initiated. | U + I | REQ-LG-4 cl. 2–5 |
| TC-LG-08 | Paid at zero balance wins regardless of old due dates; positive balance with unpaid past date is overdue ahead of due soon. | U | REQ-LG-5 cl. 1–2 |
| TC-LG-09 | Fixed local date: unpaid due today/at reminder endpoint is due soon, beyond window pending; partial-paid marker coexists; UI cannot set status. | U + widget | REQ-LG-5 cl. 3–5 |
| TC-LG-10 | Offline read recomputes status without persisted field; device clock differences cause no sync conflict; undated virtual balance remains pending. | U + I | REQ-LG-5 cl. 6–7 |
| TC-LG-11 | Variance = effective−allocated in centavos; percentage half-up to one decimal, including negative variance; positive actual with zero allocation suppresses percentage. | U | REQ-LG-6 cl. 1–3 |
| TC-LG-12 | Over/under variance has non-colour cues and updates in same operation after estimate, actual or allocation edit. | U + widget | REQ-LG-6 cl. 4–5 |
| TC-HF-01 | Setup creates precisely six distinct prompted-unfilled fee decisions with no amount=0 and no fee entry amount. | I | REQ-HF-1 cl. 1–2 |
| TC-HF-02 | Each fee may be filled or dismissed; dismissal persists actor and timestamp and contributes zero gross. | I | REQ-HF-1 cl. 3–4, 7 |
| TC-HF-03 | Any untouched fee appears as an outstanding dashboard risk, distinguishable from filled zero or dismissed. | I + widget | REQ-HF-1 cl. 2, 5 |
| TC-HF-04 | Attempt to complete with untouched fees is blocked and names every untouched category, not just first. | I + widget | REQ-HF-1 cl. 6 |
| TC-HF-05 | Crew supplier count×meal rate, OOT travel+lodging+per-diem, aircon flat, multiple typed corkage lines sum in integer centavos. | U | REQ-HF-2 cl. 1–4 |
| TC-HF-06 | Overtime supplier hourly rate×hours and venue generator+surcharge+electrical components sum independently; each fee is attributable and crew meals ignore guest count. | U + widget | REQ-HF-2 cl. 5–8 |
| TC-HF-07 | Palawan/Boracay/Siargao/Bohol destination flags enable OOT unfilled prompt despite Bohol Provincial index 0.85; NCR leaves optional prompt available. | U + I | REQ-HF-3 cl. 1–2 |
| TC-HF-08 | OOT default creates no amount and is dismissible with actor/timestamp even when destination-flagged. | I | REQ-HF-3 cl. 3–4 |
| TC-PL-13 | Reject blank/201-character sponsor, invalid role/type, negative value and oversize item description; either partner can CRUD a valid pledge. | U + I | REQ-PL-1 cl. 1, 3–5, 7 |
| TC-PL-15 | Expected support for active tentative/confirmed equals max(0,value−receipts), with withdrawn excluded and no contribution to net before receipt. | U | REQ-PL-3 cl. 1, 3, 6 |
| TC-PL-17 | No outstanding confirmed portion displays ₱0.00 (not blank), and exposure remains visually distinct from gross/net/expected. | U + widget | REQ-PL-4 cl. 3 and main |
| TC-GM-01 | Guest RSVP accepts confirmed/invited/tentative explicitly, tier accepts Tier 1/2 and defaults Tier 2; independent edits preserve other axis. | U + I | REQ-GM-1 cl. 1–5 |
| TC-GM-02 | Driving count breaks down tiers within designated RSVP; crew stays separate; default invited and one rate across tiers independently asserted by TC-GM-14/15. | U | REQ-GM-1 cl. 6–10 |
| TC-GM-09 | Absolute and delta what-if show gross/net/category before/after and integer-centavo marginal cost; exceeding cap warns but calculates. | U + widget | REQ-GM-5 cl. 1–4 |
| TC-GM-10 | Preview neither writes nor syncs; discard retains byte-identical state; commit updates driving count and totals; reduction names Tier 2-first cuts. | I | REQ-GM-5 cl. 5–9 |
| TC-SE-10 | Either partner, including non-creator, may remove the other without consent; only target loses server access and plan survives. | I + E | REQ-SE-6 cl. 1–2, 8 |
| TC-SE-11 | After removal, server denies target both push and pull, including replayed prior token; unaffected partner retains access. | I | REQ-SE-6 cl. 2–3, 6 |
| TC-SE-12 | Removal writes an immutable event with acting member and server timestamp; second device displays attribution. | I | REQ-SE-6 cl. 4 |
| TC-SE-13 | Removed partner retains already-synced offline local copy; future server pull/push is denied; no claimed forced remote wipe. | I + E | REQ-SE-6 cl. 3, 5–7; REQ-OF-5 cl. 4 |
| TC-SE-14 | Former partner edits while offline after removal: no post-removal write becomes visible on surviving plan; local pending data is not silently discarded. | I | REQ-SE-6 cl. 3, 5–6 |
| TC-SE-15 | Entry and plan-wide Activity list creates/edits/deletes with actor, timestamp, field and typed old/new money values; loser remains superseded. | I + E | REQ-SE-4 cl. 1–3 |
| TC-SE-16 | Creator delete requires explicit second confirmation; non-creator delete refused with reason. | I | REQ-SE-5 cl. 1–3 |
| TC-SE-17 | Defensive removal never requests the other partner’s affirmation or ownership-transfer confirmation; existing access stops immediately server-side. | I + E | REQ-SE-6 cl. 1–3; REQ-SE-5 cl. 5 |
| TC-SE-18 | Pending transfer preserves both partners’ access; ownership changes only after both affirm; both lifecycle actions logged with actor. | I | REQ-SE-5 cl. 4, 6, 8–9 |
| TC-SE-19 | Opposed removal with equal server timestamp resolves by stable device id, retains losing action superseded with actor, never leaves zero members. | I | REQ-SE-6 cl. 9–11 |

### 4.7 Money-flow clause-level acceptance cases (planned)

Each newly introduced or materially changed numbered clause below has its own stable TC row; existing unaffected clauses retain their prior mapped tests. Run deterministic unit cases with a fixed local date and integration cases on both target platforms. The fixture values are illustrative user input, not app-generated pricing.

| TC ID | Clause | Decidable assertion |
|---|---|---|
| TC-BS-10 | BS-1.8 | Ceremony accepts exactly the five specified values or unset via Not sure yet; invalid value rejected; setup completes when unset. |
| TC-BS-11 | BS-1.9 | Venue accepts exactly the six specified values or unset; invalid value rejected; setup completes when unset. |
| TC-BS-12 | BS-1.10 | Civil hints aircon inapplicability; garden/beach hints power; neither creates amounts/dismissals; all six prompts still require partner decisions. |
| TC-LG-15 | LG-1.5–6 | Entry schema has no persisted `deposit_paid_cents` or entry `due_date`; schedule and payment rows are independent; unscheduled entry shows virtual undated balance. |
| TC-LG-16 | LG-4.1 | Two payment rows ₱30k + ₱35k and refund ₱5k derive ₱60k, with no cumulative deposit column. |
| TC-LG-17 | LG-4.2 | ₱120k effective and ₱125k net paid shows ₱125k paid, ₱0 balance, ₱5k overpayment warning. |
| TC-LG-18 | LG-4.3 | Insert, refund, actual edit, deletion each update plan deposits and balances in one operation; deleted entry excluded. |
| TC-LG-19 | LG-4.4 | Payment/refund preserves gross and actual; lowering actual by ₱5k discount changes gross by exactly ₱5k without negative row. |
| TC-LG-20 | LG-4.5 | Recording each supported method/payment/refund triggers no bank/network transfer or authorization. |
| TC-LG-21 | LG-5.1 | Balance zero yields paid, including after schedule has overdue date. |
| TC-LG-22 | LG-5.2 | One unpaid past-due item yields overdue even with another due-soon item; paid past item ignored. |
| TC-LG-23 | LG-5.3 | Unpaid item at today and at window endpoint is due soon; beyond window pending; overdue wins. |
| TC-LG-24 | LG-5.4 | Positive net paid with balance >0 indicates partial alongside pending, due soon and overdue separately. |
| TC-LG-25 | LG-5.5 | UI offers no direct status setter; dates and amounts alone change status. |
| TC-LG-26 | LG-5.6 | No authoritative status column; two differing device dates yield no sync conflict. |
| TC-LG-27 | LG-5.7 | Offline clock drives recomputation; undated virtual obligation stays pending, never due soon/overdue. |
| TC-LG-28 | LG-5.8 | Apply paid sum by due date, then sort_order, then id; undated residual last; attribution to later item leaves earlier item paid first; refund reopens allocation. |
| TC-LG-29 | LG-7.1 | All enumerated schedule fields/types validated; both partners can add/edit/soft-delete offline. |
| TC-LG-30 | LG-7.2 | No schedule derives exactly one undated effective-amount obligation, no persisted implicit row. |
| TC-LG-31 | LG-7.3 | Schedule less than effective derives undated residual; schedule greater rejects edit with named validation error; exact sum yields no residual. |
| TC-LG-32 | LG-7.4 | Residual allocates after dated items and never notifies; actual edit recomputes residual while preserving payment rows. |
| TC-LG-33 | LG-8.1 | Validate each payment field, nullable attribution and pledge ID, six method codes, positive amount, and client ID. |
| TC-LG-34 | LG-8.2 | Positive refund reopens previously paid balance/status; zero/negative payment, refund, actual rejected. |
| TC-LG-35 | LG-8.3 | Two offline partners insert distinct payments; replay in either order and replay twice preserve both, counted once, with actors. |
| TC-LG-36 | LG-8.4 | Reject foreign-entry schedule_item_id; same-entry attribution does not override due-date allocation. |
| TC-LG-37 | LG-9.1 | At fixed date, unpaid item gets 7-day, 1-day, and one overdue local reminder; paid/deleted item gets none. |
| TC-LG-38 | LG-9.2 | Per-plan window/timing edit reschedules both devices locally; off cancels notices even offline. |
| TC-LG-39 | LG-9.3 | Lock-screen and accessibility string scan finds no supplier name or amount in generic default notification. |
| TC-LG-40 | LG-9.4 | Due soon lists on SCR-06/07 link to entries within window even if notifications disabled. |
| TC-LG-41 | LG-1.3 | Flat entry persists mandatory nonnegative estimate; per-head entry persists nonnegative rate and null `estimated_cents`, displays derived rate × driving count (or actual when set) without syncing/writing back recomputed estimate (ADR-46). |
| TC-PL-21 | PL-1.2 | secondary_sponsor requires candle/veil/cord; other roles reject sub-role. |
| TC-PL-22 | PL-1.6,8 | Zero-valued pledge without receipts stays tentative/confirmed; received is not editable; withdrawn displays despite prior full receipt and keeps its support; both links prioritize entry; deleted entry excludes support and flags orphan. |
| TC-PL-23 | PL-2.2–3 | No receipt yields net=gross; ₱25k partial on ₱50k pledge and ₱350k gross yields ₱325k net; second ₱25k yields ₱300k and derived received. |
| TC-PL-24 | PL-2.4 | Unreceived confirmed ₱50k shows gross/net ₱350k and ₱50k expected. |
| TC-PL-25 | PL-2.5 | Changing pledge lifecycle or receipt leaves gross unchanged. |
| TC-PL-26 | PL-2.6 | Receipt or linked-entry deletion recomputes all displays atomically; paired supplier payment reduces balance, never net again. |
| TC-PL-27 | PL-2.7 | Eligible cash receipts ₱600k against gross ₱500k yield −₱100k net, not zero (TC-PL-20 regression). |
| TC-PL-28 | PL-2.1 | Gross and net appear simultaneously in dashboard viewport. |
| TC-PL-29 | PL-2 main | Partial support moves net at receipt time; no status gate waits for full value. |
| TC-PL-30 | PL-3.1 | Unreceived tentative/confirmed ₱50k contributes full expected, zero net effect. |
| TC-PL-31 | PL-3.2 | Expected figure has distinct visible label. |
| TC-PL-32 | PL-3.3 | Partial ₱20k against ₱50k leaves ₱30k expected; over-receipt floors remaining expected at zero. |
| TC-PL-33 | PL-3.4 | UI never sums expected into net. |
| TC-PL-34 | PL-3.5 | Label identifies unreceived support as not yet realized. |
| TC-PL-35 | PL-3.6 | Withdrawn ₱30k after ₱10k receipt removes ₱20k expected but retains ₱10k net support. |
| TC-PL-36 | PL-4.1 | Confirmed ₱50k receiving ₱20k yields ₱30k exposure; completing receipts yields zero. |
| TC-PL-37 | PL-4.3 | No outstanding confirmed portion displays ₱0.00. |
| TC-PL-38 | PL-4.2 | Exposure list names active confirmed pledges with remaining only; withdrawn absent but history present. |
| TC-PL-39 | PL-5.1 | Breakdown shows eligible partial/withdrawn receipt amounts, names, and statuses. |
| TC-PL-40 | PL-5.2 | Sum of applied receipts equals gross−net, including negative net; gifts/payments never double-count. |
| TC-PL-41 | PL-5.3 | Unreceived promises excluded; deleted linked support shown as reconciliation issue, absent from live net. |
| TC-PL-42 | PL-6.1 | Validate receipt ID, pledge ID, positive amount, date, note, tombstone, nullable unique FK; cash payment_id null. |
| TC-PL-43 | PL-6.2 | Receipt threshold derivation incl zero-value/no-receipt edge; no stored or editable received flag; over-receipt allowed. |
| TC-PL-44 | PL-6.3 | Two offline partners add distinct receipt rows; both count once regardless of sync/replay order. |
| TC-PL-45 | PL-6.4 | Withdrawal retains historical receipts/net and removes only remaining expected/exposure. |
| TC-PL-46 | PL-7.1 | ₱40k linked entry with ₱50k in-kind receipts across two pledges reduces net by at most ₱40k; receipt date/id fixes which ₱40k is credited and excess remains visible. |
| TC-PL-47 | PL-7.2 | Supplier direct pay creates equal receipt/payment atomically with reciprocal linkage; simulate failure between inserts and assert neither persists. |
| TC-PL-48 | PL-7.3 | Unique payment_id blocks duplicate receipt; mismatch of pledge, entry, or amount rejected; duplicate replay idempotent; two partners pairing same payment offline converge to one pair with visible conflict. |
| TC-PL-49 | PL-7.4 | Sponsor-direct ₱40k lowers ₱40k entry balance to zero and net exactly ₱40k, not ₱80k. |
| TC-PL-50 | PL-7.5 | Both links count entry only; deletion excludes linked support from live net and flags orphan, retains history. |
| TC-GF-01 | GF-1.1 | Enumerated sources, positive amount, date, optional giver name/note; both partners add/read/soft-delete offline. |
| TC-GF-02 | GF-1.2 | Gifts leave gross/net/pledge metrics unchanged; first live gift reveals separate net-after-gifts; negative allowed. |
| TC-GF-03 | GF-1.3 | Two offline gift inserts count once each on repeated replay; deleting last hides extra figure. |
| TC-GF-04 | GF-2.1 | FIX-D ₱40k gifts versus ₱210k balance shows −₱170k shortfall in full PHP form; surplus path has non-colour cue. |
| TC-GF-05 | GF-2.2 | Payment, refund, gift, actual edit recompute view on read without stored rollups, payout or transfer. |

### 4.8 Prompt 4 clause-level cases (planned, not executed)

Every value in §3.6 is a hand-specified oracle. Run v1 cases offline on both platforms where UI/storage is involved. v1.1 cases are deferred design/acceptance specifications, **not** a claim that photo upload or translated UI exists.

| TC ID | REQ clauses | Decidable assertion |
|---|---|---|
| TC-AE-16 | AE-7.2–5 | §3.6 P4-C: before/after `200000/75000/50000/50000/25000/100000` → `294750/59250/53000/55000/38000/0` pesos; explicit Apply persists only changed override cents with log attribution, gross/net and engine unchanged; after Apply Buffer remaining ₱0. Cancel writes zero rows and retains original −₱15,750 buffer result. |
| TC-AE-17 | AE-7.1,4 | §3.6 P4-C-lock: Photo override ₱75,000 stays locked and unchanged; partial preview allocates `294750/75000/53000/52250/25000/0`, with named Coordination ₱2,750 and Entourage ₱13,000 breaches. Explicit partial Apply retains breach; locked underfunded recipient also remains unchanged with its shortfall disclosed. |
| TC-AE-18 | AE-7.1,5 | Six locked overrides sum 50,000,001 centavos vs 50,000,000 budget: Apply disabled, one-cent mismatch named, no silent normalization or writes. Repeat for 49,999,999. |
| TC-AE-19 | AE-7.3 | §3.6 P4-cent: 3-cent need after Buffer, proportional quotas `1.125/.75/.75/.375`; floor then remainders produce transfers `[1,1,1,0]` by fixed tie order, exact 10,000-centavo conservation. Also test zero slack: no division by zero, uncovered need remains. |
| TC-AE-20 | AE-7 main,4–5 | Offline preview on two identical pinned-rule copies gives identical explanations and post-Apply allocations; preview names locks/donors/shortfall, no vendor or funds UI; only changed overrides sync via immutable events. |
| TC-GM-16 | GM-6.1–2 | §3.6 P4-A flat 29,680,000 and rate 260,000 centavos yield ceiling **193** with zero kept buffer; at 193 gross ₱798,600 fits and at 194 ₱801,200 does not. Explain flat, rate, chosen buffer and driving RSVP/count. |
| TC-GM-17 | GM-6.2,5 | P4-A keeping 16,000,000 centavos yields **132**, 133 breaks buffer; 193 exceeds cap 160 but remains ceiling with separate warning. Received/expected pledges, gifts and supplier payments never change either ceiling; preview writes nothing. |
| TC-GM-18 | GM-6.3–4 | P4 boundary: negative numerator −10,080,001 centavos gives ceiling 0, zero-guest shortfall ₱100,800.01, not “fits”; zero-rate case with overcommitted flat + buffer reports both no finite limit and shortfall. |
| TC-GM-19 | GM-6.1,4 | Rate sum zero with nonnegative numerator says “No per-head costs; no finite budget-based guest limit,” no infinity/division; manually valued actual and crew meals count flat; deleted entries/rates excluded; priority-tier change cannot affect rate. |
| TC-GM-20 | GM-6.5 | Offline on SCR-13: preview explanation displays flat/rate/buffer, cap warning separately, no supplier promotion or money initiation; discard preserves byte-identical data and no sync event. |
| TC-TM-01 | TM-1.1–2 | Validate pinned JSON has five named templates with stable IDs, valid categories/pricing modes, no price/supplier fields; ceremony/venue mapping deterministic and unset allows manual choice; bad shape rejected. |
| TC-TM-02 | TM-1.3 | Inventory matches all 14 listed Filipino/local expense types with configured names/modes, never asserts fees/applicability or vendor names. |
| TC-TM-03 | TM-1 main,4 | Opening/cancelling all unticked suggestions writes no rows (not even ₱0); ticking opens ledger editor, rejects missing supplier or invalid amount/rate, saves only after user enters valid fields; works offline. |
| TC-TM-04 | TM-1.1,4 | Intimate ≤50 label leaves cap/count unchanged; compare variants with same ledger to prove gross/net unchanged; inspect UI for no vendor ranking/booking or payment initiation. |
| TC-CK-01 | CK-1.1–2 | Config includes named checklist labels/stable IDs; each unverified item reads NEEDS VERIFICATION with no preset eligibility, fee or due date; reject unverified offset/applicability as authoritative. **Verified rule/offset assertion BLOCKED on OQ-11; no guessed offset.** |
| TC-CK-02 | CK-1.2–3 | Couple enters a reminder date for an unverified item: label identifies user date; changing wedding date leaves that date untouched. Done toggles independently offline and two-partner LWW history preserves both field writes. |
| TC-CK-03 | CK-1.3 | Once an item-specific source/offset is actually verified and recorded (future gated test data), recompute signed-day offset on read after wedding-date edit and preserve manual date; **no concrete offset or authority oracle until OQ-11 is resolved.** |
| TC-CK-04 | CK-1.4 | Couple enters their own positive `fee_cents = F` (no preset amount): gross/net unchanged; declining confirmation or a zero fee creates no ledger row; explicit confirmation with valid supplier/category creates one ledger entry for exactly `F` centavos counted once, never a divergent amount or payment initiation. Editing the checklist fee afterward does not mutate the linked ledger entry without a separate explicit ledger edit. |
| TC-CK-05 | CK-1 main–4 | Checklist remains usable offline with done/user date/fee; preview explains source-verification gate and contains no supplier recommendation or auto-transfer. Fail release gate if unverified preset appears as legal/church advice. |
| TC-EX-02 | EX-2 main,1 | Offline summary PDF contains full-form gross/net/expected, six-category amounts and dated payment schedule from eligible projection; privacy preview names included sections before OS sheet. No network/file-link dependency. |
| TC-EX-03 | EX-2.2 | Four separate CSV schemas ledger/payments/pledges/guests with sensitive-data warning; round-trip RFC-4180 quoted commas, quotes, CRLF and UTF-8; `=1+1`, `+cmd`, `-2+3`, `@SUM`, ` \t=1+1`, control-prefixed `\r=1+1` become apostrophe-prefixed **before** CSV quoting and import as text, not executable formulas. |
| TC-EX-04 | EX-2.1,3 | Shared summary hides guest/sponsor names by default; toggle each independently and inspect generated PDF text, not merely UI. Statement for one Ninong or Ninang contains only the selected pledge, eligible receipts and linked coverage; another sponsor's name and unrelated amounts absent, and a non-Ninong/Ninang pledge cannot be selected for the v1 statement. |
| TC-EX-05 | EX-2.4 | Airplane-mode OS share-sheet handoff (Messenger/Viber/email if installed) exposes local file only, no generated link or sync; cancel/handoff removes app-owned temp artifact. Warning states external copy cannot be recalled/deleted by Kasaran. |
| TC-EX-06 | EX-2.2–3 | Deleted/ineligible rows excluded from curated export; sponsor-direct payment/receipt shown in their respective source rows without double net subtraction; statement never leaks a different sponsor when identical names or entries exist. |
| TC-EX-07 | EX-2.4–5 | Exported bytes/temp names/logs contain no accidentally persisted share URL or raw sensitive cache after handoff; independent review checks profile/activity inclusion and SEC-32 disclosure, not merely PDF visual redaction. |
| TC-EX-08 | EX-2.5; SEC-32 | From the same UI request a distinct full machine-readable copy: parse versioned manifest and compare local source fields for profile, membership, setup, ledger/schedule/payments/refunds, fee components, pledges/receipts, gifts/giver, guests, crew, checklist, overrides and attributed change history (including retained tombstones), including names omitted from redacted PDF/curated CSVs. Manifest reports as-of-last-sync, missing/inaccessible fields and server-only/other-device-unsynced limits; reconcile server-only account data with DPO before claiming SEC-32 PASS, and verify account display-name/email correction path. Formula-neutralize CSV text/formatted cells if used, warn before share, and do **not** assert OQ-01 erasure. |
| TC-LO-01 | LO-1 main,1 | v1 English only; deferred v1.1 ARB English/Taglish/Filipino key inventory and user selection, missing key falls back to English deterministically, no runtime translation. |
| TC-LO-02 | LO-1.1–2 | Switching locale leaves centavos, budget calculations, sync and user-entered text byte-identical; PHP/date remain en_PH and full a11y form. |
| TC-LO-03 | LO-1.2 | Kasaran, Ninong/Ninang, PSA/CENOMAR and local acronyms remain untranslated in both new locales. |
| TC-LO-04 | LO-1.3 | Pseudo-localize/expand labels at largest text scale in dashboard bento tiles: value legible, no clipping/overlap; VoiceOver/TalkBack label announces full amount rather than shorthand. |
| TC-AT-01 | AT-1.1 | Deferred design/security gate: private plan-scoped Supabase Storage policies reject cross-tenant read/write and public URL; metadata attaches only to a valid plan-owned ledger entry or pledge receipt (contract photo linked to ledger), with no v1 upload UI or OCR. |
| TC-AT-02 | AT-1.2 | Deferred offline design gate: stage encrypted photo bytes separately from metadata; disconnected item says pending, failed transfer says error, never uploaded until bytes are reachable; retry is idempotent. |
| TC-AT-03 | AT-1.3 | Deferred configuration gate: approve maximum bytes and MIME allowlist *before* authoring concrete limits or asserting boundary values; reject disallowed oversize/type once values are approved. **No invented threshold oracle.** |
| TC-AT-04 | AT-1.3 | Deferred release review: Photos privacy declaration updated before shipping; neither forced remote wipe nor public URL nor OCR claimed. Stub remains non-shipping until gates approved. |

**Project-brief §4 four-test gate per feature.** Deterministic: AE-16/19, GM-16/18, TM-01, CK-01/02 (verified preset BLOCKED), EX-03/08, LO-01, AT-01/03 (deferred). Explainable: AE-20, GM-20, TM-03, CK-05, EX-02/04, LO-04, AT-02. No money movement: AE-20, GM-20, TM-04, CK-04/05, EX-05, LO-02, AT-04; historical payment records and fee ledger entries never initiate transfers. No supplier recommendation: AE-20, GM-20, TM-04, CK-05, EX-04, LO-03, AT-04. All are planned test cases; OQ-11 preset and v1.1 gates retain their blocked/deferred status.

### 4.9 Prompt 5 opt-in measurement, survey and age declaration (planned)

Test oracles below map to the defined REQ-MT-1 and REQ-SV-1 clauses. Exact notice copy still needs DPO/counsel approval before real-data collection. Survey response is **optional**, not an onboarding gate, and no third-party analytics SDK is permitted in v1. Age declaration is not date-of-birth collection. Manual reviews inspect published notices, labels and lawful basis; no approval is claimed.

| ID | Asserts | Level | REQ clause |
|---|---|---|---|
| TC-MT-01 | Fresh install/account defaults measurement opt-in off; no metric event is emitted merely by signup, plan creation, dashboard view or survey dismissal; core planning works identically without opt-in. | I | REQ-MT-1 cl. 1–2 |
| TC-MT-02 | Aggregate hidden-fee prompt decisions from existing prompt state and derive co-editing from already-synced change-log member aliases and wedding date only where disclosed/authorized; do not infer opt-in from existing records, transmit raw names, token or budget to a measurement sink, or double-count sync replay. | U + I | REQ-MT-1 cl. 2–3 |
| TC-MT-03 | Figure-view event (e.g. net expanded) occurs only after explicit opt-in; payload allowlist excludes plan ID, name, monetary amount, email, invite token and note; no third-party analytics SDK or background analytics request in v1. | I + M | REQ-MT-1 cl. 1, 3–4 |
| TC-MT-04 | Withdrawal prevents new optional events, remains independent of planning and can be changed in-app; queued but not yet sent optional events are discarded and retention/deletion of already received events follows the approved notice; no implicit re-consent on reinstall/sign-in. | I + M | REQ-MT-1 cl. 1, 4–5 |
| TC-MT-05 | Review consent notice, lawful-basis decision, data inventory, Apple/Play declarations and Sentry diagnostic distinction against actual payload/retention/region before beta/release; BLOCKED until counsel and disclosures are approved, not a claim of legal compliance. | M | REQ-MT-1 cl. 5–6 |
| TC-MT-06 | At setup completion record one immutable budget snapshot as integer centavos; on wedding-day observation compare only final *actual* gross against that snapshot for consenting plans. A later budget edit cannot rewrite baseline; partial actuals or missing snapshot make result unknown rather than estimate-based success or failure; duplicate sync never adds a second observation. | U + I | REQ-MT-1 cl. 2 |
| TC-MT-07 | For each of metrics 1, 2, 3 and 5, use eligible consented-plan denominator only and exclude plans missing required setup snapshot, prompt transition time, accepted edit time or consent. Report cohort size, exclusions and opt-in selection bias; suppress publication below DPO-approved aggregation floor rather than guessing a numeric floor or treating unknown as No. | U + M | REQ-MT-1 cl. 2, 5–6 |
| TC-SV-01 | One optional in-app survey invitation is shown at the specified trigger, offers Skip/Not now, and never blocks budgeting, offline use or export; no repeated prompt after recorded completion. | I + widget | REQ-SV-1 cl. 1–2 |
| TC-SV-02 | Survey Submit requires selected Yes/No/Prefer not to say and separate default-off survey opt-in; Skip/Not now create no answer or metric consent. Offline opted-in submission queues once under stable response ID and replays exactly once; repeated delivery never duplicates it. A second partner's later submission is rejected as Already answered without replacing first response; withdrawal prevents new uploads. | I | REQ-SV-1 cl. 2–4 |
| TC-SV-03 | Inspect survey notice, retention, access and privacy-label inventory before beta; skip yields no survey response and a completed response is not used as evidence of partner consent to metrics. Counsel-dependent lawful basis remains BLOCKED. | M | REQ-SV-1 cl. 3–5 |
| TC-SE-45 | Signup requires an explicit unchecked “I am 18 or older” declaration before account creation on both platforms; absent/unchecked declaration blocks signup with accessible explanation, checked succeeds, no birth date inferred or silently collected; review privacy notice, Play 18+ audience and counsel legal-basis gate. | I + widget + M | REQ-SE-1 cl. 9 |

---

## 5. Sync & conflict tests

**Clock ADR status: DECIDED, not open.** ADR-21 (D1) fixes the ordering authority as a **server-assigned timestamp** applied at sync, with device monotonic counter then stable device id as tiebreakers; device wall-clocks are never authoritative. ADR-43–52 refine visibility, atomic field groups, read-time validation, durable order, and compatibility without replacing this authority. These are specified expected results, not executed test outcomes. Shared-record erasure alone remains blocked on OQ-01.

**One deliberate asymmetry that must be tested explicitly.** General field LWW resolves to the **later** server timestamp (REQ-SE-2 cl. 3). Simultaneous mutual *removal* resolves to the **earlier** server timestamp (REQ-SE-6 cl. 9) — first defensive action wins. Same clock, opposite direction. This is intentional but is a likely implementation bug, so TC-SE-24 and TC-SE-22 assert opposite directions on purpose.

| TC ID | Scenario | Device A | Device B | Offline duration | Expected winner / end state | Expected change-log entry |
|---|---|---|---|---|---|---|
| TC-SE-24 | Same field, both offline | edits `ledger[x].actual` → ₱58,000, syncs first | edits `ledger[x].actual` → ₱62,000, syncs second | A 10 min, B 2 h | **B's ₱62,000 wins** (later server_ts, REQ-SE-2 cl. 3) | Both rows retained; A's marked superseded, value ₱58,000 intact, actor A; typed old-value mismatch (if present) is a separately derived conflict, not a stored status |
| TC-SE-20 | Clock skew | clock correct, edits → ₱58,000, syncs **second** | clock **10 min fast**, edits → ₱62,000, syncs **first** | both brief | **A's ₱58,000 wins** — later *server* ts. B's fast clock is irrelevant | A current, B superseded; log shows server ts, not device ts |
| TC-SE-21 | Identical server_ts | write P | write Q | — | Higher `device_monotonic` wins; if equal, higher `device_id`. Both devices pick the **same** winner | Loser superseded |
| TC-SE-27 | Different fields, same record | edits `supplier_name` | edits `actual` | A 1 h, B 1 h | **Both persist.** No conflict. Record shows A's name + B's amount | Two independent entries, no supersession |
| TC-SE-28 | Delete vs edit, then Restore | soft-deletes entry (`deleted_at`) at T1; later explicitly restores at T3 | edits `actual` at T2 > T1 while offline | both offline 1 h | Delete **gates** B's edit despite its later `server_ts`; no total counts the deleted entry or its children. B's edit remains preserved but suppressed and raises a banner on both devices. Only explicit Restore at T3 (`deleted_at = null`) revalidates **last effective pre-delete values** and eligible children for totals; B's suppressed value does not spring into effect. No one-tap value revert or cascade writes (ADR-47). | Delete, suppressed edit and restore retained with actors, old/new values and ordering; Activity names deletion and preserved edit |
| TC-SE-29 | Create–create, near-identical | creates "Catering — Hotel A" ₱360,000 | creates "Catering – Hotel A" ₱360,000 | both offline 3 h | **Both rows persist as separate entries** (distinct client UUIDv7 keys); gross counts ₱720,000. No dedup in v1. **Finding:** flagged as a product question — silent duplicate-cost inflation is a realistic user harm; a same-category/amount/supplier warning may be warranted | Two creates, no supersession |
| TC-SE-30 | Long offline, stale dependent calculations | online throughout; guest count 150 → 200, allocations overridden | offline 6 days holding pre-change state, edits a per-head rate | B 6 days | Per-head effective amount and engine allocation/explanation derive locally from new count, synced inputs and pinned ruleset; only override syncs. **Both devices show identical recomputed gross/net/variance/buffer**, and neither syncs recomputed `estimated_cents` or `engine_cents` (ADR-46). | B's rate edit present and attributed; no phantom entries for derived figures |
| TC-SE-22 | **Simultaneous mutual removal** (existing) | removes B, server_ts T1 | removes A, server_ts T2 > T1 | both offline | **A survives** — removal with the *earlier* server_ts prevails (REQ-SE-6 cl. 9). Plan never memberless | Losing removal recorded as superseded, actor B preserved |
| TC-SE-25 | Convergence, order-independent | 20 mixed writes | 20 mixed writes | staggered | Applying the same 40 rows in any arrival order yields identical projections on both devices; re-running sync changes nothing | — |
| TC-SE-26 | Change-log integrity | — | — | — | Log is append-only: no UI or API path edits or deletes an entry; monetary entries carry prev + new value | — |
| TC-SE-31 | Ownership-transfer expiry | A requests transfer, A confirms | B confirms just before vs at/after seven-day deadline | — | Before expiry, both confirmations transfer ownership; without both within 7 days of request, pending confirmation expires and ownership/access remain unchanged (REQ-SE-5 cl. 7, ADR-32) | Expired request and any confirmation remain attributed; no transfer event on expiry |
| TC-SE-32 | Removed partner local wipe offer | A removes B | B reconnects and learns removal | B may have been offline | B's server push/pull are rejected; B retains the existing local copy unless B accepts an offered local wipe. Offer is displayed upon learning removal; no copy claims forced remote deletion (REQ-SE-6 cl. 5–7, ADR-34; OQ-03 open) | Removal attributed to A; no remote-wipe success claim |
| TC-SE-23 | Join-first onboarding (existing ID) | signs up without a plan, chooses Join | already has plan, shares valid invite | — | SCR-01 offers Start/Join; A may paste link instead of tapping it, joins B's plan with identical overrides and **no second plan**; expired/revoked link rejects (REQ-SE-1 cl. 7–8, ADR-52). | Join attributed; raw token absent from logs; SEC-05 strength/hash verified by TC-SE-42 |
| TC-SE-33 | **Stale offline write wins and is flagged to BOTH** | changes actual ₱50,000 → ₱60,000, syncs first | while offline sees ₱50,000, edits to ₱55,000, syncs days later with typed `old_value = 5000000` centavos | B 6 days | B wins at later server order: both show ₱55,000. B's `old_value` differs from immediately replaced ₱60,000 (not from any derived status), hence both get a dismissible banner and SCR-16 Conflicts filter with ₱55,000 winner/₱60,000 superseded. Same-value typed comparison including null yields no conflict. | Both immutable writes and original old values remain; mismatch derived on read, no persisted conflict flag or status row (ADR-43) |
| TC-SE-34 | Compound pricing and fee-component merge | from `(flat,null)` writes complete pricing group `(per_head,100000)`; separately edits a crew-meal fee to `(quantity=2,unit_rate_cents=30000,amount_cents=null)` | from the same prior states writes full pricing group `(per_head,200000)` and fee `(3,20000,null)`; syncs later | 1 h | B's **entire** higher-key snapshot wins each group: `(per_head,200000)` and `(3,20000,null)`, whose fee total is 60000; never `(per_head,null)`, `(3,30000,null)` (90000, authored by neither), or a partly mixed group. Incomplete snapshot rejected, not partially projected; unrelated fields still merge independently. | One `change_group_id` per operation and full snapshot; losing groups retained, ordering `(server_ts,device_monotonic,device_id)` (ADR-44) |
| TC-SE-35 | Conflict derived vs payment status | changes a scheduled payment date and syncs | observes different local date and offline status; edits the entry's actual | B 2 h | Typed field `old_value` is compared with its immediately replaced field value including null; local `overdue`/`pending` recomputation alone triggers **no** banner and writes no status row. A genuine old-value mismatch on actual still triggers both-device banner. | No persisted `conflict` or `status` field; genuine write and its old value remain (ADR-43) |
| TC-SE-36 | Merge breaks cross-field invariant | sets ledger actual to ₱60,000 from ₱100,000 | adds live schedule items totalling ₱80,000 against old ₱100,000 | staggered | Individually valid edits together exceed effective amount; both retain raw values, show SCR-19 needs attention, omit invalid dependent schedule contribution, retain independent valid contributions, and converge on same safe totals. No auto-repair write is emitted. Repeat for mismatched subtype/category, incompatible fee-parent subtype, incomplete supplier receipt/payment pair and invalid sponsor linkage; valid over-allocation/overpayment warns without invalidating (REQ-SE-3 cl. 4–6, ADR-45). | Both accepted writes remain; no fabricated correction row |
| TC-SE-37 | Every total ignores tombstones | deletes ledger parent with schedule, payment, fee components, linked pledge and receipts; separately soft-deletes a gift, refund and another receipt | observes deleted data, then restores parent explicitly | 1 h | While deleted, **gross, net, expected/exposure, deposits, balances, variance, buffer, gifts, net after gifts and reconciliation** omit each deleted contribution and parent-gated children; linked pledge's recorded value survives with “linked entry deleted,” linked support omitted from net. On explicit restore, revalidate and count only valid live descendants once (ADR-47). | No child cascade write; original rows and tombstones remain, Restore is a new `deleted_at = null` write |
| TC-SE-38 | Atomic create split across pull pages | creates parent ledger entry and child component | pulls with `limit=1`, parent create on page N, child create on N+1 | — | Full validated initial snapshot is a **single** create row, so page N has a whole entry or none, never partial field state; child is hidden until parent arrives. Reversing page arrival holds child pending; totals never include half an entity. | One full-snapshot create event per entity, stable IDs, no partial projection (ADR-47) |
| TC-SE-39 | Same account, two devices | device 1 edits actual and queues offline | device 2 edits same field and syncs first | 1 h | Later accepted device 1 write wins under ADR-21; both devices converge and show “You changed this on another device,” not “your partner”; per-device session revocation stops only selected device and offers local wipe without claiming remote wipe (ADR-50). | Same `plan_member_id`, distinct `device_id` and monotonic counters; both rows preserved |
| TC-SE-40 | Former-member attribution | member A contributed ledger and payment history | B reads the activity after A's account-to-alias mapping is removed | — | Existing immutable events still attribute exactly one stable alias but display “Former member”; neither row nor money value rewritten. **Shared-plan erasure outcome is not asserted** (OQ-01, ADR-51). | `plan_member_id` remains on log rows; `actor_user_id` FK is absent |
| TC-SE-41 | SCR-18 account deletion request | A opens in-app deletion path | B remains a member | — | In-app request is available and identifies the counsel gate; alias unlink can be tested independently, but no success assertion about B's shared records or actual erasure is authored pending OQ-01 (SEC-34, ADR-51). | No immutable row rewritten or fabricated “deleted shared record” entry |
| TC-SE-42 | Pasted invite SEC-05 parity | creates valid ≥128-bit CSPRNG token, stored as hash only | signs up first, pastes it on Join | — | Pasted and tapped paths accept/reject identical valid, expired, revoked or already-used tokens; neither creates a second plan; raw token absent from DB/logs (ADR-52). Test the **same RPC-compatible token format** on both paths and assert all invalid cases at the UI and server, not just parser/fake acceptance. | Acceptance attributed to member alias without exposing token |
| TC-SE-43 | **Cursor row would be skipped by out-of-order commits** | transaction A assigns lower plan server sequence and pauses before commit | concurrent transaction B attempts higher sequence, then pulls `limit=1` | — | B's assignment waits under the per-plan lock; no pull cursor advances past A before A commits or rolls back. After commit, all pages return A/B once in committed order; rollback gap does not hide B (ADR-48). | Retained row IDs and original assigned `server_ts`; cursor only advances through returned committed rows |
| TC-SE-44 | **Old client gets unknown new field** | compatible newer client inserts a `schema_version` row for unknown field or entity | old client pulls, then upgrades locally | — | Old client preserves unknown full row in log and does not project it; if it is a required financial dependency, affected total shows needs attention rather than wrong money. Upgraded drift schema transactionally rebuilds from whole log and projects the row once, retaining queue and cursor; unsupported major rejects with `min_supported_build` (ADR-49). | Immutable unknown row and ordering metadata survive both versions; no rewritten history |

**Added/changed-clause traceability (planned, not executed).** REQ-LG-1 cl. 3 → TC-LG-41; REQ-AE-5 cl. 7 → TC-AE-15; REQ-SE-1 cl. 7–8 → TC-SE-23/42; REQ-SE-2 cl. 8–9 → TC-SE-33/35, cl. 10 → TC-SE-34 and TC-API-07, cl. 11 → TC-SE-39; REQ-SE-3 cl. 4–6 → TC-SE-36/37 and TC-OF-26; REQ-SE-4 cl. 5 → TC-SE-40 and TC-API-09, cl. 6 → TC-SE-38 and TC-API-07, cl. 7–8 → TC-SE-28/37, cl. 9 → TC-SE-39 and TC-API-09, cl. 10 → TC-SE-41 (request path only; shared erasure OQ-01 blocked); REQ-OF-2 cl. 4–5 → TC-SE-30 and TC-OF-22/26; REQ-OF-5 cl. 6 → TC-SE-43/TC-OF-23/TC-API-06, cl. 7 → TC-OF-25/TC-API-07/08, cl. 8 → TC-SE-44/TC-OF-24/TC-MIG-04, cl. 9 → TC-OF-25/TC-MIG-05.

---

## 6. Offline / multi-device matrix

Every v1 entity, airplane mode, expected **end state** stated.

### 6.1 Airplane-mode CRUD per entity

| TC ID | Entity | Create | Read | Update | Delete | Expected end state after reconnect |
|---|---|---|---|---|---|---|
| TC-OF-01 | Plan setup (budget, date, cap, region, optional ceremony/venue, reminder settings) | ✅ | ✅ | ✅ | n/a | Setup and reminder settings converge; allocations recomputed identically; devices schedule local notices independently |
| TC-OF-02 | Ledger entries | ✅ | ✅ | ✅ | ✅ | Every offline entry present exactly once; gross matches the local pre-sync value to the centavo |
| TC-OF-03 | Fee components (all six subtypes) | ✅ | ✅ | ✅ | ✅ | Per-type shapes intact; crew-meal rollup unchanged by sync |
| TC-OF-04 | Pledges, receipt rows and supplier-linked pairs | ✅ | ✅ | ✅ (pledge) | ✅ (soft-delete) | Distinct receipts and atomic supplier pairs preserved; net/expected/exposure recompute identically |
| TC-OF-05 | Guests (RSVP + tier) | ✅ | ✅ | ✅ | ✅ | Both axes preserved independently; driving count consistent |
| TC-OF-06 | Crew headcount | ✅ | ✅ | ✅ | n/a | Separate from guest totals after sync |
| TC-OF-07 | Allocation overrides | ✅ | ✅ | ✅ | ✅ (revert) | Overrides survive; engine values still visible alongside |
| TC-OF-08 | Hidden-fee prompt states | ✅ | ✅ | ✅ | n/a | `dismissed` retains dismisser + timestamp; `prompted_unfilled` still distinguishable from ₱0.00 |
| TC-OF-19 | Schedule items | ✅ | ✅ | ✅ | ✅ | Dates, order and tombstones converge; derived virtual residual consistent |
| TC-OF-20 | Supplier payments/refunds | ✅ | ✅ | n/a (insert-only) | ✅ (soft-delete correction) | Each distinct row counted once after replay; derived deposits agree |
| TC-OF-21 | Gifts | ✅ | ✅ | n/a (insert-only) | ✅ (soft-delete correction) | Each distinct row counted once; gifts remain separate from pledges |

### 6.2 Durability and interruption

| TC ID | Scenario | Expected end state |
|---|---|---|
| TC-OF-12 | Queue durability across **app kill** | 12 offline writes; force-quit; relaunch offline → all 12 still queued, count = 12, none duplicated. Reconnect → all 12 apply exactly once |
| TC-OF-13 | Queue durability across **OS restart** | Same 12 writes; full device reboot; relaunch → queue intact at 12, DB decrypts with the Keystore/Keychain key, no re-auth loss. **Real device only** |
| TC-OF-14 | Resume on reconnect | No user action required; replay begins on foreground/connectivity (REQ-OF-5 cl. 1). Progress and completion visible |
| TC-OF-15 | **Partial sync interruption mid-batch** | Push batch of 20; kill network after row 11 accepted. End state: rows 1–11 committed server-side with `server_ts`; rows 12–20 still queued locally. On retry, rows 1–11 are **insert-ignored** (idempotent, REQ-OF-5 cl. 2–3), retain their assigned `server_ts`, and are not double-counted; final gross equals the single-pass value exactly |
| TC-OF-18 | Offline replay ordering and clock authority | Queue two edits to the same field with increasing `device_monotonic` values and stable `device_id`; replay after a long offline period. The server assigns each newly accepted row `server_ts` at acceptance, never the device edit timestamp. The later accepted conflicting write wins per REQ-SE-2, even if its offline edit happened earlier in wall-clock time; original device order/id survive replay. Re-send an accepted row: same id and `server_ts`, no duplicate log or cost. |
| TC-OF-16 | Write that cannot be applied | Surfaced to the partner with data intact, never discarded (REQ-OF-5 cl. 4); badge reads "1 change needs attention" (ux-spec §7.2 state 5) |
| TC-OF-09 | Offline computation parity | Allocation, guest what-if, variance, buffer, gross, net, expected/exposure remaining, balances, schedule states, and gifts all compute on-device with no network; figures identical to online result for identical inputs and evaluation date |
| TC-OF-10 | Offline indicator + pending count | Persistent indicator; exact count; escalates per ux-spec §7.2; **no copy contains "lost", "deleted", "discarded", or "failed to save"** — asserted by string scan |
| TC-OF-11 | Clock handling | `overdue` derived on read from device local date; two devices with different clocks may display different status **without generating a sync conflict**; status never written to shared state (REQ-OF-4) |
| TC-OF-17 | Two-device simultaneous editing → convergence | A and B both online, 30 s of concurrent edits across ledger, pledges, guests. End state: identical gross, net, expected, exposure, buffer remaining, and every category variance on both devices, to the centavo; change log identical in content and order |
| TC-OF-22 | Derived-only offline recomputation | Change driving count/rate and allocation input with pinned ruleset installed; offline and online devices calculate identical per-head amount, engine cents/explanation, gross and net on read; only inputs, pinned version and override cents are queued/synced, never recomputed `estimated_cents`, `engine_cents` or explanation (ADR-46). |
| TC-OF-23 | **Skipped cursor row under concurrent commits** | Pause plan P transaction A after sequence assignment but before commit; start B on same plan; B cannot assign/commit a higher sequence until A commits or rolls back. Pull first page at `limit=1` and subsequent pages while transactions finish: every committed row appears exactly once, none below a cursor commits later; per-plan cursor advances only past returned committed rows, rollback gaps harmless. A different plan can proceed independently (ADR-48). |
| TC-OF-24 | Compatible old client receives new field/entity | Receive unknown additive `field_name` and `entity_type` carrying `schema_version`; client retains full immutable rows and metadata while omitting unknown projections, without dropping queue/cursor. Upgrade with local drift migration and rebuild from **entire** retained log: unknown rows now project once in server order; a required unknown money input gates affected total with needs attention before upgrade (ADR-49). |
| TC-OF-25 | Unsupported major protocol and failed local migration | Push/pull with unsupported major version receives structured `min_supported_build`, preserves local queue. Inject a migration/rebuild failure: local schema, log, queue and cursor retain their original logical values and are retryable; no partial money projection. On compatible retry, migration commits and queue replays once (ADR-49). |
| TC-OF-26 | Missing pinned ruleset on offline device | Device has synced source inputs but lacks referenced immutable ruleset version; log and queued writes stay intact, affected allocation view displays needs attention/update, no invented allocation or derived write; after installing matching version, recomputed allocations and explanation equal partner's (ADR-46). |

---

## 7. Backend

**Contract maturity:** `supabase/functions/sync_pull` remains a phase-04 authenticated **GET** stub with `since_server_ts`, bounded optional `limit` (default 100, accepted 1–1000), and an empty result. `test/api/contract/sync_contract_test.dart` exercises that legacy stub; its passing smoke tests do **not** satisfy versioned `POST /sync/pull` with `{protocol_version, plan_id, cursor, limit}`, committed paging and membership in TC-API-02/06/07/08 or SEC-24. Phase 08 replaces the stub with the §2.4 protocol and requires those tests against real RLS rows. These are separate stages, not competing live contracts; do not ship the GET stub as the final protocol.

| TC ID | Area | Asserts | Maps to |
|---|---|---|---|
| TC-API-01 | Contract — push | `POST /sync/push` envelope carries `protocol_version`, rows carry `schema_version` but not authoritative `server_ts`; returns `{id, server_ts}` per accepted row; rejects malformed rows with 4xx and no partial commit | design §2.4; REQ-OF-5 cl. 7 |
| TC-API-02 | Contract — pull | `POST /sync/pull` with `{protocol_version, plan_id, cursor, limit}` returns rows cursor-paged to a committed high-water mark; monotonic, terminates, `has_more` accurate, cursor is last returned committed sequence and never passes an unseen future commit | design §2.4; REQ-OF-5 cl. 6–7 |
| TC-API-03 | Idempotency | Same batch pushed twice → second is a no-op; no total changes | SEC-20 |
| TC-API-04 | Auth required | Unauthenticated push/pull → 401 | SEC-01, SEC-03 |
| TC-API-05 | Membership write path | Direct client insert into `plan_members` → denied | SEC-25 |
| TC-API-06 | Committed cursor contract | Concurrent two pushes on one plan cannot commit higher `server_ts` before an assigned lower row; paged pull exposes only committed rows at a committed high-water mark, returns the last returned committed cursor, and never skips A when B raced it; rolled-back gaps and separate plans behave correctly | REQ-OF-5 cl. 6, ADR-48 |
| TC-API-07 | Versioned envelopes and immutable rows | Push and pull carry `protocol_version`; accepted change-log rows carry `schema_version`, `change_group_id` for compound operations, full create snapshot and `plan_member_id`/`device_id`; no `actor_user_id` FK, derived status or stored conflict flag; incomplete group/malformed snapshot rejected atomically | REQ-SE-2 cl. 8–10, REQ-SE-4 cl. 5–6, REQ-OF-5 cl. 7, ADR-43/44/47/49/51 |
| TC-API-08 | Unsupported major protocol | Push and pull reject unknown major with structured `min_supported_build`; server accepts no rows, client retains unchanged queue and cursor; compatible additive unknown rows can still be pulled and retained for future rebuild | REQ-OF-5 cl. 7–8, ADR-49 |
| TC-API-09 | Session revocation and attribution | Revoke one of two sessions of same user: revoked device cannot refresh or push/pull; other session stays usable; history uses plan alias and device, renders Former member after alias mapping unlink, no immutable log update; **no shared-record erasure result asserted** | REQ-SE-4 cl. 5, 9–10, SEC-04, ADR-50/51 |
| TC-EX-01 | Prohibition review | Manual checklist: no marketplace, directory, reviews, ratings, quotes, or booking in code or UI | REQ-EX-1, UT-9 |

### 7.1 Tenant isolation negative tests — the gate-blocker

**Rule:** a user of wedding X must never receive wedding Y's data or learn whether wedding Y exists. For single-resource endpoints, return the same non-enumerating 403/404 as for an unavailable resource. For filtered list endpoints, `200 []` is allowed only if a nonexistent plan produces the same status and payload; no count, error detail or timing-dependent branch may disclose foreign-plan existence (SEC-24).

| TC ID | Attempt | Expected |
|---|---|---|
| TC-SEC-01 | Automated cross-tenant suite (existing): user of plan X attempts read / update / delete on every plan-scoped table of plan Y, including measurement consent/events and survey consent/responses if persisted, plus forged `plan_id` pull/event binding | Every attempt denied by RLS or authenticated server validation. **Runs on every PR once migrations exist; blocks the RC** |
| TC-SEC-02 | Removed member replays last valid token (existing) | Denied identically to a never-member |
| TC-SEC-04 | Enumeration: request a valid-but-foreign `plan_id` vs a nonexistent one | **Responses indistinguishable** — foreign plans must not be distinguishable from nonexistent ones, or existence leaks |
| TC-SEC-05 | Direct REST bypass of the app layer | RLS denies; app-layer checks are not the only control (SEC-22) |
| TC-SEC-06 | Policy coverage | Every v1 plan-scoped table, including new `checklist_items` and any persisted consent/measurement/survey rows, has a plan-membership policy **and** `FORCE ROW LEVEL SECURITY`; a new table without one fails CI. v1.1 attachments also require metadata-table and Storage object-policy checks before release (SEC-43). | SEC-22, SEC-23, SEC-43 |

Maps to **SEC-07, SEC-09, SEC-22, SEC-23, SEC-24, SEC-25**.

### 7.2 Migrations

| TC ID | Asserts |
|---|---|
| TC-MIG-01 | Forward: every schema version N → N+1 applies against a fixture DB with representative data; no row lost, no money value altered |
| TC-MIG-02 | Backward: N+1 → N either applies cleanly or fails loudly and refuses to run — **never partially applies** |
| TC-MIG-03 | Round-trip on a device DB holding queued unsynced writes: queue survives migration; no write dropped or duplicated |
| TC-MIG-04 | Transactional local drift upgrade from an old client retaining unknown `entity_type`/`field_name` and an unsynced queue: preserve full log, ordering/`schema_version`, cursor and queue; rebuild projections from the complete retained log, project formerly unknown rows exactly once in order and recover correct integer-centavo totals; no premature projection of unknown money inputs (ADR-49). |
| TC-MIG-05 | Inject failure at drift schema migration and at projection rebuild separately: rollback the whole local transaction in both cases; schema, log, queue and pull cursor remain unchanged, no partially recomputed total; retry after fix succeeds and preserves idempotency (ADR-49). |

### 7.3 Backup / restore drill

| TC ID | Asserts |
|---|---|
| TC-BAK-01 | Backups encrypted at rest; restore requires project owner + MFA (SEC-27) |
| TC-BAK-02 | **Measured restore drill, run monthly and before each release:** restore the most recent backup to a scratch project, verify row counts and a checksum of `change_log` against source, and **record wall-clock restore time in the drill log**. Pass condition: restore completes, data verifies, and the measured time is recorded. A drill with no recorded duration is a FAIL |

### 7.4 Device at-rest security — real device only

| TC ID | Asserts | Maps to |
|---|---|---|
| TC-SEC-03 | **No cloud auto-backup of the local DB.** Trigger a genuine iCloud / Finder backup and an Android Auto Backup, then inspect the backup contents: the encrypted SQLite file **and** its key are absent. Financial data plus sponsor and guest names must never reach platform cloud backup | SEC-16 |
| TC-SEC-07 | SQLCipher at rest: pull the DB file off a real device; `sqlite3` cannot open it and `strings` reveals no sponsor name, supplier name, or peso amount | SEC-12 |
| TC-SEC-08 | Key storage: SQLCipher key present in Keychain / Keystore only — absent from the app bundle, source, shared preferences, and the DB itself | SEC-13 |
| TC-SEC-09 | No-passcode device: key item uses `WhenUnlockedThisDeviceOnly` (iOS) / no weakened Keystore fallback (Android); one-time warning shown | SEC-14 |
| TC-SEC-10 | Log hygiene: scripted scan of a captured log sample finds zero peso amounts tied to a user, zero sponsor/guest names, zero emails, zero token prefixes | SEC-28 |

These five run **only on physical hardware** (§1.3). Simulators do not reproduce real file-protection classes or genuine cloud-backup behaviour, so a simulator pass here is not evidence.

---

## 8. E2E — the MVP scenario

**TC-E2E-01** — one scripted Maestro run of the full 20-step scenario in `mvp-user-stories.md` §1, executed on **both** iOS and Android. Step numbers below match that document exactly.

| Steps | Covered behaviour |
|---|---|
| 1–2 | Account + plan creation; setup with budget ₱350,000, 150 guests, garden, church, OOT yes; completes under 10 min |
| 3–4 | Allocation produced from pinned ruleset; every figure tappable to its rule; one category overridden and preserved |
| 5 | Partner B invited, joins on a second device, sees identical figures **including the override** |
| 6–10 | All six hidden fees prompted; crew meals 18 × ₱350; OOT for 3 suppliers; aircon ₱8,000; corkage explicitly dismissed with attribution; overtime + venue power remain visibly outstanding |
| 11 | Dashboard gross + variance against budget |
| 12–14 | Pledge logged tentative → **net unchanged**, appears as expected; marked confirmed → **still unchanged**, exposure rises; one ₱50,000 receipt → derived received and **net drops by ₱50,000** (D2 path asserted in E2E, not only unit) |
| 15–17 | Guest what-if 150 → 180 previewed, crew meals excluded, committed; all figures propagate |
| 18–19 | B offline: edits actual, adds an entry, inserts a payment row — all succeed. A edits a different field on the same entry online |
| 20 | B reconnects: convergence, no lost writes, attribution correct, same-field conflict surfaced |
| Gate | The additional gate from that doc: steps 2–17 repeated with connectivity disabled throughout, syncing correctly on reconnect |

**Pass condition:** all 20 steps plus the offline gate complete on both platforms with no workaround. A step requiring a manual nudge is a FAIL.

---

## 9. Defect policy

| Severity | Definition | Examples |
|---|---|---|
| **S1 — Critical** | Data loss, data corruption, cross-tenant exposure, or money computed wrong | Cross-tenant read; a lost offline write; wrong net out-of-pocket; buffer drift; queue dropped on OS restart |
| **S2 — Major** | A v1 requirement is unmet with no workaround, or a safety control fails | Removal not effective on next sync; a hidden fee not prompted; offline CRUD unavailable for an entity; constrained money form leaking into a ledger row |
| **S3 — Moderate** | Requirement met but with a workaround, or a non-money display defect | Variance percent shown to 2 dp instead of 1; over-cap indicator appears late; change-log filter wrong |
| **S4 — Minor** | Cosmetic, or copy not matching the spec without misleading | Label wording drift; tile spacing; non-blocking layout issue at largest type size |

**Blocking rule.** **S1 and S2 block a release candidate.** S3 may ship with a documented owner and target release. S4 is backlog.

**Special rule (relocated from REQ-OF-1 cl. 4, UT-7):** any v1 operation that cannot complete offline is by definition **at least S2**, because REQ-OF-1 cl. 3 forbids degrading a feature while offline.

**Tracking.** GitHub Issues in `rhon-dev/Kasaran-App`, labelled `S1`…`S4` plus the area (`area:sync`, `area:allocation`, `area:security`). Each defect must cite the REQ or SEC ID it violates and the TC ID that caught it, or state that no test caught it — an S1/S2 with no covering test also requires a new TC before close.

---

## 10. Release-candidate exit criteria

Countable. Every line is pass/fail, no partial.

| # | Criterion | Measure |
|---|---|---|
| 1 | REQ coverage | **62 v1 REQ IDs mapped (70 total REQ IDs)**; every shippable clause must have a passing case, including Prompt 4 cases in §4.8, Prompt 5 consent/survey/age cases in §4.9, and a separate full SEC-32 copy (TC-EX-08). These are specified tests, **not** current passing results. Five REQ-AI IDs and two v1.1 IDs are out of v1; REQ-EX-1 requires completed manual review. Do not declare REQ-AE-2 adequacy or REQ-CK-1 verified presets passed while OQ-04/OQ-11 are open; those capabilities cannot ship as verified. |
| 2 | Fixtures | **All five fixture specifications must match expected values exactly**: FIX-A/B/C each at base and +25 guests, FIX-D at its fixed date, FIX-E at 20 and 25 guests — 10/10 fixture/related **planned** TCs (TC-FIX-A1…E1, TC-PL-19, TC-AE-05). Additionally §3.6 overlays have their own Prompt 4 case assertions; no original FIX-A–D expected output is replaced. |
| 3 | Defects | **Zero open S1. Zero open S2.** |
| 4 | Sync matrix | **Every TC-SE row in §5 green on both iOS and Android**; TC-SE-40/41 assert alias/request mechanics only, not counsel-blocked shared erasure |
| 5 | Offline matrix | **Every entity row in §6.1 and durability/protocol row in §6.2 green**; the string scan in TC-OF-10 finds zero prohibited words |
| 6 | Tenant isolation | **TC-SEC-01 green in CI**, plus TC-SEC-04…06 green. Non-negotiable |
| 7 | SEC gate — beta tier | **All security-plan §7 items marked PASS for internal beta are PASS.** Any unverifiable item counts as FAIL |
| 7b | Device at-rest security | TC-SEC-03, TC-SEC-07…10 green **on physical hardware** — simulator results do not count |
| 8 | E2E | **TC-E2E-01 all 20 steps + offline gate green on both platforms** |
| 9 | Migrations and sync protocol | TC-MIG-01…05 and TC-API-06…09 green; shared erasure remains blocked under OQ-01 |
| 10 | Restore drill | TC-BAK-02 completed during the current monthly cycle **and before this release**, with a recorded restore duration |
| 11 | Rounding | TC-GEN-05 drift guard green; no cent gained or lost over 1,000 iterations |
| 12 | Static money check | TC-GEN-01 lint clean — zero `double` in money paths |
| 13 | Prompt 4 privacy and verification | TC-EX-03/04/08 demonstrate CSV neutralization, independent PDF name redaction and **full** personal-data copy; TC-CK-01/05 expose NEEDS VERIFICATION and no unverified due-date preset. Neither redacted summary nor four curated CSVs alone satisfy SEC-32. |

### 10.1 What this plan does NOT cover

Stated so the residual risk is visible rather than assumed away.

1. **Performance and load.** No latency budgets, no large-plan stress (e.g. 2,000 guests, 10,000 change-log rows), no cold-start timing, no battery or sync-bandwidth measurement. A plan that syncs correctly but takes 40 s to open would pass every criterion above.
2. **Accessibility beyond automated checks.** Contrast ratios and touch-target sizes are checkable; **actual screen-reader usability is not**. Full WCAG 2.2 AA conformance cannot be claimed from this plan — it needs manual testing with VoiceOver and TalkBack plus expert review (ux-spec §9.4).
3. **Penetration testing.** TC-SEC-* proves the RLS policy denies the cases we thought of. It is not an adversarial security assessment, and it does not cover provider misconfiguration, dependency supply-chain, or auth-flow abuse beyond token replay.
4. **Erasure behaviour (OQ-01).** Per ADR-26, shared-record DPA erasure test cases remain **un-stubbed and blocked pending counsel**. See §11. This is a known compliance gap at RC.
5. **Budget adequacy (OQ-04).** TC-AE-07 asserts nothing. The feature cannot ship verified.
6. **Partial and withdrawn pledges (UT-10, UT-11) — resolved.** TC-PL-23, TC-PL-35, TC-PL-42…50 and FIX-D cover receipt-based support; these are planned tests, not executed results.
7. **Negative ledger adjustments (TC-LG-13) — resolved.** Positive refund rows and lower actual cost represent refunds and discounts without negative actuals.
8. **Localization.** English-only v1 (ux-spec §8.4). v1.1 adds the deferred pseudo-localization/overflow cases TC-LO-01…04; RTL is not specified.
9. **Device and OS breadth.** Two devices, latest−1 OS. No matrix across older Android OEM skins, low-memory devices, or tablets.
10. **Payment rails and AI.** Initiation/settlement of funds (REQ-AI-4) and AI remain out of v1. Manual payment and receipt *records* are v1 and covered above; no PCI or model-behaviour testing.
11. **Upgrade path from a shipped build.** TC-MIG-04/05 cover simulated old-client local migration and retained unknown rows with queued writes; a real store build N → N+1 upgrade on a physical user's device with an older pinned ruleset is still not covered.
12. **Checklist source verification (OQ-11).** TC-CK-01/02/04/05 specify unverified labels, user-entered dates, completion and optional fees; no legal/church applicability or preset date-offset result is asserted. TC-CK-03 is blocked pending item-specific source evidence from the relevant LGU, civil registrar and parish/church. Do not release preset rules as verified until the gate closes.
13. **v1.1 photos (ADR-59).** TC-AT-01…04 are deferred backlog/design gates, not executed Storage or upload results. Size/MIME values and Photos privacy review must be approved before implementation and shipment; OCR stays separate.

---

## 11. Blocked — pending counsel (unchanged, per ADR-26)

- **Erasure vs mutual removal (OQ-01, SEC-33/38).** With mutual one-sided removal, each partner independently controls one shared record. A test for "partner A requests erasure" must confirm B's lawful copy survives and that erasure is distinct from removal — but the correct behaviour is counsel-gated and not yet defined, so `TC-ERASE-*` **cannot be authored with a verifiable expected result** until OQ-01 is resolved. Flagged, not stubbed with a guessed outcome.
- **NPC registration / DPO designation (OQ-02, SEC-37).** No test; a compliance determination, not a behaviour.
