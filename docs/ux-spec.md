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
| SYS-01 | Secure local-store startup | Open encrypted DB before router; block on key/cipher/protection failure; warn once if no device lock | Cold start, before SCR-01 | REQ-PLT-2, SEC-12–16, ADR-74 |
| SCR-01 | Sign In / Sign Up | Authenticate; unchecked 18+ declaration; first-run Start / Join choice | Cold start, unauthenticated | REQ-SE-1 (9), ADR-52/63 |
| SCR-02 | Invite Acceptance | Join via deep link or pasted invite URL | Invite deep link; SCR-01 join choice | REQ-SE-1 (3,4,5,6), SEC-05, ADR-52 |
| SCR-03 | Setup: Budget & Date | Capture total budget and wedding date; current Phase 06 slice holds an identity-bound session draft only (ADR-75) | Start/Join; later SCR-18 | REQ-BS-1, REQ-BS-2, REQ-BS-3, REQ-GEN-2 |
| SCR-04 | Setup: Guest Cap, Region & Types | Future required cap/region and optional ceremony/venue hints; current screen is an explicit unfinished step with Back | SCR-03 next | REQ-BS-1, REQ-BS-4, REQ-BS-5, REQ-HF-1 |
| SCR-05 | Setup: Hidden-Fee Prompts | Force a decision on all six fees; gate completion | SCR-04 next | REQ-HF-1, REQ-HF-2, REQ-HF-3 |
| SCR-06 | Dashboard | Bento overview plus due-soon list and post-gift figure | Post-setup default tab | REQ-PL-2, REQ-PL-3, REQ-PL-4, REQ-AE-6, REQ-AE-2 (3), REQ-BS-5 (2), REQ-HF-1 (5), REQ-LG-5, REQ-LG-6, REQ-LG-9, REQ-GF-1, REQ-OF-3 |
| SCR-07 | Ledger List | Browse/filter costs and due-soon schedule items | Ledger tab; dashboard due-soon/category tap | REQ-LG-1…9 |
| SCR-08 | Expense Editor | Create/edit entry and its schedule/payment/refund history | SCR-07 add or row tap | REQ-LG-1…8, REQ-GM-2, REQ-PL-7 |
| SCR-09 | Hidden-Fee Editor | Create/edit one of six typed fee entries | SCR-05, SCR-07, dashboard outstanding-fee chip | REQ-HF-1, REQ-HF-2, REQ-HF-3, REQ-GM-4 |
| SCR-10 | Allocations & Overrides | Review engine allocations; override/revert; explicitly preview/apply rebalance | Dashboard category breakdown; SCR-18 | REQ-AE-1, REQ-AE-4, REQ-AE-5, REQ-AE-6, REQ-AE-7 |
| SCR-11 | Explain Figure | Explain engine figure and rebalance transfers/locks/remaining breach | Tap engine figure or SCR-10 rebalance preview | REQ-AE-4, REQ-AE-2 (1), REQ-AE-7 |
| SCR-12 | Guests List | Manage guests across RSVP status and priority tier | Guests tab | REQ-GM-1, REQ-GM-4 |
| SCR-13 | Guest What-If | Model headcount or calculate affordable guest ceiling | SCR-12 action; dashboard guest tile | REQ-GM-2, REQ-GM-3, REQ-GM-5, REQ-GM-6, REQ-BS-5 (2) |
| SCR-14 | Pledges List | Track remaining sponsor support, partial receipts, withdrawn history | Pledges tab; dashboard net tile | REQ-PL-1…7 |
| SCR-15 | Pledge Editor | Create/edit pledge; record receipts and direct supplier payments; withdraw | SCR-14 add or row tap | REQ-PL-1…7, REQ-LG-8 |
| SCR-16 | Change Log / Activity | Plan-wide/per-entity history, Conflicts filter, tombstone Restore | More tab; per-entity history affordance; conflict banner | REQ-SE-2, REQ-SE-3, REQ-SE-4, REQ-OF-5 (4), ADR-43/47 |
| SCR-17 | Shared Access | Partner status, invite, mutual defensive removal, ownership, delete plan (Phase 06 currently implements invitation issue/revoke only) | More tab | REQ-SE-1, REQ-SE-5, REQ-SE-6, REQ-PLT-3 |
| SCR-18 | Plan Settings | Edit plan/reminders/profile; device sessions, sign-out/wipe, deletion request; separate default-off measurement and survey opt-ins; v1.1 language picker | More tab | REQ-BS-1, REQ-BS-2, REQ-BS-6, REQ-GM-1 (6), REQ-AE-3, REQ-LG-9, REQ-PLT-3, REQ-MT-1, REQ-SV-1, REQ-LO-1, SEC-31/32/33/34, ADR-50/51/58/62 |
| SCR-19 | Sync Detail | Queue, last sync, retry, invalid-projection needs-attention and version state | Tap sync badge anywhere | REQ-OF-3, REQ-OF-5, REQ-SE-3, ADR-45/49 |
| SCR-20 | Post-Wedding Reconciliation | Record cash gifts and compare gifts to remaining supplier balances | More tab; dashboard gifts action; Pledges tab | REQ-GF-1, REQ-GF-2, REQ-LG-4, REQ-PL-7 |
| SCR-21 | Starter Templates | Choose wedding type; unticked cost-type suggestions, not saved ledger rows | More tab; after SCR-05 setup; SCR-07 add | REQ-TM-1, ADR-55 |
| SCR-22 | Requirements Checklist | Track personally verified items, done state, optional user date/fee; explicit fee conversion | More tab; setup completion shortcut | REQ-CK-1, ADR-56, OQ-11 |
| SCR-23 | Export & Share | Privacy-preview offline PDF/CSV/sponsor statement; distinct full personal-data copy | More tab; SCR-14 pledge action; SCR-18 account section | REQ-EX-2, SEC-32, ADR-57 |
| SCR-24 | Optional post-wedding survey | Ask one skippable yes/no spreadsheet-displacement question only after independent opt-in and privacy approval | App open after wedding date, SCR-18 feedback settings | REQ-SV-1, REQ-MT-1, ADR-62, SEC-29/30/31 |

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

### SYS-01 Secure local-store startup
**Loading:** show local progress while the page cipher, secure key and protected app-support path open. Do not wait on a network request. **No device lock:** show the one-time advisory above SCR-01: “Your device has no device lock. Set a passcode or biometric lock to protect your financial data.” Continue only after “I understand”; remember acknowledgement in device-bound secure storage. **Failure:** if cipher, key, protected path or device-lock check fails, do not mount the router, do not wipe or recreate an existing database, and show “The secure local store could not open. Your data was not reset. Unlock the device and try again.” No plaintext fallback, no automatic reset, no suggestion that unsynced data was recovered. Phase 05 contains no plan entities yet; the system state is not a new plan screen.

### SCR-01 Sign In / Sign Up
**Regions:** brand block; form; primary action; alternate-mode link; error slot; after authentication with no plan, explicit first-run choice.
**Fields:** email, password, display name (sign-up only) → `users`; unchecked 18+ self-declaration on sign-up only (no birth date).
**Actions:** sign-up requires the applicant to check “I am 18 or older”; otherwise show an accessible reason and do not create the account. Present the counsel-approved privacy notice before collecting real beta data; a checked declaration is not verified identity or consent to optional measurement. Submit → authenticate; an existing active plan routes to SCR-06, a pending invite to SCR-02; otherwise offer **“Start our plan”** → SCR-03 or **“Join my partner's plan”** → SCR-02 with paste field. Toggle sign-in/sign-up. Signing up before receiving an invite never creates an implicit plan (ADR-52/63).
**Nav in:** cold start unauthenticated. **Nav out:** SCR-03, SCR-06, SCR-02.

### SCR-02 Invite Acceptance
**Regions:** invite URL paste field when entered via SCR-01; inviter identity; plan summary; accept/decline; expiry/error slot.
**Fields:** inviter display name → `users` via `invites.inviter_user_id` while available; wedding date → `plans`; expiry → `invites.expires_at`.
**Actions:** paste link or receive a tapped deep link → parse the same ≥128-bit CSPRNG token; server validates its hash, single use, 7-day expiry and revocation (SEC-05). Invalid/unparseable link stays editable with a reason, never creates a plan. Accept → atomically establish stable member alias and live `plan_members` membership, then full replay pull from per-plan `cursor = 0` (design.md 2.5) → SCR-06. Decline → SCR-01's start/join choice.
**States of note:** expired, revoked, already accepted — each names the reason (REQ-SE-1 clause 5).
**Expiry copy:** the invite expires exactly 7 days after issuance; the expired state says so and does not offer acceptance (REQ-SE-1 clauses 4, 5).
**Nav in:** deep link or SCR-01 paste. **Nav out:** SCR-06, SCR-01.

**Phase 06 implementation boundary (2026-10-05; target states above remain requirements):** SCR-01 renders sign-in/sign-up, an unchecked 18+ checkbox, a synthetic-local notice placeholder and post-auth Start/Join buttons. Verified users first await a server membership lookup; lookup failure blocks protected routes and invitation acceptance rather than pretending the account has no plan. Existing members cannot open another plan's invitation screen. Start reaches SCR-03's bounded budget/date session draft, **not** a working `create_plan` form; SCR-04 still has no cap/region inputs. SCR-02 accepts a pasted `kasaran://accept/{token}` URL or a routed token through the same client RPC call; both use the SQL RPC's 32-lowercase-hex token format. Decline returns to Start/Join without server mutation. Success refreshes membership lookup. It does not yet render inviter/plan summary, distinct invalid/expired/revoked/used states from end to end, replay progress or a verified successful navigation to SCR-06. No real-data notice or finished eight-state matrix is implied by these partial widgets; see `testing-plan.md` §2.0.

### SCR-03 Setup: Budget & Date
**Regions:** step indicator (1 of 3); total budget field; wedding date field; validation slot; next.
**Fields:** `plans.total_budget_cents`, `plans.wedding_date`.
**Actions:** Next → validate REQ-BS-2 (reject non-numeric, zero, negative; retain other fields) → SCR-04. Past date → confirm dialog per REQ-BS-3, savable on confirmation.
**Notably absent:** no block on budgets under ₱30,000 or over ₱500,000 (REQ-BS-1 clause 3).
**Nav in:** post sign-up; SCR-18. **Nav out:** SCR-04.

**Current Phase 06 slice (ADR-75):** The first-run, verified planless account sees budget/date fields with strict peso and calendar-date validation, inline errors, a session-draft notice and a past-date confirm/decline dialog. Date decline restores the prior accepted date; other input stays entered. Next stores only a Riverpod draft and reaches unfinished SCR-04; Back returns with the same account's inputs. Identity loading/error, sign-out or an account switch erases the draft, including A→B→A; an open past-date dialog also hides the old account's date and cannot advance it. Restart also loses it. The draft is neither an encrypted/offline persisted plan nor completed setup; no `create_plan`, allocation, fee prompt or invitation is called.

### SCR-04 Setup: Guest Cap, Region & Types
**Regions:** step indicator (2 of 3); guest cap; region grouped by cost tier; optional ceremony and venue pickers, each including “Not sure yet”; tier note; next/back.
**Fields:** `plans.guest_cap`, `plans.region_code` → `regions`, `cost_tiers`; nullable `plans.ceremony_type` and `plans.venue_type` (null = Not sure yet). Ceremony choices: church, civil, other religious, garden/beach officiant, other. Venue choices: hotel, garden, beach/resort, restaurant, events place, other.
**Actions:** Next → allocation runs (REQ-AE-1) → SCR-05, even if both optional types remain unset. Region selection writes no ledger entry (REQ-BS-4 clause 5) and sets OOT default when `is_destination` (REQ-HF-3). Types change only contextual fee-card hint text (e.g. civil: “Church aircon usually doesn't apply”; garden/beach: “Venue power is often needed”), never amounts, fee state, or whether the partner must decide on all six (REQ-HF-1).
**Copy:** tier note reads *"Destination weddings usually carry supplier travel costs. We'll ask about that next."* It states the consequence without asserting an amount.
**Nav in:** SCR-03. **Nav out:** SCR-05, back to SCR-03.

**Current Phase 06 boundary:** SCR-04 only says guest cap/region are not available, that the budget/date values are an unpersisted session draft, and offers Back or Start/Join. Its target controls and SCR-05 navigation remain unimplemented until Phase 09 and later dependencies.

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
**Fields per row:** locally recomputed engine amount/explanation from pinned ruleset and inputs; synced `plan_allocations.override_cents`, overridden badge, summed effective for the category, variance in pesos and percent (REQ-LG-6 clauses 1, 2; ADR-46).
**Buffer block:** buffer allocation, summed non-buffer overrun, **buffer remaining** (derived per REQ-AE-6 clauses 1, 2) in pesos and as percent of original (clause 4).
**Actions:** override → accepts any value ≥ 0; both values remain visible (REQ-AE-5 clause 2). Revert → nulls `override_cents`, affects no other category (clauses 5, 6). Explain → SCR-11. **Rebalance to fit commitments** opens a no-write six-row before/after preview. Existing override badges become locks (including Buffer); starting allocations not totaling budget disable Apply and direct the user to repair overrides. Preview shows Buffer-first transfer, proportional unlocked under-commitment donors, unchanged locks and any uncovered shortfall; Apply feasible redistribution explicitly even when a residual breach remains, or Cancel with no writes. On intervening input/sync change, mark preview stale and require refresh/reconfirmation. Apply saves only changed `override_cents`; never changes default allocations, commitments, payments or gross/net (ADR-53).
**Over-allocation:** when overrides sum above total budget, names the excess and reduces nothing (REQ-AE-5 clause 4).
**Nav in:** dashboard breakdown; SCR-18. **Nav out:** SCR-11.

### SCR-11 Explain Figure
**Regions:** figure restated; plain-language rule; input list; modifier line; ruleset version; rebalance explanation when entered from SCR-10.
**Fields:** locally recomputed explanation, allocator kind/version and `plans.ruleset_version`; explanation is not synced (ADR-46).
**Content:** baseline basis points, skew multiplier, resulting share, amount — in prose, not a formula (REQ-AE-4 clauses 2, 3).
**Rebalance content:** list six original/effective proposed allocations, each locked override, unlocked Buffer consumed first, slack per donor, centavo transfers (integer floor and largest fractional remainder; ties fixed ADR-10 order), remaining recipient and locked-category shortfalls. State explicitly that post-apply **buffer remaining still uses REQ-AE-6**, not automatic under-spend netting. When no feasible change exists, show reason, not a false “fixed” badge. No supplier or rate advice.
**Rule enforced:** a figure with no explanation payload is not rendered at all anywhere in the app (REQ-AE-4 clause 4). This screen is the reason that rule is enforceable.
**Nav in:** tap any engine figure. **Nav out:** dismiss.

### SCR-12 Guests List
**Regions:** RSVP × tier summary matrix; driving-status indicator; guest list; crew headcount block; add.
**Fields:** `guests.name`, `rsvp_status`, `priority_tier`; counts per cell; `crew_headcount.headcount`.
**Actions:** add guest → defaults `tier_2` (REQ-GM-1 clause 3); the guest's RSVP is set explicitly, never silently confirmed (clause 4). The plan's **driving RSVP status** defaults to `invited` for per-head calculations, visibly indicated here and editable on SCR-18 (REQ-GM-1 clause 6). Edit either guest axis independently (clause 5). Crew headcount edited in its own block, visually separated (clause 10, REQ-GM-4 clause 3). What-if → SCR-13.
**Displays:** breakdown by tier within the driving RSVP status (clause 8).
**Nav in:** Guests tab. **Nav out:** SCR-13.

### SCR-13 Guest What-If
**Regions:** current count; hypothetical input (absolute or delta); before/after comparison; per-guest marginal cost; tier cut-list block; commit/discard; separate “How many guests can we afford?” buffer input and read-only result.
**Fields:** all derived, nothing persisted while open (REQ-GM-5 clause 5).
**Shows:** before/after gross and net and every affected category (clause 2); marginal cost per guest as Δgross ÷ Δcount (clause 3); over-cap indicator with full calculation still returned when above `guest_cap` (clause 4, REQ-BS-5 clause 3); on reductions, how many Tier 2 guests absorb the cut before any Tier 1 is touched (clause 9).
**Unchanged in preview:** crew meals (REQ-GM-4 clause 1) and `manually_valued` entries (REQ-GM-3 clause 4), both labelled as excluded so the omission reads as deliberate.
**Affordable ceiling:** use live flat effective costs **including** crew meals and manual-valued per-head items, summed active guest-scaling rates, budget and a couple-chosen nonnegative buffer. Show the gross-cost integer floor and all inputs, not net of pledges or gifts; do not cap answer at `guest_cap` (display a separate over-cap warning). If flat + buffer already exceeds budget, show `0 guests` with the shortfall and “Even zero guests do not fit”; if active rate sum is zero, show “No per-head costs; no finite budget-based guest limit” instead of infinity, **plus** the zero-guest shortfall when applicable. The calculation is read-only and does not commit a count, even when the main what-if has a Commit action (ADR-54).
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
**Regions:** reverse-chronological immutable feed; partner/entity/date filters and **Conflicts** filter; per-entity history; deleted-item history with explicit Restore action (section 6).
**Fields:** `change_log` old/new typed values, group snapshot, `plan_member_id`, ordering key and derived superseded/conflict labels; “Former member” for a severed alias mapping.
**Actions:** filter to stale writes where recorded old value differs from the immediately replaced value; inspect winning and superseded values side by side. For a tombstoned entity, **Restore entry** confirms and writes a new LWW `deleted_at = null` event, subject to post-merge validation; no edit or delete of log history. This is not a one-tap restore of a disagreeing *value* (§6.5). Suppressed concurrent edits remain inspectable.
**Nav in:** More, per-entity history, either member's conflict banner. **Nav out:** prior screen or the affected editor.

### SCR-17 Shared Access
**Regions:** partner slot with role; invite block; remove-partner action; ownership-transfer block (with pending-confirmation sub-state); delete plan (creator only); active-plan note.
**Fields:** `plan_members.role`, `invites.expires_at`, `lifecycle_confirmations.*` (ownership transfer only), `plans.is_active`.
**Actions:** invite → link expiring exactly 7 days after issuance (REQ-SE-1 clauses 4, 5); revoke invite. **Remove partner → mutual and one-sided: either partner may remove the other, no confirmation from the removed party, effective on their next sync (REQ-SE-6). Requires a typed/deliberate confirmation from the acting partner only, to prevent an accidental tap, and is logged and attributed (REQ-SE-4).** Transfer ownership → opens two-party confirmation, expiring after 7 days if not completed; both partners retain full access while pending (REQ-SE-5 clauses 4, 6, 7) — this is the only two-party action. Delete plan → creator only; non-creator sees the action absent and, if reached, a refusal naming creator-only (REQ-SE-5 clauses 1, 2); requires typed confirmation (clause 3).
**Stated on screen:** removing a partner cannot be undone by the removed person and does not delete their existing local copy — server access simply stops (REQ-SE-6 clauses 5, 6). Data access stays fully symmetric; only lifecycle actions are governed here (REQ-SE-5 clause 9). Without this the removal reads as either reversible or a general permission tier.
**Nav in:** More tab. **Nav out:** SCR-16 for lifecycle history (REQ-SE-5 clause 8, REQ-SE-6 clause 4).

**Phase 06 implementation boundary:** SCR-17 currently exposes only authenticated, server-backed invitation issue and revoke. A verified member with a confirmed active, one-member plan sees Issue; RLS-filtered invite metadata shows ID, expiry and status without `token_hash`. The server RPC, not the eligibility hint, authorizes mutations. Unknown account identity or membership defers navigation to the plan-check screen; failed identity or membership checks show Retry there. SCR-17 metadata loading blocks Issue, and a failed metadata read shows Retry without fabricating an empty list or permitting issue. Retrying a failed identity check refreshes both account identity and plan lookup. Offline RPC errors show generic retry copy and do not queue a mutation. An issued link is selectable only in the current widget view with a copy-now/OS clipboard-history warning; a metadata-refresh failure does not hide it. Confirmed revoke, route exit, sign-out, account-ID change or plan change drops the displayed link. A late RPC response or error is discarded after auth loss or any intervening account-ID or plan lookup change, including switching away and back. Partner status, removal, transfer and deletion remain future states, not active controls in this slice.

### SCR-18 Plan Settings
**Regions:** setup inputs (budget, date, guest cap, region, optional ceremony/venue types); driving RSVP status picker (default `invited`); ruleset version block; **separate default-off product-measurement and optional-survey consent controls** with purpose, approved notice and withdrawal; **Due-date reminders** section with on/off, independent Due soon window (default 7 days), notification before-due offsets (defaults 7 and 1 days), overdue toggle and OS notification-permission explanation; **Devices & account** list naming this and other sessions, profile correction (display name/email), link to SCR-23 Full data copy, per-device sign-out, local-wipe choice and account-deletion request; **v1.1 only** language selection English/Taglish/Filipino.
**Actions:** any setup edit → preview before applying when more than one category shifts (REQ-BS-6 clause 3); cancel persists nothing (clause 4); applied edits log (clause 5). Ruleset opt-in → before/after preview, overrides preserved (REQ-AE-3 clauses 3, 4). Reminder edits sync plan-level preferences, reschedule this device's live unpaid dated items immediately even offline; permission denial and off switch leave financial records untouched and no reminder delivered. **Off does not hide Due soon** (the configured window still drives it). Do not include names or amounts in lock-screen text; “A supplier payment is due in 7 days” is the default. No partner-edit push. Sign out this device → warn about pending writes, revoke its server refresh session, stop sync, then offer **confirmed local wipe** of encrypted data/key; do not silently wipe. Sign out a selected other device → revoke only that session, with no claim of remotely wiping its offline copy. Other sessions remain active (ADR-50). Account deletion → show deliberate request/confirmation path (SEC-33/34), but for a shared plan label completion **blocked pending counsel (OQ-01/ADR-26)**; never promise an erasure outcome or imply that deleting a local copy deletes the account. Attribution after permitted deletion reads “Former member”; other user FKs must be resolved in the eventual policy.
**Measurement/feedback:** explain that existing plan rows are used only for a consented cohort, one minimal net-view event is optional, and survey response is separate. Each control starts off; both current partners must opt in before shared plan analysis. Withdrawing either stops new optional events and drops unsent events; already-collected data follows a reviewed retention/deletion policy. Survey consent never enables measurement. No invented legal assurance or individual partner activity report (REQ-MT-1, REQ-SV-1, ADR-62).
**Stated on screen:** editing setup destroys no entries, pledges, guests, or overrides (REQ-BS-6 clauses 1, 2). Users expect budget changes to wipe work; saying otherwise prevents avoidable fear.
**Language/version state:** v1 English only; v1.1 selected locale falls back per missing key to English while PHP and date display remain en_PH. Never translate user-entered text or culturally fixed names. No photo-upload control in v1: receipt/contract attachments remain a v1.1 backlog design, with pending/offline/error upload states and privacy-label review before activation (ADR-58/59).
**Nav in:** More tab. **Nav out:** SCR-03/04 field editors, SCR-10.

### SCR-19 Sync Detail
**Regions:** connection state; pending-write count and list; last successful sync; failure detail; manual retry; **needs-attention** list of invalid dependent projections with entity, failed invariant, preserved raw values and editor link; update-required version state.
**Fields:** `sync_state.last_pushed_server_ts`, `last_pulled_server_ts`; local queue depth.
**Actions:** retry; open an invalid entity to make a deliberate corrective write. Replay is automatic and requires no action here (REQ-OF-5 clauses 1, 2) — the button exists for reassurance, and the screen says so. No automatic repair write; unknown additive events remain stored for post-upgrade rebuild, unsupported protocol major prompts minimum supported build without dropping queued writes (ADR-45/49).
**Nav in:** sync badge, any screen. **Nav out:** dismiss.

### SCR-20 Post-Wedding Reconciliation
**Regions:** gifts received list with add/inspect/tombstone; gifts total; gross/net pair; net after gifts; remaining supplier balances; signed gift-versus-balance difference; orphaned in-kind support needing review.
**Fields:** each `gifts_received` event has source (sobre / money dance / cash / bank transfer / other), amount > 0, received-on date, optional giver name and note. The giver name is third-party personal data, so keep it optional and never put it in notifications. Derived gifts total = Σ live gifts; net after gifts = net out-of-pocket − gifts total **only when at least one gift exists**; balance total = Σ live entry balances; signed difference = gifts total − balance total (REQ-GF-1/2). Net remains the eligible-receipt-only figure of REQ-PL-2 (partial receipts included), never silently reduced by gifts.
**Actions:** add, inspect, or soft-delete gift events offline with distinct UUIDs and change-log attribution; an amount correction tombstones the old row and inserts a replacement UUID event, never overwrites a cumulative total. Tap a gift/remaining-balance/orphan row for detail; link to SCR-08 to record an actual supplier payment. Recording gifts never pays a supplier automatically. Review an item pledge linked to a deleted entry without folding its receipt into live net; preserve the payment/receipt history for correction.
**Nav in:** More tab, SCR-06 post-gift action, SCR-14. **Nav out:** SCR-08, SCR-14, SCR-16.

### SCR-21 Starter Templates · v1
**Regions:** wedding-type chooser (civil, church + hotel, church + garden, beach/destination, intimate ≤50); context hint from optional ceremony/venue type; unticked list of expense-type suggestions; “Review in ledger” link.
**Fields:** pinned bundled JSON suggestion ID, name, existing category and pricing mode; no default amount, rate, supplier or ledger row. The contextual hint proposes a type but never auto-chooses it; intimate is an explicit selection and does not change `guest_cap` or guest count (ADR-55).
**Actions:** selecting a variant displays suggestions only. Tapping an unticked suggestion opens SCR-08 (or SCR-09 for an applicable hidden-fee type) with suggested label/category/mode as **draft inputs**; valid user-entered supplier and amount/rate are required before Save. Cancel or decline leaves the suggestion unticked and totals unchanged; after a valid save mark the suggestion linked to that entry, without creating a second zero-value record. Switching type does not delete saved ledger entries. Include culturally relevant types such as arrhae/unity coins, veil, cord, candle, church fees, Pre-Cana, marriage license, souvenirs/giveaways, lechon, mobile bar, photobooth, prenup shoot, SDE video and entourage attire as suggestions, not claims that every couple must buy them. No vendor recommendations.
**Errors:** missing pinned ruleset/version → unavailable list/update prompt, no fabricated suggestions; incomplete supplier/price → editor validation, no create. **Nav in:** More, SCR-07, setup completion. **Nav out:** SCR-08/09, SCR-07.

### SCR-22 Requirements Checklist · v1 target, preset timing blocked by OQ-11
**Regions:** grouped checklist for PSA birth certificates, PSA CENOMAR, marriage license application/posting period, Pre-Cana/counselling, canonical interview, baptismal/confirmation certificates and banns; each shows **NEEDS VERIFICATION**, source/applicability caution, done toggle, optional user reminder date, optional self-entered fee and linked-ledger indicator.
**Fields:** stable configured item ID/label; plan-specific `checklist_items.done`, `user_date`, `fee_cents`; if a specific item/offset is later verified by relevant LGU/civil registrar/parish, a derived preset date from wedding date with its source/verification state. Until then **no published preset offset, universal eligibility claim, fee or legal deadline** (ADR-56/OQ-11). A user reminder date is labelled “Your date (not an official deadline).”
**Actions:** toggle done independently; enter/change/clear own date and fee offline. A wedding-date edit recomputes only a future *verified preset* date, never a user date. Fee input alone does not change gross; **Add fee to ledger** requires a positive entered fee, asks for explicit confirmation and opens SCR-08 prefilled with that exact amount and requesting a supplier. Cancel or a zero fee creates nothing. A later checklist-fee edit does not automatically change the ledger entry; offer an explicit edit link. A linked entry already exists → open it rather than create a duplicate; after deletion, offer deliberate recreation only. Completion never asserts legal compliance. Missing pinned checklist config retains saved states but blocks an asserted preset. **Nav in:** More or setup shortcut. **Nav out:** SCR-08, SCR-16.

### SCR-23 Export & Share · v1
**Regions:** choose output; sensitive-data/privacy preview listing included sections; generated-file review; OS share/save action; separate **Full data copy (SEC-32)** action.
**Curated choices:** shared summary PDF (gross, net, expected *unreceived* support, category table, dated payment schedule and labelled undated residual), ledger/payments/pledges/guests CSVs, and a statement PDF for **one selected Ninong or Ninang pledge** showing only that pledge's value, eligible receipts and linked coverage. Other sponsor roles are not selectable for this v1 statement. Shared PDF starts with guest names **off** and sponsor names **off**, two independent explicit toggles; show sample redacted lines and inspect rendered file before share. Sponsor statement prefilters one pledge, never other names/unrelated values. CSV has its own warning (“May contain names and financial details”) and explicit confirmation; no assumption that PDF name toggles sanitize CSV. Formula-like cells are neutralized even after leading whitespace/control characters; ordinary CSV quoting alone is insufficient. Files generate fully offline on-device from one local projection snapshot, including pending local edits; warn the other device may not yet reflect them. Share invokes the OS sheet (Messenger/Viber/email/save if available), **never a live web link**. Explain that copies sent to another app cannot be recalled; temporary Kasaran files are cleaned after handoff, not destination copies.
**Full data copy:** distinct action and explicit scope review of all accessible personal fields: profile/email/consent, plan, ledger and fee components, schedules/payments/refunds, pledge receipts, gifts/giver names, guests, checklist, activity old/new values and attribution including deleted history. Machine-readable ZIP/JSON, private save default, separate confirmation; do not apply the curated PDF redaction toggles. An offline local-only copy is labelled incomplete if server-side profile/consent fields are not present; complete export requires authenticated online account-data retrieval and privacy/access-scope review. Profile correction remains on SCR-18; this export is **not** erasure and makes no OQ-01 outcome promise.
**Errors:** local generation/space/share-sheet failure leaves plan unchanged; retry from local data and delete partial temporary artifact. Missing dependent ruleset/invalid projection → name omitted figure and block a misleading summary, permit review of raw full-data copy; if removed, local data remains read-only but no live-account completion or server access is promised. **Nav in:** More, SCR-14, SCR-18. **Nav out:** OS share sheet or prior screen.

### SCR-24 Optional post-wedding survey · v1 design, gated before real beta
**Regions:** question asking whether Kasaran was the only wedding budget tool with no parallel spreadsheet; plain-language approved survey notice; Yes, No, Prefer not to say, Submit, Not now, Skip. No free text or inferred response.
**Fields:** local prompt/dismissal state; consent version; when opted in and submitted, stable response ID and one typed answer. First valid plan response is retained; a second partner sees Already answered, never an overwritten answer. One respondent is not a two-person consensus.
**Actions:** after wedding date on next open, show only after SEC-29/30/31 approval and independent survey opt-in. Submit requires selected answer and works offline with exactly-once queued replay; Skip dismisses permanently with no answer; Not now defers once to next app open without looping in-session. Measurement opt-in remains independent. No consent or withdrawal never blocks budgeting or export. **Nav in:** eligible post-wedding open, SCR-18. **Nav out:** previous screen.

---

## 3. State matrix

Eight states per screen. **N/A** means the state cannot occur, with the reason given — never an omission.

### 3.1 Two states behave unusually in this app, by design

**Loading is nearly absent for plan reads.** REQ-PLT-2 clause 1 requires plan data from the local store with no network round-trip. Progress is appropriate for database open/migration and post-upgrade projection rebuild, SCR-02 first replay, authentication and session revocation, and SCR-19 sync transport. SCR-16 long local-history pagination may show local progress. No plan-data read may wait for a network spinner.

**Sync-error is not a data-integrity state.** A failed push means writes are still queued locally and intact (REQ-OF-5 clause 4). Copy must never imply loss. See section 7.

### 3.2 Matrix

The SCR-01/02 rows below are **specified target states**, not implemented-state attestations; the Phase 06 boundary under SCR-02 lists the current gaps. In particular, the present SCR-02 error response must not be counted as a fully verified set of expired/revoked/used UI states, and the replay row depends on phase 08 sync.

| Screen | First-run empty | Populated | Loading | Offline + pending | Sync error | Conflict just resolved | Partner removed | Calculation invalid |
|---|---|---|---|---|---|---|---|---|
| SYS-01 | First encrypted DB created with a new device-bound key; no app tables | Existing encrypted DB opens only with original key; router then mounts | Local-only key, cipher and file-protection checks; progress, no network | Same as online: local read available when key opens | Missing key, cipher, protection or device-lock check blocks router; never wipe/reset | N/A | N/A | No passcode: one-time advisory requiring acknowledgement; failure retains existing data without recovery claim |
| SCR-01 | Post-auth Start/Join; new sign-up declaration unchecked | Existing plan → SCR-06; checked declaration on new signup | Auth request in flight | Sign-in blocked; message states connection needed and no data is at risk | Auth failure distinct from sync; unchecked/under-18 declaration blocks signup | N/A — pre-plan | N/A | N/A |
| SCR-02 | Paste invite URL or accept deep link; no plan created yet | Valid invite summary | Replay progress with row count | Accept blocked; invite requires connection; token retained | Replay interrupted; resumes from committed cursor, local rows retained (ADR-48) | N/A — no local writes yet | Invite revoked; names reason | Invalid/expired/used token names reason and cannot accept |
| SCR-03 | Current: empty budget/date session draft; target: complete setup step | Current: same-account draft restored after SCR-04 Back; future SCR-18 pre-fill pending | Current: identity loading/error hides and erases draft; no plan read from this form | Current: in-session field entry only; no durable offline/restart guarantee. Full REQ-OF-1 setup still pending | Current: no network write or sync; unknown account hides draft | Current: A→B→A clears input; future plan conflict not applicable yet | Member routed away by plan guard | Current: invalid/zero/negative budget or invalid date gets inline error; past date requires confirm or restores prior date. Future full setup pending |
| SCR-04 | Current: explicitly unfinished step with Back/Start/Join; target: cap/region and optional types | Current: no persisted plan; target: SCR-18 pre-fill | No submission in current slice | Current: no new values written | Current: no RPC | Future shared-type attribution pending | Member routed away | Future cap/region validation and optional unset behavior pending |
| SCR-05 | All six `prompted_unfilled`; contextual hints only | Mixed filled/dismissed; hints may change | N/A | Badge only | Badge only | Hint/type edits do not change fee states | N/A | Finish blocked while any untouched regardless of type (REQ-HF-1 clause 6) |
| SCR-06 | Zero entries/pledges/gifts, no due soon — see 4.4 | Bento + due soon + net after gifts only after gifts exist | N/A — local read, see §3.1 | Badge; all tiles/lists computed locally | Badge; figures unaffected | Banner naming affected figure, link SCR-16 | Read-only; local data retained | Breach, overdue scheduled item, orphan support — see 4.3 |
| SCR-07 | Empty with add and fee shortcut; due-soon empty | Grouped list and upcoming dated items | N/A | Badge; local rows fully usable | Badge | Row stamp; distinct UUID payments both visible | Read-only | Overdue/partial/refund-reopened, overpayment and schedule mismatch |
| SCR-08 | Blank entry; no schedule → virtual undated balance | Schedule and payment/refund history with derived allocations | N/A | Badge; distinct row writes available | Badge; queued events retained | Field stamp for changed row; concurrent new events both shown | Read-only | Required fields/rate, nonpositive item/payment, mismatched attribution, overpayment or schedule excess warning |
| SCR-09 | Typed blank components; virtual undated balance | Components plus schedule/payment history | N/A | Badge; save available | Badge | Component/payment-row stamps | Read-only | Component incomplete; schedule mismatch or payment over effective warned |
| SCR-10 | Allocations present immediately post-setup; never truly empty | Six rows with variance and rebalance preview action | N/A — pure local preview | Badge; Apply queues changed overrides | Badge; queue retained | Remote input invalidates open preview; refresh/reconfirm | Read-only preview, Apply disabled | Unbalanced starting sum disables Apply; locked/insufficient donors show residual breach, partial apply explicitly permitted |
| SCR-11 | N/A — only reachable from a figure or rebalance preview | Engine rule or rebalance transfers/locks and uncovered shortfall | N/A | Badge; explanation is local | Badge | Rebalance input changed → return to refreshed SCR-10 preview | Read-only, still viewable | Missing engine explanation blocks that figure; no feasible rebalance reports why |
| SCR-12 | Zero guests; crew block still shown | Matrix and list | N/A | Badge | Badge | Stamp on changed guest rows | Read-only; add suppressed | Driving count above guest cap (REQ-BS-5 clause 2) |
| SCR-13 | Zero guests valid; affordable ceiling uses costs/rates, not list count | Before/after plus separate buffer-to-keep ceiling | N/A | Badge; both previews fully local | Badge; no preview write to lose | Remote input causes recompute; unsaved preview not a conflict row | Read-only previews; commit suppressed | Over-cap result not clamped; zero-rate says no finite limit; flat+buffer shortfall says zero guests do not fit |
| SCR-14 | Zero pledges; gross = net, expected/exposure `₱0.00` | Partial/received/withdrawn groups with remaining exposure | N/A | Badge; receipts visible immediately | Badge | Receipt row additions both retained; status field winner attributed | Read-only | Orphan item support surfaced; negative net legitimate |
| SCR-15 | Blank form, zero receipts | Pledge plus receipt and direct-payment links | N/A | Badge; atomic direct-payment + receipt available | Badge; paired rows retained for retry | Separate receipt rows preserved; same-field status LWW attributed | Read-only | Missing sponsor/item detail, nonpositive receipt, invalid direct-payment link or unequal payment/receipt blocked |
| SCR-16 | Contains setup create events from plan creation; Conflicts filter may be empty | Full feed; Conflicts filter shows both values, deleted history offers Restore | Local-history pagination only (not a network read) | Badge; local entries listed as not-yet-synced | Badge | Both users see winning/superseded values, including same-user second device and tombstone suppression | Read-only; history retained, Restore disabled | Invalid projection raw values inspectable; log facts unchanged |
| SCR-17 | Solo: no partner, invite prompt; current slice shows Issue only after active solo eligibility read | Partner present, with mutual remove action available to either partner in the later lifecycle slice; current slice shows invite metadata and revoke | Current slice: membership/metadata progress blocks Issue; later lifecycle states N/A | Current slice: RPC issue/revoke unavailable, never queued; later queued removal remains planned | Current slice: membership/metadata retry; generic mutation error keeps current link until confirmed revoke | N/A — membership does not flow through the log (design.md 2.5) | Terminal state for the removed partner remains planned: local wipe and exit | Current slice: inactive/two-member plan blocks Issue; future transfer confirmation expires after 7 days |
| SCR-18 | Setup populated; reminder defaults on; consent switches separately off; current device listed; English v1 | Preferences, approved notices, grant/revoke measurement and survey separately, profile/export/sessions; v1.1 locale | N/A — local plan read; remote revoke/profile/consent response pending | No new event while consent off or partner not enrolled; unsent optional events dropped on withdrawal | Consent submission retry never silently opts in; core plan persists | Same-user edits say “You changed this on another device”; either withdrawal stops shared analysis | Read-only plan; local wipe/sign-out offered, no fresh analysis | Invalid inputs refused; shared-plan deletion blocked OQ-01; missing locale key falls back English |
| SCR-19 | Zero pending, synced | Queue and needs-attention list | Sync in progress or local migration/rebuild | Queue depth and age | Failure detail/retry; unsupported major → min-supported-build update (ADR-49) | Conflict list links to SCR-16 for **both** members | Read-only; sync halted, reason stated | State 5 shows invalid dependency/invariant, excludes affected contribution, preserves raw values; never auto-repairs |
| SCR-20 | No gifts: `₱0.00` gifts, actual supplier balances still shown; no net-after-gifts tile; invitation to add | Gifts, signed comparison, balances and orphan list | N/A — local read | Badge; add gift and reconcile offline | Badge; all local totals still visible | Both new UUID gift rows retained, attributed | Read-only history, no add/edit | Negative difference/net valid; orphan item support flagged, never silently counted |
| SCR-21 | Five unticked variant choices, no costs created | Chosen list and linked saved entries | N/A — pinned local JSON | Suggestions/editor work locally; saved entry queued | Badge; list unaffected, entry queued | Linked entry updated via normal history; suggestions do not conflict | Read-only suggestions/history, no create | Missing pinned version → no fabricated list; invalid price/supplier blocks save |
| SCR-22 | Item prompts with NEEDS VERIFICATION, none marked done or priced | Done/user dates/fees/linked ledger, no official date without verification | N/A — local read | Done/date/fee edits queued; fee creation atomic locally | Badge; queued edits retained | Independent fields LWW; duplicate fee link blocked and explained | Read-only saved checklist, no official-compliance claim | Unverified offset never shown as official; invalid fee or duplicate ledger link blocks save |
| SCR-23 | Output chooser; no file yet | Privacy preview then local PDF/CSV or full data copy | On-device generation progress only; complete account-data fetch needs online | Curated share works offline with pending-edit warning; full copy labelled local-only/incomplete | Local export still available; full online account scope retry | New local snapshot required for changed fields; no live share link to update | Read-only local-only export if retained; no account-data fetch or revocation promise | Missing derived figure blocks misleading summary; raw full copy retains recorded values |
| SCR-24 | Survey not yet eligible, consent off, or Not now deferred; no response | Eligible approved prompt, or already answered/Skipped state | Optional opted-in response awaiting acknowledgement; core app not blocked | Offline Submit queues one response; Skip saves no answer | Response stays queued for retry without duplicate; notice unavailable means no collection | First accepted plan answer wins; later partner sees Already answered | No new response or server access; optional local dismissal retained | N/A — question has no derived money |

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
5. Save. `hidden_fee_prompts.state` → `filled`. Initial entities each emit one complete create snapshot; later component quantity/rate/amount edits emit one full-group snapshot, and independent fields retain one event per changed field (ADR-44/47).
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
10. **Commit → end state:** only user-input guest/plan changes create `change_log` rows. Each device recomputes unvalued per-head effective amounts from the new driving count and saved rate **on read**; no recomputed `estimated_cents`, gross, net, allocation or explanation writes occur. Gross, net, category variance and buffer remaining update locally from the resulting inputs; B's device derives the same figures after next sync (ADR-46).

### 5.4 A sync conflict resolving and surfacing · REQ-SE-2, REQ-SE-3, REQ-SE-4, REQ-OF-5

1. Partner B goes offline on SCR-08 and sets an entry's actual amount to ₱62,000. Local write commits; queue depth 1.
2. Partner A, online, sets the **same field** on the same entry to ₱58,000. A's write syncs immediately.
3. B reconnects. The queued row pushes and the **server assigns its `server_ts` on acceptance** (Decision D1); B's device sequence (`device_monotonic`) is preserved but is not the ordering authority. Because A's write was accepted earlier, A's write carries the earlier `server_ts`.
4. Both devices order the two log rows by `(server_ts, device_monotonic, device_id)` and independently select the same winner. Under D1 **B's ₱62,000 wins**, because B's queued write was accepted later and has the later server timestamp, despite having been edited offline earlier (REQ-SE-2 clauses 3–5). Device time does not decide this.
5. Projections converge. Both devices show the same value, ₱62,000 (REQ-SE-3 clause 2).
6. **Neither write is discarded.** Both remain in `change_log`; A's value is superseded. B's row recorded an `old_value` different from the value it actually replaced immediately before application, so this is a derived stale-write conflict, not a stored flag (ADR-43).
7. **Both A's and B's devices** show one dismissible conflict banner on next replay, naming the field and linking to SCR-16; even the winning device sees that its offline edit displaced A's online value. If both devices belong to the same user, say “You changed this on another device,” never “your partner.”
8. SCR-16's **Conflicts** filter shows B's winning ₱62,000.00 and A's superseded ₱58,000.00 side by side, plus recorded old and immediately replaced values and attribution. Group edits show the full winning/losing snapshots, never a synthetic mixture.
9. **End state:** one visible current value on both devices, with both attempts retained and attributed; deletion conflicts instead show the tombstone and suppressed edits, and Restore is available for the deleted entity (§6.5).

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

### 5.7 Competitive-feature flows · ADR-53–57

1. **Rebalance (v1):** SCR-10 shows effective allocations and locks. Open preview, inspect SCR-11 for Buffer-first and largest-remainder donor transfers, then Apply changed overrides or Cancel with no write. A locked underfunded category and/or insufficient donor slack remains a named breach even after an explicitly accepted partial apply. An unbalanced starting sum prevents Apply; remote edits invalidate the preview. FIX-C expected **after explicit apply**, not at baseline: Catering & Venue ₱294,750; Photo & Video ₱59,250; Attire & Styling ₱53,000; Coordination ₱55,000; Entourage & Misc ₱38,000; Buffer ₱0, total ₱500,000. Existing FIX-C baseline/fixture is unchanged before Apply.
2. **Affordable guests (v1):** on SCR-13 enter buffer to keep; show flat subtotal, active rate sum, integer gross ceiling, current count and separate cap warning. FIX-A preview: ₱0 buffer → **193 guests**; ₱160,000 buffer → **132 guests**. Zero rate has no finite budget-based limit; flat shortfall says even zero do not fit. No write.
3. **Templates (v1):** SCR-21 shows unticked suggestions. Selecting an item enters a draft SCR-08/09, not an entry; only valid manual supplier/price Save creates cost. Cancel, type switching and untouched suggestions change no totals.
4. **Checklist (v1 target, OQ-11):** SCR-22 displays NEEDS VERIFICATION; user may mark done, enter own date and fee, independently. Wedding-date edits preserve own dates. Only explicit fee-to-ledger confirmation creates a linked cost; no preset timing or legal eligibility is asserted until item-specific source verification.
5. **Export (v1):** SCR-23 chooses a curated PDF/CSV, previews privacy scope and redactions, creates an offline file and hands it to the OS share sheet; destination copies cannot be recalled. A single-sponsor statement contains only that pledge. A separate SEC-32 Full data copy includes history/profile and is not represented as complete offline when account-only fields are missing; it is not an erasure action.

**Project-brief §4 gate:** each flow is deterministic from saved integer inputs or pinned config, displays its sources and exclusions, records no transfer/settlement (fee/payment rows record user facts only), and lists no vendors. v1.1 locale labels and private photo storage likewise neither move money nor recommend suppliers; locale is fixed ARB/fallback, photo upload gated by private plan membership. None uses invented cost benchmarks.

---

## 6. Shared-editing UI

### 6.1 Notification model — position taken

**Partner edits: in-app only; no server push in v1. Supplier due dates: local device notifications permitted (REQ-LG-9).**

Justification: two partners planning one wedding are usually co-located and often editing together. Pushing "your partner changed the flowers estimate" for every field edit produces notification fatigue fast, and the change log already provides a complete record on demand. Nothing upstream requires push, and design.md 2.6 deliberately omits realtime transport, so a push would need infrastructure that does not exist.

**Separate reminder channel:** each device schedules its own alerts from local dated, unpaid `payment_schedule_items`, with plan-level settings on SCR-18 (default 7 and 1 days before, plus overdue; off switch; independent 7-day Due soon window). Reminders work offline, do not require a server push or tell the other partner about an edit, and cancel after the item is paid/deleted. Turning off notifications does not hide Due soon. Permission denial is explained, not a budget blocker. By default lock-screen copy and accessibility announcement contain no supplier names, amounts, sponsor or giver names: “A supplier payment is due in 7 days.” Undated virtual balances never notify.

What is surfaced instead, in ascending intrusiveness:

1. **Passive** — attribution stamps on changed fields and rows. No interruption.
2. **Ambient** — activity indicator on the More tab when unseen log entries exist since last visit to SCR-16.
3. **Banner** — a dismissible banner on SCR-06, used when a remote change altered a headline figure (gross, net, buffer remaining, exposure), or on **both users' devices** when a stale-write/deletion conflict is discovered; link SCR-16.
4. **Blocking** — reserved for lifecycle events only: pending ownership-transfer confirmation, and being removed from the plan. Never for a data edit. (Defensive removal itself needs no confirmation from the removed party; the blocking surface a removed partner sees is the removed-state notice, not a confirmation prompt.)

### 6.2 Attribution

Displayed as **display name + relative timestamp**. No avatar in v1: with exactly two members, an avatar carries no information a name does not, and it consumes width that money figures need.

- Relative time under 7 days: "2 hours ago". Beyond that, absolute date per section 8.5.
- Attribution comes from stable `change_log.plan_member_id` and its live alias mapping; after account deletion, show “Former member” without rewriting history (ADR-51). An unmapped alias never grants access.
- Stamps read “You” for the current user, including another of their devices; device-specific conflict copy reads “You changed this on another device.”

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
- Filterable by member, entity type, date, and **Conflicts** (typed recorded-old vs immediately replaced value mismatch). Show current winning and superseded values together, including full compound snapshots and tombstone-suppressed edits. Not searchable in v1.
- Per-entity history is the same component filtered to one `entity_id`.
- Lifecycle actions and their confirmations appear here (REQ-SE-5 clause 8).
- Locally queued, not-yet-pushed entries appear with a pending marker so a partner sees their own offline work in context.

### 6.5 Is an overwritten value recoverable in the UI?

**Value disagreement: visible and readable, but not restorable with one tap. Deleted entity: explicit Restore action.**

The value is never lost; design.md 4.6 makes the log append-only and REQ-SE-2 clause 6 forbids discarding an accepted write. SCR-16 shows the superseded value, its author, and its timestamp.

What is deliberately **not** provided is a one-tap **value** revert. Reverting a contested amount is another write and invites a tap-war; the couple reads what happened and deliberately enters the agreed value. Separately, SCR-16 offers **Restore entry** on a deleted entity, after confirmation: a new LWW `deleted_at = null` write reopens its validated projection and children; it never rewrites history or silently selects a disputed financial value (ADR-47).

### 6.6 Is a same-field loss shown or silent?

**Shown explicitly to both members, including the writer whose value currently wins.**

Silence here would undermine confidence in shared editing. A partner who sees their entered amount replaced by another number with no explanation may conclude the app lost their work. REQ-SE-2 clause 6 requires the losing write to be preserved — so the information exists and withholding it is a choice. In §5.4 it is **A's online write** that loses after B's offline edit syncs; the banner must not imply that A was offline.

Shown on **both** devices after replay, once per discovered conflict batch, dismissible:

> **“Two changes to this entry”**
> *“[B's name]'s ₱62,000.00 actual amount is now used for [entry]. [A's name]'s ₱58,000.00 is saved in Activity. Review both changes.”*

Rules:

- Shown to **both** members, even if neither device originated the losing write. For one member editing on two devices, replace partner-name framing with “You changed this on another device.”
- Names the field, the winning and superseded values, and where both are visible. A tombstone instead reads “<name> deleted this entry; your change is saved in Activity” (or neutral attribution on the other device) with a link to its deleted history and explicit Restore.
- Never uses "overwritten", "lost", "discarded", or "failed". The write is preserved and the copy must say where.
- One banner per sync cycle regardless of conflict count, linking to SCR-16 for the full list. Twelve banners is not disclosure, it is noise.
- Non-conflicting remote changes get no conflict banner. Derive a stale-write conflict from `old_value` mismatch, not from the mere presence of a superseded row; a deleted parent suppressing a concurrent ordinary edit also triggers disclosure (ADR-43/47).

---

## 7. Offline communication

### 7.1 Indicator placement

A single **sync badge** in the header of every SCR-06 through SCR-23, always in the same position. One component, one location, the states in §7.2. Tapping it opens SCR-19.

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

**State 5 — A queued write cannot be applied, or a merged projection fails an invariant** (REQ-OF-5 clause 4, ADR-45).
Badge: `1 change needs attention`
On SCR-19 for a rejected queued write: *“One change needs attention before it can join the shared plan. It is still saved on this device. Open it for details.”* For a post-merge invariant: *“This entry needs attention: [constraint]. Its changes are saved in Activity; its affected amount is not included in totals until corrected.”* Give the raw values and correction link; no automatic write. Unknown dependency/version likewise blocks the affected figure and requests an update, not a guessed total.

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

**v1.1 plan (ADR-58, REQ-LO-1):** Flutter ARB resources for English (`app_en.arb`), Taglish (`app_tgl.arb`) and Filipino (`app_fil.arb`), selectable on SCR-18; default English and fall back per missing key to English. Keep `en_PH` money and unambiguous abbreviated-month dates independently of selected UI language; continue full-form peso accessibility labels. Never translate Kasaran, Ninong/Ninang, PSA/CENOMAR, OOT, HMUA, local acronyms, cultural nouns or any user-entered text; no runtime translation. Pseudo-localized long labels on the narrowest two-column bento and maximum dynamic type must preserve visible amounts, text meaning, and accessible full-form labels, allowing wrap/vertical growth/single-column fallback (§9.2). This does not turn v1 into a Taglish build.

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
| `SyncBadge` | connection state, pending count, oldest age, failure flag | synced, offline, offline-with-pending, stale, sync-problem, needs-attention | Header of SCR-06–23 |
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
| `ChangeLogEntry` | planMemberId, action, entity, field/group, oldValue, newValue, serverTs, deviceMonotonic, superseded, staleConflict, pendingPush | applied, superseded, stale-conflict, deleted/suppressed, former-member, pending-push, lifecycle | SCR-16, per-entity history |
| `ConflictBanner` | field/group, winningValue, supersededValue, actor/member/device relation, deletion flag | single-conflict, multiple-conflicts, deleted-entry, same-user-other-device, dismissed | SCR-06, SCR-19 |
| `ReadOnlyNotice` | reason | partner-removed, plan-deleted | All SCR-06–20 |
| `StepIndicator` | current, total, blockedReason | in-progress, blocked, complete | SCR-03, 04, 05 |
| `DateField` | value, allowPast | empty, valid, past-confirmed, invalid | SCR-03, 08, 09, 15, 20 |
| `RegionPicker` | selected, taxonomy grouped by tier | unselected, selected, destination-selected | SCR-04, 18 |
| `OptionalTypePicker` | ceremony/venue taxonomy, nullable selection, hint | not-sure-yet, selected, read-only | SCR-04, 18; hint on SCR-05 |
| `TwoPartyConfirmation` | action, initiator, confirmedBy, expiresAt | awaiting-you, awaiting-partner, expired, complete | SCR-17 |
| `RebalanceComparison` | six before/after amounts, locks, Buffer draw, donor slack/remainders, shortfalls | balanced, partial-breach, unbalanced-start, stale, read-only | SCR-10, SCR-11 |
| `AffordableGuestResult` | budget, flat effective, active rate sum, chosen buffer, cap | finite-floor, zero-shortfall, no-finite-limit, over-cap, unavailable | SCR-13 |
| `TemplateSuggestion` | pinned variant/item ID, name, category, pricing mode, linked entry | unticked, draft-editor, saved-linked, missing-ruleset, read-only | SCR-21 |
| `ChecklistRow` | item ID, verification state, done, userDate, fee, linkedEntry | untouched, done, own-date, fee-draft, linked, needs-verification, read-only | SCR-22 |
| `ExportPrivacyPreview` | output type, sections, independent guest/sponsor-name toggles, snapshot version | redacted-default, names-opted-in, csv-sensitive, sponsor-only, full-data-copy, incomplete-offline, generation-error | SCR-23 |

---

## 11. Open items and resolved former gaps

Open items first, then resolved items retained for traceability.

1. **★ Budget health graded bands — deliberately not invented.** Section 4.3. The card states five computable checks and one unavailable condition. A graded verdict needs caution thresholds, weighting, and severity ranking defined upstream first.
2. **Reference cost values.** Budget adequacy renders as unavailable until `reference_costs` is populated. Already tracked as requirements.md 13.1; noted because it is now visible in the UI.
2a. **Checklist verification OQ-11.** SCR-22 may track user decisions, dates and fees in v1, but preset applicability/offsets and authoritative legal/church dates must not ship without item-specific LGU/civil registrar/parish source verification.
2b. **Full data-copy scope review.** SEC-32 export needs authenticated profile/consent retrieval and a reviewed boundary for the requesting subject versus other contributors' personal fields; curated PDFs/four CSVs do not satisfy it. This is separate from OQ-01's counsel-gated erasure outcome.
2c. **v1.1 attachments.** Private bucket RLS, approved byte/MIME config, encrypted pending queue and Photos privacy-label update remain backlog implementation gates; no v1 uploader, OCR or public URL (ADR-59).
3. **Ownership-transfer expiry — resolved at 7 days (ADR-32).** SCR-17 shows the expiry; a timed-out confirmation leaves the plan unchanged (REQ-SE-5 clause 7).
4. **Notes limit — resolved (ADR-33).** SCR-08 uses a hard 2,000-character input limit and a live counter (REQ-LG-1 clause 8).
5. **Removed partner's local data retention.** Section 3.3 retains the local copy and SHALL offer voluntary wipe (ADR-34). Force-wipe is still open (OQ-03).
6. **Decision log — available.** `docs/decision-log.md` is an input and contains the authoritative ADRs and remaining OQs; its former absence claim is resolved (§0).

*Resolved since first draft: platform (Flutter + SQLite/`drift`), the REQ-GEN-2A constrained-display amendment (section 8.2), and ruleset configuration management (bundled JSON asset validated at app load — REQ-AE-1 clause 4 is now a load-time check, not an authoring screen).*
