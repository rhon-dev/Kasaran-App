# Kasaran — Requirements (EARS)

*Derived from [mvp-user-stories.md](./mvp-user-stories.md). Requirements are explicitly tagged **[v1]**, **[v1.1]**, or a deferred phase; REQ-EX-1 is a permanent exclusion.*

**Notation.** This document uses the full EARS keyword set, not only the event-driven form:

| Pattern | Form |
|---|---|
| Ubiquitous | THE SYSTEM SHALL … |
| Event-driven | WHEN \<trigger\>, THE SYSTEM SHALL … |
| State-driven | WHILE \<state\>, THE SYSTEM SHALL … |
| Unwanted behaviour | IF \<condition\>, THEN THE SYSTEM SHALL … |
| Optional feature | WHERE \<feature\>, THE SYSTEM SHALL … |

Each requirement carries numbered acceptance criteria. A criterion is written so that its outcome is decidable by inspection or by an automated test, with no judgement call.

---

## 0. Definitions

These terms are used with exactly these meanings throughout. Ambiguity in any requirement resolves to these definitions.

| Term | Definition |
|---|---|
| **Plan** | The single container for one wedding's budget data, shared by exactly two partners. |
| **Ledger entry** | Any cost line in the plan. Hidden-fee items are ledger entries with a specialised subtype, not a separate collection. |
| **Estimated amount** | The expected cost of a ledger entry, before the real invoice is known. |
| **Actual amount** | The confirmed cost of a ledger entry. Nullable until known. |
| **Effective amount** | `actual_amount` if non-null, otherwise `estimated_amount`. All totals use effective amount. |
| **Deposit paid** | Derived `Σ payment rows − Σ refund rows` for a live entry, including sponsor-paid supplier payments; never a cumulative stored field. |
| **Balance due** | `max(0, effective_amount − deposit_paid)` for a live entry. Overpayment is shown separately, not silently discarded. |
| **Gross event total** | Sum of `effective_amount` across all ledger entries, including hidden-fee entries. What the wedding costs. |
| **Net out-of-pocket** | Gross minus recorded pledge receipts (cash and eligible in-kind support, capped per linked entry), never minus gifts or sponsor-paid supplier payments a second time; may be negative (ADR-22). |
| **Expected pledge support** | Sum of `max(0, value − received support)` for active tentative or confirmed pledges; withdrawn pledges excluded. Never subtracted from net. |
| **Outstanding pledge exposure** | Sum of the unreceived portion of active confirmed pledges; withdrawn pledges excluded. |
| **Driving guest count** | The count of guests in the designated RSVP status (`invited` by default), regardless of priority tier; drives per-head cost calculations. |
| **Crew headcount** | Total supplier crew requiring meals. Tracked separately; never part of any guest count. |
| **Per-head entry** | A ledger entry whose effective amount is `per_head_rate × driving_guest_count`. |
| **Flat-rate entry** | A ledger entry whose effective amount is independent of any guest count. |
| **Ruleset version** | An immutable, identified snapshot of allocation baseline percentages and regional modifiers. |
| **Region** | The Philippine location classification of the wedding, carrying cost modifiers. |
| **Allocation category** | One of the six budget categories in the fixed taxonomy below. |
| **Buffer** | The allocation category reserved to absorb overruns and rounding remainder. |
| **Regional cost index** | A per-region multiplier expressing absolute cost level relative to NCR. Not a budget-share modifier — see REQ-AE-2. |
| **Expected total cost** | Sum of reference costs for the plan's size and region, multiplied by the regional cost index. |
| **RSVP status** | A guest's attendance certainty: confirmed, invited, or tentative. |
| **Priority tier** | A guest's relationship priority: Tier 1 or Tier 2. Orthogonal to RSVP status. |

### Allocation category taxonomy and NCR baselines

THE SYSTEM SHALL use exactly these six allocation categories, with these NCR baseline percentages.

| Allocation category | NCR baseline |
|---|---|
| Catering & Venue | 40% |
| Photo & Video | 15% |
| Attire & Styling | 10% |
| Coordination | 10% |
| Entourage & Miscellaneous | 5% |
| Buffer | 20% |
| **Total** | **100%** |

### Platform and technology constraints

**REQ-PLT-1 [v1]** — THE SYSTEM SHALL be built as a cross-platform Flutter application targeting Android and iOS.

1. A single Flutter codebase serves both platforms.
2. Web is out of scope for v1; no requirement in this document is satisfied by a web build alone.
3. Both platforms satisfy every requirement in this document identically.

**REQ-PLT-2 [v1]** — THE SYSTEM SHALL persist all plan data in a local-first embedded database on the device, and SHALL treat the local store as the source of truth for reads.

1. Every read is served from the local store without a network round-trip.
2. Every write commits to the local store before any sync is attempted.
3. The embedded database supports integer storage wide enough for REQ-GEN-1 centavo values.
4. The embedded database engine is SQLite, accessed via `drift` or `sqflite`. This is resolved, not deferred.

**REQ-PLT-3 [v1]** — THE SYSTEM SHALL permit exactly one active plan per account.

1. An account with an active plan cannot create a second active plan.
2. IF a partner attempts to create a second active plan, THEN THE SYSTEM SHALL block creation and name the existing active plan.
3. Being a second partner on another account's plan does not count against this limit.

---

### Monetary and rounding rules (apply to every requirement)

**REQ-GEN-1 [v1]** — THE SYSTEM SHALL store all monetary values as signed 64-bit integer centavos, and SHALL NOT use binary floating-point types for any monetary storage or arithmetic.

1. No monetary field is stored, transmitted, or computed as `float` or `double`.
2. ₱1,234.56 persists as the integer `123456`.
3. A repeated sequence of arithmetic operations on the same inputs produces a byte-identical result on every run and on both partners' devices.

**REQ-GEN-2 [v1]** — WHEN the system converts or displays a monetary value, THE SYSTEM SHALL round half-up to two decimal places and display it as PHP.

1. The **full form** is a peso sign, thousands separated by commas, exactly two decimals: `₱350,000.00`.
2. A half-centavo rounds away from zero (₱0.005 → ₱0.01).
3. No screen displays a currency symbol other than ₱, and no locale setting changes the currency.
4. A negative total, where one is arithmetically possible, displays with a leading minus inside the format: `−₱1,200.00`.
5. The full form is mandatory on full-screen detail cards, modal sheets, ledger rows, tap/expanded states, and every screen-reader accessibility label, without exception.

**REQ-GEN-2A [v1] — Constrained monetary display in bento tiles**
WHERE a monetary value is rendered inside a dashboard bento grid tile, THE SYSTEM SHALL be permitted to use a constrained form, and SHALL use the full form of REQ-GEN-2 everywhere else.

1. For an absolute value below ₱1,000,000, the constrained form drops centavos: `₱350,000`.
2. For an absolute value at or above ₱1,000,000, the constrained form uses exactly two decimal places in millions shorthand: `₱1.00M`, `₱1.20M`, `₱1.25M` (ADR-30, refining ADR-14).
3. Constrained forms SHALL truncate toward zero, so the displayed magnitude never exceeds the true magnitude: `₱1,259,000.00` renders as `₱1.25M`, `₱350,999.99` as `₱350,999`, and `−₱1,259,000.00` as `−₱1.25M`.
4. The constrained form is permitted **only** inside dashboard bento tiles. It SHALL NOT appear on detail cards, modal sheets, ledger rows, editors, previews, or the change log.
5. WHEN a partner taps a constrained figure, THE SYSTEM SHALL reveal the full form of REQ-GEN-2.
6. Every screen-reader accessibility label for a constrained figure SHALL announce the full form, never the constrained form.
7. A negative value in constrained form retains the leading minus: `−₱1,200` or `−₱1.25M`; the threshold and truncation apply to its absolute value.

---

## 1. Budget setup

**REQ-BS-1 [v1] — Required setup inputs**
WHEN a partner creates a plan, THE SYSTEM SHALL require a total budget, a wedding date, a guest cap, and a region before marking setup complete.

1. All four inputs are mandatory; setup cannot be marked complete with any one absent.
2. Total budget accepts any integer centavo value greater than 0.
3. The system accepts a total budget below ₱30,000 and above ₱500,000 without warning or block.
4. Wedding date accepts any calendar date.
5. Guest cap accepts any integer ≥ 0.
6. Region is selected from the taxonomy in REQ-BS-4; free-text region is rejected.
7. On completion the system produces a category allocation per REQ-AE-1 and routes the partner to the hidden-fee prompts per REQ-HF-1.
8. WHERE the partner supplies a ceremony type, THE SYSTEM SHALL accept exactly {church, civil, other religious, garden/beach officiant, other}; `Not sure yet` leaves the optional type unset and does not block setup.
9. WHERE the partner supplies a venue type, THE SYSTEM SHALL accept exactly {hotel, garden, beach/resort, restaurant, events place, other}; `Not sure yet` leaves the optional type unset and does not block setup.
10. WHEN either optional type is chosen or changed, THE SYSTEM SHALL change only relevant hidden-fee hint copy (for example civil: church aircon usually does not apply; garden/beach: venue power is often needed), SHALL NOT write an amount or dismiss a fee, and SHALL still require decisions on all six prompts under REQ-HF-1.

**REQ-BS-2 [v1] — Rejection of invalid setup input**
IF a partner submits a total budget that is non-numeric, zero, or negative, THEN THE SYSTEM SHALL reject the submission, retain all other entered values, and display an inline message naming the offending field and the reason.

1. Input `0` is rejected with a message stating the budget must be greater than zero.
2. Input `-5000` is rejected with a message stating the budget cannot be negative.
3. Input `abc` is rejected with a message stating the budget must be a number.
4. After rejection, previously entered date, guest cap, and region values remain populated.
5. No partial plan is persisted as complete when a rejection occurs.

**REQ-BS-3 [v1] — Wedding date in the past**
IF the wedding date entered is earlier than the device's current date, THEN THE SYSTEM SHALL warn the partner and SHALL permit the value to be saved after explicit confirmation.

1. A past date triggers a warning that names the date and asks for confirmation.
2. Confirming saves the past date and does not block any other feature.
3. Declining returns to the field with the prior value restored.
4. A past wedding date does not suppress overdue calculation in REQ-LG-5.

**REQ-BS-4 [v1] — Region taxonomy and cost tiers**
THE SYSTEM SHALL classify wedding location using a fixed, versioned region taxonomy in which every region maps to exactly one cost tier carrying a regional cost index.

1. The taxonomy defines exactly three cost tiers with these indices:

   | Cost tier | Regional cost index | Regions |
   |---|---|---|
   | Metro | 1.00 | NCR / Metro Manila |
   | Provincial | 0.85 | Nearby Luzon (Tagaytay, Batangas, Laguna, Cavite, Rizal, Bulacan, Pampanga), Baguio / Northern Luzon, Cebu, Bohol, Davao, Iloilo, Bacolod, Other Visayas, Other Mindanao |
   | Destination | 1.20 | Boracay / Aklan, Palawan (Puerto Princesa, El Nido, Coron), Siargao |

2. Every region maps to exactly one cost tier; no region is unmapped.
3. Region records, `is_destination` flags, and tier indices are configuration data, versioned with the bundled ruleset, and changeable without changing engine code.
4. WHERE a region has `is_destination = true`, THE SYSTEM SHALL default the OOT prompt in REQ-HF-3 to enabled, independently of its cost tier. Bohol has `is_destination = true` while retaining the Provincial cost index 0.85; Boracay / Aklan, Palawan, and Siargao also have `is_destination = true` (ADR-29).
5. Selecting a region never itself creates, deletes, or modifies a ledger entry.
6. The regional cost index is applied only as specified in REQ-AE-2, and SHALL NOT be applied to allocation shares; `is_destination` controls OOT defaulting and SHALL NOT itself change the cost index.

**REQ-BS-5 [v1] — Guest cap is a ceiling, not a cost driver**
THE SYSTEM SHALL treat guest cap as a partner-set ceiling used for warnings only, and SHALL NOT use guest cap as the driving guest count.

1. Guest cap never appears as a multiplier in any per-head calculation.
2. WHEN the driving guest count exceeds the guest cap, the system displays a persistent over-cap indicator stating both numbers.
3. Exceeding the guest cap does not block any edit, entry, or calculation.
4. Guest cap is editable at any time after setup.

**REQ-BS-6 [v1] — Editing setup without data loss**
WHEN a partner changes any setup input after completion, THE SYSTEM SHALL recompute engine-derived allocations and SHALL preserve all manual overrides, ledger entries, hidden-fee items, pledges, and guest data.

1. Changing total budget, region, or guest cap destroys no ledger entry, pledge, or guest record.
2. Manual allocation overrides survive the change, per REQ-AE-5.
3. WHERE a change alters more than one category allocation, the system displays a before/after preview prior to applying it.
4. Cancelling the preview persists nothing; a subsequent read returns the pre-edit state exactly.
5. An applied setup change is recorded in the change log per REQ-SE-4.

---

## 2. Expense ledger

**REQ-LG-1 [v1] — Ledger entry fields**
THE SYSTEM SHALL provide each ledger entry with a category, supplier name, estimated amount, optional actual amount, entry type, and notes; schedule items and payments SHALL be separate records.

1. Category is selected from the fixed taxonomy; free-text category values are rejected.
2. Supplier name accepts any non-empty string up to 200 characters.
3. A flat-rate entry SHALL store a mandatory estimated amount ≥ 0. A per-head entry SHALL store its nonnegative rate and derive its displayed estimate on read from that rate and the driving count; its `estimated_cents` column SHALL be null, never a synced or written-back derived estimate (REQ-GM-2, REQ-OF-2 cl. 4, ADR-46).
4. Actual amount is optional and, when set, is ≥ 0.
5. Deposit paid SHALL NOT be stored on an entry; it is derived from the separate payment and refund records per REQ-LG-4.
6. Due date SHALL NOT be stored on an entry; dated obligations belong to REQ-LG-7 schedule items, and entries without a schedule have a virtual undated balance.
7. Entry type is exactly one of: standard, or one of the six hidden-fee subtypes in REQ-HF-2.
8. WHEN a partner enters notes, THE SYSTEM SHALL show a live character counter, accept at most 2,000 characters, and stop accepting input at the limit without silently truncating existing text (ADR-33).

**REQ-LG-2 [v1] — Ledger CRUD by either partner**
THE SYSTEM SHALL permit both partners to create, read, update, and delete any ledger entry in the plan.

1. No ledger field is read-only to one partner and writable to the other.
2. Every create, update, and delete is attributed in the change log per REQ-SE-4.
3. WHEN a partner requests deletion, the system requires an explicit confirmation before removing the entry.
4. A deleted entry is removed from all totals immediately on confirmation.

**REQ-LG-3 [v1] — Estimated versus actual**
THE SYSTEM SHALL use effective amount for every total, and SHALL display estimated and actual amounts as distinct values wherever an entry is shown in detail.

1. An entry with estimated ₱50,000 and no actual contributes ₱50,000 to gross event total.
2. Setting actual to ₱62,000 on that entry changes its contribution to ₱62,000 in the same operation.
3. Clearing actual back to null returns the contribution to ₱50,000.
4. Entry detail views show both values, labelled, without requiring navigation.
5. An entry where actual differs from estimated is visually marked, using a cue that is not colour alone.

**REQ-LG-4 [v1] — Derived deposits and balance**
WHEN a partner inserts a payment or refund record on an entry, THE SYSTEM SHALL recompute that entry's deposit paid, balance due, and the plan's paid and outstanding totals.

1. Deposit paid SHALL equal the sum of positive `payment` amounts minus the sum of positive `refund` amounts on non-deleted records for each live entry; no cumulative deposit field is persisted.
2. Balance due SHALL equal `max(0, effective amount − deposit paid)`; IF deposit paid exceeds effective amount, THEN THE SYSTEM SHALL display an overpayment warning naming both amounts without clamping the derived deposit paid.
3. The plan SHALL report summed derived deposits paid and summed balance due across live entries, recomputed after each relevant insert, refund, actual-cost edit, or deletion.
4. Recording a payment or refund SHALL NOT alter estimated amount, actual amount, or gross event total; a discount SHALL be recorded by lowering actual amount, not by a negative actual or negative payment.
5. Recording a payment, refund, or method SHALL NOT initiate, authorise, or transfer funds (REQ-AI-4 remains post-launch).

**REQ-LG-5 [v1] — Derived payment status**
THE SYSTEM SHALL derive each entry's payment status as exactly one of `paid`, `pending`, `due soon`, or `overdue`, and SHALL NOT store payment status as a directly editable field.

1. Status is `paid` when balance due equals 0.
2. Status SHALL be `overdue` when balance due is greater than 0 and any unpaid schedule item has a due date earlier than the device's current local date; this takes precedence over `due soon`.
3. Status SHALL be `due soon` when balance due is greater than 0, none is overdue, and an unpaid schedule item is due from today through the plan's configured reminder window inclusive; otherwise it SHALL be `pending`.
4. An entry with positive deposit paid and positive balance due SHALL display an additional partially-paid indicator regardless of whether its status is pending, due soon, or overdue.
5. No user interface permits setting status directly; status changes only as a consequence of amount or date changes.
6. Status is recomputed on every read and is never persisted as authoritative state, so that two devices with different clocks cannot produce a sync conflict on status.
7. Status recomputation SHALL use the device's local current date while offline, per REQ-OF-4; a virtual undated obligation alone SHALL remain pending rather than overdue or due soon.
8. THE SYSTEM SHALL allocate net paid amounts to schedule items by due date ascending, then sort_order ascending, then id ascending (undated items after dated items), and derive each item's paid, partially paid, due soon, or overdue state from its allocated balance; `schedule_item_id` is attribution only and SHALL NOT override this allocation order.

**REQ-LG-6 [v1] — Planned versus actual variance**
THE SYSTEM SHALL display variance between allocated and effective amounts per category and for the plan total, in both peso amount and percentage.

1. Variance amount equals summed effective amount minus allocated amount for the category.
2. Variance percentage equals variance amount divided by allocated amount, rounded half-up to one decimal place.
3. IF allocated amount is 0 and effective amount is greater than 0, THEN the system displays the peso variance and suppresses the percentage rather than dividing by zero.
4. Over-allocation and under-allocation are distinguished by a cue that is not colour alone.
5. Variance updates within the same operation as any change to an allocation, estimated amount, or actual amount.

**REQ-LG-7 [v1] — Payment schedules**
WHERE a partner plans instalments, THE SYSTEM SHALL keep separate schedule items for a ledger entry rather than an entry-level due date.

1. Each item SHALL have a client-generated id, entry_id, kind in {reservation, downpayment, installment, balance, custom}, label, due_date, positive amount_cents, sort_order, and optional deleted_at; either partner SHALL be able to add, edit, and soft-delete items offline.
2. WHEN an entry has no live schedule items, THE SYSTEM SHALL derive one virtual undated balance of its effective amount; it SHALL NOT persist an implicit item or assign a due date (ADR-36).
3. WHEN live schedule items sum to less than the effective amount, THE SYSTEM SHALL derive a virtual undated residual for the difference, without persisting it; IF they sum above the effective amount, THEN THE SYSTEM SHALL show a schedule-over-total validation error and refuse the edit.
4. A virtual balance or residual SHALL participate in payment allocation after dated schedule items and SHALL NOT generate dated reminders; editing actual amount SHALL recompute the residual and validate the schedule without deleting payment history.

**REQ-LG-8 [v1] — Payment and refund records**
WHEN a partner records supplier money movement, THE SYSTEM SHALL insert a distinct payment record and SHALL NOT overwrite a cumulative amount.

1. Each record SHALL have client-generated id, entry_id, nullable schedule_item_id, kind in {payment, refund}, amount_cents > 0, paid_on, method in {cash, bank_transfer, gcash, maya, check, other}, nullable paid_by_pledge_id (null means couple-paid), note, and optional deleted_at.
2. A refund SHALL be a positive-amount record of kind `refund`, subtract from derived deposit paid, and be capable of reopening balance and changing status; negative amounts and negative actuals SHALL be rejected.
3. WHEN two partners insert different payments while offline, THE SYSTEM SHALL retain both distinct IDs on reconciliation and count each once (including idempotent replay), with attribution and audit history; no last-write-wins cumulative deposit SHALL replace either.
4. WHERE schedule_item_id is set, THE SYSTEM SHALL require that item to belong to the same entry; the reference attributes the transaction but SHALL NOT change the due-date allocation of REQ-LG-5 clause 8.

**REQ-LG-9 [v1] — Local due-date reminders**
WHERE a plan has dated schedule items, THE SYSTEM SHALL schedule due-date notifications locally on each device from its own local data, including while offline, and SHALL NOT use server push for reminders or partner edits.

1. For each unpaid dated item, default reminders SHALL be 7 and 1 calendar days before due date and one overdue reminder after it; a device SHALL not deliver a reminder for a fully paid or deleted item.
2. THE SYSTEM SHALL permit a per-plan configurable reminder window and reminder timing, including an off switch; changing settings or payments SHALL reschedule or cancel affected local notifications on that device.
3. Lock-screen notification copy SHALL default to generic wording without supplier names or amounts (for example, “A supplier payment is due in 7 days”); no names or amounts SHALL appear in default notifications or accessibility announcement text.
4. The ledger and dashboard SHALL expose a Due soon list of unpaid items within the configured window, with entry detail navigation; disabling notifications SHALL not conceal due-soon status or list items.

---

## 3. Hidden-fee line items

**REQ-HF-1 [v1] — All six prompted, none silently defaulted**
WHEN budget setup completes, THE SYSTEM SHALL prompt the partner for all six hidden-fee categories, and SHALL initialise each in a `prompted-unfilled` state rather than a zero value.

1. The six prompted categories are: crew meals, OOT fees, church aircon fee, corkage fees, overtime, venue power.
2. No category initialises with amount 0; `prompted-unfilled` is distinguishable from a filled amount of 0.
3. Each category can be filled or explicitly dismissed.
4. WHEN a partner dismisses a category, the system records the dismissal with a timestamp and the dismissing partner's identity.
5. WHILE any of the six remains in `prompted-unfilled` state, the system displays it as an outstanding risk on the dashboard.
6. IF a partner attempts to mark setup complete while any of the six is untouched, THEN THE SYSTEM SHALL block completion and name each untouched category.
7. A dismissed category contributes exactly 0 to gross event total.

**REQ-HF-2 [v1] — Fee-specific input shapes**
THE SYSTEM SHALL model each hidden-fee subtype with its own input fields and its own computation, and SHALL NOT reduce them to a single generic amount field.

1. **Crew meals** accept a per-supplier crew headcount and a per-meal rate; the entry total equals the sum over suppliers of `crew_headcount × per_meal_rate`.
2. **OOT fees** accept, per supplier, separate travel, lodging, and per-diem amounts; the entry total is their sum across suppliers.
3. **Church aircon fee** accepts a single flat amount.
4. **Corkage fees** accept multiple sub-entries, each with an item type from {cake, wine, liquor, lechon, other} and an amount; the entry total is their sum.
5. **Overtime** accepts, per supplier, an hourly rate and projected hours; the entry total equals the sum of `hourly_rate × projected_hours`.
6. **Venue power** accepts separate generator, surcharge, and electrical-requirement amounts.
7. Each hidden-fee entry appears in gross event total as its own attributable line and is never merged into a parent category's single figure.
8. Crew meals total independently of guest catering and are excluded from per-head recalculation per REQ-GM-4.
9. THE SYSTEM SHALL assign crew meals, church aircon, corkage, and venue power to Catering & Venue, and OOT fees and overtime to Coordination. Each fee SHALL display its assigned category as a read-only label; partners SHALL NOT reclassify these six subtypes.

**REQ-HF-3 [v1] — Region-driven OOT defaulting**
WHERE the selected region carries a destination flag, THE SYSTEM SHALL default the OOT prompt to enabled and SHALL leave its amounts unfilled.

1. Selecting Palawan, Boracay, Siargao, or Bohol enables the OOT prompt by default based on `is_destination = true`, regardless of cost tier; Bohol remains Provincial at 0.85 (REQ-BS-4).
2. Selecting NCR leaves the OOT prompt available but not defaulted to enabled.
3. Defaulting affects only the prompt state; it never writes an amount.
4. The partner can dismiss a defaulted-enabled OOT prompt, and the dismissal is recorded per REQ-HF-1.

---

## 4. Incoming pledges

**REQ-PL-1 [v1] — Pledge record**
THE SYSTEM SHALL provide each pledge with a sponsor name, sponsor role, pledge type, value, status, and an optional link to a ledger category or entry.

1. Sponsor name accepts any non-empty string up to 200 characters.
2. Sponsor role is one of {Ninong, Ninang, secondary_sponsor, family, friend, other}; WHERE secondary_sponsor is selected, THE SYSTEM SHALL require a sub-role in {candle, veil, cord}, and SHALL reject that sub-role for all other roles.
3. Pledge type is either `cash` or `item`.
4. An `item` pledge records the item sponsored as free text up to 200 characters, and may link to a ledger category or a specific entry.
5. Value is an integer centavo amount ≥ 0.
6. Editable lifecycle status is exactly one of {tentative, confirmed, withdrawn}; `received` is derived only when at least one live receipt exists AND cumulative live receipts reach or exceed pledged value, and is not manually selectable (ADR-37). An explicit `withdrawn` takes precedence in the displayed status even if that receipt threshold was reached; historical receipts remain credited (ADR-38).
7. Both partners can create, read, update, and delete any pledge.
8. WHERE both linked_entry_id and linked_category_code are present, THE SYSTEM SHALL use the entry link as the authoritative support target and its category, not apply the receipt twice; a deleted linked entry SHALL retain historical receipts but exclude linked support from live net and flag reconciliation (ADR-39).

**REQ-PL-2 [v1] — Gross and net displayed together; net reduced only on fulfillment**
THE SYSTEM SHALL display gross event total and net out-of-pocket simultaneously, and SHALL compute net as gross minus eligible recorded pledge receipts; a partial receipt counts immediately under D2, not only when the pledge is fully received.

1. Both figures are visible on the dashboard without navigation or scrolling past a fold.
2. Net SHALL equal gross when no eligible receipt exists; an unfunded confirmed pledge SHALL leave net unchanged.
3. WHEN ₱25,000 is received against a ₱50,000 pledge and ₱350,000 gross, THE SYSTEM SHALL show ₱325,000 net immediately; a further ₱25,000 receipt SHALL produce ₱300,000 net and derived `received` status.
4. A confirmed but unreceived ₱50,000 pledge SHALL leave ₱350,000 gross and net unchanged and contribute ₱50,000 to expected support under REQ-PL-3.
5. Gross SHALL never change as a consequence of pledge status, receipt, or gift changes.
6. WHEN a receipt is added or a linked entry is deleted, THE SYSTEM SHALL recompute gross, net, expected support, and exposure from live data in the same operation; sponsor-paid payments SHALL NOT be subtracted again from net.
7. Net SHALL NOT be floored at zero; IF eligible receipts exceed gross, THEN THE SYSTEM SHALL display the negative amount per REQ-GEN-2.

**REQ-PL-3 [v1] — Expected pledges shown distinctly and excluded from net**
THE SYSTEM SHALL compute expected support as the remaining unreceived portion of each live tentative or confirmed pledge, display it distinctly from net, and exclude it from net.

1. A `tentative` or `confirmed` pledge of ₱50,000 with no receipts SHALL leave net unchanged and add ₱50,000 to expected support.
2. The expected figure is displayed under a label that distinguishes it from net (e.g. "expected pledge support"), never merged into net.
3. WHEN a ₱50,000 pledge receives ₱20,000, expected support SHALL decrease to ₱30,000 and net SHALL decrease by ₱20,000 immediately; additional receipts SHALL reduce expected support no lower than zero.
4. The expected figure and net are never summed into a single displayed figure.
5. THE SYSTEM SHALL make clear in the display that the expected figure is not yet realized money.
6. WHEN a pledge is explicitly withdrawn, THE SYSTEM SHALL exclude its remaining unreceived portion from expected support while preserving its historical receipts as eligible net support (subject to REQ-PL-7).

**REQ-PL-4 [v1] — Outstanding (confirmed-but-unfulfilled) exposure**
THE SYSTEM SHALL compute outstanding pledge exposure as the summed unreceived portion of active confirmed pledges, and SHALL display it distinctly from gross, net, and expected support.

1. WHEN a confirmed ₱50,000 pledge receives ₱20,000, exposure SHALL decrease to ₱30,000 and net SHALL decrease by ₱20,000; at ₱50,000 cumulative receipts exposure SHALL be zero.
2. The system SHALL list individual active confirmed pledges with their remaining unreceived amounts; a withdrawn pledge SHALL be absent from the exposure list, without deleting history or undoing prior receipts.
3. Outstanding exposure displays as ₱0.00, not blank, when no pledge is confirmed-not-received.

**REQ-PL-5 [v1] — Pledge traceability**
WHEN a partner inspects net out-of-pocket, THE SYSTEM SHALL show which pledges reduced it and by how much.

1. The breakdown SHALL list each contributing pledge with sponsor name, current/derived status, each eligible receipt and its applied value, including partially fulfilled and withdrawn pledges with historical receipts.
2. The listed eligible applied values SHALL sum exactly to gross minus net, including negative-net cases; a gift and a sponsor-paid supplier payment SHALL not add another subtraction.
3. An unreceived tentative, confirmed, or withdrawn pledge SHALL be absent; a received portion of any non-deleted pledge SHALL be present, except support linked to a deleted entry, which SHALL be shown separately as needing reconciliation.

**REQ-PL-6 [v1] — Insert-only pledge receipts**
WHEN support actually arrives, THE SYSTEM SHALL record a distinct receipt rather than overwrite a cumulative received amount.

1. Each receipt SHALL have a client-generated id, pledge_id, amount_cents > 0, received_on, optional note, optional deleted_at, and nullable `payment_id` UNIQUE foreign key to `payments.id`; cash receipts SHALL have null payment_id.
2. WHEN at least one non-deleted receipt exists AND their sum reaches or exceeds pledge value, THE SYSTEM SHALL derive `received` from their sum (never persist or manually set it); a zero-value pledge with no receipt SHALL remain tentative or confirmed, and partial receipts SHALL reduce net immediately (ADR-37).
3. WHEN two partners add distinct offline receipts, THE SYSTEM SHALL retain both IDs on sync and count each exactly once on replay; no cumulative received value SHALL be last-write-wins overwritten.
4. WHEN a pledge is withdrawn, THE SYSTEM SHALL preserve its receipts and their net effects while excluding the remaining unreceived portion from expected support and exposure (ADR-38).

**REQ-PL-7 [v1] — In-kind and supplier-direct support**
WHERE a pledge sponsors an item or supplier payment, THE SYSTEM SHALL keep gross cost attributable to the ledger entry and apply received support to net at most once.

1. For item pledges linked to the same entry, THE SYSTEM SHALL cap their combined eligible in-kind receipt contribution to net at that entry's effective amount (allocate cap by received_on then receipt id for deterministic attribution); support exceeding the shared cap SHALL remain visible in history but SHALL NOT reduce net further through that link.
2. WHEN a sponsor directly pays a supplier, THE SYSTEM SHALL atomically create one positive pledge receipt and one positive supplier payment of equal amount, with `receipt.payment_id` referencing that payment and `payment.paid_by_pledge_id` referencing that pledge; an incomplete pair SHALL NOT commit (ADR-39).
3. THE SYSTEM SHALL enforce unique receipt.payment_id and matching pledge, entry, and amount on the pair; duplicate replay or a second partner's conflicting offline attempt to pair the same payment SHALL yield one eligible pair and an explicit reconciliation conflict, not a duplicate net deduction or payment.
4. A sponsor-paid supplier payment SHALL reduce the entry's balance due, while the matching receipt SHALL reduce net once; the payment SHALL NOT independently reduce net.
5. WHERE both entry and category links exist, THE SYSTEM SHALL apply the entry link first and never count the category link additionally; WHEN the linked entry is deleted, THE SYSTEM SHALL exclude its linked support from live net, preserve receipts and payment history, and flag the orphan for reconciliation (ADR-39).

---

## 4A. Day-of gifts

**REQ-GF-1 [v1] — Received gifts**
WHEN a partner records a day-of gift (sobre/envelope, money dance, cash, or bank transfer), THE SYSTEM SHALL create a separate gift record rather than a pledge or supplier payment.

1. Each `gifts_received` row SHALL have a client-generated id, source in {sobre, money_dance, cash, bank_transfer, other}, positive amount_cents, received_on, optional giver name, optional note, and optional deleted_at; both partners SHALL be able to add, inspect, and soft-delete gifts offline.
2. Gifts SHALL NOT change gross, net out-of-pocket, pledge expected support, or pledge exposure; WHEN at least one live gift exists, THE SYSTEM SHALL display a separate `net after gifts = net out-of-pocket − Σ live gifts` figure, which may be negative (ADR-40).
3. WHEN two devices add different offline gift rows, THE SYSTEM SHALL retain both and sum each exactly once after idempotent sync; an absent or deleted gift SHALL not trigger the extra figure.

**REQ-GF-2 [v1] — Post-wedding reconciliation**
WHEN a partner opens the post-wedding reconcile view, THE SYSTEM SHALL compare recorded gifts against supplier balances without moving money.

1. THE SYSTEM SHALL display total live gifts, total outstanding balance due across live entries, and their difference (`gift total − outstanding balances`) with full PHP formatting; a shortfall and a surplus SHALL be distinguishable without colour alone.
2. WHEN payments, refunds, gifts, or effective amounts change, THE SYSTEM SHALL recalculate the comparison on read; it SHALL NOT persist the derived totals or imply a bank balance or payout.

---

## 5. Guest math

**REQ-GM-1 [v1] — RSVP status and priority tier are separate axes**
THE SYSTEM SHALL record for every guest both an RSVP status and a priority tier, as two independent fields, and SHALL derive the driving guest count from RSVP status.

1. RSVP status is exactly one of {confirmed, invited, tentative}.
2. Priority tier is exactly one of {Tier 1, Tier 2}, where Tier 1 denotes close family and principal sponsors and Tier 2 denotes general or standard guests.
3. A newly added guest defaults to priority tier Tier 2.
4. A newly added guest's RSVP status is set explicitly and does not default silently to confirmed.
5. The two fields are independently editable; changing one never changes the other.
6. WHEN a plan is created, THE SYSTEM SHALL default the designated driving RSVP status to `invited`; the designated status is visible wherever per-head totals are shown and drives the guest count (ADR-31).
7. WHEN a partner changes the designated RSVP status, every per-head entry recomputes in the same operation.
8. THE SYSTEM SHALL report guest counts broken down by priority tier within the driving RSVP status.
9. In v1, THE SYSTEM SHALL use one per-head rate per entry, regardless of priority tier. Tier 1 and Tier 2 SHALL NOT have distinct per-head rates; priority tier drives only the Tier 2-first cut-list in REQ-GM-5 clause 9 (ADR-35).
10. Crew headcount is stored separately and is excluded from all guest counts and both axes.

**REQ-GM-2 [v1] — Per-head versus flat-rate classification**
THE SYSTEM SHALL classify every ledger entry as either per-head or flat-rate, and SHALL require a per-head rate for per-head entries.

1. Entry classification is explicit; no entry is unclassified.
2. A per-head entry stores a per-head rate ≥ 0 and derives its effective amount as `per_head_rate × driving_guest_count`.
3. A flat-rate entry's effective amount is independent of every guest count.
4. Changing an entry from flat-rate to per-head requires a per-head rate before the change is accepted.
5. IF a partner sets an actual amount on a per-head entry, THEN the actual amount takes precedence over the derived per-head calculation, and the system marks the entry as manually valued.

**REQ-GM-3 [v1] — Guest count propagation**
WHEN the driving guest count changes, THE SYSTEM SHALL recompute every per-head entry, the gross event total, the net out-of-pocket, and every per-category variance within the same operation.

1. Changing the driving count from 150 to 180 multiplies each per-head entry's derived amount by exactly 180 in place of 150.
2. Flat-rate entries are unchanged by the operation.
3. Gross, net, and variance all reflect the new count before the operation reports completion; no figure lags by a refresh.
4. Entries marked manually valued per REQ-GM-2 are not recomputed.

**REQ-GM-4 [v1] — Crew meals excluded from guest scaling**
THE SYSTEM SHALL exclude crew-meal entries from guest-count propagation.

1. A change to any guest tier leaves the crew-meals total unchanged.
2. Crew-meal totals change only in response to a change in crew headcount or per-meal rate.
3. Crew headcount is never displayed as part of a guest total.

**REQ-GM-5 [v1] — "What if we add N guests" preview**
WHEN a partner requests a guest what-if for a hypothetical count, THE SYSTEM SHALL compute and display the full projected impact without persisting any change.

1. The preview accepts either an absolute hypothetical count or a delta of N additional guests.
2. The preview displays before and after values for gross, net, and every affected category.
3. The preview displays the per-guest marginal cost, computed as the change in gross divided by the change in guest count.
4. IF the hypothetical count exceeds the guest cap, THEN the preview displays an over-cap indicator and still returns the full calculation.
5. WHILE a preview is open, no plan data is modified, and a concurrent read from the other partner's device returns pre-preview values.
6. WHEN a partner discards a preview, the plan state is byte-identical to its pre-preview state.
7. WHEN a partner commits a preview, the driving guest count updates and REQ-GM-3 propagation applies.
8. A preview is never synced to the other partner's device before commit.
9. WHERE a partner previews a guest reduction, THE SYSTEM SHALL report how many Tier 2 guests would need removing to reach the target count before any Tier 1 guest is affected.

**REQ-GM-6 [v1] — Affordable-guest ceiling (ADR-54)**
WHEN a partner requests an affordable-guest preview on SCR-13, THE SYSTEM SHALL calculate a gross-cost ceiling from the live ledger and the partner's chosen nonnegative buffer to keep, without modifying the plan.

1. THE SYSTEM SHALL sum effective amounts of live flat entries, manually valued per-head entries and crew-meal entries as `flat_effective_cents`, and sum nonnegative rates of live, non-manually-valued per-head entries as `active_rate_cents`; tombstoned entries SHALL contribute to neither sum. Priority tiers SHALL NOT change rates.
2. IF `active_rate_cents > 0` and `budget_cents − flat_effective_cents − buffer_to_keep_cents ≥ 0`, THEN THE SYSTEM SHALL show `floor((budget_cents − flat_effective_cents − buffer_to_keep_cents) / active_rate_cents)` using integer division and expose all three inputs and the current designated driving RSVP status/count.
3. IF that numerator is negative, THEN THE SYSTEM SHALL show a ceiling of zero and the positive shortfall even at zero guests; it SHALL NOT claim zero guests fits.
4. IF `active_rate_cents = 0`, THEN THE SYSTEM SHALL say “No per-head costs; no finite budget-based guest limit” rather than display infinity or divide by zero; IF flat costs plus the chosen buffer exceed budget, THE SYSTEM SHALL additionally show the zero-guest shortfall.
5. THE SYSTEM SHALL NOT subtract pledges, gifts or supplier payments from gross affordability, clamp the ceiling to guest cap, or write the preview. IF the ceiling exceeds cap, THEN THE SYSTEM SHALL show the cap warning separately; cancel leaves the plan byte-identical.

---

## 6. Rule-based allocation engine

**REQ-AE-1 [v1] — Deterministic allocation from configurable baselines**
WHEN budget setup completes, THE SYSTEM SHALL allocate the total budget across the six allocation categories using the configured baseline percentages, from a pinned ruleset version.

1. Given identical inputs and an identical ruleset version, the engine returns identical allocations on every invocation and on both devices.
2. Default baseline percentages are Catering & Venue 40%, Photo & Video 15%, Attire & Styling 10%, Coordination 10%, Entourage & Miscellaneous 5%, Buffer 20%.
3. Baseline percentages are stored as configuration data in a JSON ruleset asset bundled in the app binary for v1, editable without changing engine code. There is no web authoring dashboard in v1.
4. Baseline percentages across all six categories sum to exactly 100%, and THE SYSTEM SHALL reject a ruleset asset whose baselines do not, at app-load validation time.
5. The sum of allocations equals the total budget exactly.
6. WHEN percentage division produces a rounding remainder, THE SYSTEM SHALL assign the entire remainder to the Buffer category.
7. A ₱350,000 NCR budget allocates ₱140,000.00 to Catering & Venue, ₱52,500.00 to Photo & Video, ₱35,000.00 to Attire & Styling, ₱35,000.00 to Coordination, ₱17,500.00 to Entourage & Miscellaneous, and ₱70,000.00 to Buffer.
8. THE SYSTEM SHALL NOT use inference, prediction, learned models, training data, or any generative component in allocation.

**REQ-AE-2 [v1] — Regional cost index applies to cost expectation, not to budget share**
THE SYSTEM SHALL apply the regional cost index to reference cost benchmarks and derived rate suggestions, and SHALL NOT apply it to allocation share percentages.

*Rationale, binding on implementation: a cost index applied uniformly to every baseline percentage and then renormalised returns the original percentages unchanged, because the common factor cancels. A uniform index therefore cannot alter how a fixed budget is sliced. It expresses how much a wedding costs in that region, which is a statement about budget adequacy and about absolute rates, not about proportion.*

1. Allocation share percentages are identical across all three cost tiers for identical inputs.
2. Expected total cost equals the summed reference cost for the plan's guest count multiplied by the region's cost index.
3. THE SYSTEM SHALL display a budget adequacy indicator comparing total budget against expected total cost, stating the shortfall or surplus in pesos.
4. A ₱350,000 budget in a Destination-tier region with an expected total cost of ₱420,000.00 displays a shortfall of ₱70,000.00.
5. THE SYSTEM SHALL apply the regional cost index to suggested per-head rates and to suggested OOT fee defaults, as suggestions only.
6. A suggested value produced under clause 5 is never written to a ledger entry without explicit partner action.
7. WHERE a region additionally defines per-category skew multipliers, THE SYSTEM SHALL apply them to baseline percentages and renormalise so allocations still sum exactly to the total budget.
8. Per-category skew multipliers default to 1.0 for every category in every region, so that by default no region alters allocation shares.
9. Cost index and skew values are configuration data, versioned with the ruleset.

**REQ-AE-3 [v1] — Ruleset version pinning**
WHEN a plan is created, THE SYSTEM SHALL pin the ruleset version then in force, and SHALL NOT retroactively apply a later ruleset to that plan without explicit partner action.

1. The pinned version identifier is stored on the plan and is visible to the partners.
2. Publishing a new ruleset leaves every existing plan's allocations numerically unchanged.
3. WHERE a partner opts into a newer ruleset, the system displays a before/after preview prior to applying it.
4. Adopting a newer ruleset preserves manual overrides per REQ-AE-5.

**REQ-AE-4 [v1] — Explainability**
WHEN a partner inspects any engine-produced figure, THE SYSTEM SHALL display the rule identifier, the input values, and the factors that produced it.

1. Every allocated figure exposes its originating rule identifier.
2. For an allocation, THE SYSTEM SHALL explain the baseline percentage, the per-category skew multiplier (1.0 by default), and the resulting amount. THE SYSTEM SHALL state that the regional cost index affects expected cost and rate suggestions only, not allocation shares (ADR-11).
3. The explanation is rendered in plain language, not as a raw formula or code expression.
4. THE SYSTEM SHALL NOT display any allocation figure that cannot be traced to a rule and its inputs.

**REQ-AE-5 [v1] — Manual override**
WHEN a partner overrides a category allocation, THE SYSTEM SHALL store the override, mark the category as overridden, and rebalance only non-overridden categories.

1. An override accepts any integer centavo value ≥ 0.
2. An overridden category displays both the override value and the original engine value.
3. Recomputation triggered by any setup change preserves every override.
4. IF the sum of overrides exceeds the total budget, THEN THE SYSTEM SHALL display an over-allocation warning naming the excess amount, and SHALL NOT reduce any override to fit.
5. A partner can revert an override, after which the category returns to the engine value.
6. Reverting one override does not affect any other override.
7. `engine_cents` and its rule explanation SHALL be computed on read from synced inputs and the pinned ruleset, not synced or stored as authoritative values; only `override_cents`, the source inputs, and the ruleset identifier sync (REQ-OF-2 cl. 4, ADR-46).

**REQ-AE-6 [v1] — Buffer drawdown**
THE SYSTEM SHALL compute buffer remaining as the Buffer allocation minus the summed overrun of all non-Buffer categories, and SHALL display it on the dashboard.

1. Category overrun equals `max(0, summed_effective_amount − allocated_amount)` for a non-Buffer category.
2. Buffer remaining equals Buffer allocation minus the sum of all non-Buffer category overruns.
3. Under-spend in one category does not offset overrun in another for this calculation.
4. Buffer remaining is displayed as a peso amount and as a percentage of the original Buffer allocation.
5. IF buffer remaining falls below zero, THEN THE SYSTEM SHALL display a budget breach indicator stating the amount by which the total budget is exceeded.
6. Rounding remainder assigned under REQ-AE-1 clause 6 increases the Buffer allocation before drawdown is computed.
7. Buffer remaining recomputes within the same operation as any change to an allocation or an effective amount.

**REQ-AE-7 [v1] — Explicit rebalance of committed allocations (ADR-53)**
WHEN a partner requests “Rebalance to fit what we've committed,” THE SYSTEM SHALL preview a feasible redistribution of the currently effective six-category allocation in integer centavos, without changing the pinned default engine or existing ledger costs.

1. THE SYSTEM SHALL treat every existing non-null `override_cents` as a lock, including Buffer: no locked donor or recipient SHALL change automatically. IF the effective six allocations do not sum exactly to the budget, THEN THE SYSTEM SHALL disclose the discrepancy, disable Apply and require manual correction, never normalize silently.
2. From a budget-balanced starting allocation, THE SYSTEM SHALL compute each unlocked non-Buffer recipient need as `max(0, committed_effective_cents − allocation_cents)`, transfer up to the unlocked Buffer allocation to recipients in ADR-10 category order, and never take more than the available Buffer amount.
3. IF recipient need remains, THEN THE SYSTEM SHALL use only positive `allocation_cents − committed_effective_cents` slack of unlocked non-Buffer donor categories. THE SYSTEM SHALL transfer at most `min(total_remaining_need, total_available_slack)` centavos. Each donor contributes the floor of `(transfer_cents × donor_slack_cents / total_slack_cents)`, then remaining individual centavos go by greatest fractional remainder, ties broken by ADR-10 category order, without reducing a donor below committed cost; assign resulting transfers to unlocked recipients in that same fixed order.
4. THE SYSTEM SHALL show before/after allocations, changed overrides, committed costs, Buffer and donor sources, locks, and every uncovered category shortfall (including locked underfunded categories). IF all need cannot be covered, THEN THE SYSTEM SHALL leave the uncovered breach visible and permit the partner to explicitly apply only the feasible partial result; no preview implies that an uncovered cost fits.
5. WHEN a partner confirms Apply on a budget-balanced starting state, THE SYSTEM SHALL write only changed `override_cents` through the immutable change log (REQ-AE-5, REQ-SE-4); cancelling SHALL write nothing. Gross, net and baseline engine outputs SHALL remain unchanged. REQ-AE-6 buffer remaining SHALL use post-apply allocations without offsetting overruns by unrelated under-spend.

---

## 6A. Starter templates, requirements checklist, export and locale

**REQ-TM-1 [v1] — Wedding-type starter suggestions (ADR-55)**
WHEN a partner chooses a wedding-type template, THE SYSTEM SHALL offer unticked expense-type suggestions from the pinned bundled ruleset JSON without creating ledger rows or amounts.

1. THE SYSTEM SHALL offer exactly the named variants civil, church + hotel, church + garden, beach/destination, and intimate (≤50 guests); deterministic optional ceremony/venue inputs from REQ-BS-1 SHALL select relevant suggestions, while `Not sure yet` permits a manual template choice. The intimate label SHALL NOT alter guest cap or driving count.
2. Each configured suggestion SHALL have a stable identifier, name, one of the six ledger categories and a valid pricing mode, but no amount, rate, supplier, or recommended vendor; the pinned ruleset version SHALL determine ordering and content. Validate that shape on load.
3. The bundled suggestion vocabulary SHALL include arrhae/unity coins, veil, cord, candle, church fees, Pre-Cana, marriage license, souvenirs/giveaways, lechon, mobile bar, photobooth, prenup shoot, SDE video and entourage attire; a suggestion SHALL NOT assert applicability or a fee.
4. WHEN a partner ticks a suggestion, THE SYSTEM SHALL open the ledger editor and require a nonblank supplier plus valid user-entered amount or rate before saving an entry under REQ-LG-1; cancelling SHALL leave the suggestion unticked and create no row, including no ₱0 placeholder. Suggested expense types SHALL NOT list, rank or recommend suppliers.

**REQ-CK-1 [v1, verified presets blocked by OQ-11] — Requirements checklist (ADR-56)**
WHERE a couple uses the requirements checklist, THE SYSTEM SHALL track user completion separately from an optional user-entered reminder date and fee, without treating unverified config as legal or church advice.

1. THE SYSTEM SHALL offer checklist labels for PSA birth certificates, PSA CENOMAR, marriage license application and posting period, Pre-Cana/counselling, canonical interview, baptismal and confirmation certificates, and banns; configuration SHALL carry stable item IDs, labels, optional applicability, source-verification status and, **only after item-specific verification**, an optional signed-integer day offset from the wedding date. No universal applicability, fee or offset is presumed.
2. WHILE an item or its source/offset is unverified under OQ-11, THE SYSTEM SHALL mark it “NEEDS VERIFICATION,” SHALL NOT publish a preset due date or claim legal/church eligibility, and SHALL permit an explicitly couple-entered reminder date with a user-date label. Publishing verified preset rules or date-offset assertions is BLOCKED until relevant LGU, civil registrar or parish/church verification is documented per item.
3. WHEN either partner changes an item's done state, THE SYSTEM SHALL persist that state as a separate LWW field with normal offline/sync history; changing the wedding date SHALL recompute a verified configured due date on read from its signed offset, but SHALL NOT shift an explicit user-entered reminder date.
4. WHERE the couple enters an optional nonnegative fee in integer centavos, THE SYSTEM SHALL keep it outside gross, net and ledger until the couple explicitly confirms fee-to-ledger and supplies the valid ledger fields under REQ-LG-1; conversion requires a **positive** user-entered fee and creates an entry for **that exact fee amount**, not an invented or divergent amount. Declining or entering zero SHALL create no entry. A later checklist-fee edit SHALL NOT silently alter a linked ledger entry; the couple edits that entry explicitly. Checklist completion or a configured item SHALL NOT imply a fee.

**REQ-EX-2 [v1] — Private offline export and OS sharing (ADR-57)**
WHEN a partner exports a plan, THE SYSTEM SHALL generate the selected file on-device while offline and offer the OS share sheet, without a live share link or a web dependency. Curated PDFs/CSVs use the local eligible projection; the separate SEC-32 copy in clause 5 covers locally held historical data as well.

1. A summary PDF SHALL show gross, net, expected pledge support, six-category table and payment schedule. Before generation, THE SYSTEM SHALL show a privacy preview naming included sections; guest and sponsor names SHALL have independent hide/show toggles, with names hidden by default for shared summaries.
2. THE SYSTEM SHALL offer separate ledger, payments, pledges and guests CSVs; before each export it SHALL show a sensitive-data warning and the fields included. Every cell SHALL be RFC-4180-quoted as needed; for every text or formatted-value cell whose first non-whitespace/control character is `=`, `+`, `-` or `@`, THE SYSTEM SHALL prepend a literal apostrophe to the original cell **before** CSV quoting, including when the dangerous character follows leading whitespace/control characters. RFC quoting alone is insufficient; the imported cell SHALL remain text rather than an evaluated formula.
3. WHERE a partner requests a sponsor statement PDF, THE SYSTEM SHALL require one chosen **Ninong or Ninang** pledge and include only that pledge's sponsor, pledged value/status, eligible receipts and linked coverage; it SHALL omit all other sponsors' names, unrelated amounts and other plan data. Statement sharing SHALL use the same privacy preview and OS handoff.
4. THE SYSTEM SHALL NOT sync generated files or create live share links; after OS share-sheet handoff or cancellation it SHALL remove app-controlled temporary export artifacts. The preview SHALL warn that copies handed to another app cannot be recalled remotely or deleted from their destination by Kasaran.
5. WHERE a partner requests a copy of their personal data under SEC-32, THE SYSTEM SHALL offer a **separate full machine-readable export** from the same export UI, not a redacted summary or the four curated CSVs. It SHALL include all locally held accessible plan/account personal fields (including retained historical/tombstoned rows), including profile and membership, setup, ledger and schedule, payment/refund, hidden-fee, pledge and receipt, gift/giver, guest, crew, checklist, allocation override, and activity/change-log data with attribution. A versioned machine-readable manifest SHALL identify included entity/field inventories, missing/inaccessible fields and **as-of-last-sync** scope, making clear that server-only account fields and other devices' unsynced changes are absent from an offline copy. THE SYSTEM SHALL disclose sensitive contents before OS handoff and apply clause 2's CSV formula-neutralization to every exported text or formatted-value cell if CSV is used; this path SHALL NOT assert a shared-record erasure outcome (OQ-01). The DPO SHALL reconcile server-only fields with the authoritative account data before declaring the SEC-32 access request complete; correction of profile display name/email remains available through the account path.

**REQ-LO-1 [v1.1; v1 English-only] — User-selectable interface locale (ADR-58)**
WHERE the v1.1 locale feature is shipped, THE SYSTEM SHALL use versioned ARB resources for English, Taglish and Filipino interface copy with a deterministic English fallback for missing translations and a user-selectable locale.

1. v1 SHALL present English UI only; v1.1 locale selection SHALL change interface labels without changing budget arithmetic, persisted centavos, syncing, user-entered text or currency.
2. THE SYSTEM SHALL retain “Kasaran,” “Ninong/Ninang,” “PSA/CENOMAR,” local acronyms and user-entered strings untranslated; all locales SHALL format PHP amounts and dates with `en_PH` conventions and full-form accessibility labels per REQ-GEN-2/2A.
3. WHEN a locale resource key is missing, THE SYSTEM SHALL use its English ARB string without runtime machine translation; pseudo-localized/expanded text SHALL preserve legible bento values and full-form accessibility labels without clipping or overlap.

**REQ-AT-1 [v1.1 backlog stub; no v1 upload] — Private photo attachments (ADR-59)**
WHERE receipt or contract photos are implemented after v1, THE SYSTEM SHALL design attachment metadata and private bytes separately; this requirement is a v1.1 backlog gate, not a claim that upload ships in v1 or that OCR is included.

1. Attachment metadata SHALL reference a live plan-scoped ledger entry or pledge receipt by stable ID; contract photos SHALL attach to a ledger entry, not a nonexistent contract table. Supabase Storage bucket policies SHALL deny cross-plan reads/writes and public URLs. No v1 UI SHALL upload photos, and no OCR is included in this stub.
2. Offline pending bytes SHALL be staged encrypted on-device and queued separately from metadata events; THE SYSTEM SHALL display pending/uploaded/error truthfully and SHALL NOT represent inaccessible or unsynced bytes as uploaded.
3. Before implementation, the team SHALL approve configured maximum byte size and permitted MIME types, reject files outside those limits, and review/update the Photos privacy label/declaration before shipping. This stub specifies no invented size/MIME value and does not imply a forced remote wipe.

---

## 7. Shared editing and sync

**REQ-SE-1 [v1] — Two-partner symmetric access**
THE SYSTEM SHALL support exactly two partner accounts per plan, with identical read and write permission over all budget data.

1. A plan admits at most two partner accounts in v1.
2. No budget field is writable by one partner and read-only to the other.
3. A partner invites the second partner, who joins the plan via that invite.
4. An unaccepted invite is revocable and expires exactly 7 days after issuance.
5. IF a partner opens an invite link more than 7 days after issuance, THEN THE SYSTEM SHALL reject it and state that the invite has expired.
6. WHEN the second partner joins, they see every existing figure identically, including manual overrides.
7. WHEN a signed-in account has no active plan, THE SYSTEM SHALL offer “Start our plan” and “Join my partner's plan” before creating any plan; choosing Join SHALL NOT create a separate plan (ADR-52).
8. WHEN a partner pastes an invite link instead of tapping it, THE SYSTEM SHALL send its token through the same acceptance, revocation, membership and seven-day expiry checks as the deep link; the token SHALL have at least 128 bits of CSPRNG entropy, be stored server-side only as a hash, and never appear in logs (SEC-05, ADR-52).
9. WHEN an applicant signs up, THE SYSTEM SHALL present an unchecked “I am 18 or older” declaration and block account creation with an accessible explanation unless explicitly checked; it SHALL NOT infer adulthood from an invite or collect a birth date for this gate. Counsel SHALL review the legal basis and privacy-notice wording before real-data internal beta (ADR-63, SEC-29/30/31).

**REQ-SE-2 [v1] — Field-level last-write-wins**
WHEN two partners have edited the same plan and their changes reconcile, THE SYSTEM SHALL resolve conflicts at field granularity using last-write-wins ordered by a **server-assigned timestamp applied at sync time**, with a device-side monotonic counter used only as a deterministic tiebreaker. *(Amended per Decision D1: device wall-clocks are never authoritative for ordering.)*

1. Concurrent edits to different fields of the same entry both persist.
2. Concurrent edits to different entries both persist.
3. Concurrent edits to the same field resolve to the write bearing the later **server-assigned** timestamp. Device wall-clock time SHALL NOT determine the winner.
4. THE SYSTEM SHALL record, on every write, a device-side monotonic counter and a stable device identifier. IF two writes to the same field carry the same server-assigned timestamp, THEN THE SYSTEM SHALL resolve by the higher monotonic counter, and if still equal, by the stable device identifier, such that both devices converge on the same winner.
5. The server-assigned timestamp is applied when the write is accepted at sync; a write that has not yet synced carries no authoritative order and SHALL NOT win a conflict against an already-synced write purely by an earlier device clock reading.
6. Resolution never discards an accepted local write without recording it in the change log per REQ-SE-4.
7. THE SYSTEM SHALL NOT use inference, heuristics, or any AI component in conflict resolution.
8. WHEN a synced change-log row's typed `old_value` (including null) differs from the effective value it actually replaces immediately before that row in server order, THE SYSTEM SHALL derive a conflict on read, not persist a conflict flag; the later accepted write remains the winner even when it was made offline days earlier. A derived payment `status` or other recomputed value SHALL NOT be compared as a synced field (ADR-43).
9. WHEN a conflict is derived, THE SYSTEM SHALL show both partners a dismissible conflict banner and a “Conflicts” filter on SCR-16 naming the winning and superseded values and attribution; dismissing the banner SHALL NOT erase the log or conflict history (ADR-43).
10. WHERE `pricing_mode` and `per_head_rate_cents` change, or a fee component's `quantity`, `unit_rate_cents`, and `amount_cents` change, THE SYSTEM SHALL write the entire respective group as one validated snapshot under one `change_group_id`, resolve all fields from the group with the highest `(server_ts, device_monotonic, device_id)`, and never partially project an incomplete group. All other independent fields keep clauses 1–5 field LWW; the losing group's rows remain in the immutable log (ADR-44).
11. WHEN one account edits a plan on two devices, THE SYSTEM SHALL treat their queued changes as distinct device writes under clauses 3–5; where applicable conflict copy SHALL say “You changed this on another device,” not imply a different person (ADR-50).

**REQ-SE-3 [v1] — Convergence**
WHEN all queued writes from both devices have been applied, THE SYSTEM SHALL present identical values on both devices.

1. Given the same set of writes, convergence is independent of arrival order.
2. After sync completes, gross, net, outstanding exposure, and every category variance match exactly across devices.
3. Re-running sync with no new writes changes nothing on either device.
4. WHEN replay or concurrent edits violate a cross-field constraint, THE SYSTEM SHALL preserve all accepted rows and winners, revalidate on read, exclude only invalid dependent financial contributions from live aggregates, and show the raw values and a “needs attention” flag on SCR-19 (state 5); it SHALL NOT issue automatic corrective writes. Independent valid records remain visible and counted (ADR-45).
5. The read-time validation in clause 4 SHALL cover the six-category taxonomy, nonblank supplier, nonnegative flat estimate and actual, 2,000-character notes limit, valid per-head mode/rate and `manually_valued` actual precedence (REQ-LG-1, REQ-GM-2 cl. 4–5); fixed hidden-fee subtype/category, required component shapes, complete quantity/rate pair **or** flat amount and subtype-specific component sums (REQ-HF-2); plan budget > 0, cap/crew headcount ≥ 0, region and pinned ruleset validity, guest RSVP/tier axes (REQ-BS-2/4/5, REQ-GM-1/4, REQ-AE-1/3); schedule sum ≤ effective amount, positive dated payments/refunds, parent entry and matching payment/schedule links (REQ-LG-7/8); valid sponsor role/sub-role, positive receipts, receipt-backed/withdrawn pledge lifecycle, in-kind shared cap and live linked entry, plus reciprocal unique equal-value supplier-paid receipt/payment pair in the same plan (REQ-PL-1/6/7); positive gifts with allowed source (REQ-GF-1); nonnegative allocation overrides with valid category (REQ-AE-5); and six hidden-fee decisions before setup completion (REQ-HF-1). Over-allocation, overpayment and zero eligible support remain **warnings/derived values**, not invalidity; invalid dependent values SHALL NOT be silently clamped, repaired, or counted (ADR-45).
6. WHEN the same complete committed log and pinned ruleset are available on two devices, their read-time validation, excluded contributions, needs-attention flags, and money totals SHALL converge; a device without the pinned version SHALL retain its log and show an update/needs-attention state rather than fabricate allocations (ADR-45/46).

**REQ-SE-4 [v1] — Visible change log**
THE SYSTEM SHALL record every create, update, and delete with the acting partner, a timestamp, the field changed, the previous value, and the new value.

1. The change log is viewable per entry and as a plan-wide activity feed.
2. Monetary changes record both previous and new value.
3. A write that lost a last-write-wins resolution appears in the log with its value preserved and its superseded outcome stated.
4. Change log entries are immutable; no user interface permits editing or deleting them.
5. Every log entry attributes exactly one stable per-plan `plan_member_id` alias and its originating `device_id`, not an immutable foreign key to `users`; an account-to-alias mapping is removable without rewriting log rows. After that mapping is removed, the unchanged history renders the actor as “Former member” (ADR-50/51). The outcome of shared-record erasure remains **BLOCKED on OQ-01/SEC-33/38**; this clause does not authorize retention or erasure of the shared plan.
6. WHEN a row is created, THE SYSTEM SHALL emit one `create` change-log row containing its complete validated initial snapshot; a peer SHALL materialize the entity only from that complete event, and a child SHALL remain unprojected until its parent create arrives, including across pull pages (ADR-47).
7. WHEN an entity is soft-deleted, THE SYSTEM SHALL preserve its tombstone and history and exclude it and dependent children from **all** live totals (gross, net, expected/exposure, deposits, balances, category variance, buffer, gifts, net after gifts, and reconciliation); later ordinary edits SHALL remain in Activity as suppressed/superseded while deleted, trigger the conflict banner, and SHALL NOT resurrect it or cascade writes. A linked pledge retains its recorded value, shows “linked entry deleted,” and its linked support is excluded from live net pending reconciliation (ADR-47, REQ-PL-7).
8. WHEN a partner explicitly selects Restore on a deleted entity in SCR-16, THE SYSTEM SHALL issue a normal ordered LWW `deleted_at = null` write, then revalidate the entity's last effective pre-delete field values and eligible children per REQ-SE-3 before returning valid contributions to live totals. Edits accepted while deleted remain suppressed in history and SHALL NOT silently become effective after Restore. Restore is distinct from a one-tap revert of a superseded field value, which remains unavailable (ADR-47).
9. WHEN a user signs out on SCR-18 or revokes one listed device's session, THE SYSTEM SHALL revoke that device's server refresh session, stop its future sync, and offer a local wipe; other devices' sessions remain usable. THE SYSTEM SHALL NOT claim to force-wipe an offline or uncooperative device (ADR-50, SEC-04).
10. WHERE a user requests account deletion on SCR-18, THE SYSTEM SHALL expose an in-app request path and explain that shared-plan record treatment awaits OQ-01/SEC-33/38 counsel review; the alias-to-user mapping can be removed without changing log attribution, but no shared-record retention/deletion outcome or passing erasure acceptance test is specified until that decision (ADR-51, SEC-34).

**REQ-SE-5 [v1] — Plan-lifecycle permissions**
THE SYSTEM SHALL restrict plan deletion to the creating partner, SHALL permit either paired partner to defensively remove the other without consent, and SHALL require two-party confirmation for ownership transfer only.

1. Only the creating partner is offered the delete-plan action.
2. IF the non-creating partner attempts plan deletion, THEN THE SYSTEM SHALL refuse and state that only the plan creator may delete it.
3. Plan deletion requires an explicit typed or equivalent confirmation from the creator beyond a single tap.
4. Transferring ownership requires affirmative confirmation from both partners before it takes effect; this is the only lifecycle action that requires two-party confirmation. *(Amended per Decision 1: two-party confirmation is scoped to ownership transfer only. Partner removal is governed by REQ-SE-6.)*
5. Defensive partner removal is NOT a two-party action and is governed entirely by REQ-SE-6; this clause exists so that any reference to "REQ-SE-5 clause 5" resolves to a substantive statement rather than a placeholder. *(Per Decision D5: the former reserved placeholder is replaced with real content; the consolidation of the old ownership-transfer clause into clause 4 is recorded in the retired-IDs appendix, §14.)*
6. WHILE an ownership-transfer confirmation is pending, both partners retain full data access unchanged.
7. IF both partners have not confirmed ownership transfer within 7 days of the confirmation request, THEN THE SYSTEM SHALL expire the pending request and leave ownership and plan access unchanged (ADR-32; closes OQ-05).
8. Every lifecycle action and confirmation is recorded in the change log per REQ-SE-4.
9. Data-level access remains fully symmetric per REQ-SE-1; this requirement governs lifecycle actions only.

**REQ-SE-6 [v1] — Defensive partner removal**
THE SYSTEM SHALL permit either paired partner to unilaterally revoke the other partner's access without the removed partner's consent, effective on the removed partner's next sync. *(Added per Decisions 1 and 2. Rationale: a hostile partner would refuse a two-party removal forever, trapping the person the control should protect; and the wedding is symmetric, so the right must belong to either partner, not the creator alone.)*

1. Either paired partner MAY remove the other; the right is mutual and does not depend on who created the plan.
2. Removal takes effect on the server immediately and requires no affirmative action or consent from the removed partner.
3. WHEN the removed partner's device next attempts to sync, THE SYSTEM SHALL reject both pull and push for that partner, enforced server-side, not by client checks alone.
4. The removal is recorded in the change log, attributed to the acting partner per REQ-SE-4, with a timestamp.
5. A removed partner RETAINS the local copy of data already synced to their device. THE SYSTEM SHALL NOT claim to remotely wipe that copy, because a local-first store on an uncontrolled device cannot be remotely erased.
6. Following removal, the removed partner's server access stops and no future edits from that partner sync in either direction.
7. WHEN the removed partner's device learns of the removal, THE SYSTEM SHALL offer that partner a local wipe of their own device's plan copy, but SHALL NOT represent this offer as an enforceable remote wipe against an offline or uncooperative device (ADR-34; force-wipe OQ-03 remains open).
8. Removal does not delete the plan and does not remove the acting partner; the plan continues under the remaining partner's account.
9. IF both partners each remove the other — including from two offline devices whose removals sync in either order — THEN THE SYSTEM SHALL resolve to a single deterministic winner: the removal bearing the earlier server-assigned timestamp (REQ-SE-2) prevails; the partner named in that winning removal is the one removed, and the acting partner of that winning removal remains. *(Added per Decision D4: no undefined "whoever syncs first" behaviour in the removal path.)*
10. IF the two competing removals carry the same server-assigned timestamp, THEN THE SYSTEM SHALL break the tie by the stable device identifier of REQ-SE-2 clause 4, so both servers and both devices converge on the same surviving partner.
11. The losing removal is recorded in the change log as superseded, with its actor and timestamp preserved per REQ-SE-4; the plan is never left with zero members as a result of simultaneous removal.

---

## 8. Offline behaviour

**REQ-OF-1 [v1] — Full offline CRUD**
WHILE the device has no network connectivity, THE SYSTEM SHALL permit create, read, update, and delete on every v1 data type, and SHALL persist those changes locally across app termination.

1. Offline CRUD succeeds for: plan setup inputs and reminder configuration, ledger entries, schedule items, supplier payment/refund rows, all six hidden-fee subtypes, pledges and receipt rows, gifts, guest tiers, crew headcount, and allocation overrides; insert-only money rows are corrected by tombstone plus new row rather than amount overwrite.
2. A write made offline survives a force-quit and a device restart.
3. No v1 feature is disabled, hidden, or degraded solely because the device is offline.
4. IF a v1 operation cannot complete offline, THEN that operation is a defect against this requirement.

**REQ-OF-2 [v1] — Offline computation**
WHILE the device has no network connectivity, THE SYSTEM SHALL compute the allocation engine, guest math, what-if previews, variance, gross, net, remaining expected support, outstanding exposure, balances, schedule status, net after gifts, and post-wedding reconciliation entirely on-device.

1. Allocation runs offline and returns figures identical to those the same inputs produce online.
2. A guest what-if preview runs fully offline.
3. No dashboard figure renders as unavailable, stale, or placeholder due to absent connectivity.
4. THE SYSTEM SHALL derive per-head effective amounts from the synced rate and driving guest count on each read and SHALL NOT sync or write back a recomputed `estimated_cents`; it SHALL derive the allocation `engine_cents` result and explanation locally from synced inputs and the pinned bundled ruleset, syncing only manual override cents and source inputs/ruleset version, not engine outputs (ADR-46).
5. IF the pinned ruleset version is absent locally, THEN THE SYSTEM SHALL retain the log, identify the missing version and show needs attention/update for the affected allocation view, without inventing an engine amount; clause 3's offline parity applies where the pinned ruleset is installed (ADR-46).

**REQ-OF-3 [v1] — Offline state visibility**
WHILE the device has unsynced local changes, THE SYSTEM SHALL display the offline state and the count of pending changes.

1. Offline state is indicated persistently, not as a transient message.
2. The pending-change count reflects queued writes and decreases as they are applied.
3. WHEN sync completes with an empty queue, the indicator clears.

**REQ-OF-4 [v1] — Clock handling while offline**
WHILE offline, THE SYSTEM SHALL derive payment status from the device's local current date, and SHALL NOT persist that derivation as authoritative shared state.

1. Two devices with differing clocks may display differing `overdue` status without generating a sync conflict.
2. Status is recomputed on read on each device independently.
3. No `overdue` determination is written to the shared record.

**REQ-OF-5 [v1] — Durable, idempotent replay**
WHEN connectivity is restored, THE SYSTEM SHALL replay queued writes automatically, idempotently, and without partner action.

1. Replay begins without the partner opening a specific screen or pressing a control.
2. A write delivered twice applies exactly once; no total is double-counted.
3. WHEN queued writes replay, THE SYSTEM SHALL preserve each write's original `device_monotonic` order and `device_id`; the server SHALL assign `server_ts` when it accepts each new row, not when the offline edit was made. A duplicate replay SHALL retain the row's originally assigned `server_ts` and SHALL NOT create a second row (REQ-SE-2, ADR-21).
4. IF a queued write cannot be applied, THEN THE SYSTEM SHALL retain the write with its data intact, surface it to the partner, and SHALL NOT discard it.
5. Sync progress and completion are visible to the partner.
6. WHEN the server accepts a plan's writes, THE SYSTEM SHALL serialize `server_ts` assignment and insertion under a per-plan transactional lock held through commit; pull pages SHALL use a committed high-water mark and advance the per-plan cursor only through returned committed rows. A rollback may leave a gap, but a later-committed lower sequence SHALL NOT be skipped, including when push transactions race (ADR-48).
7. THE SYSTEM SHALL include `protocol_version` in push and pull envelopes and `schema_version` on immutable change-log rows. IF a request uses an unsupported major protocol version, THEN THE SERVER SHALL reject it with a structured `min_supported_build` response and leave local queued rows intact; no incompatible row is silently projected (ADR-49).
8. WHEN a compatible old client receives an unknown additive `entity_type` or `field_name`, THE SYSTEM SHALL persist its complete row and ordering metadata in the local log without projecting that unknown value; after upgrading it SHALL transactionally migrate the local drift schema, retain queued and unknown rows unchanged, and rebuild projections from the entire retained log. IF a required dependent input is unknown, THEN THE SYSTEM SHALL gate its financial projection with needs attention rather than silently compute an incorrect total (ADR-49).
9. IF local drift migration or projection rebuild fails, THEN THE SYSTEM SHALL roll back the migration transaction, preserve the old schema, queued writes, cursor, and retained log, and surface an update/retry state instead of partially applying a newer projection (ADR-49).

---

## 8A. Consent-based product measurement and feedback (v1)

**REQ-MT-1 [v1] — Optional privacy-first success measurement (ADR-62)**
WHERE both active partners separately opt in after reading the approved measurement notice, THE SYSTEM SHALL permit a first-party, plan-scoped cohort measurement of project-brief §5 metrics; otherwise THE SYSTEM SHALL perform no product-measurement analysis or event collection from that plan.

1. A new or restored account SHALL start with measurement off. Neither onboarding, core budgeting nor diagnostics SHALL turn it on; refusing consent SHALL leave every core planning feature available.
2. Only with both active partners' consent and an approved lawful basis/notice SHALL the cohort computation derive available facts from already-synced `hidden_fee_prompts` and the attributed immutable `change_log`, budget snapshot and wedding date. Existing sync permission alone SHALL NOT authorize retroactive analysis. If a setup-end budget snapshot, final actual gross, prompt decision time or complete history is unavailable, the affected plan SHALL be reported as unknown, not counted as success or failure; duplicate replay SHALL not create a second observation.
3. To count gross-versus-net comparison views, an explicitly opted-in app SHALL send only an allowlisted `net_comparison_viewed` event with a random event ID, UTC day and notice version; the authenticated server binds it to the plan and stores a coarse plan pseudonym. The client event payload SHALL contain no plan ID, account identifier, amount, email, name, note, URL or token. No third-party analytics SDK or background navigation tracking ships in v1.
4. WHEN either partner withdraws, THE SYSTEM SHALL stop new optional events and plan-level analysis immediately, discard unsent optional events, and expose consent controls in SCR-18; signing in again or reinstalling SHALL NOT silently re-enable collection. Previously collected events SHALL follow a DPO/counsel-approved deletion and retention policy, not an invented expiry.
5. Cohort denominators SHALL include only eligible, explicitly enrolled plans with the necessary known inputs. Reports SHALL disclose cohort size, missing-data exclusions and opt-in/self-selection bias; partner-level activity SHALL not appear on a consumer analytics dashboard. No cohort statistic SHALL publish below a DPO-approved aggregation floor.
6. Before collecting real beta events or analysing existing real plan data for this purpose, DPO/counsel SHALL approve the purpose-specific lawful basis, notice text, both store labels, processor/residency disclosures, event payload, retention and withdrawal flow (SEC-29/30/31, OQ-07). The absence of approval blocks measurement, not core local budgeting.

**REQ-SV-1 [v1] — Optional spreadsheet-displacement survey (ADR-62)**
WHEN a partner next opens the app after their plan's wedding date, THE SYSTEM SHALL offer one optional in-app question, “Is Kasaran the only tool you used to track your wedding budget, without a parallel spreadsheet?”, without requiring a response to continue planning.

1. SCR-24 SHALL show Yes, No, Prefer not to say, Not now and Skip, with no free-text field; it SHALL be dismissible while offline and SHALL NOT block budgeting, export or sync.
2. Only an explicit Submit on a selected Yes, No or Prefer not to say SHALL create an answer. Skip records a permanent local dismissal with no answer; Not now defers the prompt once for the next app open and never loops within a session. An answer or Skip SHALL suppress future prompts for that plan on that account.
3. Survey participation SHALL have its own default-off, separately revocable opt-in and notice; a survey answer or dismissal SHALL NOT imply consent to product measurement under REQ-MT-1. Without opt-in, no response leaves the device. An offline opted-in submission SHALL queue once, deduplicate by stable response ID and sync only after the approved first-party path is available.
4. A plan SHALL contribute at most one submitted response: the server accepts the first validated submission and labels a later partner response as already answered without silently replacing it. The metric SHALL report the number of eligible responding plans, the Yes share among Yes/No answers, and nonresponse/Prefer-not-to-say separately; it SHALL NOT claim a two-person consensus from one respondent.
5. Before real-couple survey collection, DPO/counsel SHALL approve the survey lawful basis, notice, role-limited access, retention/withdrawal and Apple/Play labels; until then show no real survey prompt and report no real-cohort result (SEC-29/30/31, OQ-07).

---

## 9. AI-phase requirements — excluded from v1

**REQ-AI-1 [AI-phase]** — OCR extraction of ledger entries from photographed contracts and receipts.
**REQ-AI-2 [AI-phase]** — On-device automatic categorisation of ledger entries.
**REQ-AI-3 [AI-phase]** — Cloud AI budget advice, risk warnings, forecasting, and natural-language summaries.
**REQ-AI-4 [post-launch — PAYMENTS, not AI-phase]** — InstaPay and QR Ph payment initiation and reconciliation. *(Reclassified per ADR-28: payments has its own post-launch phase (development-phases phase 22), owned by Backend with Security as mandatory reviewer. The `REQ-AI-` prefix is historical and cannot be renumbered; see §14. Excluded from v1.)*
**REQ-AI-5 [AI-phase]** — Conversational assistant for natural-language input and queries.

**REQ-EX-1 — Excluded entirely, not deferred.** THE SYSTEM SHALL NOT include a supplier marketplace, vendor directory, supplier reviews, supplier ratings, quote solicitation, or booking, in v1 or in the AI phase.

---

## 10. Traceability

| Area | Requirements | Source stories |
|---|---|---|
| Platform | REQ-PLT-1 … 3 | Cross-cutting |
| Monetary base | REQ-GEN-1 … 2A | Cross-cutting |
| Budget setup | REQ-BS-1 … 6 | BS-1, BS-2 |
| Expense ledger, schedules, payments, reminders | REQ-LG-1 … 9 | LG-1, LG-2, LG-3 |
| Hidden fees | REQ-HF-1 … 3 | HF-1, HF-2 |
| Pledges and receipts | REQ-PL-1 … 7 | PL-1, PL-2, PL-3 |
| Day-of gifts and reconciliation | REQ-GF-1 … 2 | Prompt 2 day-of gifts |
| Guest math and affordability preview | REQ-GM-1 … 6 | GM-1, GM-2, GM-3; Prompt 4 / ADR-54 |
| Allocation engine and explicit rebalance | REQ-AE-1 … 7 | AE-1, AE-2, AE-3; Prompt 4 / ADR-53 |
| Wedding-type suggestions | REQ-TM-1 [v1] | Prompt 4 / ADR-55 |
| Requirements checklist (verified presets gated) | REQ-CK-1 [v1; OQ-11] | Prompt 4 / ADR-56 |
| Offline export, curated sharing and full SEC-32 copy | REQ-EX-2 [v1] | Prompt 4 / ADR-57; SEC-32 |
| Interface locale | REQ-LO-1 [v1.1] | Prompt 4 / ADR-58 |
| Private attachment backlog | REQ-AT-1 [v1.1 stub] | Prompt 4 / ADR-59 |
| Shared editing, conflicts, onboarding, attribution and restore | REQ-SE-1 … 6 (ADR-43–45, 47, 50–52) | SE-1, SE-2, SE-3; Prompt 3 sync integrity |
| Offline computation, committed cursors and compatibility | REQ-OF-1 … 5 (ADR-46, 48–49) | OF-1, OF-2; Prompt 3 sync integrity |
| Consent-based measurement and optional survey | REQ-MT-1, REQ-SV-1 [v1] | Prompt 5 / ADR-62; privacy review SEC-29…31 before real-data beta |
| 18+ sign-up declaration | REQ-SE-1 clause 9 [v1] | Prompt 5 / ADR-63; counsel gate |
| AI/post-launch payments and permanent marketplace exclusion | REQ-AI-1 … 5, REQ-EX-1 | AI-1 … AI-5; ADR-28 |

---

## 11. Decisions resolved

The decisions in this section are resolved. Remaining open questions and formerly open defaults are identified in §13 and the decision log.

| # | Decision | Requirements |
|---|---|---|
| 1 | Payment states are derived `paid` / `pending` / `due soon` / `overdue`; deposits derive from insert-only payments less refunds, with partial payment indicated independently of status (ADR-36). | REQ-LG-4, REQ-LG-5, REQ-LG-7 … 9 |
| 2 | Sync conflicts resolve by field-level last-write-wins ordered by a **server-assigned timestamp** applied at sync time (device wall-clocks never authoritative), with a device monotonic counter + stable device id as tiebreaker, and an immutable change log preserving superseded writes. Atomic compound field groups, typed stale-value conflict disclosure, read-time invariant gates, create/tombstone handling, and committed per-plan cursors refine—not replace—this ordering (ADR-43–49). *(D1)* | REQ-SE-2 … 4, REQ-OF-2/5 |
| 3 | Region is a first-class setup input on three cost tiers: Metro 1.00, Provincial 0.85, Destination 1.20. Destination flags control OOT independently; Bohol is Provincial at 0.85 and destination-flagged (ADR-29). | REQ-BS-4, REQ-HF-3 |
| 4 | Baseline allocations are Catering & Venue 40%, Photo & Video 15%, Attire & Styling 10%, Coordination 10%, Entourage & Miscellaneous 5%, Buffer 20%. | REQ-AE-1 |
| 5 | The regional cost index drives cost expectation, budget adequacy, and rate suggestions — not allocation shares. See section 12. | REQ-AE-2 |
| 6 | Plan deletion is creator-only. Two-party confirmation applies to ownership transfer only. Either partner may defensively remove the other without consent (mutual, one-sided); the removed partner keeps their existing local copy, which is not remotely wiped. Simultaneous mutual removal resolves to a deterministic winner by server timestamp then stable id. Data access stays symmetric. *(D3, D4)* | REQ-SE-5, REQ-SE-6 |
| 7 | Platform is Flutter on Android and iOS, SQLite (`drift` or `sqflite`) for local persistence, web excluded from v1. | REQ-PLT-1, REQ-PLT-2 |
| 8 | New guests default to priority tier Tier 2, with Tier 1 reserved for close family and principal sponsors. | REQ-GM-1 |
| 9 | Partner invites expire 7 days after issuance. | REQ-SE-1 |
| 10 | Rounding remainder is assigned to the Buffer category. | REQ-AE-1, REQ-AE-6 |
| 11 | One active plan per account. | REQ-PLT-3 |
| 12 | Bento tiles may use a constrained monetary form (centavos dropped below ₱1M, exactly two decimal places in millions shorthand at/above ₱1M, truncated toward zero; ADR-30 refines ADR-14); full two-decimal form is mandatory everywhere else and in every screen-reader label. | REQ-GEN-2, REQ-GEN-2A |
| 13 | Ruleset config is a JSON asset bundled in the app binary for v1, validated at app load. No web authoring dashboard. | REQ-AE-1 |
| 14 | Pledge receipts reduce net immediately when support arrives, including partially fulfilled and withdrawn pledges' historical receipts; remaining promise is expected, not net (ADR-22 refined by ADR-37/38). | REQ-PL-2 … 7 |
| 15 | Retired or merged requirement IDs are recorded in the retired-IDs appendix (§14), never left as hollow live "reserved" clauses. *(D5)* | §14 |

## 12. Two decisions I adjusted, and why

Both were adopted in substance, but neither could be implemented exactly as stated without producing wrong behaviour.

### 12.1 The regional multiplier cannot modify allocation shares

A single multiplier applied uniformly to all six baseline percentages, followed by the renormalisation that REQ-AE-1 clause 5 requires, is arithmetically a no-op. The common factor cancels:

```
share_i = (baseline_i × m) / Σ(baseline_j × m)
        = (baseline_i × m) / (m × Σ baseline_j)
        = baseline_i / Σ baseline_j
```

Concretely: a ₱350,000 wedding in Palawan at 1.20 and the same wedding in NCR at 1.00 would receive **identical** category allocations — ₱140,000 to Catering & Venue in both cases. The 1.20 would have no observable effect anywhere in the product.

The travel and logistics overhead the index is meant to capture is real, but it is a statement about **absolute cost level**, not about proportion. Palawan does not change what fraction of your budget goes to catering; it changes how much wedding your budget buys. So REQ-AE-2 applies the index where it does real work:

- **Budget adequacy.** Expected total cost for the plan's size and region, compared against the actual budget, surfacing a peso shortfall or surplus. This is where a couple learns that ₱350,000 stretches further in Batangas than in El Nido.
- **Rate suggestions.** Suggested per-head rates and OOT defaults are scaled by the index, as suggestions the partner must accept.
- **Optional per-category skew.** REQ-AE-2 clauses 7 and 8 retain a genuine share-modifying mechanism for regions whose cost structure is actually skewed rather than uniformly shifted. It defaults to 1.0 everywhere, so it changes nothing until real per-category data exists.

**Open question for you:** if you did intend Destination weddings to allocate proportionally *differently* — a larger Coordination and Catering & Venue share at the expense of Attire, say — then the per-category skew values in clause 7 are where those numbers go. Uniform indices cannot express it.

### 12.2 Guest tiers describe two different things

The earlier open item asked which of `confirmed` / `invited` / `tentative` should drive per-head costs. Those are **RSVP certainty**. The answer given — Tier 1 for close family and principal sponsors, Tier 2 for general guests, defaulting to Tier 2 — describes **relationship priority**. They are orthogonal: a Tier 1 Ninong can be tentative, and a Tier 2 colleague can be confirmed.

Collapsing them into one field would lose whichever axis it replaced. REQ-GM-1 therefore models both:

- **RSVP status** drives the guest count used for per-head costs, because attendance is what generates cost.
- **Priority tier** defaults to Tier 2 as specified, and drives only the cut-list logic in REQ-GM-5 clause 9: when previewing a headcount reduction, the system reports how many Tier 2 guests absorb the cut before any Tier 1 guest is touched. It does not change per-head rates in v1 (ADR-35).

This preserves your intent — sponsors and close family are explicitly categorised and protected — without breaking per-head arithmetic.

## 13. Open items and resolved defaults

Platform, database engine, monetary display, and ruleset management are resolved (§11, decisions 7, 12, 13). Item 1 remains open (OQ-04); items 2–4 below record resolved defaults without reopening them. OQ-03 and other decision-log questions retain their own status. **OQ-11 additionally blocks verified legal/church checklist presets and date offsets**; REQ-CK-1 permits user dates/done state but does not fill this source-verification gap.

1. **Reference cost benchmarks for budget adequacy.** REQ-AE-2 clause 2 needs a reference cost per guest per region tier to compute expected total cost. The baseline *percentages* are settled; this is the separate absolute figure — roughly what a Metro-tier wedding costs per head. Without it the adequacy indicator cannot be built, though every other allocation requirement can. This is the one genuinely blocking item for a single feature.
2. **Driving RSVP default — resolved (ADR-31).** `invited` is the designated status on a new plan (REQ-GM-1 clause 6).
3. **Tier-specific per-head rates — resolved for v1 (ADR-35).** Not in v1: one rate per entry regardless of tier; priority tier drives only the Tier 2-first cut-list (REQ-GM-1 clause 9, REQ-GM-5 clause 9).
4. **Ownership-transfer confirmation expiry — resolved (ADR-32; OQ-05 closed).** Pending requests expire after 7 days; defensive removal is immediate and has no pending-confirmation window (REQ-SE-5 clause 7, REQ-SE-6).

---

## 14. Retired / merged IDs (redirect appendix)

*Per Decision D5. When a requirement or a numbered clause is retired, merged, or superseded, it is recorded here with a redirect to what replaces it — never left as a hollow live "reserved" clause. An ID once assigned is never reused for a different meaning.*

**Format:** `retired ID/clause | disposition (merged / superseded / withdrawn) | redirect target | decision | date`

| Retired ID / clause | Disposition | Redirect to | Decision | Date |
|---|---|---|---|---|
| REQ-SE-5 clause 5 (former text: "Transferring ownership requires affirmative confirmation from both partners") | Merged into REQ-SE-5 clause 4 | REQ-SE-5 clause 4 | D1, D5 | 2026-09-13 |

*No whole REQ IDs have been retired. REQ-SE-5 clause 5 now carries substantive content (a redirect to REQ-SE-6), so it is not a hollow placeholder; this table records the historical merge of its former text.*

### 14.1 Reclassified IDs (prefix no longer describes the classification)

An ID is never renumbered, so a reclassification can leave the prefix misleading. Those cases are recorded here.

| ID | Prefix implies | Actual classification | Decision | Date |
|---|---|---|---|---|
| REQ-AI-4 | AI-phase feature | **Post-launch payments phase** (development-phases §25), owned by Backend, not AI/ML. Not an AI capability and not part of the AI tail. | ADR-28 | 2026-09-14 |
