# Kasaran — Decision Log

*Architecture Decision Records. Each row: ID, decision, status, date, driving requirement/security IDs. This file did not exist when earlier documents were written; it is created here to record decisions that were previously scattered across requirements.md §11–13 and security-plan.md §11, plus the two decisions taken on 2026-09-13.*

## Status legend

- **DECIDED** — settled; downstream docs reflect it.
- **OPEN** — not yet settled; needs a decision or external input (e.g. counsel).

## Records

| ADR | Decision | Status | Date | Refs |
|---|---|---|---|---|
| ADR-01 | PHP-only, Philippines-only for v1. No multi-currency. | DECIDED | 2026-09-13 | REQ-GEN-2 |
| ADR-02 | Target band ₱30K–₱500K; sub-₱30K supported by omitting line items. | DECIDED | 2026-09-13 | REQ-BS-1 |
| ADR-03 | Self-planning couple is the sole primary persona; coordinators deferred. | DECIDED | 2026-09-13 | — |
| ADR-04 | Six hidden-fee categories first-class: crew meals, OOT, church aircon, corkage, overtime, venue power. | DECIDED | 2026-09-13 | REQ-HF-1, REQ-HF-2 |
| ADR-05 | Sponsorship: show gross event total and net out-of-pocket; pledge status tentative/confirmed/received. | DECIDED | 2026-09-13 | REQ-PL-2, REQ-PL-3 |
| ADR-06 | Brand name is **Kasaran**, treated as a distinct mark. | DECIDED | 2026-09-13 | — |
| ADR-07 | Payment states paid/pending/overdue, derived not editable; deposits modelled separately. | DECIDED | 2026-09-13 | REQ-LG-4, REQ-LG-5 |
| ADR-08 | Sync conflict resolution: field-level last-write-wins by HLC, with an immutable change log preserving superseded writes. | DECIDED | 2026-09-13 | REQ-SE-2, REQ-SE-4 |
| ADR-09 | Region is a first-class input on a versioned three-tier taxonomy: Metro 1.00, Provincial 0.85, Destination 1.20. | DECIDED | 2026-09-13 | REQ-BS-4, REQ-AE-2 |
| ADR-10 | Baseline allocations: Catering & Venue 40, Photo & Video 15, Attire & Styling 10, Coordination 10, Entourage & Misc 5, Buffer 20. | DECIDED | 2026-09-13 | REQ-AE-1 |
| ADR-11 | Regional cost index drives cost expectation and rate suggestions, not allocation shares. | DECIDED | 2026-09-13 | REQ-AE-2 |
| ADR-12 | Platform: Flutter (Android + iOS), SQLite via `drift`/`sqflite`, web excluded from v1. | DECIDED | 2026-09-13 | REQ-PLT-1, REQ-PLT-2 |
| ADR-13 | Money stored as int64 centavos; Dart `int` satisfies this natively. | DECIDED | 2026-09-13 | REQ-GEN-1 |
| ADR-14 | Constrained monetary display permitted in bento tiles (centavos dropped below ₱1M, `₱1.25M` above, truncated toward zero); full form everywhere else and in all a11y labels. | DECIDED | 2026-09-13 | REQ-GEN-2A |
| ADR-15 | Ruleset config is a JSON asset bundled in the app binary for v1, validated at load; no web authoring dashboard. | DECIDED | 2026-09-13 | REQ-AE-1 |
| ADR-16 | Backend: Supabase (Postgres + Auth + RLS). Tenant isolation enforced by forced RLS on every plan table. | DECIDED | 2026-09-13 | SEC-22, SEC-23, SEC-24 |
| ADR-17 | No cloud auto-backup of the local encrypted DB; local store encrypted with SQLCipher, key in Keychain/Keystore. | DECIDED | 2026-09-13 | SEC-12, SEC-13, SEC-16 |
| **ADR-18** | **Partner removal is defensive and one-sided. Two-party confirmation is scoped to ownership transfer only; removing a partner does NOT require the removed party's consent.** | **DECIDED** | **2026-09-13** | **REQ-SE-5 (cl. 4), REQ-SE-6, SEC-07** |
| **ADR-19** | **Defensive removal is MUTUAL: either paired partner may remove the other, not creator-only.** | **DECIDED** | **2026-09-13** | **REQ-SE-6 (cl. 1), SEC-07** |
| ADR-20 | Removed partner retains their existing local copy; there is no remote wipe. Server access stops; future edits do not sync. | DECIDED | 2026-09-13 | REQ-SE-6 (cl. 5, 6) |

## ADR-18 — Partner removal is defensive and one-sided

**Context.** REQ-SE-5 clause 4 originally required two-party confirmation for partner removal. security-plan.md SEC-07 required one-sided removal for the called-off-wedding case. These conflicted (security-plan §11 item 1).

**Decision.** Two-party confirmation applies to **ownership transfer only**. Defensive partner removal takes effect without the removed party's consent, immediately on the server, effective on the removed partner's next sync.

**Rationale.** A hostile partner would refuse a two-party removal forever, trapping the person the control is meant to protect. Requiring consent from the party being defended against defeats the purpose.

**Consequences.** REQ-SE-5 clause 4 amended; REQ-SE-6 added; SEC-07 aligned; `lifecycle_confirmations` no longer holds `remove_partner` (design.md §4.1); ux-spec SCR-17 and §3.3 updated; testing-plan TC-SE-10..14 added.

## ADR-19 — Defensive removal is mutual

**Context.** SEC-07 originally granted removal to the plan creator only. security-plan §11 item 5 flagged that a symmetric relationship needs a symmetric right.

**Decision.** Either paired partner may defensively remove the other. The right does not depend on who created the plan.

**Rationale.** If only the creator could remove, and the creator were the hostile party, the other partner would have no defensive move. The relationship is symmetric; the safety control must be too.

**Consequences.** SEC-07 widened to either-paired-partner; REQ-SE-6 clause 1 states the mutual right; both removal directions are tested (TC-SE-10, TC-SE-11).

## Still OPEN — not resolved by ADR-18 or ADR-19

These are recorded so it is explicit that the removal decisions did not close them.

| ADR | Item | Status | Refs |
|---|---|---|---|
| ADR-O1 | Erasure on a shared record: de-identify the other partner's copy vs full delete, with two data subjects over one record. Counsel-gated. Sharpened by mutual removal — see testing-plan and Open Questions. | OPEN | SEC-33, SEC-38 |
| ADR-O2 | NPC registration threshold and formal DPO designation at this scale. Counsel-gated. | OPEN | SEC-37 |
| ADR-O3 | Force-wipe vs wipe-offer for the removed partner's local copy. This plan offers, does not force. | OPEN | SEC-08, REQ-SE-6 (cl. 7) |
| ADR-O4 | Reference cost benchmarks per region tier for budget adequacy. | OPEN | REQ-AE-2 (cl. 2) |
| ADR-O5 | Ownership-transfer confirmation expiry duration. | OPEN | REQ-SE-5 (cl. 7) |

*Note: `docs/locked-decisions.md` was referenced as an input to the change that produced this log but does not exist in the repository. If it is created later, reconcile this log against it.*
