# Kasaran — Testing Plan

*Test cases carry a TC ID, preconditions, steps, and an expected result verifiable by someone other than the author. Covers the plan-lifecycle, sync, and pledge behaviour affected by Decisions D1–D6 (ADR-21..26 in the decision log), plus the security suites those cases depend on. Broader feature coverage (ledger, allocation, guest math, offline sync) is scaffolded in §4 and expanded as those areas are built. Per Decision D6, shared-record erasure test cases are left un-stubbed and blocked-pending-counsel (§5); no expected value is asserted for them.*

## 1. Conventions

- **TC-SE-n** — shared editing / lifecycle. **TC-SEC-n** — security. **TC-OF-n** — offline. **TC-*-n** — other feature areas.
- A test is **PASS** only if its expected result is observed exactly. Anything unverifiable is **FAIL**, never partial (consistent with security-plan §7).
- Two-device tests use device A (partner A) and device B (partner B) on one plan, per design.md §2.5.

## 2. Plan-lifecycle & defensive removal (Decisions 1, 2)

| TC ID | Title | Preconditions | Steps | Expected result | Refs |
|---|---|---|---|---|---|
| TC-SE-10 | Creator removes partner without consent | A created the plan; B is paired; both online | A opens SCR-17, removes B, confirms the acting-partner prompt | B's `plan_members` row is deleted server-side immediately; no consent requested from B; a `change_log` entry attributes the removal to A with a timestamp | REQ-SE-6 (1,2,4), SEC-07 |
| TC-SE-11 | **Non-creating partner removes the creator** | A created the plan; B is paired; both online | B opens SCR-17, removes A, confirms | A's `plan_members` row is deleted; A's next sync is refused; `change_log` attributes the removal to B. Proves removal is mutual, not creator-only | REQ-SE-6 (1), SEC-07, ADR-19 |
| TC-SE-12 | Removed partner cannot read new data | TC-SE-10 executed; A then edits an entry | B's device attempts pull | B receives no new data; RLS returns empty for the plan; B's view is the frozen pre-removal snapshot. Ties to the cross-tenant suite (TC-SEC-01) | REQ-SE-6 (3,6), SEC-09, SEC-24 |
| TC-SE-13 | Removed partner's queued offline writes rejected on reconnect | B goes offline, makes 3 local edits (queue depth 3); A removes B while B is offline; B reconnects | B's device replays its queue | All 3 pushes are rejected server-side by RLS; no total on A's plan changes; B is shown the removed-state notice; B's local copy still shows B's 3 edits locally (not wiped) | REQ-SE-6 (3,5,6), SEC-09, REQ-OF-5 |
| TC-SE-14 | Removed partner keeps local copy; no remote wipe | TC-SE-10 executed | Inspect B's device after removal | B's SQLite store still contains all previously synced data; B sees read-only mode with the removed-state copy; no server action deleted B's local data | REQ-SE-6 (5,7), ux-spec §3.3 |
| TC-SE-15 | Removal attribution appears in change log | TC-SE-10 executed | A opens SCR-16 | The removal appears as an immutable, attributed lifecycle entry with actor A and timestamp; it cannot be edited or deleted | REQ-SE-6 (4), REQ-SE-4 (4,5) |
| TC-SE-16 | Ownership transfer STILL requires two-party confirmation | A and B paired, both online | A initiates ownership transfer to B on SCR-17 | A `lifecycle_confirmations` row (action `transfer_ownership`) is created in pending state; transfer does NOT take effect until B affirmatively confirms; both retain full access while pending | REQ-SE-5 (4,6), ADR-18 |
| TC-SE-17 | Removal is not a two-party action | A and B paired | A removes B | No `lifecycle_confirmations` row is created for the removal; it is a direct delete. Confirms removal bypasses the two-party path entirely | REQ-SE-6, design.md §4.1 |
| TC-SE-18 | Plan deletion remains creator-only | A created plan; B paired | B attempts plan deletion | B is not offered the delete action; if the endpoint is invoked directly, it is refused with a creator-only message | REQ-SE-5 (1,2) |
| TC-SE-19 | Accidental-tap guard on removal | A on SCR-17 | A taps remove but does not complete the typed/deliberate confirmation | No removal occurs; B remains a member | ux-spec SCR-17, REQ-SE-6 (2) |
| TC-SE-20 | LWW resolves by server-assigned timestamp, not device clock | A and B on same plan; **B's device wall clock is set 10 minutes fast**; both edit the same field | B edits field to X (fast clock), A edits same field to Y afterward in real time; both sync | The write with the later **server-assigned** timestamp wins (A's Y), regardless of B's fast device clock; B's fast clock does not win the conflict | REQ-SE-2 (3,5), ADR-21/D1 |
| TC-SE-21 | Monotonic-counter tiebreak on equal server timestamp | Two writes to the same field accepted with the same `server_ts` | Force/simulate identical `server_ts` for two field writes | Resolution picks the higher device monotonic counter; if equal, the higher stable device id; both devices converge on the same winner | REQ-SE-2 (4), ADR-21/D1 |
| TC-SE-22 | Simultaneous mutual removal has a deterministic winner | A and B both offline; A removes B on A's device; B removes A on B's device; both then reconnect (in either order) | Both removals sync | Exactly one partner survives; the winner is the removal with the earlier `server_ts`, tiebroken on stable id (REQ-SE-6 clauses 9–11); result is identical on the server and on both devices regardless of sync order; the plan is never left with zero members; the losing removal is recorded as superseded in the change log | REQ-SE-6 (9,10,11), ADR-24/D4, SEC-07 |

## 2b. Pledge fulfillment math (Decision D2 / ADR-22)

| TC ID | Title | Preconditions | Steps | Expected result | Refs |
|---|---|---|---|---|---|
| TC-PL-10 | Promised pledge does not reduce net; shows as expected | Gross ₱350,000; no pledges | Add a `confirmed` pledge of ₱50,000 | Net remains ₱350,000 (unchanged); the expected-pledge figure shows ₱50,000; the two figures are displayed distinctly and never summed | REQ-PL-2 (4), REQ-PL-3 (1,2,4), ADR-22/D2 |
| TC-PL-11 | Fulfillment reduces net and expected together | State from TC-PL-10 (net ₱350,000, expected ₱50,000) | Change the pledge status `confirmed` → `received` | Net decreases to ₱300,000; expected-pledge figure decreases to ₱0.00; outstanding exposure decreases accordingly; all in the same operation | REQ-PL-2 (3,6), REQ-PL-3 (3), REQ-PL-4 (1), ADR-22/D2 |
| TC-PL-12 | Tentative behaves as expected, not net | Gross ₱350,000 | Add a `tentative` pledge of ₱20,000 | Net unchanged at ₱350,000; expected-pledge figure includes the ₱20,000; net breakdown (REQ-PL-5) does not list it | REQ-PL-3 (1), REQ-PL-5 (3), ADR-22/D2 |

## 3. Security suites these depend on

| TC ID | Title | Steps | Expected result | Refs |
|---|---|---|---|---|
| TC-SEC-01 | Cross-tenant denial (CI gate-blocker) | Automated: user of plan X attempts read/update/delete on plan Y rows, including a forged `plan_id` sync pull, AND a formerly-valid member post-removal replays their last token | Every attempt returns empty or denied by RLS; the post-removal replay is denied identically to a never-member. Suite is green in CI before internal beta | SEC-24, SEC-09 |
| TC-SEC-02 | Removed member token replay | After TC-SE-10, replay B's last valid access token directly against pull and push endpoints | Both refused server-side; not reliant on client checks | SEC-07, SEC-09 |
| TC-SEC-03 | No cloud auto-backup of local DB | Trigger a device cloud backup; inspect backup contents | The encrypted SQLite DB and its key are absent from the backup | SEC-16 |

**Note.** TC-SEC-01 is the general guarantee; TC-SE-12 and TC-SEC-02 are the removal-specific directions of the same property. A removed partner is, from removal onward, a non-member reaching a plan they no longer belong to — exactly the cross-tenant case.

## 4. Feature-area coverage (scaffold)

Expanded as each area is implemented; listed so the plan's scope is visible.

- **TC-AE-*** — allocation determinism, regional cost index does not alter shares, buffer drawdown, override preserve/revert.
- **TC-HF-*** — six fee types with correct per-type input shapes; crew meals excluded from guest scaling.
- **TC-PL-*** — gross vs net (net reduced only on fulfillment, D2), expected figure shown distinctly, exposure math. TC-PL-10..12 above cover the D2 core.
- **TC-GM-*** — per-head propagation, crew separation, what-if commit/discard byte-identical state.
- **TC-OF-*** — full offline CRUD, idempotent replay, queued-write attribution and preserved device sequence (server assigns `server_ts` on sync, D1).
- **TC-SYNC-*** — field-level LWW convergence by server timestamp (D1), superseded-write visibility, monotonic-counter tiebreak.

## 5. Open questions raised by testing

- **Erasure vs mutual removal (ADR-O1, SEC-33/38).** With mutual one-sided removal, each partner independently controls one shared record. A test for "partner A requests erasure" must confirm B's lawful copy survives and that erasure is distinct from removal — but the correct behaviour is counsel-gated and not yet defined, so TC-ERASE-* cannot be authored with a verifiable expected result until ADR-O1 is resolved. Flagged, not stubbed with a guessed outcome.
