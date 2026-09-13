# Kasaran — MVP Definition & User Stories

*Derived from [project-brief.md](./project-brief.md). Every story is tagged **[v1]** or **[AI-phase]**. The tag is binding: an AI-phase story does not enter a v1 sprint without an explicit written scope decision.*

---

## 1. MVP definition — the end-to-end scenario

The MVP is "done" when the following scenario runs start to finish, on real devices, without a workaround at any step. This is the acceptance test for the release, not an illustration.

1. **Partner A creates an account and a wedding plan**, setting the wedding date and confirming PHP as the currency. The plan is the single container for all budget data.
2. **A completes budget setup**: total budget ₱350,000, guest count 150, venue type *garden*, ceremony type *church*, out-of-town *yes*. Setup completes in under 10 minutes.
3. **The allocation engine produces a category-level budget** from those five inputs, using a pinned ruleset version. Every allocated figure is inspectable — A can tap any category and see which rule and inputs produced it.
4. **A overrides one category allocation manually** (raises catering, lowers flowers). The override is stored, visibly marked as an override, and the remaining categories rebalance without discarding it.
5. **A invites Partner B to the plan.** B accepts, signs in on a separate device, and sees the identical plan with identical figures — including A's override.
6. **The app prompts for all six hidden-fee categories** as part of setup, not buried in a menu: crew meals, OOT fees, church aircon, corkage, overtime, venue power.
7. **A fills crew meals** as 18 suppliers × ₱350 per meal, and the total flows into the gross budget as its own line, separate from guest catering.
8. **A fills OOT fees** for three out-of-town suppliers (travel, lodging, per-diem each) and the **church aircon premium** at ₱8,000.
9. **A explicitly dismisses corkage** (the venue allows none). The dismissal is recorded as a deliberate choice with a timestamp — not a silent empty field.
10. **Overtime and venue power remain unfilled and stay visibly flagged as outstanding**, so the couple can see exactly which known-risk fees they have not yet priced.
11. **The dashboard shows the gross event total**, including all filled hidden fees, and the variance against the ₱350,000 budget.
12. **B logs a pledge**: Ninong Ramon, principal sponsor, ₱50,000 cash, status *tentative*. B's device and A's device both show it.
13. **The dashboard shows gross and net side by side.** The tentative pledge does **not** reduce net out-of-pocket; it appears separately as potential relief. Net still equals the full gross at this point.
14. **B marks the pledge confirmed.** Net out-of-pocket drops by ₱50,000, gross is unchanged, and the ₱50,000 now appears as outstanding pledge exposure (confirmed but not yet received).
15. **A runs a guest what-if**, changing 150 guests to 180, and sees a **preview** of the impact before committing anything.
16. **Every per-head cost recomputes in the preview** — catering, favors, invitations, seating. Crew meals do **not** change, because crew headcount is tracked separately from guest headcount.
17. **A commits the what-if.** The dashboard updates gross, net, per-category variance, and the over/under-budget state consistently. B's device reflects the same figures.
18. **B goes fully offline** (airplane mode) and keeps working: edits a supplier's actual amount, adds a new ledger entry, and marks a payment. All writes succeed locally.
19. **A, still online, edits a different field on the same ledger entry B is editing.** Both edits are retained.
20. **B reconnects.** Sync converges both devices to identical figures with no lost writes, the change history attributes each edit to the partner who made it, and any true field-level conflict is surfaced rather than silently resolved.

**Additional gate — offline is not a degraded mode.** Steps 2 through 17 must also be completable start to finish with connectivity disabled for the entire duration, with all work queued and syncing correctly on reconnect. If any step in that range requires a network round-trip, the MVP is not done.

---

## 2. Roles — Partner A and Partner B

**Data access is fully symmetric.** Both partners have identical read and write permission over every budget object: budget setup inputs, allocations and overrides, ledger entries, hidden-fee items, pledges, and guest counts. There is no approver, no owner-only field, and no read-only partner. This is shared money; an asymmetric model would push one partner back to a private spreadsheet, which is the exact failure we are trying to eliminate.

**Two asymmetries exist, and both are structural rather than permission-based:**

| Concern | A/B difference | Rationale |
|---|---|---|
| **Plan creation & invite** | Whoever creates the plan is the first member and issues the invite. Bootstrap only — it confers no ongoing privilege. | Someone has to create the plan. Once B joins, the roles are indistinguishable. |
| **Edit attribution** | Every write is stamped with the partner who made it. | Required by the change-history objective. This is identity, not permission — it does not gate any action. |

**Plan-lifecycle permissions — DECIDED (Decisions 1 and 2).** Symmetric data rights are qualified by three distinct lifecycle rules: **plan deletion is creator-only** (REQ-SE-5); **ownership transfer requires two-party confirmation** (REQ-SE-5 clause 4); and **defensive partner removal is mutual and one-sided** — either partner may remove the other without consent, effective on the removed partner's next sync, logged and attributed (REQ-SE-6). The removed partner keeps their existing local copy, which is not remotely wiped. Everything else stays symmetric.

---

## 3. User stories

### 3.1 Budget setup

**BS-1 [v1] — Guided initial setup**
*As a partner, I want to enter my total budget and a few basic wedding facts, so that I get a usable category budget without building it from scratch.*

1. Setup SHALL collect exactly five inputs: total budget (PHP), wedding date, guest count, venue type, ceremony type, plus an out-of-town flag.
2. Venue type SHALL offer *hotel*, *garden*, and *other*; ceremony type SHALL offer *church*, *civil*, and *other*.
3. The system SHALL reject a total budget that is non-numeric, negative, or zero, with an inline message naming the problem.
4. The system SHALL accept any total budget from ₱1 upward, and SHALL NOT block budgets below ₱30,000 or above ₱500,000.
5. All monetary values SHALL display as PHP with a peso sign and thousands separators.
6. On completion, the system SHALL produce a category-level allocation and route the partner to the hidden-fee prompts.
7. A partner SHALL be able to return to setup at any later time and change any input, with downstream figures recomputing.

**BS-2 [v1] — Edit setup inputs without losing work**
*As a partner, I want to change a setup input later, so that my plan survives a venue or guest-count change.*

1. Changing a setup input SHALL recompute engine-derived allocations.
2. Changing a setup input SHALL NOT delete or overwrite manual allocation overrides, ledger entries, hidden-fee items, pledges, or guest data.
3. Before applying a change that alters more than one category, the system SHALL show a preview of the affected figures.
4. The partner SHALL be able to cancel the preview with no change persisted.

### 3.2 Rule-based allocation engine

**AE-1 [v1] — Deterministic allocation**
*As a partner, I want my budget split across supplier categories automatically, so that I start from a realistic plan instead of a blank sheet.*

1. Given identical setup inputs and an identical ruleset version, the engine SHALL always produce identical allocations.
2. The engine SHALL derive allocations only from budget band, guest count, venue type, ceremony type, and the OOT flag.
3. The engine SHALL NOT use inference, prediction, learned models, or any generative component.
4. The sum of category allocations SHALL equal the total budget, with any rounding remainder assigned to a single named category rather than silently dropped.
5. Allocation rules SHALL be stored as versioned data, editable without a code change.
6. Each plan SHALL pin the ruleset version in force when it was created, so published rule updates never silently change an existing couple's numbers.

**AE-2 [v1] — Explainable allocation**
*As a partner, I want to see why a category got the amount it did, so that I can trust the number before I commit to it.*

1. Every engine-produced figure SHALL expose the rule identifier and the input values that produced it.
2. The explanation SHALL be readable without technical knowledge — plain-language rule description, not a formula dump.
3. The system SHALL NOT present any figure that cannot be traced to a rule and its inputs.

**AE-3 [v1] — Manual override**
*As a partner, I want to override any allocation, so that the plan reflects what we actually care about spending on.*

1. A partner SHALL be able to set any category allocation to any non-negative value.
2. An overridden category SHALL be visibly marked as overridden and SHALL display both the override and the original engine value.
3. Subsequent recomputation SHALL preserve overrides and rebalance only non-overridden categories.
4. If overrides alone exceed the total budget, the system SHALL surface an over-allocation warning and SHALL NOT silently reduce any override.
5. A partner SHALL be able to revert an override back to the engine value.

### 3.3 Expense ledger

**LG-1 [v1] — Record and maintain expenses**
*As a partner, I want to log every supplier cost with its real amount, so that we always know where the money actually went.*

1. A ledger entry SHALL support: category, supplier name, quoted amount, actual amount, payment state, due date, and free-text notes.
2. Category SHALL be selected from a fixed taxonomy; free-text categories SHALL NOT be permitted.
3. Entry creation, edit, and deletion SHALL be available to both partners.
4. Deletion SHALL require confirmation and SHALL be recorded in change history.
5. Entries SHALL be manually created; no import, scan, or automatic capture is in v1.

**LG-2 [v1] — Payment state tracking**
*As a partner, I want to track how far along each supplier payment is, so that I know what we still owe and when.*

1. Each entry SHALL carry exactly one payment state from a fixed set (pending confirmation with the user — see open items).
2. The system SHALL compute total committed, total paid, and total outstanding across the plan.
3. The system SHALL surface entries whose due date has passed while still carrying an unsettled state.
4. The system SHALL record that a payment occurred; it SHALL NOT initiate, process, or transfer funds.

**LG-3 [v1] — Planned vs. actual variance**
*As a partner, I want to see where we are over or under our plan, so that we can correct course while there is still time.*

1. The system SHALL display variance between allocated and actual amounts per category and for the plan total.
2. Variance SHALL be expressed in both peso amount and percentage.
3. Over-budget categories SHALL be visually distinguished from under-budget ones, using a cue that does not rely on colour alone.
4. Variance SHALL update immediately on any change to allocations or actual amounts.

### 3.4 Hidden-fee line items

**HF-1 [v1] — All six fees prompted, never assumed away**
*As a partner, I want the app to ask me about the fees that ambush couples, so that I price them months out instead of the week of the wedding.*

1. The system SHALL prompt for all six categories during setup: crew meals, OOT fees, church aircon premium, corkage, overtime, and venue power.
2. Each category SHALL initialise as *prompted but unfilled* and SHALL NOT default to zero.
3. A partner SHALL be able to either fill a category or explicitly dismiss it; dismissal SHALL be recorded with a timestamp and the dismissing partner.
4. Unfilled, undismissed categories SHALL remain visibly flagged as outstanding on the dashboard.
5. The system SHALL NOT allow setup to be marked complete while any of the six is in an untouched state — filled or dismissed are both acceptable, ignored is not.

**HF-2 [v1] — Fee-specific input shapes**
*As a partner, I want each hidden fee to be entered the way it is actually charged, so that the number I get is right rather than a guess.*

1. Crew meals SHALL be entered as supplier crew headcount × per-meal rate, and SHALL total independently of guest catering.
2. OOT fees SHALL be recorded per supplier with separate travel, lodging, and per-diem components.
3. Church aircon SHALL be a single flat premium amount.
4. Corkage SHALL support multiple entries by item type (cake, wine, lechon, other).
5. Overtime SHALL be entered as hourly rate × projected hours, per supplier.
6. Venue power SHALL support generator, surcharge, and electrical-requirement amounts.
7. Every hidden-fee total SHALL appear in the gross event total and be attributable to its own line, not merged into a parent category.

### 3.5 Pledges

**PL-1 [v1] — Record sponsor and family pledges**
*As a partner, I want to record what our Ninongs, Ninangs, and family have promised, so that it lives in the budget instead of in group chats.*

1. A pledge SHALL support: pledger name, role (Ninong, Ninang, family, other), pledge type (cash amount or a specific item/category), value, and status.
2. Status SHALL be one of *tentative*, *confirmed*, or *received*.
3. Both partners SHALL be able to create, edit, and delete pledges.
4. An item-type pledge SHALL be linkable to a ledger category or entry.

**PL-2 [v1] — Gross vs. net out-of-pocket**
*As a partner, I want to see both what the wedding costs and what we personally pay, so that we can plan our own cash instead of guessing.*

1. The dashboard SHALL display gross event total and net couple out-of-pocket as two distinct, simultaneously visible figures.
2. Net out-of-pocket SHALL equal gross total minus the sum of *confirmed* and *received* pledges.
3. *Tentative* pledges SHALL NOT reduce net out-of-pocket, and SHALL be shown separately as potential relief.
4. Changing a pledge status SHALL update net immediately.
5. The system SHALL let a partner see which pledges are reducing net, and by how much.

**PL-3 [v1] — Outstanding pledge exposure**
*As a partner, I want to know which promised money has not actually arrived, so that we are not counting on cash we do not have.*

1. The system SHALL compute outstanding pledge exposure as the sum of pledges that are *confirmed* but not *received*.
2. Outstanding exposure SHALL be displayed distinctly from both gross and net.
3. The system SHALL list the individual unfulfilled pledges making up that figure.

### 3.6 Guest math

**GM-1 [v1] — Guest count with tiers**
*As a partner, I want to track guests by how certain they are, so that our headcount reflects reality.*

1. The system SHALL maintain guest counts in three tiers: *confirmed*, *invited*, and *tentative*.
2. The system SHALL expose which tier drives cost calculations, and allow the partner to choose.
3. Crew headcount SHALL be maintained separately and SHALL NOT be included in guest counts.

**GM-2 [v1] — Per-head cost propagation**
*As a partner, I want a guest-count change to update every per-head cost, so that I am not recalculating a spreadsheet by hand.*

1. Ledger entries and allocations SHALL be markable as per-head, with an associated per-head rate.
2. A change to the driving guest count SHALL recompute every per-head item automatically.
3. Crew meals SHALL NOT change in response to a guest-count change.
4. Recomputation SHALL propagate to gross total, net out-of-pocket, and per-category variance in the same operation.

**GM-3 [v1] — Guest what-if preview**
*As a partner, I want to test a guest-count change before committing, so that I can see the cost of inviting more people without wrecking our plan.*

1. A partner SHALL be able to enter a hypothetical guest count and see the full projected impact without persisting anything.
2. The preview SHALL show before/after gross, net, and per-category figures.
3. The partner SHALL be able to commit or discard the preview.
4. Discarding SHALL leave the plan byte-identical to its pre-preview state.
5. A preview SHALL NOT be visible to or sync to the other partner until committed.

### 3.7 Shared editing and sync

**SE-1 [v1] — Two-partner shared plan**
*As a partner, I want my partner and me on the same plan, so that we stop keeping separate versions.*

1. A plan SHALL support exactly two partner accounts in v1.
2. A partner SHALL invite the second partner, who joins via that invite.
3. Once joined, both partners SHALL have identical read and write access to all budget data.
4. An unaccepted invite SHALL be revocable and SHALL expire.

**SE-2 [v1] — Convergent concurrent editing**
*As a partner, I want our simultaneous edits to both survive, so that neither of us loses work.*

1. Concurrent edits to *different* fields or entries SHALL both be retained.
2. Sync SHALL converge both devices to an identical state given the same set of writes, regardless of arrival order.
3. Conflict resolution SHALL be deterministic and rule-based, with no inference or AI merge.
4. A true same-field conflict SHALL be surfaced to the partners rather than silently discarded (exact policy pending — see open items).
5. Sync SHALL NOT drop an accepted local write under any resolution outcome.

**SE-3 [v1] — Change attribution**
*As a partner, I want to see who changed what, so that we can talk about a number instead of arguing about it.*

1. Every create, edit, and delete SHALL record the acting partner and a timestamp.
2. History SHALL be viewable per entry and as a plan-wide activity feed.
3. History SHALL show the previous and new value for edited monetary fields.
4. History entries SHALL NOT be editable or deletable by either partner.

### 3.8 Offline mode

**OF-1 [v1] — Full offline read and write**
*As a partner, I want the app to work with no signal, so that I can use it at a venue, in a church, or in a basement function room.*

1. All budget data previously synced to the device SHALL be readable offline.
2. Creating, editing, and deleting budget objects SHALL succeed offline and persist across app restart.
3. The allocation engine, guest math, what-if preview, and all dashboard figures SHALL compute fully on-device with no network dependency.
4. The app SHALL clearly indicate offline state and the presence of unsynced changes.
5. No v1 feature SHALL be disabled or degraded solely because the device is offline.

**OF-2 [v1] — Reliable sync on reconnect**
*As a partner, I want my offline work to sync correctly when I get signal back, so that I never redo anything.*

1. Offline writes SHALL be queued durably and survive app termination and device restart.
2. On reconnect, queued writes SHALL replay automatically without partner action.
3. Replay SHALL be idempotent — a retried or duplicated write SHALL NOT double-apply.
4. If a write cannot be applied, the system SHALL surface it to the partner with the data intact and SHALL NOT discard it.
5. Sync progress and completion SHALL be visible to the partner.

### 3.9 AI-phase backlog — not in v1

Recorded here only so the boundary stays explicit. None of these enter a v1 sprint.

**AI-1 [AI-phase] — OCR contract parsing.** *As a partner, I want to photograph a supplier contract and have its line items extracted, so that I stop typing them in.*
**AI-2 [AI-phase] — On-device AI categorization.** *As a partner, I want entries categorised automatically, so that I do not pick a category every time.*
**AI-3 [AI-phase] — Cloud AI reasoning.** *As a partner, I want budget advice, risk warnings, and forecasts, so that I get guidance beyond arithmetic.*
**AI-4 [AI-phase] — InstaPay / QR Ph payments.** *As a partner, I want to pay suppliers in-app, so that recording and paying are one action.*
**AI-5 [AI-phase] — Chat assistant.** *As a partner, I want to ask questions in plain language, so that I do not navigate menus.*

**Excluded entirely, not deferred:** supplier marketplace, vendor directory, reviews, and booking. Per the project brief this is a different business, not a later release.

---

## 4. Definition of Ready

A story may enter development only when all of the following hold:

1. The story is tagged **[v1]**, and passes all four v1/AI-phase line tests in the project brief (deterministic, explainable, does not touch a payment rail, does not recommend a supplier).
2. Acceptance criteria are written, numbered, and individually testable — no criterion requiring subjective judgement to verify.
3. Every monetary calculation in the story has its formula stated explicitly, including rounding behaviour.
4. Offline behaviour is specified: what works offline, what queues, and what the partner sees.
5. Sync and conflict behaviour is specified for any story that writes shared data.
6. Symmetric-access implications are confirmed — no story introduces an unintended A/B permission asymmetry.
7. Any dependency on unresolved open items (allocation source data, payment states, conflict policy, platform) is either resolved or explicitly stubbed with a decision to revisit.
8. Test data is identified, including at least one case below ₱30,000 and one above ₱500,000.

## 5. Definition of Done

A story is done only when all of the following hold:

1. Every acceptance criterion has an automated test, and all pass.
2. Determinism is verified: identical inputs produce identical outputs across repeated runs and across both devices.
3. Explainability is verified: every figure the story produces traces to a rule and its inputs.
4. **No AI, inference, or generative component was introduced** — verified by review, including no new model dependency and no new outbound AI service call.
5. The story works fully offline where OF-1 applies, and its writes replay idempotently on reconnect.
6. Two-device test passes: both partners' devices show identical figures after sync, with correct attribution in change history.
7. All money displays as PHP with correct formatting; no hardcoded non-PHP currency or locale.
8. Boundary cases pass: zero, negative rejection, very small budgets, very large budgets, zero guests, and rounding remainders.
9. Accessibility check passes for any new UI: keyboard/screen-reader reachable, and no status conveyed by colour alone.
10. The end-to-end MVP scenario in section 1 still passes in full — no regression to any earlier step.
11. Change history correctly records the story's writes, and history remains immutable.

---

## Open items to confirm

Carried forward from the project brief, plus new ones this document surfaced. The starred items block specific stories.

1. **★ Payment states (blocks LG-2).** I left the state set deliberately unspecified. My earlier proposal was quoted / committed / partially paid / settled, but local practice is closer to reservation fee → downpayment → balance. Which model do you want?
2. **★ Offline conflict policy (blocks SE-2 AC-4).** Field-level last-write-wins, per-entry ownership, or surface-to-partner for manual resolution? This drives the data model, so it needs deciding before design.
3. **★ Allocation rule source data (blocks AE-1).** Still the biggest gap. The engine needs real PH category benchmarks for the ₱30K–₱500K band. I have not invented percentages and will not.
4. **Plan-lifecycle permissions — RESOLVED (Decisions 1 and 2).** Plan deletion is creator-only; ownership transfer needs two-party confirmation; defensive partner removal is mutual and one-sided (either partner, no consent, removed partner keeps their local copy). See REQ-SE-5, REQ-SE-6.
5. **Driving guest tier (affects GM-1 AC-2).** I made this partner-selectable. Simpler alternative is to always drive costs from *confirmed*. Preference?
6. **Tentative pledges and net (affects PL-2 AC-3).** I ruled that tentative pledges do not reduce net, on conservatism grounds. Confirm you agree — it is a judgement call, not a given.
7. **Platform.** Still undecided, and OF-1/OF-2 cannot be estimated without it. iOS, Android, web, or cross-platform, and is web in v1 at all?
8. **Single active plan per account?** Assumed yes for v1.
