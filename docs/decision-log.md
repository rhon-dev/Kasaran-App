# Kasaran — Decision Log

*This log separates three tiers that were previously flattened into one table. Keeping them distinct prevents a given (especially an intentionally-unresolved one) from being silently read as a resolved decision downstream.*

**The three tiers:**

1. **Givens / constraints (GIV-n)** — premises stated by the decision-maker as the starting frame, not the outcome of resolving an open question. A given may itself carry a status: it can be firm, intentionally unresolved, or later *superseded* by a decision. Givens are not renumbered; a superseded given keeps its ID and points to the ADR that replaced it.
2. **Open questions (OQ-n)** — things not yet settled, awaiting a decision or external input. (Previously the ADR-O* rows.)
3. **Decisions (ADR-n)** — the log of decisions that resolved open questions or refined givens. IDs are never reused; new decisions take new ADR numbers; a superseded decision keeps its ID and is marked SUPERSEDED with a pointer.

*Provenance: `docs/locked-decisions.md` was named as an input in an earlier instruction but does not exist in the repository; its contents were never invented. The givens in Tier 1 are transcribed from constraints the decision-maker stated in conversation. If `locked-decisions.md` is later created, reconcile Tier 1 against it.*

## Status legend

- **FIRM** — a given that stands and is not under question.
- **UNRESOLVED** — a given deliberately left open; must not be treated as decided downstream.
- **SUPERSEDED** — replaced by a later decision; pointer given. ID retained, never reused.
- **DECIDED** — a decision that is settled; downstream docs reflect it.
- **OPEN** — an open question not yet settled; needs a decision or external input (e.g. counsel).

---

## Tier 1 — Givens / constraints

*Premises, not resolutions. These framed the work; some were later refined or overridden by decisions in Tier 3.*

| GIV | Given | Status | Refs / lineage |
|---|---|---|---|
| GIV-01 | 2026 Philippine market; PHP currency; competitors Nuptl and Vowly (directory/inspiration-first, budgeting lane open). | FIRM | problem-brief; ADR-01 records the PHP/PH-only scoping decision |
| GIV-02 | Mobile app targeting **iOS + Android**. Originally stated as React Native. | **SUPERSEDED** by ADR-12 (Flutter) | The iOS+Android target stands; the RN framework choice was overridden by the Flutter decision. |
| GIV-03 | Architecture is **local-first, syncing to the cloud** (device is source of truth for reads; changes sync when online). | FIRM | REQ-PLT-2; realised by ADR-12 (SQLite/`drift`) and ADR-16 (Supabase) |
| GIV-04 | Conflict handling is **field-level last-write-wins with an immutable change log — NOT CRDTs**. | FIRM | ADR-08 recorded the mechanism; ADR-21 (D1) later refined the *clock authority* within this given, still LWW, still not CRDT |
| GIV-05 | **AI features are deferred until after a non-AI launch.** v1 is rule-based only. | FIRM | requirements AI-phase section, REQ-EX-1 |
| GIV-06 | Domain specifics are fixed: crew meals, OOT fees, church aircon, corkage (plus overtime, venue power); Ninong/Ninang and family pledges; per-head vs flat-rate cost distinction. | FIRM | ADR-04, ADR-05; REQ-HF-*, REQ-PL-*, REQ-GM-* |
| GIV-07 | **Product name is Kasaran.** Originally stated as a given with the naming question left open; now **resolved** — "Kasaran" is the final name (decision-maker, 2026-09-14). The "roughness" vs "kasalan"/wedding nuance was acknowledged and set aside; the name is adopted as a distinct, ownable mark. | **RESOLVED** → ADR-27; OQ-06 closed | See the naming caveat below and ADR-06/ADR-27. |

### Naming caveat (GIV-07) — now resolved

Short history, for anyone tracing the name's status changes:

1. An early turn ("its kasaran") locked the name; problem-brief.md said *"Name locked: Kasaran."*
2. The decision-maker later clarified that naming should sit in the *givens* tier as **intentionally unresolved**, not a settled decision. GIV-07 was set to UNRESOLVED, OQ-06 opened, and problem-brief.md was softened to "working name; provisional."
3. **The decision-maker has now confirmed (2026-09-14): "Kasaran really is the name."** Naming is **resolved**. GIV-07 is RESOLVED, **OQ-06 is closed**, and this is logged as **ADR-27**. problem-brief.md is re-locked to a final-name statement.

"Kasaran" is the final product name, adopted as a distinct, ownable mark (the "roughness" vs "kasalan"/wedding nuance was acknowledged and set aside). Downstream docs may treat the name as final and it is cleared for logo/domain.

---

## Tier 2 — Open questions

*Not yet settled. Awaiting a decision or external input.*

| OQ | Item | Status | Refs |
|---|---|---|---|
| OQ-01 | Erasure on a shared record: de-identify the other partner's copy vs full delete, with two data subjects over one record. Counsel-gated. Sharpened by mutual removal (ADR-23/24). | OPEN | SEC-33, SEC-38 |
| OQ-02 | NPC registration threshold and formal DPO designation at this scale. Counsel-gated. | OPEN | SEC-37 |
| OQ-03 | Force-wipe vs wipe-offer for the removed partner's local copy. Current plan offers, does not force. | OPEN | SEC-08, REQ-SE-6 (cl. 7) |
| OQ-04 | Reference cost benchmarks per region tier for budget adequacy. | OPEN | REQ-AE-2 (cl. 2) |
| OQ-05 | Ownership-transfer confirmation expiry duration. | **CLOSED** → ADR-32 (seven days) | REQ-SE-5 (cl. 7), ADR-32 |
| OQ-06 | Final product name / brand (whether to keep "Kasaran"). | **CLOSED** → ADR-27 (name is Kasaran, 2026-09-14) | GIV-07, ADR-06, ADR-27 |
| OQ-07 | **Data residency.** No ADR covers where Philippine personal data is stored. Supabase has no PH region; the deployment plan assumes `ap-southeast-1` (Singapore). DPA 2012 permits cross-border transfer but the controller stays accountable and must disclose the location. | OPEN | deployment-plan §2.2, SEC-30. **Blocks the privacy notice, which blocks store submission** |
| OQ-08 | **Bundled vs remote allocation ruleset.** ADR-15 bundles the ruleset in the app binary. Flutter has no code OTA, so a wrong baseline or regional modifier requires a full store release (days). Remote-with-bundled-fallback would make it a minutes-scale fix. | OPEN | deployment-plan §3.6, ADR-15, REQ-AE-3, OQ-04. Requires amending ADR-15 |
| OQ-09 | **Name clearance** (distinct from the name *decision* in ADR-27): App Store name availability, Play title collision, IPOPHIL trademark search, and domain ownership for the support / privacy / deletion URLs. | OPEN | deployment-plan §5.6. Steps 1, 2, 4 are hard submission blockers |
| OQ-10 | **Payment-rail security has no SEC block.** `security-plan.md` §9 scoped PCI-and-equivalent out of v1 on the assumption payments would arrive inside the AI phase. ADR-28 gives payments its own phase, so a dedicated SEC block (rail auth, tokenisation, reconciliation integrity, PCI applicability, DPA implications of transaction data) must be authored. | OPEN | ADR-28, security-plan §9, development-phases §25. **Blocks phase 25 from starting** |

*Note: OQ-01..05 were previously numbered ADR-O1..O5. They are renamed to the OQ series because they are open questions, not decisions; the mapping is ADR-O1→OQ-01 … ADR-O5→OQ-05. No decision ADR ID is affected. OQ-06 was surfaced by the GIV-07 naming caveat and is now closed by ADR-27.*

---

## Tier 3 — Decisions (ADRs)

*The log of decisions. IDs never reused. A superseded decision keeps its ID and is marked SUPERSEDED.*

| ADR | Decision | Status | Date | Refs |
|---|---|---|---|---|
| ADR-01 | PHP-only, Philippines-only for v1. No multi-currency. | DECIDED | 2026-09-13 | GIV-01, REQ-GEN-2 |
| ADR-02 | Target band ₱30K–₱500K; sub-₱30K supported by omitting line items. | DECIDED | 2026-09-13 | REQ-BS-1 |
| ADR-03 | Self-planning couple is the sole primary persona; coordinators deferred. | DECIDED | 2026-09-13 | — |
| ADR-04 | Six hidden-fee categories first-class: crew meals, OOT, church aircon, corkage, overtime, venue power. | DECIDED | 2026-09-13 | GIV-06, REQ-HF-1, REQ-HF-2 |
| ADR-05 | Sponsorship: show gross event total and net out-of-pocket; initial pledge states tentative/confirmed/received. Receipt-derived fulfillment and `withdrawn` refine this in ADR-37/38. | DECIDED, refined by ADR-37/38 | 2026-09-13 | GIV-06, REQ-PL-2, REQ-PL-3, ADR-37, ADR-38 |
| ADR-06 | Working name **Kasaran** adopted and used throughout. (Superseded by ADR-27, which confirms Kasaran as the final name.) | SUPERSEDED by ADR-27 | 2026-09-13 | GIV-07, ADR-27 |
| ADR-07 | Payment states paid/pending/overdue, derived not editable; deposits modelled separately. Row-based payment and schedule detail refines this in ADR-36. | DECIDED, refined by ADR-36 | 2026-09-13 | REQ-LG-4, REQ-LG-5, ADR-36 |
| ADR-08 | Sync conflict resolution: field-level last-write-wins with an immutable change log preserving superseded writes. Original clock mechanism was a hybrid logical clock (HLC). | **SUPERSEDED in part** by ADR-21 (D1) | 2026-09-13 | GIV-04, REQ-SE-2, REQ-SE-4. *LWW + change log still stand; the HLC clock authority was replaced by server-assigned timestamps in ADR-21.* |
| ADR-09 | Region is a first-class input on a versioned three-tier taxonomy: Metro 1.00, Provincial 0.85, Destination 1.20. | DECIDED | 2026-09-13 | REQ-BS-4, REQ-AE-2 |
| ADR-10 | Baseline allocations: Catering & Venue 40, Photo & Video 15, Attire & Styling 10, Coordination 10, Entourage & Misc 5, Buffer 20. | DECIDED | 2026-09-13 | REQ-AE-1 |
| ADR-11 | Regional cost index drives cost expectation and rate suggestions, not allocation shares. | DECIDED | 2026-09-13 | REQ-AE-2 |
| ADR-12 | Platform: Flutter (Android + iOS), SQLite via `drift`/`sqflite`, web excluded from v1. | DECIDED | 2026-09-13 | GIV-02 (supersedes RN), GIV-03, REQ-PLT-1, REQ-PLT-2 |
| ADR-13 | Money stored as int64 centavos; Dart `int` satisfies this natively. | DECIDED | 2026-09-13 | REQ-GEN-1 |
| ADR-14 | Constrained monetary display permitted in bento tiles (centavos dropped below ₱1M, `₱1.25M` above, truncated toward zero); full form everywhere else and in all a11y labels. Exact two-decimal million precision is clarified by ADR-30. | DECIDED, refined by ADR-30 | 2026-09-13 | REQ-GEN-2A, ADR-30 |
| ADR-15 | Ruleset config is a JSON asset bundled in the app binary for v1, validated at load; no web authoring dashboard. | DECIDED | 2026-09-13 | REQ-AE-1 |
| ADR-16 | Backend: Supabase (Postgres + Auth + RLS). Tenant isolation enforced by forced RLS on every plan table. | DECIDED | 2026-09-13 | GIV-03, SEC-22, SEC-23, SEC-24 |
| ADR-17 | No cloud auto-backup of the local encrypted DB; local store encrypted with SQLCipher, key in Keychain/Keystore. | DECIDED | 2026-09-13 | SEC-12, SEC-13, SEC-16 |
| ADR-18 | Partner removal is defensive and one-sided. Two-party confirmation is scoped to ownership transfer only; removing a partner does NOT require the removed party's consent. | DECIDED | 2026-09-13 | REQ-SE-5 (cl. 4), REQ-SE-6, SEC-07 |
| ADR-19 | Defensive removal is MUTUAL: either paired partner may remove the other, not creator-only. | DECIDED | 2026-09-13 | REQ-SE-6 (cl. 1), SEC-07 |
| ADR-20 | Removed partner retains their existing local copy; there is no remote wipe. Server access stops; future edits do not sync. | DECIDED | 2026-09-13 | REQ-SE-6 (cl. 5, 6) |
| ADR-21 (D1) | LWW clock authority: ordering source of record is a SERVER-ASSIGNED timestamp applied at sync time. Device wall-clocks never authoritative. Device monotonic counter + stable device id are tiebreakers only. Refines ADR-08's clock, within GIV-04 (still LWW, still not CRDT). | DECIDED | 2026-09-14 | GIV-04, ADR-08, REQ-SE-2, design §2.2/§2.4/§4.6, TC-SE-20, TC-SE-21 |
| ADR-22 (D2) | Pledge semantics: a pledge reduces the couple's out-of-pocket total ONLY on fulfillment (`received`). Promised-but-unfulfilled (`tentative`, `confirmed`) appear as a separate "expected" figure and never reduce net. Both shown distinctly. Partial receipts refine fulfillment in ADR-37; gifts stay separate in ADR-40. | DECIDED, refined by ADR-37/40 | 2026-09-14 | ADR-05, REQ-PL-2, REQ-PL-3, REQ-PL-4, TC-PL-10, TC-PL-11, ADR-37, ADR-40 |
| ADR-23 (D3) | Partner removal is defensive, one-sided, and mutual; two-party confirmation scoped to ownership transfer only; removed partner keeps local copy, no remote wipe; logged and attributed. (Consolidates ADR-18/19/20 under the D-label.) | DECIDED | 2026-09-14 | ADR-18, ADR-19, ADR-20, REQ-SE-5 (cl. 4), REQ-SE-6, SEC-07, TC-SE-10..15 |
| ADR-24 (D4) | Simultaneous mutual removal has a deterministic winner: order by the D1 server timestamp, tiebreak on stable id. No undefined "whoever syncs first". | DECIDED | 2026-09-14 | ADR-21, REQ-SE-6 (cl. 9–11), SEC-07, TC-SE-22 |
| ADR-25 (D5) | Retired/merged requirement IDs are recorded in a redirect appendix (requirements §14), never left as hollow live "reserved" clauses. | DECIDED | 2026-09-14 | requirements §14, REQ-SE-5 (cl. 5) |
| ADR-26 (D6) | Shared-record erasure test cases are left UN-STUBBED and marked blocked-pending-counsel, with no asserted expected value. A guessed expected result is forbidden. | DECIDED (process rule) | 2026-09-14 | testing-plan §5, SEC-33, SEC-38, OQ-01 |
| ADR-27 | **Final product name is Kasaran.** Confirms and closes the naming question. Adopted as a distinct, ownable mark; cleared for logo/domain. Supersedes ADR-06 (working-name-only) and closes OQ-06; GIV-07 RESOLVED. | DECIDED | 2026-09-14 | GIV-07, OQ-06, ADR-06, problem-brief |
| ADR-28 | **Payments (REQ-AI-4) is its own post-launch phase, pulled out of the AI tail entirely.** Becomes development phase 25, owned by **Backend Agent** with Security as mandatory reviewer — payments is a financial-rail integration, not inference, and was only ever grouped with AI because both were deferred. The ID `REQ-AI-4` is retained un-renumbered; its `AI-` prefix is now a historical artifact. | DECIDED | 2026-09-14 | REQ-AI-4, development-phases §25, agents.md, OQ-10 |
| ADR-29 | Bohol retains Provincial cost tier (0.85) but has `is_destination = true`. OOT defaulting uses the destination flag, not the tier; the tier only selects the cost index. | DECIDED | 2026-10-02 | REQ-BS-4, REQ-HF-3, design §4.2 |
| ADR-30 | Refines ADR-14: bento shorthand at or above ₱1M always shows exactly two decimal million digits, truncated toward zero (`₱1.00M`, `₱1.20M`, `₱1.25M`). | DECIDED | 2026-10-02 | ADR-14, REQ-GEN-2A, TC-GEN-03 |
| ADR-31 | New plans default the designated driving RSVP status to `invited`; each new guest's RSVP remains explicitly set. Priority tier alone does not remove guests from cost projections. | DECIDED | 2026-10-02 | REQ-GM-1, requirements §13.2, ux-spec UT-5 |
| ADR-32 | Ownership-transfer confirmation expires seven days after initiation unless both partners confirm. Closes OQ-05; defensive removal has no confirmation window. | DECIDED | 2026-10-02 | OQ-05, REQ-SE-5 (cl. 7), ux-spec UT-4 |
| ADR-33 | Notes have a hard 2,000-character limit. Show a live count and stop input at the limit; do not silently truncate saved text. | DECIDED | 2026-10-02 | REQ-LG-1 (cl. 8), ux-spec UT-3 |
| ADR-34 | On defensive removal, the app SHALL offer the removed partner a local wipe; it does not force one. OQ-03 remains open. | DECIDED | 2026-10-02 | REQ-SE-6 (cl. 7), OQ-03, ux-spec UT-6 |
| ADR-35 | Tier-specific per-head rates are not in v1. Guest priority tier drives the cut-list only; it does not alter the per-head rate. | DECIDED | 2026-10-02 | REQ-GM-1 (cl. 9), requirements §13.3 |
| ADR-36 | Refines ADR-07: replace mutable cumulative deposits and entry due date with insert-only payment/refund rows and dated schedule items. An entry with no schedule has a virtual, undated balance item; any unscheduled remainder is virtual. Derived statuses allocate net payments oldest due first; no stored payment status or cumulative amount. | DECIDED | 2026-10-02 | ADR-07, REQ-LG-1/4/5/7/8, design §1.4/§4.4 |
| ADR-37 | Refines ADR-05/22: receipt rows record partial fulfillment; each receipt reduces net when received. `received` status is derived when cumulative valid receipts reach the pledged value, not set manually; expected/exposure use the unreceived remainder. Net is not floored at zero. | DECIDED | 2026-10-02 | ADR-05/22, REQ-PL-1/2/3/4/5/6 |
| ADR-38 | A pledge may be marked `withdrawn`. Its unreceived remainder is excluded from expected support and exposure, while past receipts remain in net and history. | DECIDED | 2026-10-02 | ADR-05, ADR-37, REQ-PL-1/3/4 |
| ADR-39 | In-kind receipts reduce net only to the linked entry's effective amount; a sponsor-paid supplier bill also creates a linked payment reducing balance due, with one-to-one receipt/payment correlation. Entry link outranks category link. Deleting the entry retains history but excludes its cost and linked in-kind support from live totals and flags reconciliation. | DECIDED | 2026-10-02 | ADR-22/37, REQ-PL-7, REQ-LG-8 |
| ADR-40 | Day-of gifts are separate receipt rows, never pledges; they do not change ADR-22 net. Once any gift exists, show gifts total and a distinct `net after gifts = net out-of-pocket − gifts received`, without flooring, plus post-wedding reconciliation against remaining supplier balances. | DECIDED | 2026-10-02 | ADR-22, REQ-GF-1/2 |
| ADR-41 | Due-date reminders are local device notifications (seven and one day before, plus overdue), configurable per plan with an off switch; no supplier names or amounts on the lock screen by default. Partner-edit push remains excluded. | DECIDED | 2026-10-02 | REQ-LG-9, ux-spec §6.1, SEC-28 |
| ADR-42 | Ceremony and venue types are optional setup inputs with `Not sure yet`; they change only explanatory hidden-fee hints, not amounts, tier indices, allocations, or the obligation to decide all six prompts. | DECIDED | 2026-10-02 | REQ-BS-1, REQ-HF-1, ux-spec SCR-04 |

---

## Decision narratives

## ADR-36 — Schedule and payment events, not mutable totals

**Context.** Two partners recording deposits offline can overwrite a shared `deposit_paid_cents` field under field-level LWW. One due date also cannot describe multiple supplier installments.

**Decision.** Record each payment and refund as a separate positive-centavo event row (`kind` distinguishes direction) and each explicit installment as a schedule row; tombstones preserve history. Deposit paid is the sum of payments less refunds, not a writable field. If no schedule exists, derive one undated balance item without writing it. If explicit items total less than the effective cost, derive an undated residual item. Allocate net paid amount to dated items in due-date, sort-order, stable-id order, then the residual; `schedule_item_id` records attribution and does not override this allocation. A refund reopens balances. An entry is `paid` if its balance is zero, otherwise `overdue` if any dated item is overdue, otherwise `due soon` if any unpaid item is due within the configured window (including today), otherwise `pending`; partial coverage is an additional indicator. Statuses are never stored. An over-scheduled amount is rejected rather than silently treated as a new cost. Discounts change `actual_cents`, not a negative payment. **Consequence:** concurrent offline inserts do not collide on one cumulative amount; existing single-deposit fixtures can be expressed as payment events without changing their values.

## ADR-37 — Partial receipts define fulfillment

**Context.** A single manually selected `received` state cannot represent part of a promised amount arriving, and is not proof money was received.

**Decision.** Each receipt is an insert-only amount event. Net reduces by the sum of eligible receipts as each arrives, even before the pledge is fully fulfilled. Derive `received` once at least one receipt exists and the receipt total reaches the pledged value (a zero-value pledge without receipts is not fulfilled); users explicitly select only the unfulfilled tentative/confirmed intent state. Expected and confirmed exposure count the unreceived remainder, not the original pledge value. Net can be negative and is not clamped. **Consequence:** ADR-22's received-only rule now operates on actual receipts; receipt amounts, not a status switch, drive arithmetic.

## ADR-38 — Withdrawn pledge preserves realized support

**Context.** A reneged promise is neither tentative nor still confirmed; removing it erases history and hides any amount already received.

**Decision.** `withdrawn` excludes only the unreceived remainder from expected support and exposure. Existing receipts still reduce net and remain visible in the immutable history. Withdrawal remains an explicit lifecycle choice even after full receipt, but cannot substitute for a refund or correction of money already received. **Consequence:** promised but reneged money stops appearing as expected while received money is not undone by a label change.

## ADR-39 — In-kind sponsorship and supplier payment are different effects

**Context.** A sponsored item remains a wedding cost even when the sponsor pays its supplier directly. Counting the same payment twice would understate what the couple owes.

**Decision.** Keep the entry in gross. Cap cumulative in-kind support at the linked entry's effective amount; multiple in-kind pledges for one entry share that cap in receipt date/stable-id order. A direct supplier payment generates a payment row and a uniquely correlated pledge receipt in one local transaction: receipt reduces net once, payment reduces balance due once. `linked_entry_id` takes precedence over `linked_category_code`. On linked-entry deletion, preserve receipt and payment history, exclude the deleted entry and its in-kind support from live gross/net/balance, and show a reconciliation warning. **Consequence:** no double reduction or orphaned invisible sponsor payment.

## ADR-40 — Gifts do not redefine net

**Context.** Day-of cash and transfer gifts are received funds but not promises to sponsor a supplier cost. Including them in ADR-22 net would change existing fixture meanings.

**Decision.** Store gifts as separate positive-centavo events. Gross and D2 net remain unchanged. Once a gift exists, show `net after gifts` as net less gifts, without flooring; compare gifts total with remaining balances in a post-wedding reconciliation view. Optional giver names are third-party personal data. **Consequence:** existing pledge fixture expectations remain unchanged.

## ADR-41 — Private local reminders

**Context.** Dated installments need reminders without reopening the excluded partner-edit push channel or putting supplier names and amounts on a lock screen.

**Decision.** Each device schedules locally from its own offline-capable plan data, defaulting to seven-day, one-day, and overdue notices, with plan-level customization and off switch. Default lock-screen copy includes neither supplier identity nor money amounts. **Consequence:** reminders may reflect a device's last-synced state until it receives updates; no server push is implied.

## ADR-42 — Optional context changes hints only

**Context.** The brief mentions ceremony and venue types, but required setup omitted them; demanding them would add friction and guessing them could invent fees.

**Decision.** Let couples select either type or `Not sure yet`. Use choices only for contextual hints on existing hidden-fee cards; no selection writes an amount, changes allocation, or waives any of the six required fee decisions. **Consequence:** users retain control of all cost inputs.

**v1 four-test gate (ADR-36–42).** ADR-36/37/38/39/40 use integer-centavo event sums, explicit links, and reproducible tie ordering; ADR-41 uses fixed local date offsets; ADR-42 uses fixed enum-to-copy mappings: each is **deterministic**. Each exposes source rows or a stated rule (and ADR-42's hint is explicitly non-price): each is **explainable**. Every payment, refund, receipt, and gift row records a past event only; notifications and hints only inform: **none moves money**. No decision lists, ranks, books, or recommends suppliers: **none recommends a supplier**.

## ADR-29 — Destination flag independent of cost tier

**Context.** Bohol appears in the Provincial 0.85 tier but also triggers destination OOT prompts. Treating the tier itself as the destination test makes these two rules conflict.

**Decision.** Keep Bohol's Provincial cost index and set `is_destination = true`. Use that flag for OOT defaults; use `tier_code` only for the cost index. **Consequence:** no reclassification or new region benchmark is implied.

## ADR-30 — Two-decimal bento million shorthand

**Context.** REQ-GEN-2A said one decimal, while ADR-14, TC-GEN-03 and the UI examples used `₱1.25M`.

**Decision.** Exactly two decimals for every million shorthand, truncated toward zero. Below ₱1M the constrained form drops centavos without million shorthand. Full monetary form and screen-reader labels remain unchanged. **Consequence:** the presenter and its tests use hundredths of a million.

## ADR-31 — Conservative RSVP default

**Context.** The driving RSVP status was designated but its default was unspecified.

**Decision.** Default to `invited`. This counts invited guests until the couple changes status, rather than underestimating headcount. **Consequence:** setup and guest-flow defaults align.

## ADR-32 — Ownership-transfer confirmation window

**Context.** REQ-SE-5 required expiry but did not define a duration; OQ-05 remained open.

**Decision.** A pending transfer expires seven days after initiation if both partners have not confirmed. The plan stays unchanged. Defensive removal is immediate and has no transfer window. **Consequence:** close OQ-05 and show the fixed window in the transfer UI.

## ADR-33 — Notes input bound and feedback

**Context.** REQ-LG-1 set a 2,000-character bound without specifying what happens at the limit.

**Decision.** Display a live count and stop further input at 2,000 characters. Do not silently truncate notes on save. **Consequence:** the entry editor exposes the limit before it is reached.

## ADR-34 — Local wipe offer on removal

**Context.** REQ-SE-6 permitted but did not require a wipe offer; the removed partner's local copy is retained under ADR-20.

**Decision.** Offer a local wipe when removal is detected, without forcing it. **Consequence:** OQ-03 (whether to force a wipe) remains open; no remote wipe is implied.

## ADR-35 — Priority tier does not change per-head rate in v1

**Context.** REQ-GM-1 allowed tier-specific rates without any prescribed tier rates.

**Decision.** Exclude tier-specific per-head rates from v1. Use priority tier only for the cut-list. **Consequence:** no prices are invented; per-head projections use the couple's own rate and driving RSVP status.

**v1 gate for ADR-29–35.** Each decision is deterministic and explainable; none moves money or recommends a supplier. Payment rails remain a separate post-launch phase (ADR-28).

## ADR-21 (D1) — Server-assigned LWW clock authority

**Context.** The prior design (ADR-08) ordered field-level LWW by a hybrid logical clock seeded from the device wall clock (design §2.2). A device with a wrong clock could still distort ordering. This refines ADR-08 within GIV-04 — the LWW-not-CRDT given is unchanged; only the clock authority moves.

**Decision.** The ordering source of record is a **server-assigned timestamp** applied when a change-log row is accepted at sync. Device wall-clocks are never authoritative. A device-side monotonic counter, then a stable device id, are tiebreakers only.

**Rationale.** Removes device time from the authority chain entirely, rather than merely bounding its error as an HLC does. An unsynced write carries no authoritative order and cannot beat an already-synced write by an earlier clock reading.

**Consequences.** ADR-08 marked SUPERSEDED in part; REQ-SE-2 rewritten (clauses 3–5 changed, clause added); design §2.2, §2.4, §2.5, §4.6, §7.5 updated from `hlc_*` to `server_ts` + `device_monotonic`; TC-SE-20 and TC-SE-21 added.

## ADR-22 (D2) — Pledge reduces out-of-pocket only on fulfillment

**Context.** The prior model (ADR-05) reduced net by both `confirmed` and `received` pledges; only `tentative` was excluded (former REQ-PL-2).

**Decision.** Net out-of-pocket is reduced **only** by fulfilled (`received`) pledges. `tentative` and `confirmed` are "expected" support, shown as a distinct figure, and never reduce the real number.

**Rationale.** A promised pledge is not money in hand. Counting a confirmed-but-unfulfilled Ninong pledge against the real out-of-pocket recreates the over-optimism the product exists to prevent. The couple must see the real number and the hoped-for number separately.

**Consequences.** REQ-PL-2, REQ-PL-3, REQ-PL-4 rewritten (IDs preserved); dashboard shows net (fulfilled only) and an expected figure distinctly; TC-PL-10 and TC-PL-11 added.

## ADR-24 (D4) — Deterministic winner for simultaneous mutual removal

**Context.** Mutual one-sided removal (ADR-23/D3) raises the case where each partner removes the other, possibly from two offline devices.

**Decision.** Resolve to a single deterministic winner: the removal with the earlier server-assigned timestamp (ADR-21/D1) prevails; ties break on stable device id. The plan is never left with zero members.

**Rationale.** "Whoever syncs first" is undefined and non-reproducible. Reusing the D1 ordering authority gives one answer both servers and devices agree on.

**Consequences.** REQ-SE-6 clauses 9–11 added; TC-SE-22 asserts the winner from two offline devices.

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

---

## ID mapping (for anyone following older references)

- Open-question rows renamed: **ADR-O1 → OQ-01, ADR-O2 → OQ-02, ADR-O3 → OQ-03, ADR-O4 → OQ-04, ADR-O5 → OQ-05.** These were open questions mislabelled with an ADR prefix; the OQ series corrects the tier. No *decision* ADR ID (ADR-01..26) changed.
- New this restructure: **GIV-01..07** (givens tier), **OQ-06** (final brand name).
- Added by the deployment plan: **OQ-07** (data residency), **OQ-08** (bundled vs remote ruleset), **OQ-09** (name clearance, distinct from the ADR-27 name decision).
- **ADR-08** status changed DECIDED → SUPERSEDED-in-part (pointer to ADR-21). Its ID and text are retained.
- **ADR-06** history: first "brand locked", then reframed to "working name adopted; brand unresolved", now **SUPERSEDED by ADR-27** (name confirmed as Kasaran). ID retained throughout.
- **ADR-27** added: final product name is Kasaran; closes OQ-06; GIV-07 RESOLVED.
