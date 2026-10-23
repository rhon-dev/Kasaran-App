# Phase 10 expense ledger and unticked templates — draft design

**Status:** Design draft only. Phase 10 depends on Phase 09 plan setup and Phase 07/08 account-safe persistence, server authorization and sync. Existing local `ledger_entries` writer is a partial Phase 07 slice; its tests are not Phase 10 acceptance.

## Scope and data flow

SCR-07 reads only the current `AccountLease` projection. It lists category, effective amount, independently derived paid/balance/status, due-soon dated obligations and a distinct overdue group. SCR-08 edits supplier/category/pricing/estimate/actual/notes plus separate schedule items and payment/refund rows. Flat entries store a nonnegative estimate; per-head entries store a nonnegative rate with null stored estimate. Effective amount uses actual when present; derived estimates, deposit sums, status and variance are never synced as authoritative fields. Notes stop at 2,000 characters. Delete needs confirmation, writes a tombstone and removes live totals without deleting history.

Payment and refund records have distinct client IDs and **positive** centavos, method/date and optional same-entry schedule attribution. Refund subtracts from derived deposit; overpayment warns without clamping historical paid amount. A correction tombstones the old monetary row and inserts a new row, not an overwrite of a cumulative field. No in-app transfer or charge. Schedule rows are independent, dated, positive, and sum no more than effective amount. Without a schedule, display a virtual undated balance; under-schedule yields a virtual undated residual. Allocate net paid by due date, sort order and stable ID; optional payment attribution does not change allocation order. Recompute paid/overdue/due-soon/pending on read using device-local date and configured window, not a stored status. Local reminders use generic lock-screen text without supplier or amount; only unpaid dated obligations notify.

SCR-21 reads stable named variants and suggestions from a validated pinned bundled ruleset. Suggestions carry name, category, pricing mode and stable ID but **no** supplier, amount, rate or recommended vendor. Tapping one only opens SCR-08 preselected for editing. Cancel creates no row and leaves it unticked; save requires user-entered nonblank supplier and valid amount/rate. No phantom zero-value expense or automatic applicability assertion.

## Proposed sittings and gates

1. Full local schedule/payment schema and typed writer: RED/GREEN tests for encrypted reopen, same-plan links, exact cents, positive refund, correction tombstones, atomic projection/event/outbox and commit-lease switch. Pair-related writes await a separately tested atomic server boundary.
2. Ledger screens/presenter: SCR-07/08 UI state matrix and widget tests for errors, deletion, virtual balance, due-soon, refund reopening and account A→B→A; no user can select derived status.
3. Unticked templates and device-local reminders: pinned ruleset validation, cancellation/no-write test, local-date scheduling/cancellation and privacy-copy tests. No generic fixture prices or provider recommendation.

Before implementation, reconcile design, requirements, UX inventory/states, test traceability and a new ADR only if a new decision is made. The four v1 gates pass at design level: deterministic math, explainable totals, no money movement, no supplier recommendation. No AI.
