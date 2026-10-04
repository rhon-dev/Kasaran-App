# Phase 06 Invite Controls Design

## Scope and authority

Build only invitation issue/revoke controls in SCR-17 for an existing plan member. REQ-SE-1 clauses 1, 3–5, 8, SEC-05/06, `docs/development-phases.md` Phase 06 and the existing `issue_invite`/`revoke_invite` RPCs govern this slice. No new ADR or persisted entity. Budget setup, partner removal, transfer, deletion, and replay remain outside this slice. These controls are deterministic, explainable, move no money, and recommend no supplier (`project-brief.md` §4).

## Architecture and data flow

Add a focused invitation repository with `pairingEligibility(planId)`, `listInvites(planId)`, `issueInvite(planId)` and `revokeInvite(inviteId)` methods backed by the authenticated Supabase client. Eligibility reads `plans.is_active` and the member count through the account's RLS-protected plan; it is a UI hint, not authorization. The existing RLS-protected `invites` SELECT exposes only metadata, not `token_hash`. Only the RPC may issue or revoke. Reuse `currentPlanIdProvider` to select the account's plan; null, loading or error must not become a guessed plan ID. Check current email verification before issuing; the server remains authoritative for membership, active-plan and two-member checks.

Replace SCR-17's placeholder only for the invitation block. While online and a verified member of an active solo plan, show Issue invitation. An issued response provides an ID, expiry, and raw 32-character token; construct `kasaran://accept/{token}` only in widget memory, show it once with a warning to copy now, and drop the widget's reference on revoke, route exit, sign-out, or disposal. Never persist or log the token, include it in an error message, or reconstruct it from the list. List outstanding invitations by ID/expiry/status using only authorized metadata; allow revocation of unaccepted and unrevoked invitations. A second member or inactive plan makes issuance unavailable; the server enforces this even if UI state is stale. Existing active invitations can coexist unless a separate product decision later limits them.

## Errors and states

Loading membership or invitations shows progress, not Issue. A failed membership/list read shows a retry action, not an empty list. Failed issue/revoke shows a generic non-sensitive retry message and keeps the existing list state. After issue/revoke, invalidate/refetch invitation metadata. A revoked token vanishes from the transient link display immediately; the server will reject acceptance. Offline means issue/revoke unavailable or fails safely; no local queue. The rest of SCR-17 is explicitly labelled as not yet available rather than presented as completed lifecycle actions.

## Verification and boundaries

Write failing repository and widget tests first. Cover: RPC parameter/response handling; no token in metadata list; missing/failed membership blocks issue; issue displays a one-time link; revoke calls server and removes displayed link; failure never fabricates success; sign-out and disposal clear transient state. Extend local synthetic API tests only for any uncovered issue/revoke server behavior. Run focused tests, full Flutter suite, local synthetic identity suite and analysis. Update the SCR-17 UX state row and Phase 06 evidence ledger with executed results, without claiming complete Phase 06, real-user approval, or remote CI. The link is intentionally copyable by the user; OS clipboard history and screenshots are outside app memory and must not be described as secure erasure.
