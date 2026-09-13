# Kasaran — Testing Plan

*Inputs: [requirements.md](./requirements.md), [mvp-user-stories.md](./mvp-user-stories.md), [design.md](./design.md), [ux-spec.md](./ux-spec.md), [security-plan.md](./security-plan.md), [decision-log.md](./decision-log.md). No test code — this specifies what is tested, how, and with what data.*

**ID policy.** TC IDs are stable and never reused. This revision **preserves** all previously assigned IDs (TC-SE-10…22, TC-PL-10…12, TC-SEC-01…03) and allocates new ones in non-overlapping ranges.

---

## 0. Platform conflict — must be resolved before the tooling section is actionable

**The request specifies a React Native stack. REQ-PLT-1 mandates Flutter**, and GIV-02 in the decision log records React Native as **SUPERSEDED by ADR-12** (Flutter + SQLite/`drift`). I have not silently switched either way.

This is not a cosmetic conflict — it changes the E2E answer you asked for:

> **Detox is React Native-specific and does not drive Flutter apps.** If the platform is Flutter, "choose Detox or Maestro" has only one valid answer. If the platform is genuinely React Native, Detox becomes available and the whole stack below changes.

So §1 gives the **canonical stack for the locked platform (Flutter)**, plus a **column-for-column React Native mapping** so the plan translates immediately if RN is reinstated. Everything from §2 onward (traceability, fixtures, sync matrix, backend, exit criteria) is platform-independent and holds under either.

**Decision needed:** confirm Flutter (and I delete the RN column), or reinstate RN (and I rewrite §1 and flip REQ-PLT-1 / GIV-02 / ADR-12).

---

## 1. Tooling decision

### 1.1 Canonical stack — Flutter (per REQ-PLT-1, ADR-12)

| Layer | Choice | Justification |
|---|---|---|
| Unit runner | `flutter_test` (bundled) + `mocktail` for doubles | No third-party runner needed. The `domain/` layer imports neither Flutter nor `drift` (design §1.2), so calculation tests run as plain Dart — fast, no emulator, no DB. This is where every fixture in §3 is asserted. |
| Component / widget testing | `flutter_test`'s `WidgetTester` + `golden_toolkit` for golden snapshots | Widget tests are the Flutter equivalent of a component testing library. Goldens catch bento-tile layout and money-format regressions (REQ-GEN-2A) that assertions miss. |
| Integration (in-process) | `integration_test` package | Drives the real widget tree against a real SQLite DB on device/emulator. Covers offline CRUD and sync replay where a unit test cannot. |
| E2E driver | **Maestro** | Forced and also preferred: Detox does not support Flutter. Independently, Maestro's flows are declarative YAML, run unmodified against iOS simulators and Android emulators, tolerate async UI without explicit waits, and need no in-app instrumentation — which matters because E2E must exercise the shipped binary, not a test build. |
| Static analysis | `dart analyze` + custom lint rule banning `double` in money paths | REQ-GEN-1 forbids floating-point money. That is not observable at runtime once a value is already wrong; it must be caught statically. See TC-GEN-01. |
| DB migration harness | `drift` schema-version tests with generated fixtures | Forward and backward migration (§7). |

### 1.2 React Native equivalents (if RN is reinstated)

| Layer | Flutter | React Native |
|---|---|---|
| Unit runner | `flutter_test` + `mocktail` | Jest + `ts-jest` |
| Component testing | `WidgetTester`, `golden_toolkit` | React Native Testing Library, `jest-image-snapshot` |
| Integration | `integration_test` | Jest + `@testing-library/react-native` with an in-memory SQLite adapter |
| E2E | Maestro | **Detox** (grey-box, RN-aware, faster and less flaky than black-box) **or** Maestro (black-box, simpler, cross-platform). Under RN I would pick Detox for its synchronisation with the RN bridge, accepting the heavier setup. |
| Money static check | custom `dart analyze` lint | ESLint rule + `BigInt`/branded-type enforcement (harder — JS has no int64, see design §1.5) |

### 1.3 How E2E runs on both platforms

One Maestro flow set, two targets. Flows live in `e2e/flows/` and are parameterised only by platform-specific selectors where unavoidable.

- **iOS:** iPhone 15 simulator, latest−1 iOS, on a macOS CI runner.
- **Android:** Pixel 6 API 34 emulator, on a Linux CI runner.
- The full MVP scenario (§8) runs on **both** as a required gate. Platform-specific flows (backup exclusion, Keychain vs Keystore) run only where meaningful.

### 1.4 Where each suite runs, and why

| Suite | CI (every PR) | CI (nightly) | Local only | Real device only | Why |
|---|---|---|---|---|---|
| Domain unit tests (incl. all §3 fixtures) | ✅ | | | | Pure Dart, seconds, no device. The fixtures are the fastest highest-value signal in the project. |
| Widget tests | ✅ | | | | Headless, fast. |
| Golden snapshots | ✅ (verify) | | ✅ (update) | | Updating goldens is a human judgement; verification is automatic. |
| `integration_test` | ✅ Android emulator | ✅ iOS simulator | | | Android emulators are cheap on Linux runners; macOS runners are expensive, so iOS runs nightly. |
| Maestro E2E — MVP scenario | | ✅ both platforms | ✅ | | Too slow for every PR; required nightly and before any RC. |
| API contract + tenant isolation (§7) | ✅ | | | | **TC-SEC-01 is a release gate-blocker** (SEC-24). Must run on every PR. |
| Migration forward/backward | ✅ | | | | Cheap, and a bad migration is unrecoverable in the field. |
| Backup/restore drill | | ✅ weekly | | | Needs a real restore target; measured, not simulated. |
| SQLCipher file extraction (SEC-12) | | | | ✅ | Requires pulling the DB file off a real device and running `strings`. Simulators do not reproduce real file protection. |
| Keychain / Keystore key protection (SEC-13) | | | | ✅ | Simulator keychains do not enforce real protection classes. |
| Cloud auto-backup exclusion (SEC-16) | | | | ✅ | Requires triggering a genuine iCloud / Android Auto Backup and inspecting its contents. Not reproducible on a simulator — this is the single most important real-device test. |
| No-passcode device behaviour (SEC-14) | | | | ✅ | Cannot configure a simulator into a realistic no-passcode state. |
| Airplane-mode long-duration + OS restart queue durability | | | ✅ | ✅ | Emulator network toggling does not faithfully model radio loss; OS restart durability must be seen on real hardware. |

---

## 2. Traceability matrix

Every REQ ID in `requirements.md` (54 total) appears. Levels: **U** unit, **I** integration, **E** E2E, **M** manual/review, **S** static analysis.

| REQ ID | Test IDs | Level |
|---|---|---|
| REQ-PLT-1 | TC-PLT-01 | M (build inspection) |
| REQ-PLT-2 | TC-PLT-02, TC-OF-09 | I |
| REQ-PLT-3 | TC-PLT-03 | I |
| REQ-GEN-1 | TC-GEN-01 | S (see §2.1 — runtime-untestable) |
| REQ-GEN-2 | TC-GEN-02 | U |
| REQ-GEN-2A | TC-GEN-03, TC-GEN-04 | U + widget |
| REQ-BS-1 | TC-BS-01 | I |
| REQ-BS-2 | TC-BS-02 | U + I |
| REQ-BS-3 | TC-BS-03 | I |
| REQ-BS-4 | TC-BS-04 | U |
| REQ-BS-5 | TC-BS-05, TC-GM-06 | U |
| REQ-BS-6 | TC-BS-06 | I |
| REQ-LG-1 | TC-LG-01, TC-LG-02 | U + I |
| REQ-LG-2 | TC-LG-03, TC-LG-04 | I |
| REQ-LG-3 | TC-LG-05 | U |
| REQ-LG-4 | TC-LG-06, TC-LG-07 | U |
| REQ-LG-5 | TC-LG-08, TC-LG-09, TC-LG-10 | U + I |
| REQ-LG-6 | TC-LG-11, TC-LG-12 | U |
| REQ-HF-1 | TC-HF-01, TC-HF-02, TC-HF-03, TC-HF-04 | U + I |
| REQ-HF-2 | TC-HF-05, TC-HF-06 | U |
| REQ-HF-3 | TC-HF-07, TC-HF-08 | U + I |
| REQ-PL-1 | TC-PL-13 | U |
| REQ-PL-2 | TC-PL-10, TC-PL-11, TC-PL-14 | U |
| REQ-PL-3 | TC-PL-12, TC-PL-15 | U |
| REQ-PL-4 | TC-PL-16, TC-PL-17 | U |
| REQ-PL-5 | TC-PL-18 | U |
| REQ-GM-1 | TC-GM-01, TC-GM-02, TC-GM-03 | U |
| REQ-GM-2 | TC-GM-04, TC-GM-05 | U |
| REQ-GM-3 | TC-GM-07 | U |
| REQ-GM-4 | TC-GM-08 | U |
| REQ-GM-5 | TC-GM-09, TC-GM-10 | U + I |
| REQ-AE-1 | TC-AE-01, TC-AE-02, TC-AE-03, TC-AE-04 | U |
| REQ-AE-2 | TC-AE-05, TC-AE-06, **TC-AE-07 (BLOCKED)** | U |
| REQ-AE-3 | TC-AE-08 | U |
| REQ-AE-4 | TC-AE-09 | U + widget |
| REQ-AE-5 | TC-AE-10, TC-AE-11 | U |
| REQ-AE-6 | TC-AE-12 | U |
| REQ-SE-1 | TC-SE-23 | I |
| REQ-SE-2 | TC-SE-20, TC-SE-21, TC-SE-24 | U + I |
| REQ-SE-3 | TC-SE-25 | I |
| REQ-SE-4 | TC-SE-15, TC-SE-26 | I |
| REQ-SE-5 | TC-SE-16, TC-SE-18 | I |
| REQ-SE-6 | TC-SE-10, TC-SE-11, TC-SE-12, TC-SE-13, TC-SE-14, TC-SE-17, TC-SE-19, TC-SE-22 | I + E |
| REQ-OF-1 | TC-OF-01 … TC-OF-08 | I |
| REQ-OF-2 | TC-OF-09 | I |
| REQ-OF-3 | TC-OF-10 | I |
| REQ-OF-4 | TC-OF-11 | U + I |
| REQ-OF-5 | TC-OF-12, TC-SE-13 | I |
| REQ-AI-1 | — | Out of v1 scope (AI phase) |
| REQ-AI-2 | — | Out of v1 scope (AI phase) |
| REQ-AI-3 | — | Out of v1 scope (AI phase) |
| REQ-AI-4 | — | Out of v1 scope (AI phase) |
| REQ-AI-5 | — | Out of v1 scope (AI phase) |
| REQ-EX-1 | TC-EX-01 | M (see §2.1) |

**Coverage:** 48 of 54 REQ IDs have at least one mapped executable test. 5 (REQ-AI-1…5) are deliberately out of v1 scope, not gaps. 1 (REQ-EX-1) is review-verified only. Nine clauses across otherwise-tested requirements are untestable as written — §2.1.

### 2.1 Untestable-as-written — defects in the requirement, not skipped tests

Each of these is a flaw in the requirement's wording or an unresolved upstream dependency. None is silently dropped.

| # | Requirement | Why it cannot be tested as written | Fix needed |
|---|---|---|---|
| UT-1 | **REQ-GEN-1** | "SHALL NOT use binary floating-point" is not observable at runtime — by the time a value is wrong, the type is already gone. No behavioural assertion exists. | Reword as a static-analysis obligation. Covered by TC-GEN-01 (lint), which is the only honest verification. |
| UT-2 | **REQ-AE-2 cl. 3** (budget adequacy indicator) | Depends on `reference_costs`, which is **unpopulated** (OQ-04). Expected total cost is not computable, so no expected value can be asserted. | Populate reference costs per region tier. **TC-AE-07 is authored but BLOCKED with no assertion** — same discipline as ADR-26. |
| UT-3 | **REQ-LG-1 cl. 8** (notes ≤ 2,000 chars) | States a bound but not the behaviour at the bound — reject? truncate? warn? counter? There is no defined expected result. | Specify the at-limit behaviour, then test. |
| UT-4 | **REQ-SE-5 cl. 7** (ownership-transfer expiry) | Expiry is required but the duration is undefined (OQ-05). Cannot assert when it expires. | Fix the duration (7 days matches the invite window). |
| UT-5 | **REQ-GM-1 cl. 6** (designated driving RSVP status) | Requires a designated status but fixes no default, so a fresh plan's behaviour is undefined. | Set the default (`invited` recommended). |
| UT-6 | **REQ-SE-6 cl. 7** ("MAY offer a local wipe") | Permissive `MAY` with no obligation — nothing to assert either way. | Either make it SHALL, or move it out of the requirement into UX guidance. Interacts with OQ-03. |
| UT-7 | **REQ-OF-1 cl. 4** ("IF an operation cannot complete offline, THEN it is a defect") | Meta-statement about the process, not system behaviour. Not a testable assertion. | Move to the testing/defect policy (it now lives in §9). |
| UT-8 | **REQ-PLT-2 cl. 4** (engine is SQLite via drift/sqflite) | A build fact, not a behaviour. | Verify by dependency inspection (folded into TC-PLT-01). |
| UT-9 | **REQ-EX-1** (no marketplace/directory/reviews/booking) | Proving the *absence* of a feature cannot be done by automated test; a passing suite proves nothing about what is not there. | TC-EX-01 is a structured code/UI review checklist, explicitly manual. |

---

## 3. Calculation fixtures

**These are the authority for expected values.** Tests assert against these hand-computed numbers, never against whatever the implementation returns.

**Committed as data.** Each fixture lives at `test/fixtures/FIX-A.json`, `FIX-B.json`, `FIX-C.json` — version-controlled, human-readable, loaded by the domain unit tests. **Changing any expected value requires an explicit justification in the PR description**, naming the requirement or ADR that changed. A PR that adjusts a fixture to make a failing test pass, without that justification, is rejected on review. The fixtures are the specification; the code conforms to them.

### 3.0 Rules applied to all three fixtures

Stated once here, applied identically everywhere (this is the rounding-drift guard of §4):

1. **Storage:** all money as integer centavos (REQ-GEN-1). ₱2,400.00 → `240000`.
2. **Rounding:** half-up to 2 dp, applied **only at display** (REQ-GEN-2). Intermediate arithmetic never rounds.
3. **Allocation:** baseline percentages from ADR-10 — Catering & Venue 40, Photo & Video 15, Attire & Styling 10, Coordination 10, Entourage & Misc 5, Buffer 20. Rounding remainder → Buffer (REQ-AE-1 cl. 6).
4. **Regional index does NOT change allocation shares** (ADR-11, REQ-AE-2 cl. 1). Metro 1.00 / Provincial 0.85 / Destination 1.20 affect *expected total cost* and *rate suggestions* only. Per-category skew defaults to 1.0, so **all three fixtures produce identical allocation percentages despite different regions.** A naive implementation that scales shares by the index will fail TC-AE-05 — that is the point.
5. **Net out-of-pocket = gross − received only** (ADR-22 / D2). `tentative` + `confirmed` form the separate *expected* figure and never reduce net. Outstanding exposure = `confirmed` not yet received.
6. **Crew meals never scale with guest count** (REQ-GM-4). They scale with crew headcount only.
7. **Buffer remaining** = Buffer allocation − Σ overruns of non-Buffer categories. Under-spend in one category does **not** offset an overrun in another (REQ-AE-6 cl. 3).
8. **Category mapping of hidden fees:** crew meals, church aircon, corkage, venue power → Catering & Venue. OOT fees, overtime → Coordination.
9. **Expected total cost / budget adequacy is NOT asserted in any fixture** — `reference_costs` is unpopulated (OQ-04, UT-2).

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
| Ninong Ramon | Ninong | ₱50,000.00 | **received** |
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
| Ninong Eduardo | Ninong | ₱150,000.00 | **received** |
| Ninang Rosa | Ninang | ₱100,000.00 | confirmed |
| Groom's parents | family | ₱200,000.00 | **received** |

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
| Ninong Pedro | Ninong | ₱80,000.00 | **received** |
| Ninong Andres | Ninong | ₱60,000.00 | confirmed |
| Ninang Luz | Ninang | ₱50,000.00 | **received** |
| Ninang Baby | Ninang | ₱40,000.00 | tentative |
| Bride's uncle | family | ₱30,000.00 | **received** |
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

### 3.4 Fixture test IDs

| TC ID | Asserts | Level |
|---|---|---|
| TC-FIX-A1 | FIX-A @ 150: all figures in the expected table | U |
| TC-FIX-A2 | FIX-A @ 175 after +25 guests, incl. crew meals unchanged | U |
| TC-FIX-B1 | FIX-B @ 80: all figures, incl. identical allocation % to FIX-A | U |
| TC-FIX-B2 | FIX-B @ 105, incl. OOT and crew meals unchanged | U |
| TC-FIX-C1 | FIX-C @ 300: all figures, incl. negative buffer / breach | U |
| TC-FIX-C2 | FIX-C @ 325, incl. over-budget and over-cap | U |
| TC-PL-19 | FIX-C net = ₱335,750.00 exactly; explicitly not 250,750 or 190,750 | U |
| TC-AE-05 | FIX-A / FIX-B / FIX-C allocation percentages are identical | U |

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
| TC-GEN-03 | Constrained bento form: `₱350,000` under ₱1M, `₱1.25M` at/above, truncated toward zero — `₱1,259,000` → `₱1.25M`, never `₱1.26M` (REQ-GEN-2A) |
| TC-GEN-04 | Constrained form never leaks: ledger rows, editors, change log, and every a11y label use the full form (REQ-GEN-2A cl. 4, 6) |
| TC-GEN-05 | **Drift guard:** summing 1,000 per-head line items then displaying equals displaying the stored total; no cent lost or gained across 1,000 iterations |

### 4.2 Allocation, normalization, overrides

| TC ID | Asserts |
|---|---|
| TC-AE-01 | Determinism: identical inputs + ruleset version → byte-identical output, 100 consecutive runs |
| TC-AE-02 | Ruleset validation: baselines summing to anything other than 10000 bp are **rejected at load** (REQ-AE-1 cl. 4) |
| TC-AE-03 | Rounding remainder assigned entirely to Buffer; Σ allocations == total budget **exactly**, tested across budgets ₱1 … ₱9,999,999 in a property test |
| TC-AE-04 | Worked example: ₱350,000 NCR → 140,000 / 52,500 / 35,000 / 35,000 / 17,500 / 70,000 |
| TC-AE-05 | **Regional index does not alter shares** — FIX-A/B/C percentages identical (ADR-11) |
| TC-AE-06 | Per-category skew *does* alter shares, and renormalises so Σ == budget exactly |
| TC-AE-07 | **BLOCKED — budget adequacy.** No assertion. `reference_costs` unpopulated (OQ-04, UT-2). Authored so the gap is visible; must not be given a guessed expected value. |
| TC-AE-08 | Ruleset pinning: publishing a new ruleset leaves existing plans numerically unchanged (REQ-AE-3 cl. 2) |
| TC-AE-09 | Every allocated figure carries a rule id + inputs; a figure with no explanation payload is not returned at all (REQ-AE-4 cl. 4) |
| TC-AE-10 | Override preserved across recompute; revert restores engine value; reverting one does not affect another |
| TC-AE-11 | **Overrides not summing to 100%:** if Σ overrides > budget → over-allocation warning naming the excess, **and no override is silently clamped or scaled** (REQ-AE-5 cl. 4). If Σ overrides < budget, non-overridden categories absorb the remainder; if *all* six are overridden and sum < budget, the shortfall is surfaced, not silently added to Buffer |
| TC-AE-12 | Buffer drawdown incl. the FIX-C negative case; under-spend does not offset overrun |

### 4.3 Per-head vs flat-rate, crew rollups

| TC ID | Asserts |
|---|---|
| TC-GM-04 | Per-head entry derives `rate × driving count`; flat entry invariant to every guest count |
| TC-GM-05 | Setting `actual` on a per-head entry sets `manually_valued` and stops recomputation (REQ-GM-2 cl. 5) |
| TC-GM-07 | Guest-count change propagates to gross, net, and every category variance **in one operation** — no figure lags |
| TC-GM-08 | Crew meals invariant to guest count; change only via crew headcount or per-meal rate |
| TC-GM-03 | Crew headcount never appears in any guest tier total |
| TC-GM-11 | Crew-meal rollup: per-supplier headcounts sum correctly (18 / 22 / 15 across the fixtures); removing a supplier reduces the rollup by exactly that supplier's contribution |

### 4.4 Pledge offset math

| TC ID | Asserts |
|---|---|
| TC-PL-10 | Confirmed pledge leaves net unchanged, appears in expected figure (existing) |
| TC-PL-11 | confirmed → received decreases net and expected by the same amount (existing) |
| TC-PL-12 | Tentative behaves as expected-only, absent from net breakdown (existing) |
| TC-PL-14 | Gross never changes on any pledge status change |
| TC-PL-16 | Exposure = confirmed-not-received; TC-PL-17 renders ₱0.00 not blank |
| TC-PL-18 | Net breakdown sums exactly to gross − net and contains only `received` |
| TC-PL-19 | FIX-C net = ₱335,750.00 (D2 regression, §3.3) |
| TC-PL-20 | Pledges **exceeding total budget**: 3 received pledges totalling ₱600,000 against a ₱500,000 gross → net = **−₱100,000.00**, displayed as `−₱100,000.00` (REQ-GEN-2 cl. 4). Net is *not* floored at zero; a couple genuinely over-sponsored is a real state |

**Two gaps found while writing these — requirement defects, extending §2.1:**

| # | Gap | Consequence |
|---|---|---|
| **UT-10** | **Partially fulfilled pledges are not modelled.** REQ-PL-1 cl. 6 makes status a single enum {tentative, confirmed, received} with one `value`. A ₱60,000 pledge of which ₱25,000 has actually arrived cannot be expressed. | Cannot author a partial-fulfillment test — there is no field to assert on. Needs either a `received_amount` alongside `value`, or a documented decision that partial pledges are split into two records. **No expected value invented.** |
| **UT-11** | **Reneged pledges are not modelled.** No `withdrawn`/`reneged` state exists. Moving `confirmed` → `tentative` is semantically wrong (it was not tentative, it was broken), and deleting the record destroys the audit trail of who reneged. | Cannot author a renege test. Needs a state or a documented decision to delete-with-log. **No expected value invented.** |

Both were explicitly requested as unit-test areas. They cannot be tested because the data model has no way to represent them. Flagged rather than faked.

### 4.5 Boundary cases

| TC ID | Case | Expected |
|---|---|---|
| TC-BS-07 | Budget ₱0 | **Rejected** at setup (REQ-BS-2 cl. 1) — budget must be > 0. Allocation never runs. |
| TC-BS-08 | Budget ₱1 | Accepted. Allocation: rounding sends nearly everything to Buffer; Σ == ₱1 exactly |
| TC-GM-12 | Zero guests | Every per-head entry = ₱0.00; flat entries unchanged; gross = Σ flat; per-head cost display **suppressed, not division-by-zero** |
| TC-GM-06 | Guest count above cap | Full calculation still returned **plus** over-cap indicator naming both numbers (REQ-BS-5 cl. 2, 3); nothing is blocked |
| TC-GM-13 | Guest count reduced below existing per-head actuals | `manually_valued` entries unchanged; derived entries scale down; no negative amounts |
| TC-PL-20 | Pledges exceed budget | See §4.4 — net goes negative, not floored |
| TC-LG-13 | Negative adjustment (credit / refund line) | A negative `actual` is **rejected** (REQ-LG-1 cl. 4 requires ≥ 0). **Finding:** there is therefore no way to record a supplier refund or discount. Flagged as a probable requirement gap — not invented here |
| TC-AE-13 | All six categories overridden to ₱0 | Σ overrides = 0 < budget; shortfall surfaced; no divide-by-zero in variance percent (REQ-LG-6 cl. 3) |

---

## 5. Sync & conflict tests

**Clock ADR status: DECIDED, not open.** ADR-21 (D1) fixes the ordering authority as a **server-assigned timestamp** applied at sync, with device monotonic counter then stable device id as tiebreakers; device wall-clocks are never authoritative. These tests are therefore **finalizable now** and are not blocked. (The instruction's "if that ADR is still OPEN" branch does not apply.)

**One deliberate asymmetry that must be tested explicitly.** General field LWW resolves to the **later** server timestamp (REQ-SE-2 cl. 3). Simultaneous mutual *removal* resolves to the **earlier** server timestamp (REQ-SE-6 cl. 9) — first defensive action wins. Same clock, opposite direction. This is intentional but is a likely implementation bug, so TC-SE-24 and TC-SE-22 assert opposite directions on purpose.

| TC ID | Scenario | Device A | Device B | Offline duration | Expected winner / end state | Expected change-log entry |
|---|---|---|---|---|---|---|
| TC-SE-24 | Same field, both offline | edits `ledger[x].actual` → ₱58,000, syncs first | edits `ledger[x].actual` → ₱62,000, syncs second | A 10 min, B 2 h | **B's ₱62,000 wins** (later server_ts, REQ-SE-2 cl. 3) | Both rows retained; A's marked superseded, value ₱58,000 intact, actor A |
| TC-SE-20 | Clock skew | clock correct, edits → ₱58,000, syncs **second** | clock **10 min fast**, edits → ₱62,000, syncs **first** | both brief | **A's ₱58,000 wins** — later *server* ts. B's fast clock is irrelevant | A current, B superseded; log shows server ts, not device ts |
| TC-SE-21 | Identical server_ts | write P | write Q | — | Higher `device_monotonic` wins; if equal, higher `device_id`. Both devices pick the **same** winner | Loser superseded |
| TC-SE-27 | Different fields, same record | edits `supplier_name` | edits `actual` | A 1 h, B 1 h | **Both persist.** No conflict. Record shows A's name + B's amount | Two independent entries, no supersession |
| TC-SE-28 | Delete on A vs edit on B | soft-deletes entry (`deleted_at`) at T1 | edits `actual` at T2 > T1 | both offline 1 h | Delete and edit are both field writes under LWW. **B's later edit to `actual` applies, but `deleted_at` remains set** — the row stays deleted with an updated amount. End state: entry absent from all totals. **Finding:** this is defensible but surprising; if the product intent is "edit resurrects the row," that must become an explicit requirement. Not assumed here | Both entries present; neither superseded (different fields) |
| TC-SE-29 | Create–create, near-identical | creates "Catering — Hotel A" ₱360,000 | creates "Catering – Hotel A" ₱360,000 | both offline 3 h | **Both rows persist as separate entries** (distinct client UUIDv7 keys); gross counts ₱720,000. No dedup in v1. **Finding:** flagged as a product question — silent duplicate-cost inflation is a realistic user harm; a same-category/amount/supplier warning may be warranted | Two creates, no supersession |
| TC-SE-30 | Long offline, stale dependent calculations | online throughout; guest count 150 → 200, allocations overridden | offline 6 days holding pre-change state, edits a per-head rate | B 6 days | Derived values are **never persisted** (design §1.4), so B has no stale stored totals to reconcile. On reconnect B replays, projections rebuild, and **both devices show identical recomputed gross/net/variance/buffer**. B's per-head rate edit applies against the *new* guest count, not the count B last saw | B's rate edit present and attributed; no phantom entries for derived figures |
| TC-SE-22 | **Simultaneous mutual removal** (existing) | removes B, server_ts T1 | removes A, server_ts T2 > T1 | both offline | **A survives** — removal with the *earlier* server_ts prevails (REQ-SE-6 cl. 9). Plan never memberless | Losing removal recorded as superseded, actor B preserved |
| TC-SE-25 | Convergence, order-independent | 20 mixed writes | 20 mixed writes | staggered | Applying the same 40 rows in any arrival order yields identical projections on both devices; re-running sync changes nothing | — |
| TC-SE-26 | Change-log integrity | — | — | — | Log is append-only: no UI or API path edits or deletes an entry; monetary entries carry prev + new value | — |

---

## 6. Offline / multi-device matrix

Every v1 entity, airplane mode, expected **end state** stated.

### 6.1 Airplane-mode CRUD per entity

| TC ID | Entity | Create | Read | Update | Delete | Expected end state after reconnect |
|---|---|---|---|---|---|---|
| TC-OF-01 | Plan setup (budget, date, cap, region) | ✅ | ✅ | ✅ | n/a | All setup edits present server-side; allocations recomputed identically on both devices |
| TC-OF-02 | Ledger entries | ✅ | ✅ | ✅ | ✅ | Every offline entry present exactly once; gross matches the local pre-sync value to the centavo |
| TC-OF-03 | Fee components (all six subtypes) | ✅ | ✅ | ✅ | ✅ | Per-type shapes intact; crew-meal rollup unchanged by sync |
| TC-OF-04 | Pledges | ✅ | ✅ | ✅ | ✅ | Statuses preserved; net/expected/exposure recompute to the same figures |
| TC-OF-05 | Guests (RSVP + tier) | ✅ | ✅ | ✅ | ✅ | Both axes preserved independently; driving count consistent |
| TC-OF-06 | Crew headcount | ✅ | ✅ | ✅ | n/a | Separate from guest totals after sync |
| TC-OF-07 | Allocation overrides | ✅ | ✅ | ✅ | ✅ (revert) | Overrides survive; engine values still visible alongside |
| TC-OF-08 | Hidden-fee prompt states | ✅ | ✅ | ✅ | n/a | `dismissed` retains dismisser + timestamp; `prompted_unfilled` still distinguishable from ₱0.00 |

### 6.2 Durability and interruption

| TC ID | Scenario | Expected end state |
|---|---|---|
| TC-OF-12 | Queue durability across **app kill** | 12 offline writes; force-quit; relaunch offline → all 12 still queued, count = 12, none duplicated. Reconnect → all 12 apply exactly once |
| TC-OF-13 | Queue durability across **OS restart** | Same 12 writes; full device reboot; relaunch → queue intact at 12, DB decrypts with the Keystore/Keychain key, no re-auth loss. **Real device only** |
| TC-OF-14 | Resume on reconnect | No user action required; replay begins on foreground/connectivity (REQ-OF-5 cl. 1). Progress and completion visible |
| TC-OF-15 | **Partial sync interruption mid-batch** | Push batch of 20; kill network after row 11 accepted. End state: rows 1–11 committed server-side with `server_ts`; rows 12–20 still queued locally. On retry, rows 1–11 are **insert-ignored** (idempotent, REQ-OF-5 cl. 3) and not double-counted; final gross equals the single-pass value exactly |
| TC-OF-16 | Write that cannot be applied | Surfaced to the partner with data intact, never discarded (REQ-OF-5 cl. 4); badge reads "1 change needs attention" (ux-spec §7.2 state 5) |
| TC-OF-09 | Offline computation parity | Allocation, guest what-if, variance, buffer, gross, net all compute on-device with no network; figures identical to the online result for the same inputs |
| TC-OF-10 | Offline indicator + pending count | Persistent indicator; exact count; escalates per ux-spec §7.2; **no copy contains "lost", "deleted", "discarded", or "failed to save"** — asserted by string scan |
| TC-OF-11 | Clock handling | `overdue` derived on read from device local date; two devices with different clocks may display different status **without generating a sync conflict**; status never written to shared state (REQ-OF-4) |
| TC-OF-17 | Two-device simultaneous editing → convergence | A and B both online, 30 s of concurrent edits across ledger, pledges, guests. End state: identical gross, net, expected, exposure, buffer remaining, and every category variance on both devices, to the centavo; change log identical in content and order |

---

## 7. Backend

| TC ID | Area | Asserts | Maps to |
|---|---|---|---|
| TC-API-01 | Contract — push | `POST /sync/push` accepts rows without `server_ts`, returns `{id, server_ts}` per accepted row; rejects malformed rows with 4xx and no partial commit | design §2.4 |
| TC-API-02 | Contract — pull | `GET /sync/pull?since_server_ts&limit` is cursor-paged, monotonic, terminates; `has_more` accurate | design §2.4 |
| TC-API-03 | Idempotency | Same batch pushed twice → second is a no-op; no total changes | SEC-20 |
| TC-API-04 | Auth required | Unauthenticated push/pull → 401 | SEC-01, SEC-03 |
| TC-API-05 | Membership write path | Direct client insert into `plan_members` → denied | SEC-25 |
| TC-EX-01 | Prohibition review | Manual checklist: no marketplace, directory, reviews, ratings, quotes, or booking in code or UI | REQ-EX-1, UT-9 |

### 7.1 Tenant isolation negative tests — the gate-blocker

**Rule:** a user of wedding X must receive **403 or 404 — never data, never an empty-but-valid payload that leaks existence** for wedding Y.

| TC ID | Attempt | Expected |
|---|---|---|
| TC-SEC-01 | Automated cross-tenant suite (existing): user of plan X attempts read / update / delete on every plan-scoped table of plan Y, incl. forged `plan_id` pull | Every attempt denied by RLS. **Runs on every PR; blocks the RC** |
| TC-SEC-02 | Removed member replays last valid token (existing) | Denied identically to a never-member |
| TC-SEC-04 | Enumeration: request a valid-but-foreign `plan_id` vs a nonexistent one | **Responses indistinguishable** — foreign plans must not be distinguishable from nonexistent ones, or existence leaks |
| TC-SEC-05 | Direct REST bypass of the app layer | RLS denies; app-layer checks are not the only control (SEC-22) |
| TC-SEC-06 | Policy coverage | Every plan-scoped table has a policy **and** `FORCE ROW LEVEL SECURITY`; a new table without one fails CI | SEC-22, SEC-23 |

Maps to **SEC-07, SEC-09, SEC-22, SEC-23, SEC-24, SEC-25**.

### 7.2 Migrations

| TC ID | Asserts |
|---|---|
| TC-MIG-01 | Forward: every schema version N → N+1 applies against a fixture DB with representative data; no row lost, no money value altered |
| TC-MIG-02 | Backward: N+1 → N either applies cleanly or fails loudly and refuses to run — **never partially applies** |
| TC-MIG-03 | Round-trip on a device DB holding queued unsynced writes: queue survives migration; no write dropped or duplicated |

### 7.3 Backup / restore drill

| TC ID | Asserts |
|---|---|
| TC-BAK-01 | Backups encrypted at rest; restore requires project owner + MFA (SEC-27) |
| TC-BAK-02 | **Measured restore drill, run weekly:** restore the most recent backup to a scratch project, verify row counts and a checksum of `change_log` against source, and **record wall-clock restore time in the drill log**. Pass condition: restore completes, data verifies, and the measured time is recorded. A drill with no recorded duration is a FAIL |

### 7.4 Device at-rest security — real device only

| TC ID | Asserts | Maps to |
|---|---|---|
| TC-SEC-03 | **No cloud auto-backup of the local DB.** Trigger a genuine iCloud / Finder backup and an Android Auto Backup, then inspect the backup contents: the encrypted SQLite file **and** its key are absent. Financial data plus sponsor and guest names must never reach platform cloud backup | SEC-16 |
| TC-SEC-07 | SQLCipher at rest: pull the DB file off a real device; `sqlite3` cannot open it and `strings` reveals no sponsor name, supplier name, or peso amount | SEC-12 |
| TC-SEC-08 | Key storage: SQLCipher key present in Keychain / Keystore only — absent from the app bundle, source, shared preferences, and the DB itself | SEC-13 |
| TC-SEC-09 | No-passcode device: key item uses `WhenUnlockedThisDeviceOnly` (iOS) / no weakened Keystore fallback (Android); one-time warning shown | SEC-14 |
| TC-SEC-10 | Log hygiene: scripted scan of a captured log sample finds zero peso amounts tied to a user, zero sponsor/guest names, zero emails, zero token prefixes | SEC-28 |

These five run **only on physical hardware** (§1.4). Simulators do not reproduce real file-protection classes or genuine cloud-backup behaviour, so a simulator pass here is not evidence.

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
| 12–14 | Pledge logged tentative → **net unchanged**, appears as expected; marked confirmed → **still unchanged**, exposure rises; marked received → **net drops by ₱50,000** (D2 path asserted in E2E, not only unit) |
| 15–17 | Guest what-if 150 → 180 previewed, crew meals excluded, committed; all figures propagate |
| 18–19 | B offline: edits actual, adds an entry, marks a payment — all succeed. A edits a different field on the same entry online |
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
| 1 | REQ coverage | **48/48** testable REQ IDs have a passing mapped test. The 5 AI-phase REQs are out of scope; REQ-EX-1 has a completed manual review |
| 2 | Fixtures | **All three fixtures match expected values exactly**, at base and at +25 guests — 8/8 fixture TCs green (TC-FIX-A1…C2, TC-PL-19, TC-AE-05) |
| 3 | Defects | **Zero open S1. Zero open S2.** |
| 4 | Sync matrix | **10/10 rows in §5 green on both iOS and Android** |
| 5 | Offline matrix | **8/8 entity rows + 9/9 durability rows green**; the string scan in TC-OF-10 finds zero prohibited words |
| 6 | Tenant isolation | **TC-SEC-01 green in CI**, plus TC-SEC-04…06 green. Non-negotiable |
| 7 | SEC gate — beta tier | **All security-plan §7 items marked PASS for internal beta are PASS.** Any unverifiable item counts as FAIL |
| 7b | Device at-rest security | TC-SEC-03, TC-SEC-07…10 green **on physical hardware** — simulator results do not count |
| 8 | E2E | **TC-E2E-01 all 20 steps + offline gate green on both platforms** |
| 9 | Migrations | TC-MIG-01…03 green |
| 10 | Restore drill | TC-BAK-02 completed within the last 7 days **with a recorded restore duration** |
| 11 | Rounding | TC-GEN-05 drift guard green; no cent gained or lost over 1,000 iterations |
| 12 | Static money check | TC-GEN-01 lint clean — zero `double` in money paths |

### 10.1 What this plan does NOT cover

Stated so the residual risk is visible rather than assumed away.

1. **Performance and load.** No latency budgets, no large-plan stress (e.g. 2,000 guests, 10,000 change-log rows), no cold-start timing, no battery or sync-bandwidth measurement. A plan that syncs correctly but takes 40 s to open would pass every criterion above.
2. **Accessibility beyond automated checks.** Contrast ratios and touch-target sizes are checkable; **actual screen-reader usability is not**. Full WCAG 2.2 AA conformance cannot be claimed from this plan — it needs manual testing with VoiceOver and TalkBack plus expert review (ux-spec §9.4).
3. **Penetration testing.** TC-SEC-* proves the RLS policy denies the cases we thought of. It is not an adversarial security assessment, and it does not cover provider misconfiguration, dependency supply-chain, or auth-flow abuse beyond token replay.
4. **Erasure behaviour (OQ-01).** Per ADR-26, shared-record DPA erasure test cases remain **un-stubbed and blocked pending counsel**. See §11. This is a known compliance gap at RC.
5. **Budget adequacy (OQ-04).** TC-AE-07 asserts nothing. The feature cannot ship verified.
6. **Partial and reneged pledges (UT-10, UT-11).** Untestable because unmodelled. Real user scenarios with no coverage.
7. **Negative ledger adjustments (TC-LG-13).** Refunds and discounts appear to be unrepresentable; flagged, unresolved.
8. **Localization.** English-only v1 (ux-spec §8.4). No pseudo-localization, no RTL, no translated-string overflow testing.
9. **Device and OS breadth.** Two devices, latest−1 OS. No matrix across older Android OEM skins, low-memory devices, or tablets.
10. **Payments and AI.** Out of v1 scope entirely (REQ-AI-4, REQ-EX-1). No PCI or model-behaviour testing.
11. **Upgrade path from a shipped build.** TC-MIG-* covers schema migration in isolation; there is no test of a real user upgrading from store build N to N+1 with queued offline writes and a pinned older ruleset.

---

## 11. Blocked — pending counsel (unchanged, per ADR-26)

- **Erasure vs mutual removal (OQ-01, SEC-33/38).** With mutual one-sided removal, each partner independently controls one shared record. A test for "partner A requests erasure" must confirm B's lawful copy survives and that erasure is distinct from removal — but the correct behaviour is counsel-gated and not yet defined, so `TC-ERASE-*` **cannot be authored with a verifiable expected result** until OQ-01 is resolved. Flagged, not stubbed with a guessed outcome.
- **NPC registration / DPO designation (OQ-02, SEC-37).** No test; a compliance determination, not a behaviour.
