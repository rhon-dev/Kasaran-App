# Phase 06 Invite Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an existing plan member issue and revoke one-time invitation links on SCR-17 without persisting raw tokens.

**Architecture:** `InvitationRepository` is the sole client adapter for `issue_invite`/`revoke_invite` RPCs and RLS-protected pairing metadata reads. SCR-17 consumes a Riverpod-injected repository and `currentPlanIdProvider`, keeps the returned link in widget state only, and drops it on revoke, disposal, or sign-out. Server RPCs remain the authorization boundary.

**Tech Stack:** Flutter, Dart, Riverpod, Supabase Flutter 2.18.0, flutter_test, local Supabase synthetic tests.

## Global Constraints

- Follow `docs/superpowers/specs/2026-10-04-phase-06-invite-controls-design.md` and REQ-SE-1 clauses 1, 3–5, 8.
- Do not persist, log, or include raw invite tokens in errors. Display once per issue; metadata queries never return `token_hash`.
- No budget setup, sync, money movement, supplier recommendations, or lifecycle actions in this slice. No new ADR.
- Never represent local synthetic tests or GitHub jobs that never started as production approval.
- Make each behavior fail in a focused test before changing production code.

---

### Task 1: Repository boundary and RPC mapping

**Files:**
- Create: `lib/data/repositories/invitation_repository.dart`
- Create: `test/data/repositories/invitation_repository_test.dart`

**Interfaces:**
- Produce `InvitationRepository` with `Future<PairingEligibility> pairingEligibility(String planId)`, `Future<List<InviteMetadata>> listInvites(String planId)`, `Future<IssuedInvite> issueInvite(String planId)`, `Future<void> revokeInvite(String inviteId)`.
- Add an injectable `InvitationGateway` with `Future<Object?> rpc(String name, Map<String, Object?> params)` and `Future<List<Map<String, Object?>>> select(String table, String columns, String planId)`; `SupabaseInvitationGateway` adapts these calls to `SupabaseClient`. This isolates the policy/response parser from network tests.
- `InviteMetadata` contains `id`, `expiresAt`, `acceptedAt`, `revokedAt`; `IssuedInvite` contains `id`, `expiresAt`, and transient `token`. `PairingEligibility` contains `isActive` and `memberCount`.
- `invitationRepositoryProvider` is injectable in widget tests and creates `SupabaseInvitationRepository(SupabaseInvitationGateway(Supabase.instance.client))` in production.

- [ ] **Step 1: Write one failing issue test.** Assert `issueInvite(planId)` forwards only `p_plan_id`, parses the RPC map, and rejects a response missing ID/expiry/token; fake the boundary so no live credentials enter unit tests. Example assertion:

```dart
final result = await repository.issueInvite('synthetic-plan');
expect(result.id, 'synthetic-invite');
expect(result.token, List.filled(32, 'a').join());
expect(gateway.lastRpc, 'issue_invite');
expect(gateway.lastParams, {'p_plan_id': 'synthetic-plan'});
```

- [ ] **Step 2: Run RED.** `flutter test --no-pub test/data/repositories/invitation_repository_test.dart --plain-name 'issue parses a one-time server response' --reporter=compact`. Expected failure: missing repository or method, not test setup.
- [ ] **Step 3: Implement production adapter.** Use `client.rpc<Object?>('issue_invite', params: {'p_plan_id': planId})`. Check verified `currentUser.emailConfirmedAt`; parse maps with explicit type checks. Use RLS SELECT on `plans` (`is_active`), `plan_members` (`user_id`) and `invites` (`id,expires_at,accepted_at,revoked_at`) filtered by `plan_id`. Do not request `token_hash`. Use `client.rpc<Object?>('revoke_invite', params: {'p_invite_id': inviteId})`. Reject malformed response safely; never interpolate SDK exception text into user-facing copy. Keep widget-facing models token-free except `IssuedInvite`.
- [ ] **Step 4: Run GREEN.** Run the focused test above. Then add separate RED/GREEN tests for missing-token rejection, metadata list omitting secrets, eligibility inactive/two-member, and revoke ID forwarding. Run `flutter test --no-pub test/data/repositories/invitation_repository_test.dart --reporter=compact` after each behavior.
- [ ] **Step 5: Commit.** `git add lib/data/repositories/invitation_repository.dart test/data/repositories/invitation_repository_test.dart && git commit -m 'feat(invite): add server-backed invitation repository'`.

### Task 2: Bounded SCR-17 invitation block

**Files:**
- Modify: `lib/ui/screens/scr_17_shared_access.dart`
- Create: `test/ui/screens/scr_17_shared_access_test.dart`
- Modify: `test/ui/router/app_router_test.dart` (replace the SCR-17 placeholder assertion with the actual screen assertion).

**Interfaces:**
- Consume `invitationRepositoryProvider`, `currentPlanIdProvider`, and `authStateProvider` from Task 1 and existing providers. Do not introduce a second plan-membership source.

- [ ] **Step 1: Write RED widget test.** Override the repository with a fake and the plan lookup with a fixed plan ID. Tap `Issue invitation`; assert the widget shows `kasaran://accept/` plus the synthetic token exactly once, with a copy-now notice. Route away/remount and assert the token is absent. Use `ProviderScope`/`MaterialApp` like `test/ui/screens/scr_02_invite_acceptance_test.dart`.
- [ ] **Step 2: Run RED.** `flutter test --no-pub test/ui/screens/scr_17_shared_access_test.dart --plain-name 'issue shows link only in current view' --reporter=compact`. Expected failure: SCR-17 remains placeholder.
- [ ] **Step 3: Implement minimal screen.** Make `Scr17SharedAccess` a `ConsumerStatefulWidget`. Read `currentPlanIdProvider`; on loading/error/null show progress/retry/no-plan text, not Issue. Fetch pairing eligibility and invitation metadata on active plan, show Issue only for active solo plan and verified auth. Keep `String? _issuedLink` and `String? _issuedId` in state, never in providers, logs, storage, route or exceptions. Use `SelectableText` for one-time manual copying; warn about OS clipboard history. Catch errors with fixed generic copy and keep old metadata. Clear widget references on revoke success, auth loss, or disposal. Label partner removal/transfer/delete as unavailable, not functional.
- [ ] **Step 4: Run GREEN.** Re-run first widget test. Add one RED/GREEN test at a time for revoke forwarding and link removal, list failure retry, disabled actions for two members/inactive plan, and sign-out dropping link. Update router test's SCR-17 assertion. Run focused widget and router suites after each cycle.
- [ ] **Step 5: Commit.** `git add lib/ui/screens/scr_17_shared_access.dart test/ui/screens/scr_17_shared_access_test.dart test/ui/router/app_router_test.dart && git commit -m 'feat(invite): add bounded Shared Access invite controls'`.

### Task 3: Evidence, integration and PR

**Files:**
- Modify: `docs/ux-spec.md` (SCR-17 implementation boundary plus loading/offline/error states).
- Modify: `docs/development-phases.md` (Phase 06 source/evidence/gaps).
- Modify: `docs/testing-plan.md` (specific TC-SE-23/42 source and executed result).

- [ ] **Step 1: Check document precedence.** Keep REQ-SE-1 and existing ADRs unchanged; do not claim partner removal, sync replay, stage or production approval.
- [ ] **Step 2: Update exact SCR-17 state/evidence rows.** Explicitly distinguish metadata reads and transient one-time link from persisted tokens; record test counts only after execution.
- [ ] **Step 3: Verify.** Run `flutter analyze --no-pub`, focused repository/widget/router suites, `flutter test --no-pub --reporter=expanded`, and `python3 -m unittest discover -s test/api/identity -v` against local synthetic Supabase. If first Edge contract test times out on cold start, retry the focused contract subset after readiness before claiming full-suite success. Stop services with plain `supabase stop`; never use `--no-backup`. Run `git diff --check` and `gitleaks git --log-opts='origin/main..HEAD' --redact --no-banner --log-level=error` before publishing. Never print scan findings or credentials.
- [ ] **Step 4: Commit and publish.** Verify `git status`, `HEAD`, `origin/main`, and prior PR state first. Commit docs conventionally. Push `feat/phase-06-invite-controls`; open a draft PR to `main` only for its unmerged delta. Read back PR base/head/state and checks. If CI jobs never start, state that result plainly.
