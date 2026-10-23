# Phase 09 budget setup and checklist — draft design

**Status:** Design draft only; implementation not approved by this draft. Phase 09 depends on Phase 07 account-safe plan persistence and Phase 08 sync. No phase exit, release or real-user claim.

## Scope and data flow

The existing SCR-03 budget/date flow is a session-only draft. SCR-04 adds guest cap, region and nullable ceremony/venue types using the pinned bundled taxonomy; no plan or fee is persisted during draft navigation. A verified account's generation-bound store and server membership must be ready before a single validated plan creation can complete. The creation RPC's required fields and persisted `plans` schema must be checked together before wiring submission. Invalid budget/date/cap/region leaves all other entered inputs intact. A past date needs explicit confirmation. Account loading/error, sign-out or A→B→A clears draft and any open confirmation. The transition to SCR-05 must not imply completed setup: six fee decisions remain required there under REQ-HF-1, owned by Phase 11.

Allocation is calculated locally from the pinned ruleset and valid budget/region. It must be explainable and use integer centavos and basis points; a missing ruleset blocks figures rather than guessing. Region choice alone creates no ledger entry. Guest cap is a warning ceiling, never the per-head multiplier. A post-setup change keeps ledger, guest, pledge and overrides intact; show a no-write before/after preview when more than one category changes, and persist the accepted edit and change log atomically.

SCR-22 requirements checklist uses stable bundled item identifiers with labels and verification state. Until OQ-11's item-specific source/date review, each unverified preset displays “NEEDS VERIFICATION,” has no preset due date, and makes no universal eligibility or fee assertion. Either partner may set a **user-entered** reminder date and independent done state; those are separate fields with ordinary sync history. User-entered date never shifts when wedding date changes. Optional user-entered fee stays outside all totals until the couple explicitly confirms a positive exact-centavo conversion through the ledger editor; cancelling or zero creates no entry. Concurrent first edits materialize one stable plan/item row, not duplicate items. Re-editing a checklist fee never mutates an existing linked ledger row.

## Proposed sittings and gates

1. Form/draft: SCR-04 inputs and session binding; widget and router tests for missing fields, invalid budget, past date, sign-out and A→B→A. No persistence.
2. Persistence: once Phase 07/08 boundaries pass, create a plan once with required server fields, verified session and local event transaction; reopen and two-device tests prove no partial plan or lost draft. Allocation preview and apply have no write on cancel.
3. Manual checklist: versioned labels, unverified states, user date/done/fee fields and explicit ledger handoff; negative tests for invented due dates, implicit fees, duplicate creation and foreign plan. Verified presets remain blocked by OQ-11.

No new screen or requirement IDs are assigned in this draft; before implementation, reconcile SCR-04/SCR-22 state matrices, requirements, test traceability and any new ADR under repository precedence. The four v1 gates pass at design level: deterministic rules, explainable inputs, no money movement, no supplier recommendations. No AI.
