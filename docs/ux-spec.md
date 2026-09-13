# Kasaran — UX Specification

*Inputs: [requirements.md](./requirements.md), [design.md](./design.md), [mvp-user-stories.md](./mvp-user-stories.md). No visual mockups, no palettes, no code.*

## 0. Input discrepancies and upstream gaps

**`docs/decision-log.md` does not exist.** It was listed as an input; the repository contains only `problem-brief.md`, `project-brief.md`, `mvp-user-stories.md`, `requirements.md`, and `design.md`. I have not inferred its contents. Nothing appears lost — decisions are recorded in requirements.md sections 11–13 and design.md sections 7–8 — but if a separate consolidated log is wanted, it needs writing.

**Two items that were open when this spec was first written are now resolved.** Recorded here so the spec reads consistently.

1. **Platform — resolved as Flutter** (Android and iOS, SQLite via `drift`). This spec remains platform-neutral by design — no widget or gesture primitive is named — so nothing here changed, but section 9's touch-target and dynamic-type rules are now known to target Flutter's implementation of both platform floors.
2. **REQ-GEN-2 constrained-display amendment — adopted** as REQ-GEN-2A. Bento tiles use a constrained monetary form (centavos dropped below ₱1M, `₱1.25M` above, truncated toward zero); the full two-decimal form holds everywhere else and in every screen-reader label. Section 8.2 now describes settled behaviour, not a proposal.

**Budget health thresholds are only partly defined upstream.** See section 4.3. I have specified the card using only conditions that exist in requirements.md and have not invented graded bands.

---

## 1. Screen inventory

| Screen ID | Name | Purpose | Entry points | REQ IDs satisfied |
|---|---|---|---|---|
| SCR-01 | Sign In / Sign Up | Authenticate; create account | Cold start, unauthenticated | REQ-SE-1 |
| SCR-02 | Invite Acceptance | Partner B joins a plan via deep link | Invite deep link | REQ-SE-1 (3,4,5,6) |
| SCR-03 | Setup: Budget & Date | Capture total budget, wedding date | After sign-up; SCR-18 | REQ-BS-1, REQ-BS-2, REQ-BS-3, REQ-GEN-2 |
| SCR-04 | Setup: Guest Cap & Region | Capture guest cap, region | SCR-03 next | REQ-BS-1, REQ-BS-4, REQ-BS-5 |
| SCR-05 | Setup: Hidden-Fee Prompts | Force a decision on all six fees; gate completion | SCR-04 next | REQ-HF-1, REQ-HF-2, REQ-HF-3 |
| SCR-06 | Dashboard | Bento overview: budget, countdown, categories, health | Post-setup default tab | REQ-PL-2, REQ-PL-3, REQ-PL-4, REQ-AE-6, REQ-AE-2 (3), REQ-BS-5 (2), REQ-HF-1 (5), REQ-LG-6, REQ-OF-3 |
| SCR-07 | Ledger List | Browse, filter, and triage all cost lines | Ledger tab; dashboard category tap | REQ-LG-1, REQ-LG-2, REQ-LG-3, REQ-LG-5, REQ-LG-6 |
| SCR-08 | Expense Editor | Create/edit a standard ledger entry | SCR-07 add or row tap | REQ-LG-1, REQ-LG-2, REQ-LG-3, REQ-LG-4, REQ-GM-2 |
| SCR-09 | Hidden-Fee Editor | Create/edit one of six typed fee entries | SCR-05, SCR-07, dashboard outstanding-fee chip | REQ-HF-1, REQ-HF-2, REQ-HF-3, REQ-GM-4 |
| SCR-10 | Allocations & Overrides | Review engine allocations; override; revert | Dashboard category breakdown; SCR-18 | REQ-AE-1, REQ-AE-4, REQ-AE-5, REQ-AE-6 |
| SCR-11 | Explain Figure | Show rule, inputs, modifier behind any engine number | Tap any engine-derived figure | REQ-AE-4, REQ-AE-2 (1) |
| SCR-12 | Guests List | Manage guests across RSVP status and priority tier | Guests tab | REQ-GM-1, REQ-GM-4 |
| SCR-13 | Guest What-If | Model a headcount change before committing | SCR-12 action; dashboard guest tile | REQ-GM-2, REQ-GM-3, REQ-GM-5, REQ-BS-5 (2) |
| SCR-14 | Pledges List | Track sponsor pledges and exposure | Pledges tab; dashboard net tile | REQ-PL-1, REQ-PL-3, REQ-PL-4, REQ-PL-5 |
| SCR-15 | Pledge Editor | Create/edit a pledge; change status | SCR-14 add or row tap | REQ-PL-1, REQ-PL-2, REQ-PL-3 |
| SCR-16 | Change Log / Activity | Plan-wide and per-entity history with attribution | More tab; per-entity history affordance | REQ-SE-2 (5), REQ-SE-3, REQ-SE-4, REQ-OF-5 (4) |
| SCR-17 | Shared Access | Partner status, invite, removal, ownership, delete plan | More tab | REQ-SE-1, REQ-SE-5, REQ-PLT-3 |
| SCR-18 | Plan Settings | Edit setup inputs; driving RSVP status; ruleset opt-in | More tab | REQ-BS-2, REQ-BS-6, REQ-GM-1 (6), REQ-AE-3, REQ-PLT-3 |
| SCR-19 | Sync Detail | Pending-write queue, last sync, failure detail, retry | Tap sync badge anywhere | REQ-OF-3, REQ-OF-5, REQ-SE-3 |

### 1.1 Requirements no screen satisfies

Separated into requirements that are *correctly* non-UI and requirements that are *genuine gaps*.

**Correctly non-UI — no screen expected.**

| REQ ID | Why no screen |
|---|---|
| REQ-GEN-1 | Storage representation. Verified by test, not visible. |
| REQ-PLT-1 | Build-target constraint. |
| REQ-PLT-2 | Persistence architecture. Its *effect* — instant local reads — shows as the absence of loading states in section 3. |
| REQ-OF-1, REQ-OF-2 | Cross-cutting behavioural guarantees. Every screen's offline column in section 3 is the evidence. |
| REQ-OF-4 | Clock handling. Surfaces indirectly as `overdue` on SCR-07. |
| REQ-SE-2 (1–4) | Resolution mechanics. Outcomes surface on SCR-16. |
| REQ-AI-1 … REQ-AI-5 | AI phase, excluded from v1. |
| REQ-EX-1 | A prohibition. Satisfied by absence — no marketplace or directory screen exists in section 1. |

**Genuine gaps — flagged, not silently absorbed.**

| REQ ID | Gap |
|---|---|
| REQ-AE-2 (3) | Budget adequacy has a home on SCR-06 but **cannot render in v1**. `reference_costs` is unpopulated (design.md 4.2; requirements.md 13.1). Specified as an explicit unavailable state in section 4.3, not omitted and not shown as healthy. |
| REQ-AE-1 (4) | Ruleset publish-time validation that baselines sum to 10000 bp. No UI surface — there is no ruleset authoring screen in v1, so this is a build/deploy-time check. Worth confirming that config is edited outside the app in v1. |
| REQ-LG-1 (8) | The 2,000-character notes limit has no specified counter or truncation behaviour. Assigned to SCR-08 in section 2; flagged because the requirement states the bound without stating the feedback. |
| REQ-SE-5 (7) | Two-party confirmation expiry duration is undefined upstream (requirements.md 13.5). SCR-17 cannot display a countdown for an undefined window. |

---

## 2. Per-screen specification

Field sources cite entities and derived calculations from design.md sections 1.4 and 4. **Derived** means computed on read and never stored, per design.md 1.4.

### SCR-01 Sign In / Sign Up
**Regions:** brand block; form; primary action; alternate-mode link; error slot.
**Fields:** email, password, display name (sign-up only) → `users`.
**Actions:** submit → authenticate, then route to SCR-03 if no active plan, SCR-06 if one exists (REQ-PLT-3). Toggle sign-in/sign-up.
**Nav in:** cold start unauthenticated. **Nav out:** SCR-03, SCR-06, or SCR-02 when a pending invite token exists.

### SCR-02 Invite Acceptance
**Regions:** inviter identity; plan summary; accept/decline; expiry/error slot.
**Fields:** inviter display name → `users` via `invites.inviter_user_id`; wedding date → `plans`; expiry → `invites.expires_at`.
**Actions:** Accept → write `plan_members`, then full replay pull from `since_hlc = 0` (design.md 2.5) → SCR-06. Decline → SCR-01.
**States of note:** expired, revoked, already accepted — each names the reason (REQ-SE-1 clause 5).
**Nav in:** deep link. **Nav out:** SCR-06, SCR-01.

### SCR-03 Setup: Budget & Date
**Regions:** step indicator (1 of 3); total budget field; wedding date field; validation slot; next.
**Fields:** `plans.total_budget_cents`, `plans.wedding_date`.
**Actions:** Next → validate REQ-BS-2 (reject non-numeric, zero, negative; retain other fields) → SCR-04. Past date → confirm dialog per REQ-BS-3, savable on confirmation.
**Notably absent:** no block on budgets under ₱30,000 or over ₱500,000 (REQ-BS-1 clause 3).
**Nav in:** post sign-up; SCR-18. **Nav out:** SCR-04.

### SCR-04 Setup: Guest Cap & Region
**Regions:** step indicator (2 of 3); guest cap field; region picker grouped by cost tier; tier note; next/back.
**Fields:** `plans.guest_cap`, `plans.region_code` → `regions`, `cost_tiers`.
**Actions:** Next → allocation runs (REQ-AE-1) → SCR-05. Region selection writes no ledger entry (REQ-BS-4 clause 5) and sets the OOT prompt default when `is_destination` (REQ-HF-3).
**Copy:** tier note reads *"Destination weddings usually carry supplier travel costs. We'll ask about that next."* It states the consequence without asserting an amount.
**Nav in:** SCR-03. **Nav out:** SCR-05, back to SCR-03.

### SCR-05 Setup: Hidden-Fee Prompts
**Regions:** step indicator (3 of 3); six fee cards each showing state badge; per-card fill/dismiss; blocked-completion slot; finish.
**Fields:** `hidden_fee_prompts.state` per fee type; totals from `ledger_entries` + `fee_components`.
**Actions:** Fill → SCR-09 for that type. Dismiss → records `dismissed_at`, `dismissed_by` (REQ-HF-1 clause 4). Finish → blocked while any card is `prompted_unfilled`, naming each untouched card (REQ-HF-1 clause 6).
**Critical distinction:** `prompted_unfilled` renders as *"Not answered yet"*, never as ₱0.00 (REQ-HF-1 clause 2). A dismissed card renders *"Not applicable"* and contributes exactly 0 (clause 7).
**Nav in:** SCR-04. **Nav out:** SCR-06 on finish; SCR-09 per card.

### SCR-06 Dashboard
Fully specified in section 4.

### SCR-07 Ledger List
**Regions:** header with gross total; filter bar (category, derived status, entry type); grouped list; add FAB; sync badge.
**Fields per row:** supplier name, category, **effective amount** (derived: `actual_cents ?? estimated_cents`), **balance due** (derived: `effective − deposit_paid`, floored at 0), **payment status** (derived: paid / pending / overdue per REQ-LG-5), due date, per-head or flat marker, estimate-differs-from-actual marker (REQ-LG-3 clause 5).
**Actions:** row tap → SCR-08 or SCR-09 by `entry_type`; filter; add → type chooser; swipe delete → confirm (REQ-LG-2 clause 3), removes from totals immediately (clause 4).
**Nav in:** Ledger tab; dashboard category tap. **Nav out:** SCR-08, SCR-09, SCR-16 per-entity history.

### SCR-08 Expense Editor
**Regions:** supplier; category picker; pricing mode toggle; amounts; deposit; due date; notes; history link; save/delete.
**Fields:** all of `ledger_entries` per REQ-LG-1. Category from fixed taxonomy, free text rejected (clause 2). Estimated mandatory; actual optional; deposit defaults 0.
**Derived, read-only in-form:** effective amount, balance due, payment status.
**Actions:** toggle per-head requires a rate before accepting the change (REQ-GM-2 clause 4). Setting actual on a per-head entry sets `manually_valued` and stops recomputation, with an inline explanation (REQ-GM-2 clause 5). Deposit above effective shows an overpayment warning and stores the value unclamped (REQ-LG-4 clause 2). Notes counter surfaces the 2,000-character bound — see gap in 1.1.
**Nav in:** SCR-07. **Nav out:** SCR-07, SCR-16.

### SCR-09 Hidden-Fee Editor
Six typed variants sharing one shell. Per-type field differences in section 5.1.
**Regions:** type header; component list (repeatable rows); running total; guest-scaling note; save/dismiss.
**Fields:** `ledger_entries` header plus `fee_components` rows.
**Actions:** add/remove component; save; dismiss whole fee type. Component total = `quantity × unit_rate_cents` when both present, else `amount_cents` (design.md 4.4).
**Crew meals only:** persistent note that crew meals do not scale with guests (REQ-GM-4 clause 1) and that crew headcount is not a guest count (clause 3).
**Nav in:** SCR-05, SCR-07, dashboard chip. **Nav out:** originating screen.

### SCR-10 Allocations & Overrides
**Regions:** total budget header; six category rows; buffer drawdown block; over-allocation slot.
**Fields per row:** `plan_allocations.engine_cents`, `override_cents`, overridden badge, summed effective for the category, variance in pesos and percent (REQ-LG-6 clauses 1, 2).
**Buffer block:** buffer allocation, summed non-buffer overrun, **buffer remaining** (derived per REQ-AE-6 clauses 1, 2) in pesos and as percent of original (clause 4).
**Actions:** override → accepts any value ≥ 0; both values remain visible (REQ-AE-5 clause 2). Revert → nulls `override_cents`, affects no other category (clauses 5, 6). Explain → SCR-11.
**Over-allocation:** when overrides sum above total budget, names the excess and reduces nothing (REQ-AE-5 clause 4).
**Nav in:** dashboard breakdown; SCR-18. **Nav out:** SCR-11.

### SCR-11 Explain Figure
**Regions:** figure restated; plain-language rule; input list; modifier line; ruleset version.
**Fields:** `plan_allocations.explanation` (opaque JSONB), `allocator_kind`, `allocator_version`, `plans.ruleset_version`.
**Content:** baseline basis points, skew multiplier, resulting share, amount — in prose, not a formula (REQ-AE-4 clauses 2, 3).
**Rule enforced:** a figure with no explanation payload is not rendered at all anywhere in the app (REQ-AE-4 clause 4). This screen is the reason that rule is enforceable.
**Nav in:** tap any engine figure. **Nav out:** dismiss.

### SCR-12 Guests List
**Regions:** RSVP × tier summary matrix; driving-status indicator; guest list; crew headcount block; add.
**Fields:** `guests.name`, `rsvp_status`, `priority_tier`; counts per cell; `crew_headcount.headcount`.
**Actions:** add guest → defaults `tier_2` (REQ-GM-1 clause 3), RSVP set explicitly with no silent default (clause 4). Edit either axis independently (clause 5). Crew headcount edited in its own block, visually separated (clause 10, REQ-GM-4 clause 3). What-if → SCR-13.
**Displays:** breakdown by tier within the driving RSVP status (clause 8).
**Nav in:** Guests tab. **Nav out:** SCR-13.

### SCR-13 Guest What-If
**Regions:** current count; hypothetical input (absolute or delta); before/after comparison; per-guest marginal cost; tier cut-list block; commit/discard.
**Fields:** all derived, nothing persisted while open (REQ-GM-5 clause 5).
**Shows:** before/after gross and net and every affected category (clause 2); marginal cost per guest as Δgross ÷ Δcount (clause 3); over-cap indicator with full calculation still returned when above `guest_cap` (clause 4, REQ-BS-5 clause 3); on reductions, how many Tier 2 guests absorb the cut before any Tier 1 is touched (clause 9).
**Unchanged in preview:** crew meals (REQ-GM-4 clause 1) and `manually_valued` entries (REQ-GM-3 clause 4), both labelled as excluded so the omission reads as deliberate.
**Actions:** Commit → updates driving count, propagates per REQ-GM-3. Discard → state byte-identical to pre-preview (clause 6).
**Nav in:** SCR-12, dashboard guest tile. **Nav out:** SCR-12 or SCR-06.

### SCR-14 Pledges List
**Regions:** gross/net pair; potential relief; outstanding exposure with contributing list; pledge list grouped by status; add.
**Fields:** `pledges.*`; **net** (derived: gross − confirmed − received, REQ-PL-2 clause 2); **potential relief** (derived: sum tentative, REQ-PL-3 clause 2); **outstanding exposure** (derived: sum confirmed-not-received, REQ-PL-4).
**Actions:** row tap → SCR-15; status change inline. Tap net → breakdown of contributing pledges summing exactly to gross − net, tentative absent (REQ-PL-5).
**Displays:** exposure renders `₱0.00`, never blank, when nothing is confirmed-not-received (REQ-PL-4 clause 3).
**Nav in:** Pledges tab; dashboard net tile. **Nav out:** SCR-15.

### SCR-15 Pledge Editor
**Regions:** sponsor name; role picker; type toggle; item description (item type only); value; status; link to category or entry; save/delete.
**Fields:** all of `pledges` per REQ-PL-1.
**Actions:** status change updates net and exposure in the same operation (REQ-PL-2 clause 5). Moving tentative → confirmed decreases net by exactly the pledge value (REQ-PL-3 clause 3). Confirmed → received leaves net unchanged and decreases exposure (REQ-PL-4 clause 1) — stated inline, because that pairing is counterintuitive.
**Copy:** role picker uses **Ninong** and **Ninang** untranslated (section 8.4).
**Nav in:** SCR-14. **Nav out:** SCR-14.

### SCR-16 Change Log / Activity
Specified in section 6.

### SCR-17 Shared Access
**Regions:** partner slot with role; invite block; pending-confirmation block; ownership transfer; delete plan (creator only); active-plan note.
**Fields:** `plan_members.role`, `invites.expires_at`, `lifecycle_confirmations.*`, `plans.is_active`.
**Actions:** invite → 7-day link (REQ-SE-1 clause 4); revoke. Remove partner and transfer ownership → open two-party confirmation, both partners retain full access while pending (REQ-SE-5 clause 6). Delete plan → creator only; non-creator sees the action absent and, if reached, a refusal naming creator-only (clauses 1, 2); requires typed confirmation (clause 3).
**Stated on screen:** data access stays fully symmetric; only lifecycle actions are restricted (REQ-SE-5 clause 9). Without this the asymmetry reads as a general permission tier.
**Nav in:** More tab. **Nav out:** SCR-16 for lifecycle history (clause 8).

### SCR-18 Plan Settings
**Regions:** setup inputs (budget, date, guest cap, region); driving RSVP status picker; ruleset version block; remainder category note.
**Actions:** any setup edit → preview before applying when more than one category shifts (REQ-BS-6 clause 3); cancel persists nothing (clause 4); applied edits log (clause 5). Ruleset opt-in → before/after preview, overrides preserved (REQ-AE-3 clauses 3, 4).
**Stated on screen:** editing setup destroys no entries, pledges, guests, or overrides (REQ-BS-6 clauses 1, 2). Users expect budget changes to wipe work; saying otherwise prevents avoidable fear.
**Nav in:** More tab. **Nav out:** SCR-03/04 field editors, SCR-10.

### SCR-19 Sync Detail
**Regions:** connection state; pending-write count and list; last successful sync; failure detail; manual retry.
**Fields:** `sync_state.last_pushed_hlc`, `last_pulled_hlc`; local queue depth.
**Actions:** retry. Replay is automatic and requires no action here (REQ-OF-5 clauses 1, 2) — the button exists for reassurance, and the screen says so.
**Nav in:** sync badge, any screen. **Nav out:** dismiss.

---

## 3. State matrix

Eight states per screen. **N/A** means the state cannot occur, with the reason given — never an omission.

### 3.1 Two states behave unusually in this app, by design

**Loading is nearly absent.** REQ-PLT-2 clause 1 requires every read served from the local store with no network round-trip. There is no remote fetch to wait on, so no screen shows a spinner for data. Loading appears in exactly three places: database open and migration on cold start, the SCR-02 first-replay, and never elsewhere. Any spinner beyond those three is a defect — it means something reached for the network on a read path.

**Sync-error is not a data-integrity state.** A failed push means writes are still queued locally and intact (REQ-OF-5 clause 4). Copy must never imply loss. See section 7.

### 3.2 Matrix

| Screen | First-run empty | Populated | Loading | Offline + pending | Sync error | Conflict just resolved | Partner removed | Calculation invalid |
|---|---|---|---|---|---|---|---|---|
| SCR-01 | Default state | N/A — no plan data | Auth request in flight | Sign-in blocked; message states connection needed and no data is at risk | Auth failure, distinct from sync | N/A — pre-plan | N/A | N/A |
| SCR-02 | Default state | N/A | Replay progress with row count | Accept blocked; invite requires connection; token retained | Replay interrupted; resumes from cursor, partial data retained | N/A — no local writes yet | Invite already revoked; names reason | Expired invite (REQ-SE-1 clause 5) |
| SCR-03 | Default state | Pre-filled when reached from SCR-18 | N/A — local only | Badge only; setup fully available (REQ-OF-1) | Badge only; no blocking | N/A — single-partner phase | N/A | Invalid budget per REQ-BS-2; past date per REQ-BS-3 |
| SCR-04 | Default state | Pre-filled from SCR-18 | N/A | Badge only | Badge only | N/A | N/A | None defined — cap and region cannot be invalid |
| SCR-05 | All six `prompted_unfilled` | Mixed filled/dismissed | N/A | Badge only | Badge only | N/A | N/A | Finish blocked while any untouched (REQ-HF-1 clause 6) |
| SCR-06 | Post-setup: zero entries, zero pledges — see 4.4 | Full bento | Cold-start skeleton only | Badge in header; every tile live and accurate | Badge escalates; figures unaffected | Banner naming affected figure, link to SCR-16 | Read-only notice; plan data retained | Breach, over-cap, over-allocation, unfilled fees — see 4.3 |
| SCR-07 | Empty with add affordance and hidden-fee shortcut | Grouped list | N/A | Badge; local rows indistinguishable in accuracy | Badge | Row-level attribution stamp on changed rows | Read-only; add and edit suppressed | Rows with `overdue` status; deposit-exceeds-effective rows |
| SCR-08 | New-entry blank form | Populated form | N/A | Badge; save fully available | Badge | Field-level stamp on remotely changed fields; see 6.3 | Read-only; save suppressed | Category missing, estimated missing, per-head without rate, deposit above effective |
| SCR-09 | Type-appropriate blank component list | Populated components | N/A | Badge; save available | Badge | Component-level stamp | Read-only | Component with neither rate-pair nor amount |
| SCR-10 | Allocations present immediately post-setup; never truly empty | Six rows with variance | N/A | Badge | Badge | Stamp on remotely overridden category | Read-only; override suppressed | Over-allocation (REQ-AE-5 clause 4); negative buffer remaining (REQ-AE-6 clause 5) |
| SCR-11 | N/A — only reachable from an existing figure | Explanation shown | N/A | Badge; explanation is local | Badge | N/A — explanation is derived, not user-written | Read-only, still viewable | Missing explanation payload → figure is not rendered upstream, so this screen is unreachable (REQ-AE-4 clause 4) |
| SCR-12 | Zero guests; crew block still shown | Matrix and list | N/A | Badge | Badge | Stamp on changed guest rows | Read-only; add suppressed | Driving count above guest cap (REQ-BS-5 clause 2) |
| SCR-13 | N/A — requires a plan; runs with zero guests and reports zero deltas | Before/after comparison | N/A | Badge; computes fully offline (REQ-OF-2 clause 2) | Badge; preview unaffected as it is local-only | **N/A — a preview is never synced (REQ-GM-5 clause 8), so no remote write can touch it** | Read-only; commit suppressed, preview still viewable | Over-cap with full calculation still returned (REQ-GM-5 clause 4) |
| SCR-14 | Zero pledges; gross shown, net equals gross, exposure `₱0.00` | Grouped list with all three figures | N/A | Badge | Badge | Banner when a pledge status changed remotely | Read-only | None defined — pledge values cannot be invalid; negative is rejected at entry |
| SCR-15 | Blank form | Populated | N/A | Badge | Badge | Field stamp | Read-only; save suppressed | Sponsor name empty, negative value, item type without description |
| SCR-16 | Contains setup entries from the moment a plan exists; never empty | Full feed | Pagination on long histories | Badge; local entries listed as not-yet-synced | Badge | **This is where resolution surfaces** — see 6.4 | Read-only; history retained in full | N/A — log entries are facts, not calculations |
| SCR-17 | Solo: no partner, invite prompt | Partner present | N/A | Badge; invite generation blocked, stated as requiring connection | Badge | N/A — membership does not flow through the log (design.md 2.5) | Terminal state for the removed partner: explains removal, offers exit | Pending confirmation with no defined expiry — see 1.1 gap |
| SCR-18 | Populated from setup; never empty | Same | N/A | Badge; edits available | Badge | Stamp on remotely changed setup fields | Read-only | Invalid budget, past date |
| SCR-19 | Zero pending, synced | Queue listed | Sync in progress | Primary purpose: queue depth and age | Primary purpose: failure detail and retry | Lists resolved conflicts with link to SCR-16 | Read-only; sync halted, reason stated | N/A |

### 3.3 Partner-removed state, stated precisely

REQ-SE-5 governs removal, and the removed partner's experience is not specified upstream. Position taken: **the removed partner retains local data in read-only form and is told plainly.**

Reason: their device holds a legitimate local database. Wiping it silently would look like data loss and would contradict the offline guarantee they have been trained to rely on. Sync stops, writes are refused, and the reason is stated once, clearly, at the top of every screen.

Copy: *"You no longer have access to this wedding plan. You can still view your copy, but changes won't be saved or synced."*

Whether the local copy should eventually be purged is a privacy decision, not a UX one, and is not resolved here.

---

## 4. Main dashboard (SCR-06)

### 4.1 Bento layout

Regions in source order, which is also screen-reader order. Sizes are relative units, not pixels.

```
┌─────────────────────────────────────────────┐
│ HEADER  plan name · sync badge · countdown  │  full width, compact
├───────────────────────┬─────────────────────┤
│ A  GROSS EVENT TOTAL  │ B  NET OUT-OF-      │  2 cols, tall
│    vs total budget    │    POCKET           │
├───────────────────────┴─────────────────────┤
│ C  BUDGET HEALTH                            │  full width, tall
├───────────────────────┬─────────────────────┤
│ D  BUFFER REMAINING   │ E  OUTSTANDING      │  2 cols, medium
│                       │    PLEDGE EXPOSURE  │
├───────────────────────┴─────────────────────┤
│ F  CATEGORY BREAKDOWN  6 rows               │  full width, tall
├───────────────────────┬─────────────────────┤
│ G  GUESTS             │ H  OUTSTANDING      │  2 cols, medium
│    driving count      │    HIDDEN FEES      │
├───────────────────────┴─────────────────────┤
│ I  AI INSIGHTS  — inert placeholder, v1     │  full width, fixed 1 unit
└─────────────────────────────────────────────┘
```

Tiles A and B are adjacent and equal in visual weight because REQ-PL-2 clause 1 requires gross and net simultaneously visible without scrolling past a fold. Placing either below the fold violates it.

### 4.2 Tile data sources

| Tile | Field | Source |
|---|---|---|
| Header | Countdown days | `plans.wedding_date` − device date. Past date shows elapsed, not negative (REQ-BS-3 clause 2). |
| Header | Sync badge | Local queue depth, connection state (section 7) |
| A | Gross event total | Derived: Σ effective across `ledger_entries` incl. hidden fees |
| A | Total budget | `plans.total_budget_cents` |
| B | Net out-of-pocket | Derived: gross − confirmed − received (REQ-PL-2 clause 2) |
| B | Potential relief | Derived: Σ tentative, labelled separately, never summed into net (REQ-PL-3 clauses 2, 4) |
| C | Budget health | Section 4.3 |
| D | Buffer remaining | Derived per REQ-AE-6 clauses 1, 2; pesos and percent of original (clause 4) |
| E | Outstanding exposure | Derived: Σ confirmed-not-received (REQ-PL-4) |
| F | Per-category allocated / effective / variance | `plan_allocations` + derived variance (REQ-LG-6 clauses 1, 2) |
| G | Driving guest count and tier split | `guests` filtered by `plans.driving_rsvp_status` (REQ-GM-1 clauses 6, 8) |
| H | Unanswered fee count | `hidden_fee_prompts` where state = `prompted_unfilled` (REQ-HF-1 clause 5) |
| I | Nothing | Section 4.5 |

### 4.3 Budget health card — exact inputs, and where I stop

**What is defined upstream.** Six binary conditions, each with an explicit threshold in requirements.md. The card is a checklist of these and nothing more.

| # | Condition | Exact threshold | REQ ID |
|---|---|---|---|
| 1 | Budget breach | `buffer_remaining < 0` | REQ-AE-6 clause 5 |
| 2 | Over-allocation | `Σ override_cents > total_budget_cents` | REQ-AE-5 clause 4 |
| 3 | Over guest cap | `driving_guest_count > guest_cap` | REQ-BS-5 clause 2 |
| 4 | Unanswered hidden fees | any `hidden_fee_prompts.state = 'prompted_unfilled'` | REQ-HF-1 clause 5 |
| 5 | Overdue payments | any entry with `balance_due > 0` and `due_date < today` | REQ-LG-5 clause 2 |
| 6 | Budget adequacy shortfall | `total_budget_cents < expected_total_cost_cents` | REQ-AE-2 clause 3 |

Each renders as met or not met, with the governing number shown. All values come from the rule-based engine and derived calculations in design.md 1.4 and 5.2. No network, no model, no inference.

**Condition 6 cannot render in v1.** `reference_costs` is unpopulated (design.md 4.2; requirements.md 13.1), so `expected_total_cost` is not computable. It renders as **unavailable**, explicitly:

> *"Budget adequacy — not available yet. We don't have regional cost benchmarks for this area."*

It must not be hidden and must not read as met. An unavailable check displayed as passing is worse than an absent one.

**Where I stop.** The card cannot present a *graded* health verdict, because nothing upstream defines the bands:

- No percentage thresholds for a caution tier — nothing states that buffer below some remaining share warrants a warning short of breach.
- No composite score or weighting across the six conditions.
- No severity ranking between them.
- No time-based risk thresholds relative to the wedding date.

Inventing any of these would put fabricated numbers in front of a couple making financial decisions, and would violate REQ-AE-4 clause 4, since a made-up band traces to no rule. **The card therefore states facts, not a verdict.** If a graded score is wanted, the bands must be defined upstream first; I have listed them as an open item in section 11.

### 4.4 First-run dashboard

Immediately post-setup there are allocations but no spending. Every tile renders a real value, not an empty state:

- A: gross `₱0.00` against the budget — accurate, not empty
- B: net equals gross equals `₱0.00`
- C: conditions 1, 2, 3, 5 not met; 4 reflects any dismissed-vs-unanswered fees; 6 unavailable
- D: buffer remaining equals full buffer allocation, 100%
- E: `₱0.00` (REQ-PL-4 clause 3)
- F: six categories with allocated amounts, zero effective, full negative variance
- G: driving count as entered; zero if no guests added yet
- H: count of unanswered fees, which is 0 immediately after the SCR-05 gate

Only F and G carry a genuine call to action. There is no blank-slate dashboard state, because setup guarantees allocations exist.

### 4.5 AI insights placeholder (tile I)

- **Position:** last region, full width, below all v1 content.
- **Dimensions:** fixed height of 1 layout unit — the same height as a compact tile such as H. It does not grow, does not scroll, and does not reflow when adjacent tiles change.
- **Renders in v1:** nothing. No text, no icon, no skeleton, no animation, no tap target.
- **Label:** the region is labelled in code and in the layout spec as `ai_insights_placeholder`. The label is not user-visible in v1.
- **Accessibility:** excluded from the accessibility tree in v1. An empty focusable region is a screen-reader dead end.
- **Purpose:** reserving the position so introducing REQ-AI-3 advisories later does not reflow the dashboard a couple has learned. Per design.md 6.3, advisories read from a separate `advisories` table outside the sync path, so this tile will never be a data dependency of any v1 figure.

A visible "AI coming soon" affordance is deliberately rejected: it advertises absent function and invites taps that do nothing.

---

## 5. Key flows

### 5.1 Adding a hidden-fee item — the four types do differ

**They differ substantially.** Only one of the four is a single-amount form. Treating them uniformly would defeat REQ-HF-2 clause 1, which forbids reducing them to a generic amount field.

| Field | Crew meals | OOT fees | Church aircon | Corkage |
|---|---|---|---|---|
| Repeatable rows | Yes, per supplier | Yes, per supplier | **No — single row** | Yes, per item |
| Row label | Supplier name | Supplier name | — | Item type picker: cake / wine / liquor / lechon / other |
| Quantity | Crew headcount | — | — | — |
| Unit rate | Per-meal rate | — | — | — |
| Flat amount | — | **Three per row:** travel, lodging, per-diem | Single amount | Amount per item |
| Row total | `headcount × rate` | travel + lodging + per-diem | amount | amount |
| Guest scaling | **Never** (REQ-GM-4) | Never | Never | Never |
| Pre-enabled by region | No | **Yes when destination** (REQ-HF-3) | No | No |
| Entity shape | `fee_components`: quantity + unit_rate | 3 components per supplier, amount only | 1 component, amount only | 1 component per item, amount only |

Overtime (`quantity` = hours, `unit_rate` = hourly) and venue power (three fixed components) follow the same pattern; they are outside the four requested but share the shell.

**Flow — crew meals** · REQ-HF-1, REQ-HF-2 (1, 7, 8), REQ-GM-4, REQ-SE-4

1. From SCR-05 or SCR-07, choose Crew meals. SCR-09 opens with one blank component row.
2. Enter supplier name, crew headcount, per-meal rate. Row total computes live as `headcount × rate`.
3. Add rows for remaining suppliers. Running total updates per row.
4. Note is persistently visible: crew meals do not change when guest count changes.
5. Save. `hidden_fee_prompts.state` → `filled`. One `change_log` row per changed field.
6. **End state:** entry appears in SCR-07 as its own attributable line; gross on SCR-06 increases by the entry total; the crew-meals chip disappears from tile H; a guest what-if leaves this total unchanged.

**Flow — OOT fees** · REQ-HF-1, REQ-HF-2 (2, 7), REQ-HF-3

1. If region is destination-tier, the OOT card on SCR-05 is already enabled (REQ-HF-3 clause 1). No amount is pre-filled (clause 3).
2. Open SCR-09. Each row is one supplier with three separate amount fields.
3. Enter travel, lodging, per-diem per supplier. Row total is their sum.
4. Save.
5. **End state:** three `fee_components` per supplier persisted; entry visible as its own line; gross increased; card state `filled`.

**Flow — church aircon** · REQ-HF-1, REQ-HF-2 (3, 7)

1. Open the card. SCR-09 shows a **single amount field**, no repeatable rows.
2. Enter the flat premium. Save.
3. **End state:** one component; entry on SCR-07; gross increased.

**Flow — corkage, including dismissal** · REQ-HF-1 (3, 4, 7), REQ-HF-2 (4)

1. Open the card. Rows are item-typed, not supplier-typed.
2. Either add rows per item type and save, **or** choose Not applicable.
3. On dismissal, `state` → `dismissed` with `dismissed_at` and `dismissed_by` recorded.
4. **End state, dismissed:** card reads "Not applicable" with who dismissed it and when; contributes exactly `₱0.00` to gross; no longer counted in tile H; SCR-05 completion no longer blocked by it. The distinction from `prompted_unfilled` remains visible everywhere.

### 5.2 Logging a pledge · REQ-PL-1, REQ-PL-2, REQ-PL-3, REQ-PL-4, REQ-SE-4

1. From SCR-14, add. SCR-15 opens.
2. Enter sponsor name; pick role — **Ninong**, **Ninang**, family, friend, other.
3. Choose cash or item. Item reveals a description field and optional link to a category or entry.
4. Enter value. Set status: tentative, confirmed, or received.
5. Save.
6. **End state, tentative:** pledge listed under Tentative; net **unchanged**; value appears in potential relief; exposure unchanged. Inline copy explains that tentative pledges do not reduce what the couple pays until confirmed.
7. **End state, confirmed:** net decreases by exactly the value; exposure increases by the value; the pledge appears in the net breakdown on tile B.
8. **End state, received:** net unchanged from confirmed; exposure decreases by the value. Labelled inline, because "money arrived and my net did not move" reads as a bug otherwise.

### 5.3 Guest what-if, commit or discard · REQ-GM-2, REQ-GM-3, REQ-GM-5, REQ-BS-5

1. From SCR-12 or dashboard tile G, open SCR-13. Current driving count shown with its RSVP tier.
2. Enter an absolute hypothetical count or a delta of N guests.
3. Preview computes locally and immediately (REQ-OF-2 clause 2). No write occurs.
4. Screen shows before/after gross, before/after net, every affected category, and per-guest marginal cost as Δgross ÷ Δcount.
5. Excluded items are listed as excluded: crew meals, and any `manually_valued` per-head entry.
6. If the hypothetical exceeds guest cap, an over-cap indicator appears **and the full calculation is still shown**.
7. On a reduction, the tier cut-list states how many Tier 2 guests absorb the cut before any Tier 1 guest is affected.
8. Partner B's device shows pre-preview values throughout; nothing syncs.
9. **Discard → end state:** plan byte-identical to pre-preview. No `change_log` rows. Nothing on B's device changed at any point.
10. **Commit → end state:** driving count updated; every non-excluded per-head entry recomputed; gross, net, all category variance, and buffer remaining updated in the same operation; `change_log` rows written; B's device matches after next sync.

### 5.4 A sync conflict resolving and surfacing · REQ-SE-2, REQ-SE-3, REQ-SE-4, REQ-OF-5

1. Partner B goes offline on SCR-08 and sets an entry's actual amount to ₱62,000. Local write commits; queue depth 1.
2. Partner A, online, sets the **same field** on the same entry to ₱58,000. A's write syncs immediately.
3. B reconnects. Queued row pushes with its **original HLC preserved**, not reconnect time (REQ-OF-5 clause 3).
4. Both devices order the two log rows by `(hlc_physical, hlc_counter, device_id)` and independently select the same winner (REQ-SE-2 clauses 3, 4).
5. Projections converge. Both devices show the same value (REQ-SE-3 clause 2).
6. **Neither write is discarded.** Both remain in `change_log`; the loser is superseded, computed at read time (design.md 4.6).
7. The losing device shows a banner naming the field and the winning value, linking to SCR-16.
8. SCR-16 shows both rows in clock order, the winner marked current and the loser marked superseded with its value intact and its author attributed.
9. **End state:** one visible current value on both devices; both attempts permanently recoverable in the change log; each attributed; the couple can see a disagreement happened and what the other person intended.

---

## 6. Shared-editing UI

### 6.1 Notification model — position taken

**In-app only. No push notifications for partner edits in v1.**

Justification: two partners planning one wedding are usually co-located and often editing together. Pushing "your partner changed the flowers estimate" for every field edit produces notification fatigue fast, and the change log already provides a complete record on demand. Nothing upstream requires push, and design.md 2.6 deliberately omits realtime transport, so a push would need infrastructure that does not exist.

What is surfaced instead, in ascending intrusiveness:

1. **Passive** — attribution stamps on changed fields and rows. No interruption.
2. **Ambient** — activity indicator on the More tab when unseen log entries exist since last visit to SCR-16.
3. **Banner** — a dismissible banner on SCR-06, used only when a remote change altered a headline figure (gross, net, buffer remaining, exposure) or when a conflict resolved.
4. **Blocking** — reserved for lifecycle events only: pending two-party confirmation, partner removed. Never for a data edit.

### 6.2 Attribution

Displayed as **display name + relative timestamp**. No avatar in v1: with exactly two members, an avatar carries no information a name does not, and it consumes width that money figures need.

- Relative time under 7 days: "2 hours ago". Beyond that, absolute date per section 8.5.
- Attribution is always the acting partner from `change_log.actor_user_id` (REQ-SE-4 clause 5).
- Stamps read "You" for the current user rather than their own name.

### 6.3 Field-level attribution placement

- **SCR-07, SCR-12, SCR-14 rows:** one stamp per row, reflecting the most recent change to any field on that entity.
- **SCR-08, SCR-09, SCR-15 forms:** stamp beneath each field changed remotely since this user last opened the record. Not on every field — only genuinely remote ones, or the form becomes unreadable.
- **SCR-06 tiles:** no per-tile stamps. Derived figures have no single author. This is why the banner in 6.1 item 3 exists.
- **SCR-10:** stamp on any category overridden by the other partner, since an override is a judgement call worth attributing.

### 6.4 How the change log reads

SCR-16 is a reverse-chronological feed, grouped by day, each entry one line:

```
[Partner name] · [action] · [entity] · [field]
  [old value] → [new value]                    [relative time]
```

Rules:

- Monetary changes show both old and new values (REQ-SE-4 clause 2).
- Superseded entries carry a marker and their value stays legible (clause 3).
- Entries are immutable — no edit or delete affordance exists anywhere (clause 4).
- Filterable by partner, entity type, and date. Not searchable in v1.
- Per-entity history is the same component filtered to one `entity_id`.
- Lifecycle actions and their confirmations appear here (REQ-SE-5 clause 8).
- Locally queued, not-yet-pushed entries appear with a pending marker so a partner sees their own offline work in context.

### 6.5 Is an overwritten value recoverable in the UI?

**Yes — visible and readable, but not restorable with one tap.**

The value is never lost; design.md 4.6 makes the log append-only and REQ-SE-2 clause 5 forbids discarding an accepted write. SCR-16 shows the superseded value, its author, and its timestamp.

What is deliberately **not** provided is a one-tap Restore. Reason: restoring is just another write, and a Restore button invites a tap-war where each partner reverts the other, generating log noise and no agreement. The couple should read what happened and decide, then type the value they agree on. The value is one screen away and fully legible — that satisfies recoverability without automating a disagreement.

### 6.6 Is "their edit won while you were offline" shown or silent?

**Shown. Explicitly, and only to the partner whose write lost.**

Silence here would be a betrayal of the offline promise. A partner who spent time entering figures on a plane and returns to different numbers with no explanation will conclude the app lost their work. That is the single most damaging misread available, and REQ-SE-2 clause 5 already requires the losing write to be preserved — so the information exists and withholding it is a choice.

Shown on the losing device, once, dismissible:

> **"Your partner also changed this"**
> *"[Name] changed the [field] on [entry] to ₱58,000.00 while you were offline. Their change is the one being used. Your ₱62,000.00 is saved in the activity log."*

Rules:

- Shown **only** to the losing partner. The winner has no action to take and no confusion to resolve.
- Names the field, the winning value, the losing value, and where the losing value lives.
- Never uses "overwritten", "lost", "discarded", or "failed". The write is preserved and the copy must say where.
- One banner per sync cycle regardless of conflict count, linking to SCR-16 for the full list. Twelve banners is not disclosure, it is noise.
- Non-conflicting remote changes get no banner. Only genuine same-field losses.

---

## 7. Offline communication

### 7.1 Indicator placement

A single **sync badge** in the header of every SCR-06 through SCR-19, always in the same position. One component, one location, four states. Tapping it opens SCR-19.

Deliberately never a full-screen block or a modal. REQ-OF-1 clause 3 forbids degrading any feature while offline; a modal degrades all of them.

### 7.2 Escalation ladder and literal copy

**State 0 — Online, synced.** Badge minimal or absent. No copy. Nothing to say.

**State 1 — Fresh offline, 0–N pending, under about an hour.**
Badge: `Offline`
On SCR-19: *"You're offline. Keep working — everything you enter is saved on this device and will sync when you're back online."*

**State 2 — Offline with queued writes.**
Badge: `Offline · 12 pending`
On SCR-19: *"12 changes are waiting to sync. They're saved on this device. They'll upload automatically when you reconnect."*

**State 3 — Offline for days.**
Badge: `Offline · 12 pending · 4 days`
On SCR-19: *"You haven't been online since Tuesday. 12 changes are saved here and waiting. Your partner won't see them until this device syncs."*

The escalation is the *partner-visibility* consequence, which is the only real cost of a long offline period. Still no implication of loss.

**State 4 — Online but sync failing.**
Badge: `Sync problem · 12 pending`
On SCR-19: *"We can't reach the server right now. Your 12 changes are safe on this device and we'll keep trying. Nothing has been lost."*
With retry, last-attempt time, and last successful sync time.

**State 5 — A write cannot be applied** (REQ-OF-5 clause 4).
Badge: `1 change needs attention`
On SCR-19: *"One change couldn't be saved to the shared plan. It's still here and hasn't been deleted. Open it to see the details."*

### 7.3 Copy rules

Binding on all sync and offline strings:

1. Never use *lost, deleted, discarded, failed to save, error, could not save*. In every state above, local data is intact — REQ-OF-5 clause 4 guarantees it.
2. Every state naming a problem must state where the data is in the same breath.
3. Use *this device* rather than *locally* or *cached*. "Cached" implies disposable.
4. Never suggest the user avoid working offline. REQ-OF-1 makes offline a first-class mode.
5. Counts are exact, never "some changes".
6. Distinguish *offline* (no connection, expected) from *sync problem* (connected, server unreachable, unexpected). Conflating them makes a normal state look broken.

---

## 8. Number, currency, and language rules

### 8.1 Standard monetary format

Per REQ-GEN-2: `₱` prefix, no space, comma thousands separators, exactly two decimals.

`₱350,000.00` · `₱1,250,000.00` · `₱0.00` · `₱8,500.50`

Centavos always display in this form. Wedding costs are quoted in whole pesos, so decimals are usually `.00` — but REQ-GEN-2 clause 1 requires them, and a conditional format would make column alignment unstable.

### 8.2 Constrained monetary display in bento tiles

`₱1,250,000.00` is fourteen characters and does not fit a half-width bento tile at a readable size on a small phone. This is resolved by REQ-GEN-2A, the adopted constrained-display amendment. The constrained form is permitted **only** inside dashboard bento tiles:

| Range | Constrained form | Full form |
|---|---|---|
| < ₱1,000,000 | `₱350,000` (centavos dropped) | `₱350,000.00` |
| ≥ ₱1,000,000 | `₱1.25M` | `₱1,250,000.00` |

Rules, per REQ-GEN-2A:

1. Permitted **only** in dashboard bento tiles. Ledger rows, editors, totals, previews, and the change log keep the full two-decimal form.
2. The full form is always in the accessibility label, so a screen reader never hears `₱1.25M` (section 9.3).
3. Tapping any constrained figure reveals the full form.
4. Truncation is toward zero, so a tile never overstates: `₱1,259,000.00` displays as `₱1.25M`, and `₱350,999.99` displays as `₱350,999`. A tile never claims more money than exists.

Implementation note: this behaviour lives entirely in the `MoneyDisplay` presenter (section 10), which is the single chokepoint between `int` centavos and rendered text. No screen formats money itself, so the constrained form structurally cannot leak outside a tile.

### 8.3 Negative and over-budget presentation

- Negative: minus inside the format, `−₱1,200.00`, per REQ-GEN-2 clause 4. Never parentheses — accounting convention is unfamiliar to this audience.
- Over-budget variance and negative buffer are marked with **an icon plus a text label plus the sign**, never colour alone (REQ-LG-3 clause 5, REQ-LG-6 clause 4, REQ-AE-6 clause 5).
- Text labels: `Over by ₱12,400.00` and `Under by ₱3,000.00`. Not `+₱12,400.00`, since a plus sign next to a wedding cost is ambiguous about whether more is good.
- Variance percent: one decimal (REQ-LG-6 clause 2). Suppressed, not zero-divided, when allocation is zero (clause 3).

### 8.4 Language

**English UI with Filipino domain terms kept untranslated.**

Never translated, and never glossed in body copy: **Ninong**, **Ninang**, **OOT**, **corkage**, **lechon**, **HMUA**, **entourage**, **pakimkim** if introduced later.

Justification: these are the words the audience uses when planning. "Principal sponsor (male)" is technically accurate and reads as a translation of their own life. Filipino couples searching for corkage policies use the word corkage. Substituting a Western equivalent would recreate the localisation failure the problem brief identifies in generic Western apps.

Rules:

- Chrome, labels, buttons, and system copy: English.
- Domain nouns: Filipino as listed, unglossed in body copy.
- One-time explanation permitted on first encounter — OOT expands to "out-of-town" once on the SCR-05 card, never again.
- No Tagalog verbs or sentence structure in chrome. This is not Taglish prose, it is English with correct domain vocabulary.

**Strings are externalised from the first commit.** Not because v1 ships another language, but because retrofitting extraction across every screen after the fact is a large mechanical change that always gets deferred. Externalising now costs almost nothing. Domain terms sit in a separate do-not-translate set so a future translator cannot helpfully turn Ninong into Godfather.

### 8.5 Dates

**Abbreviated month, never all-numeric:** `13 Sep 2026`.

Justification: the Philippines sees both `MM/DD/YYYY` from US influence and `DD/MM/YYYY` from other conventions, so `09/13/2026` versus `13/09/2026` is genuinely ambiguous — and a misread wedding date or supplier due date has real consequences. An abbreviated month removes the ambiguity at the cost of two characters.

- Full: `13 Sep 2026`. With weekday where useful: `Sun, 13 Sep 2026`.
- Countdown: `284 days to go`. Past date: `12 days ago` (REQ-BS-3 clause 2 permits past dates).
- Relative under 7 days in the change log, then absolute (section 6.2).
- Due dates always absolute. `in 3 days` is not acceptable for a payment deadline.

---

## 9. Accessibility baseline

Stated to satisfy both platform floors. The platform is Flutter (section 0), which implements the accessibility APIs of both underlying systems, so these rules map to Flutter's `Semantics` and text-scaling support.

### 9.1 Touch targets

**Minimum 48 × 48 density-independent pixels** for every interactive element, taking Android's 48dp floor rather than iOS's 44pt so one rule satisfies both.

- Applies to component-level tap targets, not visual size: an icon may render at 24 but its target is 48.
- Adjacent targets carry at least 8dp separation. Relevant to `fee_components` row delete controls and the RSVP × tier matrix on SCR-12, where mis-taps are costly.
- Tappable money figures per section 8.2 condition 3 meet the same floor.

### 9.2 Dynamic type and numeric overflow

Text scales with the OS setting on all screens. Overflow in a bento tile follows a fixed escalation:

1. **Shrink** the figure to a floor of 80% of its nominal size. No further.
2. **Drop centavos** per the constrained form of REQ-GEN-2A (section 8.2).
3. **Abbreviate** to `₱1.25M` per REQ-GEN-2A, for values at or above ₱1M.
4. **Grow the tile vertically.** The bento reflows; the figure never shrinks below the floor and is never clipped.
5. **At the largest accessibility sizes, the bento collapses to a single-column stack.** Two-column tiles cannot hold a scaled seven-figure number at any legible size.

Rules: a monetary figure is **never** truncated with an ellipsis — `₱1,250,...` is unreadable and potentially misleading. A figure is never clipped by a fixed-height container. Labels may wrap; figures may not.

Tile I (AI placeholder) keeps its fixed 1-unit height at all type sizes, since it renders nothing.

### 9.3 Screen reader labels for numeric tiles

Every numeric tile carries an explicit label. The visual figure alone is insufficient, and constrained forms must never be spoken.

| Tile | Spoken label |
|---|---|
| A | "Gross event total, 350,000 pesos, out of a 350,000 peso budget" |
| B | "Net out of pocket, 300,000 pesos. Potential relief from tentative pledges, 50,000 pesos" |
| C | "Budget health. 5 of 6 checks passing. Budget adequacy not available" |
| D | "Buffer remaining, 58,000 pesos, 82 percent of buffer" |
| E | "Outstanding pledge exposure, 50,000 pesos" |
| F row | "Catering and venue. Allocated 140,000 pesos. Spent 152,400 pesos. Over by 12,400 pesos" |
| G | "Driving guest count, 150 confirmed guests. 40 tier 1, 110 tier 2" |
| H | "2 hidden fees not answered: overtime, venue power" |
| I | Excluded from the accessibility tree |

Rules:

- Always the **full** value, never `1.25M` (section 8.2 condition 2).
- Speak "pesos" as a word; `₱` is unreliably announced across screen readers.
- Never announce a bare number without its meaning.
- Status conveyed by icon or colour must appear in the label as words: "Over by", "Overdue", "Not answered".
- Sync badge: "Offline, 12 changes waiting to sync" — matching section 7 copy, not an icon description.
- Reading order follows the source order in section 4.1.

### 9.4 Contrast

**WCAG 2.2 Level AA** as the floor:

- Body text and figures: **4.5:1** minimum against background.
- Large text, at or above 18pt regular / 14pt bold: **3:1**.
- Interactive component boundaries, focus indicators, icons carrying meaning: **3:1**.
- Applies to every state including disabled figures in read-only mode after partner removal, which must remain legible.

**Colour is never the sole carrier of meaning** anywhere — required by REQ-LG-3 clause 5, REQ-LG-6 clause 4, and REQ-AE-6 clause 5. Every over-budget, overdue, breach, over-cap, and unanswered-fee signal pairs an icon and a text label with any colour treatment.

Full WCAG conformance cannot be asserted from a specification. It needs manual testing with real screen readers and expert accessibility review before any conformance claim is made.

---

## 10. Component inventory

Names, inputs, and states only.

| Component | Inputs | States | Used on |
|---|---|---|---|
| `MoneyField` | value in centavos, label, required, min, max, allowNegative | empty, focused, valid, invalid, over-limit warning, read-only | SCR-03, 08, 09, 10, 15 |
| `MoneyDisplay` | centavos, size variant, constrained mode, tappable | standard, constrained, negative, zero, unavailable | Everywhere |
| `CategoryPicker` | selected code, taxonomy, suggestion order | unselected, selected, invalid, read-only | SCR-08, 15 |
| `PricingModeToggle` | mode, perHeadRate | flat, per-head, per-head-missing-rate, manually-valued-locked, read-only | SCR-08 |
| `SyncBadge` | connection state, pending count, oldest age, failure flag | synced, offline, offline-with-pending, stale, sync-problem, needs-attention | Header of SCR-06–19 |
| `AttributionStamp` | actor, timestamp, isCurrentUser, superseded | own, partner, superseded, pending-push | SCR-07–16 |
| `BentoTile` | span, height unit, label, content, a11yLabel, tappable | populated, zero-value, unavailable, inert | SCR-06 |
| `BudgetHealthCheck` | condition id, met, governing value, reqRef | met, not-met, unavailable | SCR-06 tile C |
| `VarianceIndicator` | allocated, effective, showPercent | under, over, exact, percent-suppressed | SCR-06 tile F, SCR-07, SCR-10 |
| `FeeComponentRow` | componentType, label, quantity, unitRate, amount | quantity-rate mode, amount mode, incomplete, read-only | SCR-09 |
| `FeePromptCard` | feeType, state, total, dismissedBy, dismissedAt | prompted-unfilled, filled, dismissed, region-defaulted | SCR-05, SCR-06 tile H |
| `PledgeStatusControl` | status, value | tentative, confirmed, received, read-only | SCR-14, 15 |
| `GrossNetPair` | gross, net, potentialRelief | equal, net-reduced, zero-state | SCR-06 tiles A/B, SCR-14 |
| `RsvpTierMatrix` | counts by status and tier, drivingStatus | populated, empty, driving-highlighted | SCR-12 |
| `CrewHeadcountBlock` | headcount | zero, populated, read-only | SCR-12, SCR-09 crew variant |
| `WhatIfComparison` | before, after, affectedCategories, excludedItems | neutral, increase, decrease, over-cap | SCR-13 |
| `TierCutList` | targetCount, tier1Count, tier2Count | within-tier-2, exceeds-tier-2, not-a-reduction | SCR-13 |
| `ExplainSheet` | explanation payload, allocatorKind, rulesetVersion | rule-based, unavailable | SCR-11 |
| `OverrideRow` | engineCents, overrideCents, categoryCode | engine-value, overridden, over-allocated, read-only | SCR-10 |
| `BufferGauge` | allocation, overrun, remaining | healthy, breached, full | SCR-06 tile D, SCR-10 |
| `ChangeLogEntry` | actor, action, entity, field, oldValue, newValue, hlc, superseded, pendingPush | applied, superseded, pending-push, lifecycle | SCR-16, per-entity history |
| `ConflictBanner` | field, winningValue, losingValue, actor | single-conflict, multiple-conflicts, dismissed | SCR-06, SCR-19 |
| `ReadOnlyNotice` | reason | partner-removed, plan-deleted | All SCR-06–19 |
| `StepIndicator` | current, total, blockedReason | in-progress, blocked, complete | SCR-03, 04, 05 |
| `DateField` | value, allowPast | empty, valid, past-confirmed, invalid | SCR-03, 08 |
| `RegionPicker` | selected, taxonomy grouped by tier | unselected, selected, destination-selected | SCR-04, 18 |
| `TwoPartyConfirmation` | action, initiator, confirmedBy, expiresAt | awaiting-you, awaiting-partner, expired, complete | SCR-17 |

---

## 11. Open items this spec surfaced

Ordered by blocking severity.

1. **★ Budget health graded bands — deliberately not invented.** Section 4.3. The card currently states six facts. A graded verdict needs caution thresholds, weighting, and severity ranking defined upstream first.
2. **Reference cost values.** Budget adequacy renders as unavailable until `reference_costs` is populated. Already tracked as requirements.md 13.1; noted because it is now visible in the UI.
3. **Two-party confirmation expiry duration.** SCR-17 cannot show a countdown for an undefined window (requirements.md 13.4).
4. **Notes character-limit feedback.** REQ-LG-1 clause 8 sets a 2,000-character bound without specifying counter or truncation behaviour.
5. **Removed partner's local data retention.** Section 3.3 keeps it readable. Whether it is eventually purged is a privacy decision.
6. **`decision-log.md`.** Referenced as an input, absent from the repository. Section 0.

*Resolved since first draft: platform (Flutter + SQLite/`drift`), the REQ-GEN-2A constrained-display amendment (section 8.2), and ruleset configuration management (bundled JSON asset validated at app load — REQ-AE-1 clause 4 is now a load-time check, not an authoring screen).*
