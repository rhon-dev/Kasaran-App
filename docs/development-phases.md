# Kasaran — Development Phases

**24-phase index; detailed bodies 01–08.** This is a plan, not a completion certificate. Inputs and precedence: `decision-log.md` and `project-brief.md` govern `requirements.md`; `design.md`/`ux-spec.md`, `security-plan.md`, and `testing-plan.md` supply implementation constraints and test oracles. A requirement appears in exactly one *owning* phase below; a later verification gate is not a second assignment. The two v1.1 entries are assigned a **backlog handoff**, not implementation or release coverage.

## Phase index — 24 phases

A phase is a milestone with several independently testable **sittings**, not a promise to complete the entire phase in one sitting. External waits (beta, counsel, store review, observation) are gates, not sittings. No phase is marked complete solely because its body exists.

| # | Name | Owner | Depends on | Sole REQ ownership | Objective / sitting boundary |
|---|---|---|---|---|---|
| 01 | Repo, tooling & CI skeleton | DevOps/Release | — | REQ-PLT-1 | Flutter/CI skeleton; finish outstanding real CI gates |
| 02 | Money primitives & formatting | Backend | 01 | REQ-GEN-1, REQ-GEN-2, REQ-GEN-2A | Integer-centavo arithmetic and formatting/lint tests |
| 03 | Flutter shell & navigation | Mobile/Frontend | 01 | — | Placeholder routes, tabs, real-router/deep-link tests |
| 04 | Backend shell: environments & secrets | DevOps/Release | 01 | — | Local sync stubs/contracts; staging ref and production residency gated |
| 05 | Local encrypted store | Data & Sync | 03, 04 | REQ-PLT-2 | SQLCipher and hardware-backed keys; device verification |
| 06 | Shared-account auth & pairing | Security | 04, 05 | REQ-PLT-3, REQ-SE-1 | Verified-email sign-in, 18+ declaration, Start/Join, deep-link/paste invite |
| 07 | Data layer: entities & change-log writer | Data & Sync | 05, 06 | — | Several sittings: schemas/repositories; immutable log/RLS; migration tests |
| 08 | Sync engine: ordered replay & convergence | Data & Sync | 06, 07 | REQ-SE-2, REQ-SE-3, REQ-OF-5 | Several sittings: transport; commit ordering; projections; compatibility |
| 09 | Budget setup & requirements checklist | Mobile/Frontend | 02, 07, 08 | REQ-BS-1…6, REQ-CK-1 | Setup then optional manual checklist; verified presets blocked OQ-11 |
| 10 | Expense ledger & unticked templates | Mobile/Frontend | 09 | REQ-LG-1…9, REQ-TM-1 | Entries, schedule/payment/refund rows, reminders; suggestion-to-editor |
| 11 | Hidden-fee line items | Mobile/Frontend | 10 | REQ-HF-1…3 | Six prompts, typed fee components, explicit dismissal |
| 12 | Guest math | Backend | 10 | REQ-GM-1…6 | RSVP/priority, per-head/flat, what-if, affordable ceiling |
| 13 | Rule-based allocation | Backend | 02, 09, 12 | REQ-AE-1…7 | Pinned ruleset, overrides, buffer, explicit preview/apply; OQ-04 cost benchmarks |
| 14 | Pledges & gifts | Backend | 10, 13 | REQ-PL-1…7, REQ-GF-1…2 | Receipt-based net, linked payments, gifts and reconciliation |
| 15 | Dashboard, private export & consented feedback | Mobile/Frontend | 09–14 | REQ-EX-2, REQ-MT-1, REQ-SV-1 | Bento, offline export, opt-in metrics and skippable survey; distinct testable sittings |
| 16 | Shared editing & lifecycle | Data & Sync | 08, 15 | REQ-SE-4…6 | Activity/conflict UI, alias attribution, mutual removal/transfer; OQ-01 erasure unresolved |
| 17 | Offline feature hardening | Data & Sync | 16 | REQ-OF-1…4 | Full offline CRUD/computation, queue visibility, local clock, exports |
| 18 | Security, privacy & beta gate | Security | 17 | REQ-EX-1 | RLS/device/log/privacy controls, survey/metric notice review; no marketplace |
| 19 | QA execution & pre-beta production gate | QA + DevOps/Release | 18 | — | Planned TC suites on both platforms; provision approved production project, migrations, backup and privacy gates **before** real-data beta |
| 20 | Internal beta & real-couple UAT | Product Manager | 19 | — | Use only already-approved production environment; consent, multi-day soak/UAT, optional survey after wedding |
| 21 | Production readiness, submission & stabilisation | Production Readiness + DevOps/Release | 20 | — | Backup/restore and rollback, counsel/store gates, default Apple phased release, observation |
| 22 | **Post-launch** payments | Backend (Security reviewer) | 21 | REQ-AI-4 | Separate payment-rail design/build only after OQ-10 SEC block and external approvals |
| 23 | **Post-launch** AI | AI/ML | 21 | REQ-AI-1, REQ-AI-2, REQ-AI-3, REQ-AI-5 | On-device categorisation first; cloud advice/OCR/assistant later; separate sittings and gates |
| 24 | **v1.1 backlog handoff only** | Product Manager | 21 | REQ-LO-1, REQ-AT-1 | Plan later build/gates for locale and private photos; no v1 implementation claim |

**Old → new phase mapping:** 01–19 → same numbers; 20 (internal beta) + 21 (real-couple UAT) → 20; 22 (production readiness) + 23 (store submission/launch) + 24 (monitoring) → 21; 25 (payments) → 22; 26 (on-device AI) + 27 (cloud AI/OCR) → 23; **new 24** is a newly added v1.1 backlog handoff; former phase 24 monitoring is folded into 21. The current index is authoritative; references outside this file that intentionally cite old numbers must label them historical, while operational references use the new phase numbers (ADR-70).

**Status against source on this branch, not exit certification:** 01 is **partial**: Flutter project, workflow, Fastlane and lint skeleton exist, but the deliberate fail/recover CI evidence and release-artifact secret scan are not established. 02 is **partial**: money helpers/presenter and half-centavo/drift tests exist, but the custom money lint and CI evidence must still meet exit criteria. 03 is **partial**: screens 01–19, one production router, tabs and golden tests exist; production-router tests now cover `kasaran://accept/<token>`, auth/plan refresh and one SCR-19 path, but HTTPS verified App Links / Universal Links remain OQ-09 work and placeholder screens are not complete features. 04 is **partial**: local config, authenticated empty Edge stubs (including bounded pull limit), contract tests and CI job exist, **but no staging project ref is recorded** and OQ-07 residency remains open; local contract success does not prove authenticated staging, live production or remote CI. Phase 05 onward is planned, not implemented. A test file or CI job existing does not mean it has passed. Reassess after Prompt 5 D code changes land.

**Pre-beta production entry:** Phase 19 must obtain OQ-07 DPO/counsel processor, transfer and notice approval before provisioning the ADR-72-selected Singapore production project for real data. It must then deploy live Auth/migrations/RLS, prove SEC-24 and SEC-29…31/35, establish PITR plus an independently encrypted Auth-inclusive off-provider backup, test a scratch restore and break-glass route, verify the notice/support channel, and record the first real-couple go/no-go **before** phase 20. Phase 18 prepares security/privacy controls; phase 21 rechecks recovery and performs public store submission/rollout after beta. If any gate is unverified, phase 20 uses synthetic-only staging and does not recruit real couples. See deployment-plan §§1.1, 2.3, 7 and ADR-63–67/72.

**SEC-02 / phase 06 prerequisite:** `supabase/config.toml` currently has `[auth.email] enable_confirmations = false` for **local development only**. Staging and production **MUST set it to true** and prevent unverified accounts from creating or joining a plan; do not promote the local configuration unchanged. Require the 18+ sign-up declaration before real beta access, subject to counsel's legal-basis review. Staging remains synthetic-only; real couples' beta data belongs in the separately approved production environment, not staging. OQ-07 still blocks production real-data approval and the notice's publication until DPO/counsel review, despite ADR-72's Singapore region choice.

**Launch-readiness sittings in the later milestones:** Phase 15 distinguishes computation from existing synced `hidden_fee_prompts`/attributed `change_log` and wedding date from optional view-frequency events, with notice/consent, a payload allowlist and opt-in **off** until chosen; no third-party analytics SDK. A separate phase-15 sitting implements the optional, skippable in-app survey and explicit response action, with tests in 19 before inviting real couples in 20; a skip is not a response and a survey answer is not analytics consent. Phase 18 must gate SEC-29…31/35 (and the age and metric/survey notices) **before phase 20's first real-data beta**, not postpone those to store submission. Phase 19 must activate the paid tier, production PITR/backup, budget alerts, recovery proof and break-glass before any real beta; phase 21 rechecks them, requires the measured **monthly and pre-release** restore drills, RC-only macOS Maestro, and Apple's default iOS phased release for store rollout. No live rollout proceeds on an unverified backup, unresolved counsel gate or OQ-07; payment rails remain phase 22 and all AI phase 23.

## Self-validation

### (a) Exclusive REQ coverage matrix

`requirements.md` now defines **70 distinct REQ headings**, including REQ-MT-1 and REQ-SV-1. The index assigns each ID below to *one owner only*; later TC/SEC gates verify rather than double-assign.

| Requirement IDs (inclusive ranges) | Count | Sole phase | Scope |
|---|---:|---:|---|
| REQ-PLT-1; REQ-PLT-2; REQ-PLT-3 | 3 | 01; 05; 06 respectively | v1 |
| REQ-GEN-1, REQ-GEN-2, REQ-GEN-2A | 3 | 02 | v1 |
| REQ-BS-1…6; REQ-CK-1 | 7 | 09 | v1; OQ-11 blocks verified presets |
| REQ-LG-1…9; REQ-TM-1 | 10 | 10 | v1 |
| REQ-HF-1…3 | 3 | 11 | v1 |
| REQ-GM-1…6 | 6 | 12 | v1 |
| REQ-AE-1…7 | 7 | 13 | v1; OQ-04 blocks benchmark-dependent adequacy |
| REQ-PL-1…7; REQ-GF-1…2 | 9 | 14 | v1 |
| REQ-EX-2; REQ-MT-1; REQ-SV-1 | 3 | 15 | v1; metrics opt-in and optional survey distinct from crash diagnostics |
| REQ-SE-1; REQ-SE-2, REQ-SE-3; REQ-SE-4…6 | 6 | 06; 08; 16 respectively | v1 |
| REQ-OF-1…4; REQ-OF-5 | 5 | 17; 08 respectively | v1 |
| REQ-EX-1 | 1 | 18 | permanent prohibition, not feature implementation |
| REQ-AI-4 | 1 | 22 | post-launch payment rails, OQ-10 block; historical ID retained |
| REQ-AI-1, REQ-AI-2, REQ-AI-3, REQ-AI-5 | 4 | 23 | post-launch AI, not v1 |
| REQ-LO-1, REQ-AT-1 | 2 | 24 | v1.1 **backlog handoff only**, build/gate unassigned |
| **Total** | **70** | **one ownership row per ID** | **70 defined in requirements.md** |

### (b) SEC and TC phase gates (test specifications are not executions)

| Gate group | Planned implementation → verification |
|---|---|
| SEC-01…06, SEC-10/11; SEC-02 email confirmation/age | 04 config → 06 auth/invite → 18 gate; true staging/prod confirmation |
| SEC-07…09, SEC-12…16, SEC-17…21 | 16 removal, 05 encrypted store, 08 sync respectively → 18 device/adversarial gate |
| SEC-22…25, SEC-26 | 06/07 RLS, 04 CI secret scan → 18 tenant-isolation gate; new plan-scoped metrics/survey data needs policy coverage if persisted |
| SEC-27/28, SEC-29…36, SEC-37…42 | 21 backups, 18 log/privacy/consent/DPA beta gate, 21 counsel/store gate; export in 15 → 18/19 review |
| SEC-43/44 | 24 backlog handoff only; later v1.1 private Storage policy/label review, not v1 gate |
| TC-PLT-01…03, TC-GEN-01…05, TC-API-01/02/04/05 | 01/05/06; 02; 04 respectively; TC-API-03 in 08 |
| TC-MIG-01…03, TC-SEC-01/04/05/06 | 07 migrations/RLS → 18 adversarial check; 08 adds TC-MIG-04/05 upgrade/rebuild |
| TC-SE-20/21/24/25/27…30/33…39/43/44; TC-OF-12/15/18/23…26; TC-API-02/03/06…08 | 08 engine, protocol and migrations → 16 visible conflict/lifecycle → 19 cross-platform suite |
| TC-SE-10…19/22/23/26/31/32/40…42; TC-API-09 | 06 invite; 16 activity/removal/session mechanics → 19 suite; shared-record erasure oracle remains blocked OQ-01 |
| TC-BS-01…08, TC-CK-01…05; TC-LG-01…13/41, TC-TM-01…04, TC-HF-01…08 | 09, 10, 11 → 19; verified checklist preset oracle blocked OQ-11 |
| TC-GM-01…13/16…20; TC-AE-01…13/15…20; TC-PL-10…20; TC-FIX-A1…C2 | 12, 13, 14 → 19; OQ-04 benchmark-specific assertion not invented |
| TC-EX-02…08, TC-SEC-01…10, TC-EX-01, TC-E2E-01 | 15 export → 17 offline → 18 security → 19 QA; SEC-32 requires server-only retrieval/DPO review, not just a curated share file |
| TC-MT-01…07; TC-SV-01…03 | 15 metrics/survey → 18 privacy review → 19 QA; 20 beta responses **only after** consent/privacy gate and tests; TC-MT-05 and TC-SV-03 remain blocked until counsel/disclosures approved; specifications are not passing results |
| TC-BAK-01/02 | 21 measured monthly restore drill and one before each release (ADR-61…69 integration), not an unverified weekly success claim |
| TC-LO-01…04, TC-AT-01…04 | 24 backlog handoff only; no v1 test-execution claim |

### (c) Sitting and dependency check

**24 index rows (within 20–26); 8 detailed phase bodies (01–08).** ADR-73 resolves the former one-sitting-per-phase conflict: phases are milestones with multiple bounded, independently testable sittings. Each implementation sitting must name a concrete exit and dependencies before execution; detailed 07/08 bodies below enumerate slices and TC exits. Remaining phase bodies (09–24) still need expansion before execution. External beta, counsel/store review and observation waits are gates, not sittings. All listed dependencies point to lower phase numbers; 22, 23 and 24 are independent post-launch/backlog branches from 21. This validates the planning rule, not any unfinished body or implementation.

**Open blockers:** OQ-01 shared-record erasure; OQ-03 force-wipe (current policy is offer only); OQ-04 cost benchmarks; OQ-07 residency/production/staging ref; OQ-09 clearance/domain; OQ-10 payment SEC block; OQ-11 checklist verified presets; OQ-12 business-model choice (no monetisation decision or v1 upsell implied). Counsel must verify the 18+ basis and measurement/notice obligations before real beta. The measurement plan must not silently convert existing synced data into analytics without notice/opt-in; no third-party analytics SDK in v1. Phase 20 cannot begin with real couples until SEC-29…31/35 and the internal-beta gate pass. The adopted REQ-MT-1/REQ-SV-1 wording defines the privacy gates; the test plan still specifies, not executes, them.

---
# Phase bodies

*Phases 01–06 retain their previously authored detailed bodies below, corrected for their current planning/status caveats above. Bodies describe target outcomes, not work already certified. Phase 07 and 08 bodies are added after 06.*

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
- iOS builds in PR CI (release candidates only under the solo-maintainer trim; no nightly Maestro obligation).
- **No AI code, no AI dependencies.**

**Rollback:** Greenfield phase — revert the initialisation commits, or delete the branch. No data, no deployed resource, no external state to unwind.

**Open questions to resolve before starting:** None blocking.
*Advisory, not a blocker:* OQ-09 (name clearance) is OPEN. The bundle identifier and Android package name are set in task 1, and they are effectively immutable after first store submission. Running OQ-09 steps 1, 2, and 4 now is cheap insurance; doing it after phase 21 is not possible.

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
3. Extend the presenter with the **constrained bento form** per REQ-GEN-2A: drop centavos below ₱1,000,000; exactly two-decimal millions shorthand at or above; truncate toward zero so a tile never overstates.
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

**Objective:** Establish the local backend and, once its reference is supplied, the synthetic-only staging project; commit declarative auth and project configuration and expose authenticated but empty sync endpoints with contract tests. Production region/project remains blocked by OQ-07, not implicitly created here. See `design.md` §2.4 for the authoritative `POST /sync/push` and `POST /sync/pull` contract (not `/v1/sync`).

**Requirements covered:** — (none; this phase is infrastructure)

**Tasks**

1. Create the **staging** Supabase project in region `ap-southeast-1` per `deployment-plan.md` §2.2. **Production project creation is blocked — see open questions.**
2. Commit `supabase/config.toml` with auth settings satisfying SEC-03: access-token TTL ≤ 1 hour, refresh-token rotation enabled.
3. Create `supabase/functions/` with `sync_push` and `sync_pull` Edge stubs accepting the versioned envelopes in `design.md` §2.4 — authenticate the caller, return an empty result set; full acceptance stamps, durable cursor and idempotency are phase 08. Do not claim the full `TC-API-01/02` contract on an empty stub.
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
| Unauthenticated call rejected | `curl` the local `/functions/v1/sync_pull` endpoint with no bearer token | HTTP 401 |
| Authenticated call succeeds and is empty | `curl` with a valid staging token | HTTP 200, empty row set |
| Malformed push rejected | `curl` push with an invalid row body | 4xx, and no partial commit observable in the DB |
| Token TTL correct | Decode an issued access token | `exp − iat` ≤ 3600 s |
| **Secret scan gate works** | Commit a dummy secret, run CI; remove it, re-run | Fails, then passes |
| No service-role key in client | `strings` the built `.aab` and grep for the key prefix | Zero matches |

**TC IDs that must pass:** TC-API-04 and the *empty-stub envelope subset* of TC-API-01/02. Full TC-API-01/02 (accepted rows, stamps, committed pagination), TC-API-03 idempotency are phase 08; TC-API-05 direct membership denial is phase 06/07 when that table exists. A scaffold cannot pass those full oracles by returning empty success.

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
> 2. **Authorise a descope:** create staging only in `ap-southeast-1` and defer the production project to a later phase. Staging holds synthetic data exclusively (`deployment-plan.md` §1.1), so the residency question does not bind for it. Phase 04 still remains partial until a **real staging project ref and contract evidence** are recorded; phase 20's real-data beta and phase 21 submission inherit the production blocker.
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

1. Add pinned `drift` and `sqlite3` native assets with the `sqlite3mc` page cipher (ADR-74 supersedes the older `sqlite3_flutter_libs` + `sqlcipher_flutter_libs` dependency pairing); fail closed if the cipher is missing.
2. Implement `platform/db/encrypted_database.dart` — generate a page-cipher key on first run, store it in the iOS Keychain / Android Keystore, and retrieve it on subsequent opens (SEC-13).
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
- iOS `AppDelegate.swift` local-security channel (runtime backup exclusion and Complete file protection) and Android `AndroidManifest.xml` / native channel changes for backup exclusion and device-lock inspection
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

1. Integrate Supabase Auth for sign-up, sign-in, mandatory email verification and an explicit 18+ declaration; block plan creation and joining until verification (SEC-01, SEC-02). `supabase/config.toml`'s `enable_confirmations = false` is **local-only**: stage/prod deployment configuration MUST set `enable_confirmations = true` and test the unverified-account denial. Counsel must verify the age/legal-basis copy before real beta.
2. Implement session handling: store access and refresh tokens in Keychain/Keystore (SEC-19), rotate refresh tokens on use, and invalidate server-side on sign-out (SEC-03, SEC-04).
3. Write the migration creating the identity and access tables from `design.md` §4.1 — `users`, `plans`, `plan_member_aliases`, `plan_members`, `invites`. (`lifecycle_confirmations` belongs to phase 16.)
4. Enable and force RLS on those five tables, with membership resolved through `plan_members` keyed to the authenticated user (SEC-22, SEC-23 scoped to identity tables).
5. Enforce one active plan per account (REQ-PLT-3): a database constraint or trigger, plus a client-side block whose message names the existing active plan.
6. Enforce the two-partner cap: at most two `plan_members` rows per plan, by trigger (REQ-SE-1 cl. 1).
7. Implement invite issue, accept, and revoke: 128-bit CSPRNG token, **hash only** stored in `invites.token_hash`, 7-day expiry, single-use (REQ-SE-1 cl. 3–5; SEC-05, SEC-06).
8. Deny direct client inserts into `plan_members` — membership is written only by the server-side accept flow (SEC-25).
9. Wire SCR-01 (Sign In / Sign Up) and SCR-02 (Invite Acceptance) to real behaviour, replacing the phase-03 placeholders, and replace the stubbed auth guard provider with the real one.
10. Verify re-pairing after reinstall: a reinstalled app signs in and recovers plan membership with no residual credential from the prior install (SEC-10, SEC-11).

> **Sitting boundary:** Auth/sessions (tasks 1–2, 9-partial, 10) and pairing/membership (tasks 3–8) are separately testable sittings within phase 06. The 24-phase index no longer equates a milestone with one sitting.

**Working-tree inventory (2026-10-04; implementation in progress, not a phase exit):**

| Slice | Present in this branch | Still not demonstrated / not wired |
|---|---|---|
| Auth/session | `main.dart` initializes Supabase after the encrypted local-store gate; `auth_repository.dart` uses Supabase Auth and an unchecked-adult policy; `auth_provider.dart` derives verified/unverified state; `token_store.dart` supplies secure-storage adapters for session JSON and PKCE. Fake-gateway and widget tests exist. | Real verification-link round trip, refresh-token reuse/TTL and server-side revocation probes, physical Keychain/Keystore and backup inspection, and stage/prod confirmation settings. The displayed privacy notice is explicitly a synthetic-local placeholder, not counsel-approved copy. |
| Server identity/pairing | `0001_identity_and_access.sql` defines five public identity/access tables (`users`, `plans`, `plan_member_aliases`, `plan_members`, `invites`), forced RLS, denied direct mutations, one-membership/two-member checks, and `create_plan`, `issue_invite`, `accept_invite`, `revoke_invite` RPCs. A rebuilt disposable local Supabase instance applied the migration from an empty volume; all eleven synthetic identity tests then passed, including distinct-invite concurrency, email changes and invalid reminder offsets. | The local subset is not stage deploy, full TC-SEC-01, or a production-safe rollback. Foreign-plan list reads return `200 []`; this must be indistinguishable from a nonexistent-plan list response (§7.1). Exercise the full negative matrix before calling TC-SEC-01 passed. |
| Client pairing | SCR-01 offers Start/Join; an asynchronous `planAccessProvider` checks server membership after verified Auth and blocks protected routes or invitation acceptance on lookup error/loading or an existing membership. SCR-02 paste/custom-scheme parsing matches the SQL token format (32 lowercase hex), calls `accept_invite`, refreshes membership after success, and offers Decline without calling the RPC; focused router/widget tests passed locally. | SCR-03 remains a placeholder, so Start cannot submit `create_plan`; no app-level issue/revoke, client-side named-existing-plan message, invite summary, first replay, or verified post-accept dashboard transition is implemented. Full re-pair-after-reinstall is unverified. The fake-backed parity test is not an end-to-end invite verdict. |

This inventory distinguishes bounded local test results from unverified phase exit criteria. Use `testing-plan.md` §2.0's evidence distinctions; do not mark TC-PLT-03, TC-SE-23/42/45 or TC-SEC-01 passed from a partial local run.

**Target deliverables** (paths below are planned outputs, not an inventory of files already verified):

- `supabase/migrations/0001_identity_and_access.sql` (five tables including `plan_member_aliases`, RLS and pairing RPCs; clean disposable-local replay passed, remote deploy pending)
- `lib/data/repositories/auth_repository.dart`, `lib/data/repositories/plan_membership_repository.dart` (present, bounded)
- `lib/ui/screens/scr_01_sign_in.dart`, `lib/ui/screens/scr_02_invite_acceptance.dart` (partial; §inventory above)
- `lib/ui/providers/auth_provider.dart`, `lib/ui/providers/plan_provider.dart` and `lib/ui/router/app_router.dart` (reactive Auth and async plan-access guards present; lookup and errors need on-device verification)
- `lib/platform/secure_storage/token_store.dart` (adapter present; device verification pending)
- `test/data/repositories/auth_repository_test.dart`, `test/ui/screens/scr_01_sign_in_test.dart`, `test/ui/screens/scr_02_invite_acceptance_test.dart`, `test/api/identity/test_identity.py` (sources present; no full TC verdict)
- Plan-membership repository test and on-device `integration_test/auth/pairing_test.dart` (not yet present)

**Exit Criteria**

| Check | Command / steps | Expected result |
|---|---|---|
| Sign-up requires verification | Manual: sign up, then attempt to create a plan before clicking the verification link | Creation refused with a message naming email verification |
| Stage/prod confirmation and age gate | Inspect deployed auth settings; try unverified and under-18 sign-ups | `enable_confirmations = true` in both deployed environments; unverified cannot create/join; 18+ declaration required; legal notice approved before beta |
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

**TC IDs that must pass:** TC-PLT-03, TC-SE-23, TC-SE-42 (pasted and tapped invite parity)

**Non-goals** — must not touch:
- Any budget entity table — ledger, pledges, guests, allocations, fee components (phase 07).
- Defensive removal, ownership transfer, or `lifecycle_confirmations` (phase 16).
- The change log or attribution (phase 07 writer, phase 16 UI).
- Sync of any kind (phase 08).
- Account deletion and the erasure flow (phase 18; blocked on OQ-01 regardless).
- Budget setup or onboarding content beyond the auth guard redirect (phase 09).
- **No AI code, no AI dependencies.**

**Rollback:** For local synthetic development, revert the phase code and reset the disposable local database only after confirming it contains no retained work. The current migration adds five public tables, functions, triggers and an Auth trigger; there is no verified down-migration or rehearsed remote rollback. Dropping identity tables after accounts or invitations exist would destroy data and cannot be described as clean. Any staging rollback needs a reviewed, rehearsed migration/backup procedure per `deployment-plan.md` §2.6; production deployment is deferred. Rotate any affected auth keys after a real exposure, not merely because a local migration was reverted.

**Open questions to resolve before starting:** None blocking this phase directly.
*Inherited:* if phase 04 was descoped to staging-only under OQ-07, this phase runs against staging only, and the production identity migration is deferred with it.


---

## Phase 07: Data layer — entities, repositories & change-log writer

**Owning agent:** Data & Sync (Security reviews RLS and plan-scoped schema)

**Depends on:**
- **05** — SQLCipher/drift lifecycle, secure key, and local-first reads.
- **06** — identity/plan membership and alias model; auth and identity migrations must exist before plan-scoped RLS. A local synthetic project is sufficient for development; no live production deployment is implied.

**Objective:** Implement the v1 entity schema, repository-only writes and transactional immutable change-log/outbox foundation. Store source inputs and integer-centavo events, not computed money or derived status. Establish forced RLS on every plan-scoped server table and migration safety before network replication.

**Requirements covered:** — (structural dependency for the REQ IDs owned by feature phases 09–17; no duplicate REQ assignment)

**Sittings / Tasks**

1. **Schema sitting:** Add versioned server migrations and matching drift tables for `plans`, `plan_members`, aliases, `ledger_entries`, `payment_schedule_items`, `payments`, `fee_components`, `hidden_fee_prompts`, `guests`, `crew_headcount`, `pledges`, `pledge_receipts`, `gifts_received`, `plan_allocations`, `checklist_items`, `change_log`, and device queue/cursor state as applicable in `design.md` §4. Phase 06 owns identity migration; extend it rather than silently duplicate tables. Client UUIDv7 IDs; money is signed int64 centavos. Keep `estimated_cents` null for per-head entries, no cumulative deposit/receipt, no stored derived status, `engine_cents`, conflict flag or generated export artifact. Template suggestions stay in the bundled validated ruleset, not ledger rows.
2. **Repository sitting:** Add typed repositories behind `data/repositories/` for plan setup, ledger and children, prompted fees, guest/crew, allocations, pledges/receipts, gifts and checklist. Read projections only from local SQLite; validate parent-child plan/entry links and record every financial correction as tombstone plus new positive row. Materialize checklist state on first edit via one stable plan/item create; idempotently avoid duplicate concurrent first creates. Fees become entries only after explicit confirmation with user-entered positive centavos. Do not seed fictitious fees, checklist dates or costs (OQ-04/11).
3. **Writer sitting:** In one local DB transaction, validate the complete input, apply the local projection, append an immutable typed `change_log` event and enqueue it durably. Use a single full-snapshot `$create` event; one field event for each independent field, one full `change_group_id` snapshot for pricing mode/rate and fee quantity/rate/amount; include plan member alias/device ID, `schema_version`, typed old/new including null and monotonic device counter. Preserve tombstones and history; never persist derived conflict/superseded flags. Atomic sponsor-direct receipt/payment pairs must remain indivisible both locally and for later server acceptance.
4. **Server-security sitting:** Enable **and force** plan-membership RLS on every new plan-scoped table, deny foreign-plan read/write/delete and direct membership insertion, and constrain immutable log updates/deletes. Add executable cross-tenant negative and policy-inventory tests to CI before calling the schema safe. Any new persisted opt-in measurement or survey record added in 15/20 reopens this inventory and gate; do not assume ordinary analytics bypass RLS. No actual data layer is complete with missing RLS.
5. **Migration sitting:** Test forward/backward behavior on representative data and drift upgrades with a queued offline write. Stage synthetic seed fixtures only. Keep unknown versioned rows/cursor retained for phase 08's transactional rebuild; verify no cents change and no queue loss. Pin ruleset IDs on plans without computing/syncing engine outputs.

**Deliverables**

- Versioned `supabase/migrations/` for the data layer and forced-RLS policies; corresponding `data/db/` drift schema/migrations.
- `data/repositories/` typed implementations and `data/changelog/` transactional writer/queue.
- Local repository, schema, tenant-isolation and migration tests, plus a **blocking** `tenant-isolation` CI gate once migrations exist.

**Exit Criteria**

| Check | Evidence / command | Expected result |
|---|---|---|
| Data model and writer | Local repository tests over a reopened encrypted DB | Full create snapshot, typed updates, group snapshots, tombstone and queue commit atomically; reads need no network; integer cents preserved |
| Migration safety | Run migration suite with queued rows and representative money data | **TC-MIG-01…03** pass; backward migration cleanly applies or fails before partial effects; no queued row or centavo lost |
| Tenant boundary | Run all negative tests with two real authenticated synthetic plans against local Supabase | **TC-SEC-01, TC-SEC-04…06** pass; no cross-plan enumeration or REST bypass; every plan table has enforced policy; CI fails if a new table lacks one |
| Membership/write integrity | Direct client write attempt and append-only log mutation attempt | **TC-API-05** and the storage/API assertions of **TC-SE-26** pass; its UI assertion waits for phase 16 |
| Local schema versus requirements | Inspect columns and repository writes | No float money, no stored derived status/engine amount, no phantom template/fee row; complete plan-scoped checklist protection |

**TC IDs that must pass:** TC-MIG-01, TC-MIG-02, TC-MIG-03, TC-SEC-01, TC-SEC-04, TC-SEC-05, TC-SEC-06, TC-API-05 and the writer/storage assertions of TC-SE-26. The **full** TC-SE-26 includes UI and belongs to phase 16/19; auth/device adversarial and physical-encryption tests remain in 18; TC-MIG-04/05 require the phase-08 replay/rebuild engine.

**Non-goals** — must not touch:
- Network replay, server ordering, committed pull cursors or version negotiation (08).
- Full feature screens, price benchmarks, legal/checklist preset dates or monetisation (09–15 and OQ-04/11/12).
- v1.1 photo bytes/Storage and any AI or payment rail.

**Rollback:** Roll back development-only migrations against a synthetic test project after confirming no queued writes; use forward corrective migrations rather than destructive down-migration on any shared/real dataset. Preserve immutable events and encryption key until recovery is verified; never delete a production log to undo a projection bug.

**Open questions to resolve before starting:** No OQ authorises skipping RLS. OQ-07 still blocks creating/attesting production region and live staging reference; OQ-11 blocks publication of verified checklist presets but not manual state/date/fee schema. OQ-01 blocks any claim that alias unlink resolves legal erasure.

---

## Phase 08: Sync engine — transport, ordering, replay & convergence

**Owning agent:** Data & Sync (Security reviews authorization and version/tenant boundaries)

**Depends on:**
- **06** — valid member sessions and server membership checks.
- **07** — versioned entity schema, append-only writer, local outbox/projections, forced RLS and migration suite.

**Objective:** Deliver automatic, durable two-device push/pull over the immutable log with server-authoritative LWW, commit-safe per-plan pagination, atomic group/financial events, deterministic local projections and upgrade-safe compatibility. Local writes remain readable before any network call; failure retains the queue.

**Requirements covered:** REQ-SE-2, REQ-SE-3, REQ-OF-5.

**Sittings / Tasks**

1. **Transport sitting:** Implement `POST /sync/push` and `POST /sync/pull` exactly as `design.md` §2.4 (including `protocol_version`, row `schema_version`, validated pull `limit`, cursor/`has_more`, auth and live plan membership). Reject foreign plans indistinguishably from nonexistent ones. Do not accept client-authored `server_ts`. Cap batches, respond to unsupported major with structured `min_supported_build` and leave the device's queue/cursor intact. Retry on connectivity restoration without a screen/button; make pending/error/progress visible in 17.
2. **Ordering sitting:** Under a transactional **per-plan lock held through commit**, assign server sequence/`server_ts` on first acceptance. Duplicate row IDs are insert-ignore and retain original stamp. Pull only committed rows through a committed high-water mark; cursor advances to the last returned committed event only after the entire local page (including unknown rows) commits. Test racing push transactions, rollback gaps, `limit=1`, replay and process death between persistence and cursor update.
3. **Merge sitting:** Replay full-snapshot creates atomically; hold child events until parent creation, and gate live state/totals on tombstones until an explicit Restore. Resolve ordinary fields by `(server_ts, device_monotonic, device_id)`, compound pricing and component groups by the same key over the *whole* typed snapshot; preserve losing events. Compare typed `old_value` to the immediately replaced effective value to derive (not store) stale conflict; a later-accepted old offline edit may win. Derived overdue/payment/engine/per-head values are never synced as authoritative fields. Revalidate cross-field invariants on read; exclude only invalid dependent contributions and surface needs attention without repair writes.
4. **Atomicity/compatibility sitting:** Enforce sponsor-direct linked payment+receipt as one accept/reject unit on server and client. Keep each device's queue, counter and cursor distinct even for the same account; revoked membership/session cannot pull or push. Retain compatible unknown additive rows and ordering data without projecting them; on app upgrade migrate drift + rebuild projections transactionally from the *entire* retained log, with rollback preserving queue, cursor and old schema on failure. Missing pinned ruleset → needs attention, not fabricated allocations.
5. **Convergence sitting:** Exercise two synthetic accounts/devices and independent arrival orders across entries, ledger/payment/receipt/gift inserts, delete/restore, groups and long-offline writes. Repeat sync with empty queues and assert byte-identical projections and integer-centavo gross/net/exposure/variance across peers, with attribution visible for both partners and same-user devices. Run all contract/isolation suites on both supported platforms in 19; never call an unexecuted suite passed.

**Deliverables**

- Versioned Edge `sync_push`/`sync_pull` with server transaction/lock and RLS membership checks; `sync/transport/`, `sync/queue/`, `sync/clock/` client services and local projection/rebuild support.
- Automated API/concurrency/idempotency and two-device sync tests, plus transactional upgrade/failure-injection tests.

**Exit Criteria**

| Check | Evidence / command | Expected result |
|---|---|---|
| API envelope/auth/version | Run local Supabase contract tests with valid and invalid accounts | **TC-API-01…04, TC-API-06…08** pass; `/sync/pull` respects bounded `limit`, no malformed/unauthorized partial write, unsupported major keeps queue |
| Per-plan commit cursor | Pause one push before commit, race a second; page pull at `limit=1` and inject rollback | **TC-SE-43, TC-API-02/06** pass: no later commit overtakes an uncommitted earlier key; no event skipped |
| Replay/idempotency | Queue offline writes, force-quit/restart, deliver same batch twice | **TC-OF-12/15/18/23…25, TC-API-03** pass; original server stamps preserved, no loss or duplicate sums |
| LWW, groups, projection safety | Run deterministic two-device sync matrix and swap arrival order | **TC-SE-20/21/24/25/27…30/33…39** pass on applicable engine paths; full group wins, stale mismatch shown to both, tombstones and parent-gated children safe, same accepted log converges |
| Mixed-version migration | Retain unknown events and pending writes; upgrade, inject failure, retry | **TC-SE-44, TC-MIG-04/05, TC-API-07/08** pass; no silent financial projection or lost cursor; failed rebuild rolls back wholly |
| Tenant and pair atomicity | Foreign/revoked token and interrupted sponsor-payment pair attempts | **TC-SEC-01/02/04/05** and pair integrity checks pass; no cross-tenant leak or half-applied linked receipt/payment |

**TC IDs that must pass:** TC-API-01…04 and 06…08; TC-SE-20/21/24/25/27…30/33…39/43/44; TC-OF-12/15/18/23…25; TC-MIG-04/05; TC-SEC-01/02/04/05. Some UI portions of TC-SE-28/33/35/37/39 depend on phase 16, visibility on 17, and complete cross-platform rerun on 19: this engine exits only on its implemented assertions, **not** a claim those later end-to-end checks have passed.

**Non-goals** — must not touch:
- Feature forms/dashboard, human conflict resolution, partner-removal UI (09–17); payment state remains locally derived.
- Counsel-dependent shared-record erasure or force-wipe claims (OQ-01/03); a removed partner retains already synced local bytes.
- AI, payment initiation, v1.1 photos or analytics SDKs.

**Rollback:** Disable further push and keep encrypted local outboxes/cursors intact; revert an unshipped client build or deploy a forward-compatible server correction. Never erase accepted log rows, renumber server order, reset client cursors, or replay non-idempotent payments as a shortcut. Re-run contract, migration and tenant tests before restoring sync.

**Open questions to resolve before starting:** No unresolved OQ changes the server-authoritative LWW algorithm. OQ-07 limits this development to local/synthetic infrastructure until the ADR-72-selected Singapore processor/transfer and notice have DPO/counsel approval; OQ-01/03 prevent claims about legal erasure or enforceable remote wiping. Any incompatible protocol release must have a tested minimum-build/rollback path before phase 21.
