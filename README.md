# Kasaran

*A wedding budget-planning app for Filipino couples — local-first, offline-capable, built for the realities of a Philippine wedding budget.*

> **Naming note.** "Kasaran" is the decided product name (ADR-27), despite its *roughness* connotation in Filipino versus *kasalan* (*wedding*). Store-name, trademark, and domain clearance remain open (OQ-09); a collision could still require a change.

---

## Status

**Flutter foundation scaffold, not a feature-complete app.** Phases 01–04 have source and tooling: money primitives and presenter, the app/router with 19 placeholder screens, and Supabase configuration with empty sync stubs. Budget, ledger, and sync behavior are not implemented by these placeholders.

`pubspec.yaml`, `lib/`, `test/`, platform projects, GitHub Actions CI, Fastlane, and the `no_float_money` custom lint are present alongside `docs/`.

The build sequence is defined in `docs/development-phases.md`; the phase index still has an unresolved one-sitting/phase-cap issue, and phase bodies 01–06 are written. A written phase body is not evidence that all its exit criteria have been met.

---

## The problem it solves

Filipino couples planning a wedding on a peso budget are ambushed by two things generic budgeting tools miss (`docs/problem-brief.md`):

**Hidden fees** that stack on top of headline supplier prices and surface late, when there is no budget left to absorb them:

- **Crew meals** — every supplier feeds their team on the day; across 15–20 suppliers this is a real line item.
- **OOT (out-of-town) fees** — supplier travel, lodging, and per-diem for destination or province weddings.
- **Church aircon premiums** — a common add-on for an air-conditioned ceremony.
- **Corkage** — charged on outside food, cake, drinks, or lechon.

(The requirements extend this set to overtime and venue power fees as well — `docs/requirements.md`.)

**Untracked pledges.** Ninong/Ninang (principal sponsors) and family pledge cash or cover specific items, but this lives in group chats and memory, never in the budget. So couples cannot separate the **gross event total** (what the wedding costs) from their **true out-of-pocket** (what they personally pay after received pledges only). Kasaran tracks pledges and shows both numbers distinctly.

Target market: 2026 Philippines, PHP budgets, couples self-planning without a full-service planner (competitors noted in the brief are Nuptl and Vowly, which are directory/inspiration-first rather than budgeting-first).

---

## Features

### v1 scope

Each is specified in `docs/requirements.md` and `docs/mvp-user-stories.md`:

- **Budget setup** `v1` — guided intake: total budget, wedding date, guest cap, region.
- **Expense ledger** `v1` — line items with estimated vs actual amounts, deposits, and derived paid/pending/overdue status.
- **Hidden-fee line items** `v1` — crew meals, OOT, church aircon, corkage (plus overtime, venue power) as first-class, prompted entries.
- **Pledges** `v1` — sponsor pledges with fulfillment state; net out-of-pocket reduced only on fulfillment, shown distinctly from gross and from expected support.
- **Guest math** `v1` — RSVP and priority-tier tracking, per-head vs flat-rate cost scaling, and "what if we add N guests" previews.
- **Rule-based allocation engine** `v1` — deterministic, explainable budget allocation with regional cost modifiers and manual overrides. No AI.
- **Shared editing + offline sync** `v1` — two partners on one plan, full offline use, field-level last-write-wins with a visible, immutable change log.

### Deferred — not in v1

Deliberately excluded until after the non-AI production launch (`docs/project-brief.md`, `docs/development-phases.md`):

- **AI categorization** (on-device) — deferred.
- **OCR contract parsing and cloud AI reasoning** — deferred.
- **Payments (InstaPay / QR Ph)** — deferred to its own post-launch phase (not an AI feature; `docs/decision-log.md` ADR-28).
- **Supplier marketplace / directory** — out of scope entirely, not merely deferred.

---

## Tech stack

Confirmed by `docs/decision-log.md` and `docs/design.md`:

| Concern | Choice | Source |
|---|---|---|
| Client framework | **Flutter** (Android + iOS) | ADR-12 |
| Local store | **SQLite** via `drift`, encrypted with SQLCipher | ADR-12, ADR-17 |
| Architecture | **Local-first**, device is source of truth for reads, syncing to cloud | GIV-03 |
| Conflict resolution | **Field-level last-write-wins**, ordered by a server-assigned timestamp, with an immutable **change log** — not CRDTs | ADR-08, ADR-21 (GIV-04) |
| Backend | **Supabase** (Postgres + Auth + Row-Level Security) | ADR-16 |
| Money | int64 centavos, no floating point | `docs/requirements.md` REQ-GEN-1 |

Build tooling, minimum OS versions, and store pipeline are documented in `docs/deployment-plan.md`.

---

## Repository structure

```
Kasaran/
├── lib/
│   ├── main.dart                  Flutter app entry point
│   ├── config/                    build-time Supabase environment configuration
│   ├── ui/                        router, 19 placeholder screens, shell, money presenter
│   ├── domain/                    centavo money primitives; allocation/calculation/validation scaffolds
│   ├── data/                      database, repository, change-log scaffolds
│   ├── sync/                      queue, clock, transport scaffolds
│   └── platform/                  platform database scaffold
├── test/                          money, router, widget, and API contract tests
├── tools/lint/                    no_float_money custom lint
├── supabase/                      local config, sync_push/sync_pull stubs
├── android/ and ios/              Flutter platform projects
├── fastlane/                      build lanes and app metadata
├── .github/workflows/ci.yml       analyze, test, Android build, contract/secret gates
├── pubspec.yaml / pubspec.lock    Flutter package manifest and lockfile
└── docs/                          briefs, requirements, design, UX, security,
                                 testing, deployment, phases, and decision log
```

The routes and backend endpoints are scaffolds; do not mistake their presence for completed feature or production sync behavior.

---

## Planning / roadmap

The `docs/` package is a full planning set — from problem framing through requirements, design, UX, security, testing, and deployment. The build itself is sequenced in **[docs/development-phases.md](docs/development-phases.md)**:

- The phase **index** (27 phases: foundation → auth → data layer → sync engine → features → hardening → QA → beta → UAT → launch → payments → AI) is **awaiting approval**.
- Phase **bodies** are written for **phases 01–06** (batch 1); later batches are pending. The current code scaffolds phases 01–04.
- Decisions are tracked in `docs/decision-log.md` across three tiers: **givens (GIV)**, **open questions (OQ)**, and **decisions (ADR)**.

---

## Getting started

Install Flutter/Dart and, for the local backend, Supabase CLI and Docker. From the repository root:

```sh
flutter pub get
flutter analyze
flutter test
supabase start
supabase status
flutter run --dart-define=ENV=local \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=YOUR_LOCAL_ANON_KEY
```

Replace `YOUR_LOCAL_ANON_KEY` with the anon key printed by `supabase status`. The three defines are read by `lib/config/app_config.dart`; never pass a service-role key to the client. `supabase start` requires Docker. `flutter run` currently opens the placeholder app, not a usable wedding plan. See `.env.example` for environment variable names and `docs/development-phases.md` for subsequent implementation.

---

## Open decisions

Unresolved items from `docs/decision-log.md` that a reader should know are **not** settled:

- **OQ-09 name clearance** — the name **Kasaran** is decided (ADR-27), but App Store / Play name availability, IPOPHIL trademark search, and domain ownership remain unverified and could force a change.
- **OQ-01** — shared-record data erasure model (two data subjects, one record). Counsel-gated.
- **OQ-02** — NPC registration threshold and DPO designation. Counsel-gated.
- **OQ-03** — force-wipe vs wipe-offer for a removed partner's local copy.
- **OQ-04** — regional reference-cost benchmarks; budget-adequacy feature cannot ship verified without them.
- **OQ-07** — data residency; there is no Philippine Supabase region, and no ADR yet decides where PH personal data is stored. Blocks the privacy notice.
- **OQ-08** — whether the allocation ruleset stays bundled in the binary or moves to remote-with-fallback.
- **OQ-10** — payment-rail security has no controls block yet; blocks the payments phase.

The **backend** choice, by contrast, is **not** open — it is decided as Supabase (ADR-16).

---

## Contributing

TBD — not yet in repo. No `CONTRIBUTING` file exists.

## License

TBD — not yet in repo. No `LICENSE` file exists.
