# Phase 04 Free Synthetic Staging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an evidenced, synthetic-only Singapore Supabase staging project without paid upgrade, production deployment or promotion of local auth settings.

**Architecture:** Use the already visible `kasaran` organization, not the original personal organization. Provision only after an independent Free-plan check. Store the generated DB password in macOS Keychain, deploy the existing empty Edge stubs by explicit project reference, and record remote evidence separately from local/CI and later sync gates.

**Tech Stack:** Supabase CLI 2.108.0, macOS Keychain, existing Deno Edge stubs, Dart contract tests, `gh` for a draft PR.

## Global Constraints

- Approved design: `docs/superpowers/specs/2026-10-05-phase-04-free-staging-design.md`, ADR-76. `ap-southeast-1`; synthetic-only; Free only. A missing Free-plan confirmation **stops project creation**.
- The `kasaran` organization currently also contains an active `ap-northeast-1` project. Never modify, pause, delete, migrate or bill that project. The original organization has three inactive unrelated projects; do not touch it.
- No `supabase config push`, `supabase db push`, remote seed, client release, paid upgrade or production project. Local `[auth.email] enable_confirmations = false` must not reach staging. OQ-07, ADR-64, SEC-29–31/35 and beta remain open.
- Never print secrets, connection strings, raw project API-key responses, tokens, database passwords, email addresses or secret-scan matches. Do not type a password into a browser; use the vault workflow if a login page is needed.
- Do not claim full TC-API-01/02/03/05, tenant isolation, Pro readiness or remote CI from empty stubs. Keep the GET pull stub separate from `design.md` §2.4's future versioned POST contract.
- Existing Phase 06 SCR-03 draft PR #13 is open and independent. ADR-75 is reserved there; do not renumber ADR-76.

---

### Task 1: Verify target organization and Free billing gate

**Files:** Read `docs/deployment-plan.md` §1/§2.2, `docs/decision-log.md` ADR-64/72/76 and `docs/superpowers/specs/2026-10-05-phase-04-free-staging-design.md`. No source edit.

**Interfaces:** Input = `kasaran` organization's ID from `supabase orgs list --output json`. Output = documented, independently confirmed Free plan and unmodified baseline project list; no target project creation.

- [ ] **Step 1:** Read organization and project lists through the authenticated CLI; parse only names, organization IDs, region and status. Confirm exactly one intended `kasaran` organization and no existing `kasaran-staging` project. Do not expose database hosts or API keys.
- [ ] **Step 2:** Verify the `kasaran` organization's plan in its Supabase Billing dashboard (user-assisted screenshot or logged-in browser with vault handling). CLI organization-list JSON has no billing-plan field; a name or inactive status is not proof. If Free cannot be verified, stop and ask the owner. Do not retry any previously approval-blocked CLI inspection command.
- [ ] **Step 3:** Record a non-secret before-state (organization ID, existing project reference/region/status) in a private scratch note; do not create a second organization. Confirm the chosen target name is absent.

### Task 2: Provision a single Free Singapore project with a protected DB credential

**Files:** No repository edit; macOS Keychain item named `Kasaran Staging DB Password`; Supabase project `kasaran-staging`.

**Interfaces:** Consumes Task 1's Free-plan proof and exact organization ID. Produces a new project reference, independently read back with organization ID, region `ap-southeast-1`, status and Free plan still in effect.

- [ ] **Step 1:** Generate a unique random DB password with `openssl rand -hex 32`, hold it only in a shell variable with tracing disabled, and save it to the user's Keychain using `security add-generic-password -a "$USER" -s 'Kasaran Staging DB Password' -w "$DB_PASS" -U`. Verify retrieval without printing; if Keychain refuses, stop before project creation. Clear shell variables after the CLI call. Do not save password in plaintext in repo or scratch.
- [ ] **Step 2:** With the verified `kasaran` organization ID, run `supabase projects create kasaran-staging --org-id "$ORG_ID" --db-password "$DB_PASS" --region ap-southeast-1 --size nano --output json` once. Redirect output to a restricted scratch file (`umask 077`), print only exit status and sanitised target metadata, and never enable shell tracing. A CLI request for paid upgrade or different size is a hard stop, not implicit approval.
- [ ] **Step 3:** Re-read the project list. Require exactly one new `kasaran-staging` in the intended organization and region, with the original project's ref/region/status unchanged. If creation returns success but lookup is not yet healthy, wait a bounded interval and re-read; do not create a duplicate. Retain the project on later failure and report exact partial state without deleting it.
- [ ] **Step 4:** Recheck the organization's billing plan. If the project unexpectedly incurs paid charges, stop all further writes and ask the owner; do not modify unrelated projects or assume a delete eliminates charges.

### Task 3: Deploy safe stubs and prove bounded hosted behavior

**Files:** Existing `supabase/functions/sync_push/index.ts`, `supabase/functions/sync_pull/index.ts`, `supabase/functions/_shared/`; existing `test/api/contract/sync_contract_test.dart`. Only add a remote smoke-test helper if its behavior can be tested first with a local HTTP fixture; never embed a remote key or URL in source.

**Interfaces:** Consumes the exact new project reference and verified hosted Auth configuration. Produces read-back function metadata and a status-only smoke evidence matrix.

- [ ] **Step 1:** Read hosted Auth controls by a supported Supabase dashboard/management route. Require email confirmations enabled, access-token TTL ≤3600 seconds and refresh-token rotation enabled. Do not use local `supabase/config.toml` as evidence. If any setting is unverified or unsafe, report blocker; do not push local config or silently change the setting.
- [ ] **Step 2:** Deploy only `sync_push` and `sync_pull` using separate `supabase functions deploy <name> --project-ref "$PROJECT_REF" --use-api` calls. Never pass `--no-verify-jwt`. Read back `supabase functions list --project-ref "$PROJECT_REF" --output json` and verify both names and deployment status before claiming success.
- [ ] **Step 3:** Run status-only remote probes for missing/invalid bearer (401 for both functions). If an authorized server-side process can provision a synthetic verified Auth account without exposing service-role material to local tests or the client, also test authenticated empty push/pull (200), malformed push (4xx) and issued-JWT `exp - iat` ≤3600 seconds. If not, label those probes blocked; do not use real email, disable confirmations or claim they passed.
- [ ] **Step 4:** Run the existing local contract test with local services as a separate baseline, then stop Supabase with plain `supabase stop` to preserve local volumes. Do not call the local suite hosted-stage evidence. If a remote smoke fails, retain project and report status/response code only, not response bodies or headers.

### Task 4: Record evidence and deliver independent PR

**Files:** Modify `docs/deployment-plan.md` §1 environments and phase-04 note, `docs/development-phases.md` phase-04 status/body and `docs/testing-plan.md` phase-04 evidence. Do not alter REQ/TC/SEC identifiers or PR #13.

**Interfaces:** Consumes actual Task 1–3 observed results only. Produces a branch diff and a draft PR to `main` containing non-secret project reference and pass/fail/blocked distinctions.

- [ ] **Step 1:** Update documents with the observed organization/project ref, region, Free status evidence and hosted smoke results; retain ADR-64 Pro target, OQ-07, legal review, full sync/RLS and CI gates as pending. If provisioning stopped, record that instead of inventing a project reference.
- [ ] **Step 2:** Run document stale-phrase and identifier searches, `git diff --check`, Flutter analysis and the applicable local contract suite. Scan branch history and staged diff with gitleaks and print only exit status. Review every changed file and the v1 four scope checks.
- [ ] **Step 3:** Commit with Conventional Commits. Fetch `origin/main`, verify the branch diff and GitHub auth, push, open a **draft** PR against `main`, and read back the exact head/base/body/state plus actual checks. Do not call billing-blocked Actions a passing test.
