# Kasaran — Requirements (EARS)

*Derived from [mvp-user-stories.md](./mvp-user-stories.md). All requirements are **[v1]** unless tagged **[AI-phase]**.*

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
| **Deposit paid** | Cumulative amount already handed to the supplier for an entry. Defaults to 0. |
| **Balance due** | `effective_amount − deposit_paid`, floored at 0. |
| **Gross event total** | Sum of `effective_amount` across all ledger entries, including hidden-fee entries. What the wedding costs. |
| **Net out-of-pocket** | `gross_event_total − (sum of confirmed pledges + sum of received pledges)`. What the couple personally pays. |
| **Outstanding pledge exposure** | Sum of pledge values with status `confirmed` and not yet `received`. Promised but not in hand. |
| **Driving guest count** | The single guest tier designated to drive per-head cost calculations. |
| **Crew headcount** | Total supplier crew requiring meals. Tracked separately; never part of any guest count. |
| **Per-head entry** | A ledger entry whose effective amount is `per_head_rate × driving_guest_count`. |
| **Flat-rate entry** | A ledger entry whose effective amount is independent of any guest count. |
| **Ruleset version** | An immutable, identified snapshot of allocation baseline percentages and regional modifiers. |
| **Region** | The Philippine location classification of the wedding, carrying cost modifiers. |

### Monetary and rounding rules (apply to every requirement)

**REQ-GEN-1 [v1]** — THE SYSTEM SHALL store all monetary values as signed 64-bit integer centavos, and SHALL NOT use binary floating-point types for any monetary storage or arithmetic.

1. No monetary field is stored, transmitted, or computed as `float` or `double`.
2. ₱1,234.56 persists as the integer `123456`.
3. A repeated sequence of arithmetic operations on the same inputs produces a byte-identical result on every run and on both partners' devices.

**REQ-GEN-2 [v1]** — WHEN the system converts or displays a monetary value, THE SYSTEM SHALL round half-up to two decimal places and display it as PHP.

1. Display format is a peso sign, thousands separated by commas, exactly two decimals: `₱350,000.00`.
2. A half-centavo rounds away from zero (₱0.005 → ₱0.01).
3. No screen displays a currency symbol other than ₱, and no locale setting changes the currency.
4. A negative total, where one is arithmetically possible, displays with a leading minus inside the format: `−₱1,200.00`.

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

**REQ-BS-4 [v1] — Region taxonomy**
THE SYSTEM SHALL classify wedding location using a fixed, versioned region taxonomy in which each region carries cost modifiers and a destination flag.

1. The taxonomy contains at minimum: NCR / Metro Manila; Nearby Luzon (Tagaytay, Batangas, Laguna, Cavite, Rizal, Bulacan, Pampanga); Baguio / Northern Luzon; Cebu; Bohol; Boracay / Aklan; Palawan (Puerto Princesa, El Nido, Coron); Siargao; Davao; Other Visayas; Other Mindanao; Other.
2. Each region record carries a per-category cost modifier set and a boolean destination flag.
3. Region records are configuration data, versioned with the ruleset, and changeable without a code change.
4. Regions flagged as destination default the OOT prompt in REQ-HF-3 to an enabled state.
5. Selecting a region never itself creates, deletes, or modifies a ledger entry.

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
THE SYSTEM SHALL provide each ledger entry with a category, supplier name, estimated amount, actual amount, deposit paid, due date, entry type, and notes.

1. Category is selected from the fixed taxonomy; free-text category values are rejected.
2. Supplier name accepts any non-empty string up to 200 characters.
3. Estimated amount is mandatory and ≥ 0.
4. Actual amount is optional and, when set, is ≥ 0.
5. Deposit paid defaults to 0 and is ≥ 0.
6. Due date is optional.
7. Entry type is exactly one of: standard, or one of the six hidden-fee subtypes in REQ-HF-2.
8. Notes accept free text up to 2,000 characters.

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

**REQ-LG-4 [v1] — Deposits and balance**
WHEN a partner records a deposit paid on an entry, THE SYSTEM SHALL recompute that entry's balance due and the plan's paid and outstanding totals.

1. Balance due equals effective amount minus deposit paid, floored at 0.
2. IF deposit paid exceeds effective amount, THEN the system displays an overpayment warning naming both amounts, and stores the value without clamping it.
3. The plan reports total deposits paid and total balance due across all entries.
4. Deposit paid never alters estimated amount, actual amount, or gross event total.
5. Recording a deposit never initiates, authorises, or transfers funds.

**REQ-LG-5 [v1] — Derived payment status**
THE SYSTEM SHALL derive each entry's payment status as exactly one of `paid`, `pending`, or `overdue`, and SHALL NOT store payment status as a directly editable field.

1. Status is `paid` when balance due equals 0.
2. Status is `overdue` when balance due is greater than 0 and due date is non-null and earlier than the current date.
3. Status is `pending` in all other cases.
4. An entry with balance due greater than 0 and deposit paid greater than 0 reports status `pending` with an additional partially-paid indicator.
5. No user interface permits setting status directly; status changes only as a consequence of amount or date changes.
6. Status is recomputed on every read and is never persisted as authoritative state, so that two devices with different clocks cannot produce a sync conflict on status.
7. Status recomputation uses the device's local current date while offline, per REQ-OF-4.

**REQ-LG-6 [v1] — Planned versus actual variance**
THE SYSTEM SHALL display variance between allocated and effective amounts per category and for the plan total, in both peso amount and percentage.

1. Variance amount equals summed effective amount minus allocated amount for the category.
2. Variance percentage equals variance amount divided by allocated amount, rounded half-up to one decimal place.
3. IF allocated amount is 0 and effective amount is greater than 0, THEN the system displays the peso variance and suppresses the percentage rather than dividing by zero.
4. Over-allocation and under-allocation are distinguished by a cue that is not colour alone.
5. Variance updates within the same operation as any change to an allocation, estimated amount, or actual amount.

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

**REQ-HF-3 [v1] — Region-driven OOT defaulting**
WHERE the selected region carries a destination flag, THE SYSTEM SHALL default the OOT prompt to enabled and SHALL leave its amounts unfilled.

1. Selecting Palawan, Boracay, Siargao, or Bohol enables the OOT prompt by default.
2. Selecting NCR leaves the OOT prompt available but not defaulted to enabled.
3. Defaulting affects only the prompt state; it never writes an amount.
4. The partner can dismiss a defaulted-enabled OOT prompt, and the dismissal is recorded per REQ-HF-1.

---

## 4. Incoming pledges

**REQ-PL-1 [v1] — Pledge record**
THE SYSTEM SHALL provide each pledge with a sponsor name, sponsor role, pledge type, value, status, and an optional link to a ledger category or entry.

1. Sponsor name accepts any non-empty string up to 200 characters.
2. Sponsor role is one of {Ninong, Ninang, family, friend, other}.
3. Pledge type is either `cash` or `item`.
4. An `item` pledge records the item sponsored as free text up to 200 characters, and may link to a ledger category or a specific entry.
5. Value is an integer centavo amount ≥ 0.
6. Status is exactly one of {tentative, confirmed, received}.
7. Both partners can create, read, update, and delete any pledge.

**REQ-PL-2 [v1] — Gross and net displayed together**
THE SYSTEM SHALL display gross event total and net out-of-pocket simultaneously, and SHALL compute net as gross minus the sum of confirmed and received pledge values.

1. Both figures are visible on the dashboard without navigation or scrolling past a fold.
2. Net equals gross when no pledge has status confirmed or received.
3. A confirmed pledge of ₱50,000 against a gross of ₱350,000 yields a net of ₱300,000.
4. Gross never changes as a consequence of any pledge status change.
5. WHEN a pledge status changes, both figures update within the same operation.

**REQ-PL-3 [v1] — Tentative pledges excluded from net**
THE SYSTEM SHALL exclude pledges with status `tentative` from the net out-of-pocket calculation, and SHALL display their summed value separately as potential relief.

1. A tentative pledge of ₱50,000 leaves net unchanged.
2. Summed tentative value is displayed under a label distinguishing it from net.
3. WHEN a tentative pledge is changed to confirmed, net decreases by exactly that pledge's value.
4. Potential relief and net are never summed into a single displayed figure.

**REQ-PL-4 [v1] — Outstanding pledge exposure**
THE SYSTEM SHALL compute outstanding pledge exposure as the summed value of pledges with status `confirmed`, and SHALL display it distinctly from both gross and net.

1. A pledge moved from confirmed to received decreases outstanding exposure by its value and leaves net unchanged.
2. The system lists the individual pledges comprising outstanding exposure, each with sponsor name and value.
3. Outstanding exposure displays as ₱0.00, not blank, when no pledge is confirmed-not-received.

**REQ-PL-5 [v1] — Pledge traceability**
WHEN a partner inspects net out-of-pocket, THE SYSTEM SHALL show which pledges reduced it and by how much.

1. The breakdown lists each contributing pledge with sponsor name, status, and value.
2. The listed values sum exactly to the difference between gross and net.
3. Tentative pledges are absent from this breakdown.

---

## 5. Guest math

**REQ-GM-1 [v1] — Guest tiers and driving count**
THE SYSTEM SHALL maintain guest counts in the tiers `confirmed`, `invited`, and `tentative`, and SHALL apply exactly one designated tier as the driving guest count.

1. Each tier stores an independent integer ≥ 0.
2. The designated driving tier is visible wherever per-head totals are shown.
3. WHEN a partner changes the designated driving tier, every per-head entry recomputes in the same operation.
4. Crew headcount is stored separately and is excluded from all three tiers.

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

---

## 6. Rule-based allocation engine

**REQ-AE-1 [v1] — Deterministic allocation from configurable baselines**
WHEN budget setup completes, THE SYSTEM SHALL allocate the total budget across categories using configurable baseline percentages and the selected region's modifiers, from a pinned ruleset version.

1. Given identical inputs and an identical ruleset version, the engine returns identical allocations on every invocation and on both devices.
2. The engine derives allocations only from total budget, guest cap, driving guest count, region, and wedding date.
3. Baseline percentages are stored as configuration data, editable without a code change.
4. Baseline percentages across all categories sum to exactly 100% before modifiers are applied, and the system rejects a ruleset that does not.
5. The sum of allocations equals the total budget exactly; any rounding remainder is assigned to a single designated category rather than discarded.
6. THE SYSTEM SHALL NOT use inference, prediction, learned models, training data, or any generative component in allocation.

**REQ-AE-2 [v1] — Regional modifiers**
WHEN the engine allocates, THE SYSTEM SHALL apply the selected region's per-category modifiers to the baseline percentages before distributing the total budget.

1. Each region supplies a multiplier per category, defaulting to 1.0 where unspecified.
2. After modifiers are applied, the system renormalises so allocations still sum exactly to the total budget.
3. Two plans identical except for region produce different allocations whenever the two regions' modifier sets differ.
4. Two plans identical except for region produce identical allocations when both regions' modifiers are all 1.0.
5. Modifier values are configuration data, versioned with the ruleset.

**REQ-AE-3 [v1] — Ruleset version pinning**
WHEN a plan is created, THE SYSTEM SHALL pin the ruleset version then in force, and SHALL NOT retroactively apply a later ruleset to that plan without explicit partner action.

1. The pinned version identifier is stored on the plan and is visible to the partners.
2. Publishing a new ruleset leaves every existing plan's allocations numerically unchanged.
3. WHERE a partner opts into a newer ruleset, the system displays a before/after preview prior to applying it.
4. Adopting a newer ruleset preserves manual overrides per REQ-AE-5.

**REQ-AE-4 [v1] — Explainability**
WHEN a partner inspects any engine-produced figure, THE SYSTEM SHALL display the rule identifier, the input values, and the applied modifier that produced it.

1. Every allocated figure exposes its originating rule identifier.
2. The explanation states the baseline percentage, the regional modifier, and the resulting amount.
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

---

## 7. Shared editing and sync

**REQ-SE-1 [v1] — Two-partner symmetric access**
THE SYSTEM SHALL support exactly two partner accounts per plan, with identical read and write permission over all budget data.

1. A plan admits at most two partner accounts in v1.
2. No budget field is writable by one partner and read-only to the other.
3. A partner invites the second partner, who joins the plan via that invite.
4. An unaccepted invite is revocable and expires after a defined period.
5. WHEN the second partner joins, they see every existing figure identically, including manual overrides.

**REQ-SE-2 [v1] — Field-level last-write-wins**
WHEN two partners have edited the same plan and their changes reconcile, THE SYSTEM SHALL resolve conflicts at field granularity using last-write-wins by write timestamp.

1. Concurrent edits to different fields of the same entry both persist.
2. Concurrent edits to different entries both persist.
3. Concurrent edits to the same field resolve to the write with the later timestamp.
4. IF two writes to the same field carry identical timestamps, THEN THE SYSTEM SHALL resolve deterministically by a stable tiebreaker such that both devices converge on the same winner.
5. Resolution never discards an accepted local write without recording it in the change log per REQ-SE-4.
6. THE SYSTEM SHALL NOT use inference, heuristics, or any AI component in conflict resolution.

**REQ-SE-3 [v1] — Convergence**
WHEN all queued writes from both devices have been applied, THE SYSTEM SHALL present identical values on both devices.

1. Given the same set of writes, convergence is independent of arrival order.
2. After sync completes, gross, net, outstanding exposure, and every category variance match exactly across devices.
3. Re-running sync with no new writes changes nothing on either device.

**REQ-SE-4 [v1] — Visible change log**
THE SYSTEM SHALL record every create, update, and delete with the acting partner, a timestamp, the field changed, the previous value, and the new value.

1. The change log is viewable per entry and as a plan-wide activity feed.
2. Monetary changes record both previous and new value.
3. A write that lost a last-write-wins resolution appears in the log with its value preserved and its superseded outcome stated.
4. Change log entries are immutable; no user interface permits editing or deleting them.
5. Every log entry attributes exactly one partner identity.

---

## 8. Offline behaviour

**REQ-OF-1 [v1] — Full offline CRUD**
WHILE the device has no network connectivity, THE SYSTEM SHALL permit create, read, update, and delete on every v1 data type, and SHALL persist those changes locally across app termination.

1. Offline CRUD succeeds for: plan setup inputs, ledger entries, all six hidden-fee subtypes, pledges, guest tiers, crew headcount, and allocation overrides.
2. A write made offline survives a force-quit and a device restart.
3. No v1 feature is disabled, hidden, or degraded solely because the device is offline.
4. IF a v1 operation cannot complete offline, THEN that operation is a defect against this requirement.

**REQ-OF-2 [v1] — Offline computation**
WHILE the device has no network connectivity, THE SYSTEM SHALL compute the allocation engine, guest math, what-if previews, variance, gross, net, and outstanding exposure entirely on-device.

1. Allocation runs offline and returns figures identical to those the same inputs produce online.
2. A guest what-if preview runs fully offline.
3. No dashboard figure renders as unavailable, stale, or placeholder due to absent connectivity.

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
3. Replay preserves the original write timestamps for REQ-SE-2 resolution, rather than using reconnect time.
4. IF a queued write cannot be applied, THEN THE SYSTEM SHALL retain the write with its data intact, surface it to the partner, and SHALL NOT discard it.
5. Sync progress and completion are visible to the partner.

---

## 9. AI-phase requirements — excluded from v1

**REQ-AI-1 [AI-phase]** — OCR extraction of ledger entries from photographed contracts and receipts.
**REQ-AI-2 [AI-phase]** — On-device automatic categorisation of ledger entries.
**REQ-AI-3 [AI-phase]** — Cloud AI budget advice, risk warnings, forecasting, and natural-language summaries.
**REQ-AI-4 [AI-phase]** — InstaPay and QR Ph payment initiation and reconciliation.
**REQ-AI-5 [AI-phase]** — Conversational assistant for natural-language input and queries.

**REQ-EX-1 — Excluded entirely, not deferred.** THE SYSTEM SHALL NOT include a supplier marketplace, vendor directory, supplier reviews, supplier ratings, quote solicitation, or booking, in v1 or in the AI phase.

---

## 10. Traceability

| Area | Requirements | Source stories |
|---|---|---|
| Monetary base | REQ-GEN-1 … 2 | Cross-cutting |
| Budget setup | REQ-BS-1 … 6 | BS-1, BS-2 |
| Expense ledger | REQ-LG-1 … 6 | LG-1, LG-2, LG-3 |
| Hidden fees | REQ-HF-1 … 3 | HF-1, HF-2 |
| Pledges | REQ-PL-1 … 5 | PL-1, PL-2, PL-3 |
| Guest math | REQ-GM-1 … 5 | GM-1, GM-2, GM-3 |
| Allocation engine | REQ-AE-1 … 5 | AE-1, AE-2, AE-3 |
| Shared editing | REQ-SE-1 … 4 | SE-1, SE-2, SE-3 |
| Offline | REQ-OF-1 … 5 | OF-1, OF-2 |
| AI phase | REQ-AI-1 … 5, REQ-EX-1 | AI-1 … AI-5 |

---

## 11. Decisions resolved by this document

Three open items from earlier documents are now closed:

1. **Payment states — resolved.** `paid` / `pending` / `overdue`, derived rather than manually set (REQ-LG-5), with deposits modelled separately (REQ-LG-4). Partial payment is an indicator on `pending`, not a fourth state.
2. **Offline conflict policy — resolved.** Field-level last-write-wins by write timestamp, plus an immutable visible change log that preserves superseded writes (REQ-SE-2, REQ-SE-4).
3. **Regional cost variation — resolved as a mechanism.** Region is a first-class setup input with a versioned taxonomy and per-category modifiers (REQ-BS-4, REQ-AE-2).

## 12. Open items still blocking

1. **★ Baseline percentages and regional modifier values.** REQ-AE-1 and REQ-AE-2 specify the mechanism, and the engine is now buildable against placeholder configuration. The actual numbers — what share of a ₱300K NCR wedding goes to catering, and how much Palawan multiplies it — remain unsourced. I have not invented them. The engine will produce arithmetically correct nonsense until these are real.
2. **★ Plan-lifecycle permissions.** REQ-SE-1 covers data symmetry but deliberately does not state who may delete the plan or remove a partner. Recommendation remains two-party confirmation or creator-only.
3. **★ Platform.** REQ-OF-1 through REQ-OF-5 cannot be estimated or designed without knowing iOS, Android, web, or cross-platform, and whether web is in v1.
4. **Driving guest tier default.** REQ-GM-1 makes the tier partner-designated. Which tier should a new plan default to?
5. **Invite expiry period.** REQ-SE-1 requires an expiry but does not fix the duration.
6. **Rounding remainder category.** REQ-AE-1 assigns the remainder to a designated category. Which one, or should it be partner-selectable?
7. **Single active plan per account.** Still assumed yes for v1.
