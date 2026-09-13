# Kasaran

*A wedding budget-planning app for Filipino couples — local-first, offline-capable, built for the realities of a Philippine wedding budget.*

> **Naming note.** "Kasaran" reads closer to *roughness* in Filipino, while *kasalan* means *wedding*. This tension is on the record. The repository's decision log now marks the name **resolved** to "Kasaran" as a distinct brand mark (`docs/decision-log.md`, ADR-27). **However, the maintainer has signalled the name should still be treated as an open question.** See [Open decisions](#open-decisions) — this README does not present the name as final.

---

## Status

**Planning / documentation phase. There is no application code in this repository yet.**

The repository currently contains a planning package under `docs/` and nothing else — no source, no package manifest, no CI configuration. Every statement below is drawn from those documents; nothing describes running software.

The build sequence is defined in `docs/development-phases.md`, whose phase index is **awaiting approval** and whose phase bodies exist for phases 01–06 only (batch 1).

---

## The problem it solves

Filipino couples planning a wedding on a peso budget are ambushed by two things generic budgeting tools miss (`docs/problem-brief.md`):

**Hidden fees** that stack on top of headline supplier prices and surface late, when there is no budget left to absorb them:

- **Crew meals** — every supplier feeds their team on the day; across 15–20 suppliers this is a real line item.
- **OOT (out-of-town) fees** — supplier travel, lodging, and per-diem for destination or province weddings.
- **Church aircon premiums** — a common add-on for an air-conditioned ceremony.
- **Corkage** — charged on outside food, cake, drinks, or lechon.

(The requirements extend this set to overtime and venue power fees as well — `docs/requirements.md`.)

**Untracked pledges.** Ninong/Ninang (principal sponsors) and family pledge cash or cover specific items, but this lives in group chats and memory, never in the budget. So couples cannot separate the **gross event total** (what the wedding costs) from their **true out-of-pocket** (what they personally pay after pledges). Kasaran tracks pledges and shows both numbers distinctly.

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
| Client framework | **Flutter** (Android + iOS) | ADR-12. *Note: an earlier plan named React Native; that was superseded (GIV-02).* |
| Local store | **SQLite** via `drift`, encrypted with SQLCipher | ADR-12, ADR-17 |
| Architecture | **Local-first**, device is source of truth for reads, syncing to cloud | GIV-03 |
| Conflict resolution | **Field-level last-write-wins**, ordered by a server-assigned timestamp, with an immutable **change log** — not CRDTs | ADR-08, ADR-21 (GIV-04) |
| Backend | **Supabase** (Postgres + Auth + Row-Level Security) | ADR-16 |
| Money | int64 centavos, no floating point | `docs/requirements.md` REQ-GEN-1 |

Build tooling, minimum OS versions, and store pipeline are documented in `docs/deployment-plan.md`.

---

## Repository structure

```
Kasaran-App/
├── .gitignore
├── README.md                      ← this file
└── docs/
    ├── problem-brief.md           the hidden-fee and pledge problem, target market
    ├── project-brief.md           vision, objectives, v1 scope, the v1/AI-phase line
    ├── mvp-user-stories.md        MVP scenario, user stories with acceptance criteria
    ├── requirements.md            EARS requirements (REQ IDs), the authority for scope
    ├── design.md                  client architecture, sync engine, data model, AI seams
    ├── ux-spec.md                 19 screens, state matrix, flows, components
    ├── security-plan.md           threat model, SEC controls, DPA compliance, release gate
    ├── testing-plan.md            tooling, traceability, hand-computed calculation fixtures
    ├── deployment-plan.md         environments, CI/CD, store submission, day-2 ops
    ├── agents.md                  11 role charters, conflict/escalation rules, ownership
    ├── development-phases.md      the phased build plan (index + phase 01–06 bodies)
    └── decision-log.md            givens, open questions, and decisions (GIV / OQ / ADR)
```

No application source, package manifest, or CI configuration is present at this time.

---

## Planning / roadmap

The `docs/` package is a full planning set — from problem framing through requirements, design, UX, security, testing, and deployment. The build itself is sequenced in **[docs/development-phases.md](docs/development-phases.md)**:

- The phase **index** (27 phases: foundation → auth → data layer → sync engine → features → hardening → QA → beta → UAT → launch → payments → AI) is **awaiting approval**.
- Phase **bodies** are written for **phases 01–06 only** (batch 1); later batches are pending.
- Decisions are tracked in `docs/decision-log.md` across three tiers: **givens (GIV)**, **open questions (OQ)**, and **decisions (ADR)**.

---

## Getting started

**No application code yet — see [docs/development-phases.md](docs/development-phases.md) for the build plan.**

There is nothing to install, build, run, or test at this stage. Install/build/run commands will be added when the corresponding phases produce code (phase 01 establishes the repo, tooling, and CI skeleton).

---

## Open decisions

Unresolved items from `docs/decision-log.md` that a reader should know are **not** settled:

- **Product name** — although the decision log records "Kasaran" as resolved (ADR-27), the maintainer has flagged it should be treated as **still open**. Treat the name as provisional. Related and genuinely open: **OQ-09 name clearance** — App Store / Play name availability, IPOPHIL trademark search, and domain ownership are not yet done, and can invalidate the name regardless of the branding decision.
- **OQ-01** — shared-record data erasure model (two data subjects, one record). Counsel-gated.
- **OQ-02** — NPC registration threshold and DPO designation. Counsel-gated.
- **OQ-03** — force-wipe vs wipe-offer for a removed partner's local copy.
- **OQ-04** — regional reference-cost benchmarks; budget-adequacy feature cannot ship verified without them.
- **OQ-05** — ownership-transfer confirmation expiry duration.
- **OQ-07** — data residency; there is no Philippine Supabase region, and no ADR yet decides where PH personal data is stored. Blocks the privacy notice.
- **OQ-08** — whether the allocation ruleset stays bundled in the binary or moves to remote-with-fallback.
- **OQ-10** — payment-rail security has no controls block yet; blocks the payments phase.

The **backend** choice, by contrast, is **not** open — it is decided as Supabase (ADR-16).

---

## Contributing

TBD — not yet in repo. No `CONTRIBUTING` file exists.

## License

TBD — not yet in repo. No `LICENSE` file exists.
