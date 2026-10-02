# Kasaran — UX Specification

*Inputs: [decision-log.md](./decision-log.md), [requirements.md](./requirements.md), [design.md](./design.md), [mvp-user-stories.md](./mvp-user-stories.md). No visual mockups, no palettes, no code.*

## 0. Inputs and upstream gaps

**`docs/decision-log.md` exists and is the decision authority.** Read it alongside requirements.md and design.md: ADR-15 fixes the bundled ruleset, ADR-16 fixes Supabase, ADR-17 fixes local encryption, ADR-21 (D1) fixes server-assigned sync ordering, and ADR-23/24 fix removal semantics. Open questions there remain open; this spec does not silently resolve them.

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
| SCR-04 | Setup: Guest Cap, Region & Types | Capture required cap/region and optional ceremony/venue hints | SCR-03 next | REQ-BS-1, REQ-BS-4, REQ-BS-5, REQ-HF-1 |
| SCR-05 | Setup: Hidden-Fee Prompts | Force a decision on all six fees; gate completion | SCR-04 next | REQ-HF-1, REQ-HF-2, REQ-HF-3 |
| SCR-06 | Dashboard | Bento overview plus due-soon list and post-gift figure | Post-setup default tab | REQ-PL-2, REQ-PL-3, REQ-PL-4, REQ-AE-6, REQ-AE-2 (3), REQ-BS-5 (2), REQ-HF-1 (5), REQ-LG-5, REQ-LG-6, REQ-LG-9, REQ-GF-1, REQ-OF-3 |
| SCR-07 | Ledger List | Browse/filter costs and due-soon schedule items | Ledger tab; dashboard due-soon/category tap | REQ-LG-1…9 |
| SCR-08 | Expense Editor | Create/edit entry and its schedule/payment/refund history | SCR-07 add or row tap | REQ-LG-1…8, REQ-GM-2, REQ-PL-7 |
| SCR-09 | Hidden-Fee Editor | Create/edit one of six typed fee entries | SCR-05, SCR-07, dashboard outstanding-fee chip | REQ-HF-1, REQ-HF-2, REQ-HF-3, REQ-GM-4 |
| SCR-10 | Allocations & Overrides | Review engine allocations; override; revert | Dashboard category breakdown; SCR-18 | REQ-AE-1, REQ-AE-4, REQ-AE-5, REQ-AE-6 |
| SCR-11 | Explain Figure | Show rule, inputs, modifier behind any engine number | Tap any engine-derived figure | REQ-AE-4, REQ-AE-2 (1) |
| SCR-12 | Guests List | Manage guests across RSVP status and priority tier | Guests tab | REQ-GM-1, REQ-GM-4 |
| SCR-13 | Guest What-If | Model a headcount change before committing | SCR-12 action; dashboard guest tile | REQ-GM-2, REQ-GM-3, REQ-GM-5, REQ-BS-5 (2) |
| SCR-14 | Pledges List | Track remaining sponsor support, partial receipts, withdrawn history | Pledges tab; dashboard net tile | REQ-PL-1…7 |
| SCR-15 | Pledge Editor | Create/edit pledge; record receipts and direct supplier payments; withdraw | SCR-14 add or row tap | REQ-PL-1…7, REQ-LG-8 |
| SCR-16 | Change Log / Activity | Plan-wide and per-entity history with attribution | More tab; per-entity history affordance | REQ-SE-2 (5), REQ-SE-3, REQ-SE-4, REQ-OF-5 (4) |
| SCR-17 | Shared Access | Partner status, invite, mutual defensive removal, ownership, delete plan | More tab | REQ-SE-1, REQ-SE-5, REQ-SE-6, REQ-PLT-3 |
| SCR-18 | Plan Settings | Edit setup inputs, RSVP, ruleset and local due-date reminders | More tab | REQ-BS-1, REQ-BS-2, REQ-BS-6, REQ-GM-1 (6), REQ-AE-3, REQ-LG-9, REQ-PLT-3 |
| SCR-19 | Sync Detail | Pending-write queue, last sync, failure detail, retry | Tap sync badge anywhere | REQ-OF-3, REQ-OF-5, REQ-SE-3 |
| SCR-20 | Post-Wedding Reconciliation | Record cash gifts and compare gifts to remaining supplier balances | More tab; dashboard gifts action; Pledges tab | REQ-GF-1, REQ-GF-2, REQ-LG-4, REQ-PL-7 |

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

Ruleset asset validation (REQ-AE-1 clause 4) is correctly non-UI: baselines sum to 10000 bp at app load; there is no v1 authoring screen (ADR-15).

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
**Actions:** Accept → write `plan_members`, then full replay pull from `since_server_ts = 0` (design.md 2.5) → SCR-06. Decline → SCR-01.
**States of note:** expired, revoked, already accepted — each names the reason (REQ-SE-1 clause 5).
**Expiry copy:** the invite expires exactly 7 days after issuance; the expired state says so and does not offer acceptance (REQ-SE-1 clauses 4, 5).
**Nav in:** deep link. **Nav out:** SCR-06, SCR-01.

### SCR-03 Setup: Budget & Date
**Regions:** step indicator (1 of 3); total budget field; wedding date field; validation slot; next.
**Fields:** `plans.total_budget_cents`, `plans.wedding_date`.
**Actions:** Next → validate REQ-BS-2 (reject non-numeric, zero, negative; retain other fields) → SCR-04. Past date → confirm dialog per REQ-BS-3, savable on confirmation.
**Notably absent:** no block on budgets under ₱30,000 or over ₱500,000 (REQ-BS-1 clause 3).
**Nav in:** post sign-up; SCR-18. **Nav out:** SCR-04.

### SCR-04 Setup: Guest Cap, Region & Types
**Regions:** step indicator (2 of 3); guest cap; region grouped by cost tier; optional ceremony and venue pickers, each including “Not sure yet”; tier note; next/back.
**Fields:** `plans.guest_cap`, `plans.region_code` → `regions`, `cost_tiers`; nullable `plans.ceremony_type` and `plans.venue_type` (null = Not sure yet). Ceremony choices: church, civil, other religious, garden/beach officiant, other. Venue choices: hotel, garden, beach/resort, restaurant, events place, other.
**Actions:** Next → allocation runs (REQ-AE-1) → SCR-05, even if both optional types remain unset. Region selection writes no ledger entry (REQ-BS-4 clause 5) and sets OOT default when `is_destination` (REQ-HF-3). Types change only contextual fee-card hint text (e.g. civil: “Church aircon usually doesn't apply”; garden/beach: “Venue power is often needed”), never amounts, fee state, or whether the partner must decide on all six (REQ-HF-1).
**Copy:** tier note reads *"Destination weddings usually carry supplier travel costs. We'll ask about that next."* It states the consequence without asserting an amount.
**Nav in:** SCR-03. **Nav out:** SCR-05, back to SCR-03.

### SCR-05 Setup: Hidden-Fee Prompts
**Regions:** step indicator (3 of 3); six fee cards each showing state badge; per-card fill/dismiss; blocked-completion slot; finish.
**Fields:** `hidden_fee_prompts.state` per fee type; totals from `ledger_entries` + `fee_components`; hint copy from optional ceremony/venue type, never a pre-filled amount.
**Actions:** Fill → SCR-09 for that type. Dismiss → records `dismissed_at`, `dismissed_by` (REQ-HF-1 clause 4). Finish → blocked while any card is `prompted_unfilled`, naming each untouched card (REQ-HF-1 clause 6).
**Critical distinction:** `prompted_unfilled` renders as *"Not answered yet"*, never as ₱0.00 (REQ-HF-1 clause 2). A dismissed card renders *"Not applicable"* and contributes exactly 0 (clause 7).
**Nav in:** SCR-04. **Nav out:** SCR-06 on finish; SCR-09 per card.

### SCR-06 Dashboard
Fully specified in section 4.

### SCR-07 Ledger List
**Regions:** header with gross total; Due soon list of outstanding dated schedule items (within the plan's configured window, 7 days by default, plus separate overdue items); filter bar (category, derived entry/item status, entry type); grouped entries; add FAB; sync badge.
**Fields per row:** supplier, category, effective amount, derived net paid (`Σ payments − Σ refunds`), balance due (`max(0, effective − net paid)`), entry status (`paid` / `pending` / `due soon` / `overdue`) with independent partial indicator, next unpaid scheduled due date or “Undated balance”, per-head/flat marker, actual/estimate difference. Due-soon rows show item label, full amount remaining and absolute date. A virtual undated balance never appears as overdue or in Due soon (REQ-LG-5/7).
**Actions:** due-soon or entry tap → SCR-08 or SCR-09 by `entry_type`; filter; add → type chooser; swipe delete → confirm (REQ-LG-2 clause 3), removes from totals immediately (clause 4) while retaining linked history for reconciliation (REQ-PL-7).
**Nav in:** Ledger tab; dashboard category tap. **Nav out:** SCR-08, SCR-09, SCR-16 per-entity history.

### SCR-08 Expense Editor
**Regions:** supplier; category picker; pricing mode; estimated/actual price; schedule list; payment/refund history; notes; history link; save/delete. The same schedule/payment sections are available on a hidden-fee entry via SCR-09.
**Fields:** `ledger_entries` core per REQ-LG-1; schedule item kind (reservation/downpayment/installment/balance/custom), label, amount, due date and order; payment/refund amount > 0, paid-on date, method (cash/bank transfer/GCash/Maya/check/other), optional schedule-item attribution, optional note and sponsor attribution. A payment method **records** what happened; saving cannot transfer money. Unattributed payment is from the couple; sponsor direct payment is initiated from SCR-15 and writes its matching receipt in the same local transaction.
**Derived, read-only in-form:** effective amount, `Σ payment − Σ refund`, balance due and overpayment warning, each item's allocated/remaining amount and paid/partial/due-soon/overdue state, entry paid/pending/due-soon/overdue status. No schedule → one virtual undated balance; explicit schedule below effective → a virtual undated residual. An edit that makes the schedule sum exceed effective is refused with a schedule-over-total validation error; payment history is preserved. Dated items allocate net paid by due date, sort order and ID, virtual residual last; optional `schedule_item_id` labels attribution only, **never** changes allocation order. Refund can reopen an item; all statuses recalculate locally.
**Actions:** add/edit/remove independent schedule rows and payment/refund events with confirmation before tombstoning; show payment history and sponsor/receipt link; toggle per-head requires rate; actual on per-head sets `manually_valued` (REQ-GM-2). Discounted actual lowers effective cost subject to schedule validation; payment over effective is stored, warned and not clamped. Notes show live `n / 2,000`; stop input at limit (REQ-LG-1 clause 8). Two offline partners add distinct UUID events, never edit a cumulative deposit field (ADR-21, REQ-LG-8).
**Nav in:** SCR-07. **Nav out:** SCR-07, SCR-16.

### SCR-09 Hidden-Fee Editor
Six typed variants sharing one shell. Per-type field differences in section 5.1.
**Regions:** type header; read-only allocation-category label; component list (repeatable rows where applicable); running total; guest-scaling note for crew meals; save/dismiss.
**Fields:** `ledger_entries` header plus `fee_components` rows and the same independent schedule/payment sections as SCR-08. Category is one of the six allocation categories, **not** the fee subtype: crew meals, church aircon, corkage, venue power → Catering & Venue; OOT fees and overtime → Coordination (REQ-HF-2 clause 9; design.md §4.4). SCR-09 displays that category read-only; the fee remains a separate attributable ledger entry.
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
**Actions:** add guest → defaults `tier_2` (REQ-GM-1 clause 3); the guest's RSVP is set explicitly, never silently confirmed (clause 4). The plan's **driving RSVP status** defaults to `invited` for per-head calculations, visibly indicated here and editable on SCR-18 (REQ-GM-1 clause 6). Edit either guest axis independently (clause 5). Crew headcount edited in its own block, visually separated (clause 10, REQ-GM-4 clause 3). What-if → SCR-13.
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
**Regions:** gross/net pair; expected remaining figure; confirmed outstanding exposure and contributor list; pledges grouped tentative/confirmed/partially received/received/withdrawn; gifts and reconciliation link; add.
**Fields:** `pledges.*` and receipt aggregates; **net** = gross − eligible *actual receipts* (including partial and historical receipts on a withdrawn pledge); all item pledges linked to the same live entry share its effective-amount cap, applied by receipt date/UUID order; **expected remaining** = Σ max(0, value − receipts) for tentative/confirmed; **exposure** = same remainder for confirmed only. Withdrawn pledges have no remaining expectation/exposure; item support for a deleted linked entry is orphaned and excluded from live net (ADR-37–39).
**Actions:** row → SCR-15; withdraw with explicit confirmation; tap net → receipt-by-receipt breakdown that sums exactly to gross − net; gifts/reconciliation → SCR-20. A cash gift is never a pledge receipt.
**Displays:** exposure `₱0.00` when none. Label expected amounts as promised *but not yet received*. Show partial progress as “received X of Y”, explicitly mark withdrawn history and orphan support rather than making them vanish. Net can be negative, without a zero floor.
**Nav in:** Pledges tab; dashboard net tile. **Nav out:** SCR-15, SCR-20.

### SCR-15 Pledge Editor
**Regions:** sponsor name; role picker plus candle/veil/cord sub-role for secondary sponsor; cash/item toggle and item description; value; tentative/confirmed/withdrawn state; category/entry link; receipt history and add-receipt/direct-payment action; save/delete.
**Fields:** `pledges` and independent `pledge_receipts` rows (`amount_cents > 0`, `received_on`, note; optional unique `payment_id`). A cash receipt has no payment link. `received` is read-only and derived only once **at least one** live receipt exists and its total reaches value; it is **not** a manual state toggle (ADR-37). A zero-value pledge with no receipt remains tentative/confirmed. Withdrawal is explicitly editable and does not erase past receipts (ADR-38). If both links are set, entry takes precedence; a deleted linked entry leaves orphan history and removes item support from live net (ADR-39).
**Actions:** adding a partial receipt decreases net only by eligible applied support and decreases expected remaining/exposure by the recorded receipt amount; confirming a promise without receipt leaves net unchanged. A direct supplier payment requires a linked live entry and captures method, date and amount; save creates a payment with `paid_by_pledge_id` and an equal receipt with unique `payment_id` atomically in the offline local store, one receipt per payment. This reduces both net and supplier balance **once**, not twice; the UI shows both linked records. All in-kind pledges for the linked entry share its effective-amount cap; gross does not change. Withdraw with confirmation removes remaining expected/exposure but keeps historical received support in net; even a fully received pledge may be explicitly withdrawn, but withdrawal does not replace a receipt correction/refund (ADR-38). Monetary row correction tombstones the old row and inserts a new event, retaining attributed history.
**Copy:** role picker uses **Ninong** and **Ninang** untranslated (section 8.4).
**Nav in:** SCR-14. **Nav out:** SCR-14.

### SCR-16 Change Log / Activity
Specified in section 6.

### SCR-17 Shared Access
**Regions:** partner slot with role; invite block; remove-partner action; ownership-transfer block (with pending-confirmation sub-state); delete plan (creator only); active-plan note.
**Fields:** `plan_members.role`, `invites.expires_at`, `lifecycle_confirmations.*` (ownership transfer only), `plans.is_active`.
**Actions:** invite → link expiring exactly 7 days after issuance (REQ-SE-1 clauses 4, 5); revoke invite. **Remove partner → mutual and one-sided: either partner may remove the other, no confirmation from the removed party, effective on their next sync (REQ-SE-6). Requires a typed/deliberate confirmation from the acting partner only, to prevent an accidental tap, and is logged and attributed (REQ-SE-4).** Transfer ownership → opens two-party confirmation, expiring after 7 days if not completed; both partners retain full access while pending (REQ-SE-5 clauses 4, 6, 7) — this is the only two-party action. Delete plan → creator only; non-creator sees the action absent and, if reached, a refusal naming creator-only (REQ-SE-5 clauses 1, 2); requires typed confirmation (clause 3).
**Stated on screen:** removing a partner cannot be undone by the removed person and does not delete their existing local copy — server access simply stops (REQ-SE-6 clauses 5, 6). Data access stays fully symmetric; only lifecycle actions are governed here (REQ-SE-5 clause 9). Without this the removal reads as either reversible or a general permission tier.
**Nav in:** More tab. **Nav out:** SCR-16 for lifecycle history (REQ-SE-5 clause 8, REQ-SE-6 clause 4).

### SCR-18 Plan Settings
**Regions:** setup inputs (budget, date, guest cap, region, optional ceremony/venue types); driving RSVP status picker (default `invited`); ruleset version block; **Due-date reminders** section with on/off, independent Due soon window (default 7 days), notification before-due offsets (defaults 7 and 1 days), overdue toggle and OS notification-permission explanation.
**Actions:** any setup edit → preview before applying when more than one category shifts (REQ-BS-6 clause 3); cancel persists nothing (clause 4); applied edits log (clause 5). Ruleset opt-in → before/after preview, overrides preserved (REQ-AE-3 clauses 3, 4). Reminder edits sync plan-level preferences, reschedule this device's live unpaid dated items immediately even offline; permission denial and off switch leave financial records untouched and no reminder delivered. **Off does not hide Due soon** (the configured window still drives it). Do not include names or amounts in lock-screen text; “A supplier payment is due in 7 days” is the default. No partner-edit push.
**Stated on screen:** editing setup destroys no entries, pledges, guests, or overrides (REQ-BS-6 clauses 1, 2). Users expect budget changes to wipe work; saying otherwise prevents avoidable fear.
**Nav in:** More tab. **Nav out:** SCR-03/04 field editors, SCR-10.

### SCR-19 Sync Detail
**Regions:** connection state; pending-write count and list; last successful sync; failure detail; manual retry.
**Fields:** `sync_state.last_pushed_server_ts`, `last_pulled_server_ts`; local queue depth.
**Actions:** retry. Replay is automatic and requires no action here (REQ-OF-5 clauses 1, 2) — the button exists for reassurance, and the screen says so.
**Nav in:** sync badge, any screen. **Nav out:** dismiss.

### SCR-20 Post-Wedding Reconciliation
**Regions:** gifts received list with add/inspect/tombstone; gifts total; gross/net pair; net after gifts; remaining supplier balances; signed gift-versus-balance difference; orphaned in-kind support needing review.
**Fields:** each `gifts_received` event has source (sobre / money dance / cash / bank transfer / other), amount > 0, received-on date, optional giver name and note. The giver name is third-party personal data, so keep it optional and never put it in notifications. Derived gifts total = Σ live gifts; net after gifts = net out-of-pocket − gifts total **only when at least one gift exists**; balance total = Σ live entry balances; signed difference = gifts total − balance total (REQ-GF-1/2). Net remains the eligible-receipt-only figure of REQ-PL-2 (partial receipts included), never silently reduced by gifts.
**Actions:** add, inspect, or soft-delete gift events offline with distinct UUIDs and change-log attribution; an amount correction tombstones the old row and inserts a replacement UUID event, never overwrites a cumulative total. Tap a gift/remaining-balance/orphan row for detail; link to SCR-08 to record an actual supplier payment. Recording gifts never pays a supplier automatically. Review an item pledge linked to a deleted entry without folding its receipt into live net; preserve the payment/receipt history for correction.
**Nav in:** More tab, SCR-06 post-gift action, SCR-14. **Nav out:** SCR-08, SCR-14, SCR-16.

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
| SCR-04 | Default cap/region; both optional types “Not sure yet” | Pre-filled from SCR-18 | N/A | Badge only; hints local | Badge only | Changed type attributed | N/A | Invalid required cap/region; optional unset never blocks |
| SCR-05 | All six `prompted_unfilled`; contextual hints only | Mixed filled/dismissed; hints may change | N/A | Badge only | Badge only | Hint/type edits do not change fee states | N/A | Finish blocked while any untouched regardless of type (REQ-HF-1 clause 6) |
| SCR-06 | Zero entries/pledges/gifts, no due soon — see 4.4 | Bento + due soon + net after gifts only after gifts exist | N/A — local read, see §3.1 | Badge; all tiles/lists computed locally | Badge; figures unaffected | Banner naming affected figure, link SCR-16 | Read-only; local data retained | Breach, overdue scheduled item, orphan support — see 4.3 |
| SCR-07 | Empty with add and fee shortcut; due-soon empty | Grouped list and upcoming dated items | N/A | Badge; local rows fully usable | Badge | Row stamp; distinct UUID payments both visible | Read-only | Overdue/partial/refund-reopened, overpayment and schedule mismatch |
| SCR-08 | Blank entry; no schedule → virtual undated balance | Schedule and payment/refund history with derived allocations | N/A | Badge; distinct row writes available | Badge; queued events retained | Field stamp for changed row; concurrent new events both shown | Read-only | Required fields/rate, nonpositive item/payment, mismatched attribution, overpayment or schedule excess warning |
| SCR-09 | Typed blank components; virtual undated balance | Components plus schedule/payment history | N/A | Badge; save available | Badge | Component/payment-row stamps | Read-only | Component incomplete; schedule mismatch or payment over effective warned |
| SCR-10 | Allocations present immediately post-setup; never truly empty | Six rows with variance | N/A | Badge | Badge | Stamp on remotely overridden category | Read-only; override suppressed | Over-allocation (REQ-AE-5 clause 4); negative buffer remaining (REQ-AE-6 clause 5) |
| SCR-11 | N/A — only reachable from an existing figure | Explanation shown | N/A | Badge; explanation is local | Badge | N/A — explanation is derived, not user-written | Read-only, still viewable | Missing explanation payload → figure is not rendered upstream, so this screen is unreachable (REQ-AE-4 clause 4) |
| SCR-12 | Zero guests; crew block still shown | Matrix and list | N/A | Badge | Badge | Stamp on changed guest rows | Read-only; add suppressed | Driving count above guest cap (REQ-BS-5 clause 2) |
| SCR-13 | N/A — requires a plan; runs with zero guests and reports zero deltas | Before/after comparison | N/A | Badge; computes fully offline (REQ-OF-2 clause 2) | Badge; preview unaffected as it is local-only | **N/A — a preview is never synced (REQ-GM-5 clause 8), so no remote write can touch it** | Read-only; commit suppressed, preview still viewable | Over-cap with full calculation still returned (REQ-GM-5 clause 4) |
| SCR-14 | Zero pledges; gross = net, expected/exposure `₱0.00` | Partial/received/withdrawn groups with remaining exposure | N/A | Badge; receipts visible immediately | Badge | Receipt row additions both retained; status field winner attributed | Read-only | Orphan item support surfaced; negative net legitimate |
| SCR-15 | Blank form, zero receipts | Pledge plus receipt and direct-payment links | N/A | Badge; atomic direct-payment + receipt available | Badge; paired rows retained for retry | Separate receipt rows preserved; same-field status LWW attributed | Read-only | Missing sponsor/item detail, nonpositive receipt, invalid direct-payment link or unequal payment/receipt blocked |
| SCR-16 | Contains setup entries from the moment a plan exists; never empty | Full feed | Pagination on long histories | Badge; local entries listed as not-yet-synced | Badge | **This is where resolution surfaces** — see 6.4 | Read-only; history retained in full | N/A — log entries are facts, not calculations |
| SCR-17 | Solo: no partner, invite prompt | Partner present, with mutual remove action available to either partner | N/A | Badge; invite generation and ownership transfer blocked offline, but a queued removal is permitted and takes effect server-side on reconnect | Badge | N/A — membership does not flow through the log (design.md 2.5) | Terminal state for the removed partner: explains removal, offers local wipe and exit | Ownership-transfer confirmation expires after 7 days; defensive removal is immediate with no pending state |
| SCR-18 | Setup populated; reminder defaults on, 7-day Due soon, 7/1 delivery plus overdue | Edited preferences; permission status explained | N/A | Badge; reminders rescheduled locally | Badge; local schedule remains | Preference fields attributed; reschedule after sync | Read-only; no scheduling writes | Invalid budget, past date, invalid reminder offset/window; permission denied explained |
| SCR-19 | Zero pending, synced | Queue listed | Sync in progress | Primary purpose: queue depth and age | Primary purpose: failure detail and retry | Lists resolved conflicts with link to SCR-16 | Read-only; sync halted, reason stated | N/A |
| SCR-20 | No gifts: `₱0.00` gifts, actual supplier balances still shown; no net-after-gifts tile; invitation to add | Gifts, signed comparison, balances and orphan list | N/A — local read | Badge; add gift and reconcile offline | Badge; all local totals still visible | Both new UUID gift rows retained, attributed | Read-only history, no add/edit | Negative difference/net valid; orphan item support flagged, never silently counted |

### 3.3 Partner-removed state, stated precisely

REQ-SE-6 governs defensive removal (mutual and one-sided; either partner may remove the other without consent, per Decisions 1 and 2). The removed partner's experience: **the removed partner retains local data in read-only form and is told plainly.**

Reason: their device holds a legitimate local database. Wiping it silently would look like data loss and would contradict the offline guarantee they have been trained to rely on. Sync stops, writes are refused (REQ-SE-6 clauses 3, 6), and the reason is stated once, clearly, at the top of every screen. Because removal is mutual, this same state can be reached by either partner regardless of who created the plan. **The removed-state screen SHALL offer a voluntary local wipe on this device**, with a deliberate confirmation; it SHALL NOT claim to remove copies on other or offline devices (REQ-SE-6 clauses 5, 7; OQ-03 leaves force-wipe open, with the current plan using an offer).

Copy: *"You no longer have access to this wedding plan. You can still view your copy, but changes won't be saved or synced."*

Automatic or enforceable remote purging remains unresolved (OQ-03); this voluntary local wipe does not resolve that question.

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
│ J  DUE SOON  upcoming dated payment items   │  full width, list
├─────────────────────────────────────────────┤
│ K  NET AFTER GIFTS  → SCR-20                 │  full width; only once gifts exist
├─────────────────────────────────────────────┤
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
| B | Net out-of-pocket | Derived: gross − eligible *recorded receipts*, including partial and historically received amounts on withdrawn pledges. Live linked in-kind support capped at entry effective amount; orphaned item support excluded. Promises and gifts do NOT reduce this figure (ADR-22, ADR-37–39). |
| B | Expected remaining pledge support | Derived: Σ `max(0, value − receipts)` for tentative/confirmed pledges only; label as unrealized support, never merge with net (REQ-PL-3). |
| C | Budget health | Six defined conditions in §4.3; five can be evaluated, budget adequacy is unavailable pending benchmarks. On the first-run dashboard, the four checks that pass are budget breach, over-allocation, over guest cap, and overdue payments; hidden fees pass too after SCR-05 completes. |
| D | Buffer remaining | Derived per REQ-AE-6 clauses 1, 2; pesos and percent of original (clause 4) |
| E | Outstanding exposure | Derived: Σ remaining (`max(0, value − receipts)`) for confirmed, non-withdrawn pledges (REQ-PL-4) |
| F | Per-category allocated / effective / variance | `plan_allocations` + derived variance (REQ-LG-6 clauses 1, 2) |
| G | Driving guest count and tier split | `guests` filtered by `plans.driving_rsvp_status` (REQ-GM-1 clauses 6, 8) |
| H | Unanswered fee count | `hidden_fee_prompts` where state = `prompted_unfilled` (REQ-HF-1 clause 5) |
| J | Due soon | Outstanding explicit schedule items due within the configured window (7 days by default), with full label, remaining amount and absolute date; overdue items shown separately. Tap → SCR-08/09; virtual undated balances absent, notification off does not hide list (REQ-LG-7/9). |
| K | Net after gifts | `net_out_of_pocket − Σ gifts_received.amount_cents`; appears only when at least one live gift exists and points to SCR-20. Does not replace tile B (REQ-GF-1/2). |
| I | Nothing | Section 4.5 |

### 4.3 Budget health card — exact inputs, and where I stop

**What is defined upstream.** Six conditions in requirements.md; five are evaluable in v1 and the sixth is unavailable until benchmark data exists. The card is a checklist of these and nothing more, with no aggregate score or invented health band.

| # | Condition | Exact threshold | REQ ID |
|---|---|---|---|
| 1 | Budget breach | `buffer_remaining < 0` | REQ-AE-6 clause 5 |
| 2 | Over-allocation | `Σ override_cents > total_budget_cents` | REQ-AE-5 clause 4 |
| 3 | Over guest cap | `driving_guest_count > guest_cap` | REQ-BS-5 clause 2 |
| 4 | Unanswered hidden fees | any `hidden_fee_prompts.state = 'prompted_unfilled'` | REQ-HF-1 clause 5 |
| 5 | Overdue payments | any live dated schedule item with outstanding allocated balance and `due_date < device-local today` | REQ-LG-5 clause 2, REQ-LG-7 |
| 6 | Budget adequacy shortfall | `total_budget_cents < expected_total_cost_cents` | REQ-AE-2 clause 3 |

Each computable condition renders as met or not met, with the governing number shown. All values come from the rule-based engine and derived calculations in design.md 1.4 and 5.2. No network, no model, no inference.

**Condition 6 cannot render in v1.** `reference_costs` is unpopulated (design.md 4.2; requirements.md 13.1), so `expected_total_cost` is not computable. It renders as **unavailable**, explicitly:

> *"Budget adequacy — not available yet. We don't have regional cost benchmarks for this area."*

It must not read as met or change the passing-check count. An unavailable check displayed as passing is worse than an absent one.

**Where I stop.** The card cannot present a *graded* health verdict, because nothing upstream defines the bands:

- No percentage thresholds for a caution tier — nothing states that buffer below some remaining share warrants a warning short of breach.
- No composite score or weighting across the six conditions.
- No severity ranking between them.
- No time-based risk thresholds relative to the wedding date.

Inventing any of these would put fabricated numbers in front of a couple making financial decisions, and would violate REQ-AE-4 clause 4, since a made-up band traces to no rule. **The card therefore states facts, not a verdict.** If a graded score is wanted, the bands must be defined upstream first; I have listed them as an open item in section 11.

### 4.4 First-run dashboard

In the empty-ledger case immediately post-setup (all fee prompts explicitly dismissed, rather than filled with costs), there are allocations but no spending. Every tile renders a real value, not an empty state:

- A: gross `₱0.00` against the budget — accurate, not empty
- B: net equals gross equals `₱0.00`
- C: checks 1 (budget breach), 2 (over-allocation), 3 (over guest cap), and 5 (overdue payments) pass because there are no entries or guests yet. Check 4 (unanswered hidden fees) also passes after the SCR-05 gate has required every prompt to be filled or dismissed; check 6 (adequacy) is unavailable, **not** passing. Five passing, one unavailable. With filled fee entries, recompute all checks from the actual totals.
- D: buffer remaining equals full buffer allocation, 100%
- E: `₱0.00` (REQ-PL-4 clause 3)
- F: six categories with allocated amounts, zero effective, full negative variance
- G: driving count derived from guests with the `invited` status by default; zero if no guests added yet
- H: count of unanswered fees, which is 0 immediately after the SCR-05 gate
- J: “No supplier payments due soon”; no virtual undated item is treated as a deadline
- K: absent until a live gift exists; tile B remains the full net figure

Only F and G carry a genuine call to action. There is no blank-slate dashboard state, because setup guarantees allocations exist.

### 4.5 AI insights placeholder (tile I)

- **Position:** last region, full width, below all v1 content including J and conditional K.
- **Dimensions:** fixed height of 1 layout unit — the same height as a compact tile such as H. It does not grow, does not scroll, and does not reflow when adjacent tiles change.
- **Renders in v1:** nothing. No text, no icon, no skeleton, no animation, no tap target.
- **Label:** the region is labelled in code and in the layout spec as `ai_insights_placeholder`. The label is not user-visible in v1.
- **Accessibility:** excluded from the accessibility tree in v1. An empty focusable region is a screen-reader dead end.
- **Purpose:** reserving the position so introducing REQ-AI-3 advisories later does not reflow the dashboard a couple has learned. Per design.md 6.3, advisories read from a separate `advisories` table outside the sync path, so this tile will never be a data dependency of any v1 figure.

A visible "AI coming soon" affordance is deliberately rejected: it advertises absent function and invites taps that do nothing.

---

## 5. Key flows

### 5.1 Adding a hidden-fee item — all six types differ

**They differ substantially.** Only church aircon is a single-amount form. Treating all six uniformly would defeat REQ-HF-2, which forbids reducing them to a generic amount field.

| Field | Crew meals | OOT fees | Church aircon | Corkage | Overtime | Venue power |
|---|---|---|---|---|---|---|
| Repeatable rows | Yes, per supplier | Yes, per supplier | **No — single row** | Yes, per item | Yes, per supplier | No — three fixed components |
| Row label | Supplier name | Supplier name | — | Item type picker: cake / wine / liquor / lechon / other | Supplier name | Generator / surcharge / electrical requirements |
| Quantity | Crew headcount | — | — | — | Projected hours | — |
| Unit rate | Per-meal rate | — | — | — | Hourly rate | — |
| Flat amount | — | **Three per supplier:** travel, lodging, per-diem | Single amount | Amount per item | — | Three separate amounts |
| Row total | `headcount × rate` | travel + lodging + per-diem | amount | amount | `hours × hourly rate` | generator + surcharge + electrical |
| Guest scaling | **Never** (REQ-GM-4) | Never | Never | Never | Never | Never |
| Pre-enabled by region | No | **Yes when `is_destination`** (including Bohol, REQ-HF-3) | No | No | No | No |
| Entity shape | `fee_components`: quantity + unit_rate | 3 components per supplier, amount only | 1 component, amount only | 1 component per item, amount only | quantity + unit_rate per supplier | 3 fixed components, amount only |

All six use the same SCR-09 shell, with subtype-specific inputs and a read-only allocation category label (design.md §4.4).

**Flow — crew meals** · REQ-HF-1, REQ-HF-2 (1, 7, 8), REQ-GM-4, REQ-SE-4

1. From SCR-05 or SCR-07, choose Crew meals. SCR-09 opens with one blank component row.
2. Enter supplier name, crew headcount, per-meal rate. Row total computes live as `headcount × rate`.
3. Add rows for remaining suppliers. Running total updates per row.
4. Note is persistently visible: crew meals do not change when guest count changes.
5. Save. `hidden_fee_prompts.state` → `filled`. One `change_log` row per changed field.
6. **End state:** entry appears in SCR-07 as its own attributable line; gross on SCR-06 increases by the entry total; the crew-meals chip disappears from tile H; a guest what-if leaves this total unchanged.

**Flow — OOT fees** · REQ-HF-1, REQ-HF-2 (2, 7), REQ-HF-3

1. If the region's `is_destination` flag is true (including Provincial-tier Bohol), the OOT card on SCR-05 is already enabled (REQ-HF-3 clause 1). No amount is pre-filled (clause 3).
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

**Flow — overtime** · REQ-HF-1, REQ-HF-2 (5, 7)

1. Open Overtime on SCR-05 or SCR-07. Add a row for each supplier with projected hours and hourly rate.
2. Each row and the running total compute `projected hours × hourly rate`; save marks the prompt filled.
3. **End state:** separate ledger line and per-supplier components appear; gross increases by their sum without changing when guest count changes.

**Flow — venue power** · REQ-HF-1, REQ-HF-2 (6, 7)

1. Open Venue power on SCR-05 or SCR-07. Enter separate generator, surcharge, and electrical-requirement amounts.
2. Running total sums all three; save marks the prompt filled.
3. **End state:** three components and one attributable ledger line appear; gross increases by their sum without guest scaling.

### 5.2 Pledge receipt, withdrawal and direct payment · REQ-PL-1…7, REQ-LG-8, REQ-SE-4

1. From SCR-14, add. SCR-15 captures sponsor name, role (including secondary sponsor with candle/veil/cord), cash or item, value, tentative/confirmed, and optional category/entry link. The entry link takes precedence if both are present.
2. **Tentative/confirmed with no receipt:** net unchanged (ADR-22); expected remaining includes the pledge value, and confirmed also adds that amount to exposure.
3. Add a partial receipt with positive amount and received-on date; its own UUID row appears in history. Net falls by eligible receipt-backed support, while expected remaining and confirmed exposure fall by the receipt amount, not the entire pledge face value. Another partner can independently record another receipt offline without overwriting the first.
4. **Fully received:** when at least one live receipt exists and their sum reaches/exceeds pledge value, SCR-15 displays `received` automatically; there is no editable Received status. Over-receipts remain visible and can drive negative net; for multiple item pledges linked to one live entry, applied support shares its effective-amount cap in receipt-date/UUID order.
5. **Direct-to-supplier item support:** choose a live linked entry and record amount/date/method; saving writes one `payments` row with `paid_by_pledge_id`, plus one equal `pledge_receipts` row with nullable-unique `payment_id` pointing at that payment, in one local offline transaction. The receipt lowers net; the payment lowers the supplier balance. Do not enter the same event as a second cash receipt. A supplier refund reverses payment coverage and requires correction of linked receipt support.
6. **Withdrawn:** explicit withdraw action removes only the *unreceived remainder* from expected/exposure, not historical received support from net; the pledge and receipts remain visible under Withdrawn. Deleting an entry linked to item support removes that support from live net and flags orphaned history on SCR-20 instead of moving it to the category.
7. **End state:** SCR-14 net breakdown sums actual eligible receipt-backed support; gift rows are excluded. SCR-08 shows payment and refund history, SCR-20 shows gifts separately. No step authorises or transfers funds.

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
3. B reconnects. The queued row pushes and the **server assigns its `server_ts` on acceptance** (Decision D1); B's device sequence (`device_monotonic`) is preserved but is not the ordering authority. Because A's write was accepted earlier, A's write carries the earlier `server_ts`.
4. Both devices order the two log rows by `(server_ts, device_monotonic, device_id)` and independently select the same winner. Under D1 **B's ₱62,000 wins**, because B's queued write was accepted later and has the later server timestamp, despite having been edited offline earlier (REQ-SE-2 clauses 3–5). Device time does not decide this.
5. Projections converge. Both devices show the same value, ₱62,000 (REQ-SE-3 clause 2).
6. **Neither write is discarded.** Both remain in `change_log`; the loser is superseded, computed at read time (design.md 4.6).
7. **A's device** shows a banner naming the field and B's winning value when it next syncs, linking to SCR-16. B's device does not show a losing-write banner.
8. SCR-16 shows both rows in clock order, the winner marked current and the loser marked superseded with its value intact and its author attributed.
9. **End state:** one visible current value on both devices; both attempts permanently recoverable in the change log; each attributed; the couple can see a disagreement happened and what the other person intended.

### 5.5 Scheduling a balance, refund and reminder · REQ-LG-4/5/7/8/9

1. Open SCR-08 (or SCR-09 for a hidden fee). Until a schedule is added, its effective amount appears as a **virtual undated balance**: payable, but neither overdue nor eligible for reminders.
2. Add reservation, downpayment and balance rows, each with its own amount, label and date. If their sum is below effective, show an extra virtual undated residual; if above, **refuse the edit** with a schedule-over-total validation error (including a discounted actual-price edit), without deleting existing payment history.
3. Record a positive payment, date and method. Optionally attribute it to a schedule item for history only; allocate net paid across items by due date, sort order and UUID regardless of attribution. No account is charged. Add another offline payment from a second device: both distinct UUID rows survive sync (ADR-21), with net paid derived from both.
4. Add a positive **refund** row, not a negative payment. Net paid falls; the balance and schedule-item coverage recompute. A fully paid item can reopen as partial or overdue. A discount on actual price lowers effective, not the payment history, subject to schedule validation.
5. SCR-06/07 show unpaid dated items due within the plan's configured window (7 days by default) in Due soon and past-date items as overdue. SCR-18 defaults local notification delivery to 7 days, 1 day and overdue, with a plan-level off switch; each device schedules from local data, cancels paid/deleted items and never sends partner-edit push. Turning delivery off does not hide Due soon. Default lock-screen copy contains neither supplier nor amount.
6. **End state:** entry `paid` only at zero remaining balance; `overdue` if any unpaid dated item is overdue, `due soon` if none overdue and any is due within the configured window, otherwise `pending`; partial coverage is indicated independently. No due date, status, allocation or running deposit is stored on the entry.

### 5.6 Gifts and post-wedding reconciliation · REQ-GF-1/2

1. Open SCR-20. Add a gift with source (sobre, money dance, cash, bank transfer or other), positive amount, received-on date and optional giver name/note. Another partner's separately added gift is another UUID row, not a competing total.
2. Once a gift exists, show gifts total and a separate “Net after gifts” beside the unchanged net out-of-pocket; show supplier balances due with absolute dates, and signed `gifts total − remaining balances`. A negative difference means gifts do not cover the balance, not an invalid calculation.
3. Show any item sponsorship orphaned by deletion of its linked entry with its payment/receipt history intact; exclude that support from live net and provide a link to review. Neither gifts nor orphan history automatically marks a supplier paid.
4. Tap a balance to open SCR-08/09 and record an actual payment; return to SCR-20 to see recomputed remaining balance and difference. Giver names stay out of lock-screen reminders.

---

## 6. Shared-editing UI

### 6.1 Notification model — position taken

**Partner edits: in-app only; no server push in v1. Supplier due dates: local device notifications permitted (REQ-LG-9).**

Justification: two partners planning one wedding are usually co-located and often editing together. Pushing "your partner changed the flowers estimate" for every field edit produces notification fatigue fast, and the change log already provides a complete record on demand. Nothing upstream requires push, and design.md 2.6 deliberately omits realtime transport, so a push would need infrastructure that does not exist.

**Separate reminder channel:** each device schedules its own alerts from local dated, unpaid `payment_schedule_items`, with plan-level settings on SCR-18 (default 7 and 1 days before, plus overdue; off switch; independent 7-day Due soon window). Reminders work offline, do not require a server push or tell the other partner about an edit, and cancel after the item is paid/deleted. Turning off notifications does not hide Due soon. Permission denial is explained, not a budget blocker. By default lock-screen copy and accessibility announcement contain no supplier names, amounts, sponsor or giver names: “A supplier payment is due in 7 days.” Undated virtual balances never notify.

What is surfaced instead, in ascending intrusiveness:

1. **Passive** — attribution stamps on changed fields and rows. No interruption.
2. **Ambient** — activity indicator on the More tab when unseen log entries exist since last visit to SCR-16.
3. **Banner** — a dismissible banner on SCR-06, used only when a remote change altered a headline figure (gross, net, buffer remaining, exposure) or when a conflict resolved.
4. **Blocking** — reserved for lifecycle events only: pending ownership-transfer confirmation, and being removed from the plan. Never for a data edit. (Defensive removal itself needs no confirmation from the removed party; the blocking surface a removed partner sees is the removed-state notice, not a confirmation prompt.)

### 6.2 Attribution

Displayed as **display name + relative timestamp**. No avatar in v1: with exactly two members, an avatar carries no information a name does not, and it consumes width that money figures need.

- Relative time under 7 days: "2 hours ago". Beyond that, absolute date per section 8.5.
- Attribution is always the acting partner from `change_log.actor_user_id` (REQ-SE-4 clause 5).
- Stamps read "You" for the current user rather than their own name.

### 6.3 Field-level attribution placement

- **SCR-07, SCR-12, SCR-14, SCR-20 rows:** one stamp per row, reflecting the most recent change to that entity; distinct new payment, receipt and gift events have their own attribution rather than a cumulative-field conflict.
- **SCR-08, SCR-09, SCR-15 forms:** stamp beneath each field changed remotely since this user last opened the record; event rows also show their own author. Not on every field — only genuinely remote ones, or the form becomes unreadable.
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

The value is never lost; design.md 4.6 makes the log append-only and REQ-SE-2 clause 6 forbids discarding an accepted write. SCR-16 shows the superseded value, its author, and its timestamp.

What is deliberately **not** provided is a one-tap Restore. Reason: restoring is just another write, and a Restore button invites a tap-war where each partner reverts the other, generating log noise and no agreement. The couple should read what happened and decide, then type the value they agree on. The value is one screen away and fully legible — that satisfies recoverability without automating a disagreement.

### 6.6 Is a same-field loss shown or silent?

**Shown. Explicitly, and only to the partner whose write lost.**

Silence here would undermine confidence in shared editing. A partner who sees their entered amount replaced by another number with no explanation may conclude the app lost their work. REQ-SE-2 clause 6 requires the losing write to be preserved — so the information exists and withholding it is a choice. In §5.4 it is **A's online write** that loses after B's offline edit syncs; the banner must not imply that A was offline.

Shown on the losing device, once, dismissible:

> **"Your partner also changed this"**
> *"[B's name] changed the actual amount on [entry] to ₱62,000.00. That amount is now being used. Your ₱58,000.00 is saved in the activity log."*

Rules:

- Shown **only** to the losing partner. The winner has no action to take and no confusion to resolve.
- Names the field, the winning value, the losing value, and where the losing value lives.
- Never uses "overwritten", "lost", "discarded", or "failed". The write is preserved and the copy must say where.
- One banner per sync cycle regardless of conflict count, linking to SCR-16 for the full list. Twelve banners is not disclosure, it is noise.
- Non-conflicting remote changes get no banner. Only genuine same-field losses.

---

## 7. Offline communication

### 7.1 Indicator placement

A single **sync badge** in the header of every SCR-06 through SCR-20, always in the same position. One component, one location, four states. Tapping it opens SCR-19.

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

Never translated, and never glossed in body copy: **Ninong**, **Ninang**, **OOT**, **corkage**, **lechon**, **HMUA**, **entourage**, **sobre** (day-of envelope gifts).

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
| B | "Net out of pocket, 300,000 pesos, subtracting support actually received, including partial receipts. Expected pledge support not yet received, 50,000 pesos" |
| C | "Budget health. 5 checks passing; budget adequacy not available" (first-run example only; compute count from current state) |
| D | "Buffer remaining, 58,000 pesos, 82 percent of buffer" |
| E | "Outstanding pledge exposure, 50,000 pesos" |
| F row | "Catering and venue. Allocated 140,000 pesos. Spent 152,400 pesos. Over by 12,400 pesos" |
| G | "Driving guest count, 150 confirmed guests. 40 tier 1, 110 tier 2" |
| H | "2 hidden fees not answered: overtime, venue power" |
| J | "Due soon. Supplier balance due 6 Oct 2026, 10,000 pesos remaining" (example; announce item and absolute due date) |
| K | "Net after gifts, 250,000 pesos. Gifts received, 50,000 pesos. Net out of pocket before gifts, 300,000 pesos" (only when gifts exist) |
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
| `MoneyField` | value in centavos, label, required, min, max, allowNegative | empty, focused, valid, invalid, over-limit warning, read-only | SCR-03, 08, 09, 10, 15, 20 |
| `MoneyDisplay` | centavos, size variant, constrained mode, tappable | standard, constrained, negative, zero, unavailable | Everywhere |
| `CategoryPicker` | selected code, taxonomy, suggestion order | unselected, selected, invalid, read-only | SCR-08, 15 |
| `PricingModeToggle` | mode, perHeadRate | flat, per-head, per-head-missing-rate, manually-valued-locked, read-only | SCR-08 |
| `SyncBadge` | connection state, pending count, oldest age, failure flag | synced, offline, offline-with-pending, stale, sync-problem, needs-attention | Header of SCR-06–20 |
| `AttributionStamp` | actor, timestamp, isCurrentUser, superseded | own, partner, superseded, pending-push | SCR-07–16, 20 |
| `BentoTile` | span, height unit, label, content, a11yLabel, tappable | populated, zero-value, unavailable, inert | SCR-06 |
| `BudgetHealthCheck` | condition id, met, governing value, reqRef | met, not-met, unavailable | SCR-06 tile C |
| `VarianceIndicator` | allocated, effective, showPercent | under, over, exact, percent-suppressed | SCR-06 tile F, SCR-07, SCR-10 |
| `FeeComponentRow` | componentType, label, quantity, unitRate, amount | quantity-rate mode, amount mode, incomplete, read-only | SCR-09 |
| `FeePromptCard` | feeType, state, total, dismissedBy, dismissedAt | prompted-unfilled, filled, dismissed, region-defaulted | SCR-05, SCR-06 tile H |
| `PledgeStatusControl` | explicit state, derived receipt total, value, withdrawn | tentative, confirmed, partially received, derived received, withdrawn, read-only | SCR-14, 15 |
| `GrossNetPair` | gross, net (actual eligible receipts only), expectedRemaining | equal, net-reduced, negative-net, zero-state | SCR-06 tiles A/B, SCR-14, SCR-20 |
| `ScheduleItemEditor` | UUID, kind, label, dueDate, amount, sortOrder | blank, valid, invalid, deleted, read-only | SCR-08, 09 |
| `ScheduledBalanceRow` | item or virtual residual, allocated, remaining, dueDate, derived status | paid, partial, due-soon, overdue, pending, undated-virtual, mismatch | SCR-06 tile J, SCR-07–09, SCR-20 |
| `PaymentEventEditor` | UUID, entry, schedule attribution, kind, positive amount, paidOn, method, sponsor, note | payment, refund, sponsor-direct, invalid, deleted, read-only | SCR-08, 09, 15 |
| `ReceiptEventRow` | UUID, pledge, amount, receivedOn, paymentId, note | cash, sponsor-direct-linked, tombstoned, read-only | SCR-14, 15, 20 |
| `ReminderSettings` | enabled, dueSoonWindowDays, dayOffsets, overdueEnabled, permissionState | default-window-7-delivery-7-1-overdue, customised, off, permission-denied, read-only | SCR-18 |
| `GiftEventEditor` | UUID, source, positive amount, receivedOn, optional giverName/note | blank, valid, invalid, deleted, read-only | SCR-20 |
| `ReconciliationSummary` | giftsTotal, net, netAfterGifts, remainingBalance, orphanSupport | zero-gifts, covered, shortfall, negative-net, orphan-review, read-only | SCR-20, SCR-06 tile K |
| `RsvpTierMatrix` | counts by status and tier, drivingStatus | populated, empty, driving-highlighted | SCR-12 |
| `CrewHeadcountBlock` | headcount | zero, populated, read-only | SCR-12, SCR-09 crew variant |
| `WhatIfComparison` | before, after, affectedCategories, excludedItems | neutral, increase, decrease, over-cap | SCR-13 |
| `TierCutList` | targetCount, tier1Count, tier2Count | within-tier-2, exceeds-tier-2, not-a-reduction | SCR-13 |
| `ExplainSheet` | explanation payload, allocatorKind, rulesetVersion | rule-based, unavailable | SCR-11 |
| `OverrideRow` | engineCents, overrideCents, categoryCode | engine-value, overridden, over-allocated, read-only | SCR-10 |
| `BufferGauge` | allocation, overrun, remaining | healthy, breached, full | SCR-06 tile D, SCR-10 |
| `ChangeLogEntry` | actor, action, entity, field, oldValue, newValue, serverTs, deviceMonotonic, superseded, pendingPush | applied, superseded, pending-push, lifecycle | SCR-16, per-entity history |
| `ConflictBanner` | field, winningValue, losingValue, actor | single-conflict, multiple-conflicts, dismissed | SCR-06, SCR-19 |
| `ReadOnlyNotice` | reason | partner-removed, plan-deleted | All SCR-06–20 |
| `StepIndicator` | current, total, blockedReason | in-progress, blocked, complete | SCR-03, 04, 05 |
| `DateField` | value, allowPast | empty, valid, past-confirmed, invalid | SCR-03, 08, 09, 15, 20 |
| `RegionPicker` | selected, taxonomy grouped by tier | unselected, selected, destination-selected | SCR-04, 18 |
| `OptionalTypePicker` | ceremony/venue taxonomy, nullable selection, hint | not-sure-yet, selected, read-only | SCR-04, 18; hint on SCR-05 |
| `TwoPartyConfirmation` | action, initiator, confirmedBy, expiresAt | awaiting-you, awaiting-partner, expired, complete | SCR-17 |

---

## 11. Open items and resolved former gaps

Open items first, then resolved items retained for traceability.

1. **★ Budget health graded bands — deliberately not invented.** Section 4.3. The card states five computable checks and one unavailable condition. A graded verdict needs caution thresholds, weighting, and severity ranking defined upstream first.
2. **Reference cost values.** Budget adequacy renders as unavailable until `reference_costs` is populated. Already tracked as requirements.md 13.1; noted because it is now visible in the UI.
3. **Ownership-transfer expiry — resolved at 7 days (ADR-32).** SCR-17 shows the expiry; a timed-out confirmation leaves the plan unchanged (REQ-SE-5 clause 7).
4. **Notes limit — resolved (ADR-33).** SCR-08 uses a hard 2,000-character input limit and a live counter (REQ-LG-1 clause 8).
5. **Removed partner's local data retention.** Section 3.3 retains the local copy and SHALL offer voluntary wipe (ADR-34). Force-wipe is still open (OQ-03).
6. **Decision log — available.** `docs/decision-log.md` is an input and contains the authoritative ADRs and remaining OQs; its former absence claim is resolved (§0).

*Resolved since first draft: platform (Flutter + SQLite/`drift`), the REQ-GEN-2A constrained-display amendment (section 8.2), and ruleset configuration management (bundled JSON asset validated at app load — REQ-AE-1 clause 4 is now a load-time check, not an authoring screen).*
