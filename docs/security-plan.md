# Kasaran — Security & Privacy Plan

*Inputs: [design.md](./design.md), [requirements.md](./requirements.md). Checklist items carry an ID (SEC-n), a verifiable pass condition, and an owner. Every item is checkable by someone other than the author.*

## 0.0 Missing input

**`docs/decision-log.md` was listed as an input and does not exist in the repository** (contents: problem-brief, project-brief, mvp-user-stories, requirements, design, ux-spec). Nothing was inferred from it. Decisions this plan depends on are read from design.md §3 (Supabase, RLS, append-only log) and §4 (schema: `users`, `plan_members`, `invites` with `token_hash`, soft deletes). If a consolidated decision log exists elsewhere, this plan should be re-checked against it.

**Owner roles used below.** `BACKEND` (Supabase config, RLS, endpoints), `CLIENT` (Flutter app), `DPO` (Data Protection Officer / privacy owner), `RELEASE` (store submission and gate sign-off). At student-project scale one person may hold several; the label marks accountability, not headcount.

---

## 0. Threat model

Assets and threats first. Controls are chosen to cover these, not the reverse.

| # | Asset | Threat actor | Attack | Impact | Mitigating SEC IDs |
|---|---|---|---|---|---|
| T1 | Shared plan data | Ex-partner after breakup / called-off wedding | Retains app access and keeps reading or editing the plan | Ongoing unauthorised access to finances and guest list; emotional harm | SEC-07, SEC-08, SEC-09, SEC-22 |
| T2 | Local SQLite store | Opportunistic finder / thief | Lost or stolen **unlocked** phone, opens app | Full read of budget, sponsor names, guest list | SEC-10, SEC-11, SEC-12 |
| T3 | Another couple's plan | Curious or malicious app user | Crafts requests for a `plan_id` they are not paired to; a broken authz check serves it | Cross-tenant financial data breach | SEC-15, SEC-16, SEC-17 |
| T4 | Plan membership | Anyone who obtains an invite link | Leaked/forwarded invite code used to join a plan | Unauthorised third party joins the couple's plan | SEC-05, SEC-06 |
| T5 | Entire database | Malicious or curious insider with backend DB access | Direct table reads bypassing the app | Mass breach across all couples | SEC-18, SEC-19, SEC-20 |
| T6 | Sync traffic | Network attacker on public wifi | Intercepts or replays sync requests | Token theft, data disclosure, duplicated writes | SEC-13, SEC-14 |
| T7 | Local store via backup | Attacker with cloud-backup or desktop-backup access | Extracts app DB from iCloud / Android backup or an unencrypted iTunes/Finder backup | Offline read of financial data | SEC-11, SEC-12 |

### 0.1 The called-off-wedding case — product behaviour, not a hypothetical

This is a first-class requirement (problem-brief describes real couples; REQ-SE-6 governs defensive removal, REQ-SE-5 governs the other lifecycle actions). The precise behaviour of **"revoke my partner's access and keep my data"**:

1. Removal of a partner is a **mutual, one-sided** action: **either** paired partner may remove the other, without the removed party's consent, and it takes effect on the server immediately (REQ-SE-6, Decisions 1 and 2). It is not creator-only, because if the creator were the hostile party the other partner would have no defensive move. Two-party confirmation applies to *ownership transfer* only (REQ-SE-5 clause 4), never to defensive removal. **Resolved — no longer flagged for confirmation.**
2. On removal, the server deletes the removed user's `plan_members` row. Their next sync (pull or push) is rejected: they are no longer a member, RLS returns nothing, and writes are refused (SEC-09).
3. **The removed partner keeps whatever was already on their device.** This is unavoidable and must be stated plainly: a local-first app (REQ-OF-1) means their SQLite copy already holds every figure they synced. No server action can reach into their phone. Pretending otherwise would be a false security claim.
4. What the retained partner gets: the plan continues under their account, the removed member can no longer read new changes or write anything, and the activity log records the removal with actor and timestamp (SEC-22).
5. What is offered to limit the residual copy: the client honours a server "membership revoked" signal by moving to a read-only terminal state and offering local wipe (ux-spec §3.3, SEC-08). Whether it *force-wipes* is a privacy decision in §11 — force-wipe is user-hostile if the removed person has a legitimate interest in their own records, and unenforceable if they are offline.

---

## 1. Authentication & pairing

**Recommended model: account linking via server-issued single-use invite.** Each partner holds their own authenticated account; a plan is a shared resource both accounts are linked to through `plan_members`.

Justified against the threat model:

- **Rejected — shared login** (one email/password both partners use). Fatal against T1: revocation is impossible without a password reset that also locks out the person doing the revoking, and there is no per-actor attribution, which REQ-SE-4 requires. A shared credential also cannot be individually rotated after a breakup.
- **Rejected — pure invite code as identity** (no accounts, code is the credential). Fatal against T4 and T2: whoever holds the code is the user, so a leaked code is a full account takeover and a lost unlocked phone grants permanent access with nothing to revoke.
- **Chosen — account linking.** Individual accounts give per-actor attribution (REQ-SE-4), independent revocation (T1), and a credential that is not the pairing artefact (T4). It costs an auth provider, which design.md §3 already assumes via Supabase.

| ID | Item | Pass condition | Owner |
|---|---|---|---|
| SEC-01 | Identity provider | All auth flows use Supabase Auth (email/password + email verification). No custom credential store exists in the codebase. Verify by code search for any password hashing outside the provider. | BACKEND |
| SEC-02 | Email verification required | An account cannot join or create a plan until its email is verified. Verify by attempting plan actions with an unverified test account and confirming refusal. | BACKEND |
| SEC-03 | Session lifetime | Access token TTL ≤ 1 hour; refresh token rotates on use and is revocable server-side. Verify by inspecting issued token claims and confirming a revoked refresh token is rejected. | BACKEND |
| SEC-04 | Sign-out revokes | Sign-out invalidates the refresh token server-side, not just locally. Verify: sign out, then attempt refresh with the prior token → rejected. | BACKEND |
| SEC-05 | Pairing code strength | Invite token ≥ 128 bits from a CSPRNG; only a hash is stored server-side (`invites.token_hash`, design.md §4.1); raw token never logged. Verify by inspecting generation code and confirming the DB column holds a hash, not the token. | BACKEND |
| SEC-06 | Pairing code lifecycle | Invite is single-use and expires 7 days after issuance (REQ-SE-1); acceptance sets `accepted_at` and prevents reuse; revocation sets `revoked_at`. Verify: accept once → second accept refused; wait past expiry → refused; revoke → refused. | BACKEND |
| SEC-07 | Mutual one-sided defensive removal, with deterministic simultaneous-removal winner | **Either** paired partner can remove the other without the removed party's consent, effective on the removed party's next sync; the right is mutual, not creator-only (REQ-SE-6; Decisions D3, formerly ADR-18/19). The action is logged and attributed (SEC-22, REQ-SE-4). **Simultaneous mutual removal resolves to a deterministic winner** ordered by the server-assigned timestamp (D1/REQ-SE-2) and tiebroken on stable device id (D4/REQ-SE-6 clauses 9–11); the plan is never left with zero members. Verify all three: (a) creator removes partner B — B's `plan_members` row is gone and B's next sync is refused; (b) non-creating partner B removes the creator A — A's row is gone and A's next sync is refused; (c) two offline devices each remove the other, then both sync — exactly one partner survives, identical on both server and both devices, matching the server-timestamp/stable-id order. | BACKEND |
| SEC-08 | Revocation reaches the client | On membership loss, the client enters read-only terminal state and offers local wipe (ux-spec §3.3). Verify: remove B server-side; B's app on next foreground shows the revoked state and a wipe option. | CLIENT |
| SEC-09 | Revoked member cannot sync | After removal, both pull and push for that user return no data and are rejected by RLS, not by client-side checks alone. Verify by replaying B's last valid token directly against the sync endpoints post-removal → empty/refused. | BACKEND |
| SEC-10 | Re-pairing after reinstall | A reinstalled app re-authenticates with the existing account and re-pulls from `since_server_ts = 0`; no residual credential is needed from the old install. Verify: uninstall, reinstall, sign in, confirm full plan restored. | CLIENT |
| SEC-11 | Device-loss recovery | Losing a device requires no plan-side recovery beyond signing in on a new device; a lost device's local data is addressed by SEC-12 at-rest encryption. Verify: sign in on a second device, confirm access; confirm no plan secret is printed to logs during pairing. | CLIENT |

**Residual-copy statement (binding).** The removed partner retains the local data they had already synced. There is no technical means to guarantee its deletion from a device the operator does not control. This plan does not claim otherwise. SEC-08 offers wipe; it cannot enforce it against an offline or uncooperative device. This limit is disclosed to users in the privacy notice (SEC-24).

---

## 2. Local data at rest

| ID | Item | Pass condition | Owner |
|---|---|---|---|
| SEC-12 | SQLite encryption | The `drift` database uses SQLCipher (or an equivalent page-level cipher). The DB file is not readable as plaintext SQLite. Verify: pull the DB file off a test device and confirm `sqlite3` cannot open it and `strings` shows no sponsor names, supplier names, or amounts. | CLIENT |
| SEC-13 | Key storage | The SQLCipher key is stored in the iOS Keychain / Android Keystore, never in the DB, app bundle, source, or shared preferences. Verify by code search and by confirming the key is absent from the app's readable file space. | CLIENT |
| SEC-14 | No-passcode behaviour | WHEN the device has no passcode/biometric set, the Keychain/Keystore item still gates DB-key access at the OS floor available; the app surfaces a one-time warning that device-lock is strongly recommended for financial data. Pass: key item uses `WhenUnlockedThisDeviceOnly` (iOS) / Keystore without weakened fallback (Android); warning shown once on a no-passcode device. Verify on a test device with no passcode. | CLIENT |
| SEC-15 | Uninstall behaviour | Uninstall removes the app sandbox including the SQLite file and Keychain/Keystore key (or the key is rendered useless). Pass: after uninstall/reinstall, no prior plan data is readable without a fresh server pull. Verify by reinstall test. | CLIENT |
| SEC-16 | Excluded from cloud backup | The DB file and the key are excluded from iCloud/iTunes/Finder backup and from Android Auto Backup / Google cloud backup. Pass: iOS file has `isExcludedFromBackup = true` (or lives in a non-backed-up directory) and `NSFileProtectionComplete`; Android `android:allowBackup="false"` or explicit backup-rules exclusion of the DB and datastore. Verify by inspecting a device backup and confirming the DB is absent. | CLIENT |

**Justification for SEC-16.** Financial data plus identifiable sponsor and guest names in an auto-uploaded backup re-creates threat T7 through the platform's own cloud. Auto-backup of this store is **not acceptable**; exclusion is mandatory, not optional. The cost is that a user who loses their phone without signing in elsewhere loses the un-synced tail of local writes — acceptable, because synced data restores from the server on the new device and the un-synced tail is small (ux-spec §7).

---

## 3. Transport

| ID | Item | Pass condition | Owner |
|---|---|---|---|
| SEC-17 | TLS baseline | All network calls use TLS 1.2 or higher; cleartext HTTP is disabled platform-wide. Pass: iOS ATS left enabled with no exception domains; Android `cleartextTrafficPermitted="false"`. Verify by proxying traffic and confirming no plaintext request leaves the device. | CLIENT |
| SEC-18 | Certificate handling | Certificates are validated against the system trust store; no validation is disabled or overridden in code. Verify by code search for any trust-all / `badCertificateCallback => true` / disabled host verification, and confirm none exists. | CLIENT |
| SEC-19 | Token storage on device | Access and refresh tokens live in Keychain/Keystore, never in the SQLite DB, shared preferences, or logs. Verify by code search and by confirming tokens are absent from the DB dump used in SEC-12. | CLIENT |
| SEC-20 | Replay protection | The sync endpoint is idempotent on the client-generated log-row primary key (design.md §2.1, §2.4): a replayed push applies exactly once. Pass: submit the same batch twice → second is a no-op, no total changes. Verify with a scripted double-submit. | BACKEND |
| SEC-21 | Queued-write contents | A write that was queued offline carries its device sequence (`device_monotonic`) and the acting user's identity, receives its authoritative `server_ts` on acceptance (Decision D1), and uploads under the current valid session token — not a token cached from when the write was made. Pass: make an offline write, rotate the session, reconnect → write uploads under the fresh token, is stamped with a server timestamp on acceptance, and is attributed correctly (REQ-OF-5, REQ-SE-4). Verify by inspecting the uploaded row's actor and the auth header. | BACKEND |

---

## 4. Backend authorization

**Tenant isolation rule, stated once, precisely:**

> A database row is readable or writable by a user **if and only if** it belongs to a `plan_id` for which a `plan_members` row exists linking that `plan_id` to the requesting user's authenticated `user_id`. No other path grants access.

| ID | Item | Pass condition | Owner |
|---|---|---|---|
| SEC-22 | Enforcement location | Isolation is enforced by Postgres Row-Level Security on **every** plan-scoped table, not by application code alone. Pass: RLS is enabled and forced on `plans`, `plan_members`, `ledger_entries`, `fee_components`, `pledges`, `guests`, `crew_headcount`, `plan_allocations`, `hidden_fee_prompts`, `invites`, `change_log`, `lifecycle_confirmations`. Verify by querying `pg_tables` / policy catalog and confirming each has a policy and `FORCE ROW LEVEL SECURITY`. | BACKEND |
| SEC-23 | The isolation policy | Every plan-scoped policy resolves membership through `plan_members`, keyed to `auth.uid()`. Pass: the policy predicate for each table reduces to "exists a `plan_members` row for this row's `plan_id` and `auth.uid()`". Verify by reading each policy definition. | BACKEND |
| SEC-24 | Negative authorization test | An automated test suite proves cross-tenant denial. Pass: user A cannot read, update, or delete any row of user B's plan via any endpoint, including direct REST with a crafted `plan_id`; the suite includes at least read, write, delete, and a forged-`plan_id` sync pull. All return empty or denied. This is the single most important test in the project — a green suite is the pass condition, run in CI. | BACKEND |
| SEC-25 | Membership write path | Only the server-side invite-acceptance flow can insert a `plan_members` row; clients cannot insert membership directly. Pass: a direct client insert into `plan_members` is denied by RLS. Verify by attempting the insert with a normal user token → refused. | BACKEND |
| SEC-26 | Secrets management | Service-role keys, DB credentials, and signing secrets are held in environment/secret storage, never in the repo or the client binary. Pass: repo secret-scan is clean; the client bundle contains only the anon/public key, never the service-role key. Verify with a secret scanner in CI and by inspecting the built app. | BACKEND |
| SEC-27 | Backup encryption & restore access | Database backups are encrypted at rest and restore is limited to the project owner with MFA. Pass: confirm the provider encrypts backups and that restore requires owner authentication; document who can restore. Verify against provider console settings. | BACKEND |
| SEC-28 | Log hygiene | No log line — client, server, or provider request log — contains a ₱ amount tied to an identifiable user, a sponsor or guest name, an email, or any token. Pass: a scripted grep over a captured log sample for peso amounts, `@` emails, known test sponsor names, and token prefixes returns nothing. Structured logs carry `plan_id`/`user_id` UUIDs only, never content. Verify by generating activity on a test plan and scanning the resulting logs. | BACKEND |

**Note on SEC-24.** design.md §3 flags the RLS policy as "the whole security model" and warns it needs deliberate tests, not eyeballing. SEC-24 is that test, promoted to a gate item.

**SEC-16 and SEC-24 are unchanged by Decisions 1 and 2, and remain consistent.** SEC-16 (no cloud auto-backup of the local DB) is orthogonal to removal — it concerns backup exclusion, not membership. SEC-24 (cross-tenant denial, CI gate-blocker before internal beta) now additionally *covers the removal flow*: a removed partner is, from the moment of removal, a non-member attempting to reach a plan they no longer belong to — which is exactly the cross-tenant case SEC-24 already proves is denied by RLS. The removal-specific direction (a formerly-valid member post-removal) is exercised explicitly by SEC-07 and SEC-09 and by the test cases in testing-plan.md; SEC-24's forged-`plan_id` suite is the general guarantee behind them.

---

## 5. Philippine compliance — Data Privacy Act of 2012 (RA 10173) / NPC

Kasaran collects **personal data** (names, emails) and **financial and event data** (budgets, pledges with sponsor names, guest lists) from data subjects in the Philippines. The DPA applies. Items below list obligations; where applicability at this scale is genuinely uncertain, the pass condition is *verify with counsel* rather than a guess — the obligation is still listed.

| ID | Item | Pass condition | Owner |
|---|---|---|---|
| SEC-29 | Lawful basis | Processing rests on a documented lawful basis — consent for account creation and processing, contract/legitimate-interest analysis recorded for the shared-plan model. Pass: a written basis exists for each processing purpose in the data inventory (§6). | DPO |
| SEC-30 | Privacy notice content | A privacy notice is presented before or at collection and states: identity of the personal information controller, data collected, purposes, recipients/third parties, retention, data-subject rights and how to exercise them, and the residual-copy limitation from §1. Pass: notice is reachable pre-signup and contains every listed element. | DPO |
| SEC-31 | Consent capture | Consent is freely given, specific, informed, and recorded with a timestamp; the privacy notice is acknowledged at signup. Pass: a test signup produces a stored consent record. | BACKEND / DPO |
| SEC-32 | Access & correction | A data subject can obtain a copy of their personal data and correct it. In-app: account/profile edit plus an export path. Pass: a test user can export their data and correct their display name and email. | CLIENT / BACKEND |
| SEC-33 | Erasure on a shared record | Erasure is serviceable despite two people sharing one plan. **Behaviour:** erasing user A removes A's identity (account, email, attribution reduced to a neutral "former member") and A's sole-authored personal data; the shared plan persists for user B, who is a separate data subject with their own rights over the shared financial record. Content A entered that is now part of B's budget (a pledge, an entry) is retained as B's record, de-identified of A. Pass: erase test user A; A's account and personal identifiers are gone, B still has a working plan, and no A email/name remains in the plan. **Verify the de-identification-vs-deletion split with counsel** (SEC-38). | BACKEND / DPO |
| SEC-34 | Account deletion self-service | A user can request account deletion from within the app (also a store requirement, §6). Pass: an in-app deletion path exists and completes SEC-33 behaviour. | CLIENT |
| SEC-35 | Breach notification | A documented procedure notifies the NPC and affected data subjects within **72 hours** of knowledge of a breach likely to cause real harm (NPC rule). Pass: a written incident-response runbook exists naming who assesses, who notifies, and the 72-hour clock. | DPO |
| SEC-36 | Retention & disposal | Data is retained only as long as the purpose requires; inactive-account and post-deletion disposal timelines are documented. Pass: a retention schedule exists and the deletion job honours it. | DPO |
| SEC-37 | NPC registration & DPO designation | Determine whether registration with the NPC and formal DPO designation apply at this scale. NPC registration thresholds turn on factors like number of records and sensitivity. **Pass: verify with counsel / NPC guidance whether registration is required; designate a DPO regardless, since the DPA expects a responsible person even for small controllers.** Do not assume exemption. | DPO |
| SEC-38 | Counsel review of erasure model | The SEC-33 de-identify-B's-copy-vs-delete approach is reviewed by someone competent in DPA obligations before public launch. Pass: written sign-off, or documented changes made. **This is a "verify with counsel" item, not an engineering judgement.** | DPO |

---

## 6. Store privacy labels

### 6.1 Data inventory

| Field | Purpose | Linked to identity? | Used for tracking? | Third parties reached |
|---|---|---|---|---|
| Email | Account, auth, verification | Yes | No | Supabase (processor) |
| Display name | Attribution in shared plan | Yes | No | Supabase |
| Password (hash) | Auth | Yes (held by provider) | No | Supabase |
| Wedding date | Core function (countdown, adequacy) | Yes | No | Supabase |
| Budget, allocations, ledger amounts | Core function | Yes | No | Supabase |
| Supplier names | Core function | Yes | No | Supabase |
| Sponsor names & roles (Ninong/Ninang) | Core function (pledges) | Yes | No | Supabase |
| Guest names, RSVP, tier | Core function (guest math) | Yes | No | Supabase |
| Region / wedding location | Core function (regional cost) | Yes (coarse) | No | Supabase |
| Device sync metadata (HLC, device_id) | Sync integrity | Yes | No | Supabase |

**No advertising SDKs, no analytics-for-tracking, no data brokers.** Supabase is a processor under instruction, not an independent controller or an advertising third party. If any analytics is added later, this table and both store labels must be revised before that build ships.

### 6.2 Apple App Privacy

| Apple category | Applies? | Linked to user? | Tracking? |
|---|---|---|---|
| Contact Info (email, name) | Yes | Yes | No |
| Financial Info (budget, pledges, amounts) | Yes | Yes | No |
| User Content (supplier/sponsor/guest names, notes) | Yes | Yes | No |
| Identifiers (account/user id) | Yes | Yes | No |
| Usage Data | No in v1 | — | — |
| Location | Coarse region only, self-selected, not device GPS — declare as User Content region, **not** Location. | Yes | No |

### 6.3 Google Play Data Safety

| Play question | Answer |
|---|---|
| Data collected | Personal (name, email), Financial (budget/pledge info), other user content (guest/sponsor names) |
| Data shared with third parties | No third-party *sharing* in the Play sense; Supabase is processing on the developer's behalf |
| Encrypted in transit | Yes (SEC-17) |
| Encrypted at rest (device) | Yes (SEC-12) |
| Can users request deletion | Yes, in-app (SEC-34) |
| Used for tracking | No |

| ID | Item | Pass condition | Owner |
|---|---|---|---|
| SEC-39 | Labels match reality | Apple App Privacy and Play Data Safety declarations match the §6.1 inventory exactly; no collected field is undeclared and no declared category is uncollected. Verify by diffing submitted labels against the inventory. | RELEASE |
| SEC-40 | Account deletion path published | Both stores' account-deletion requirement is met: in-app deletion (SEC-34) plus, for Apple, a publicly reachable deletion instruction URL. Verify both are live before submission. | RELEASE |
| SEC-41 | Location not over-declared | The app declares self-selected region as user content, requests no device-location permission, and links no GPS API. Verify by permission-manifest inspection. | CLIENT / RELEASE |

---

## 7. SEC gate

Every SEC ID maps to a milestone at which it must be **PASS**. **An item that cannot be verified is FAIL, never "partial."** A milestone is not reached until all its items and all earlier items are PASS.

| SEC ID | Internal beta | Store submission | Public launch |
|---|---|---|---|
| SEC-01 Identity provider | PASS | PASS | PASS |
| SEC-02 Email verification | PASS | PASS | PASS |
| SEC-03 Session lifetime | PASS | PASS | PASS |
| SEC-04 Sign-out revokes | PASS | PASS | PASS |
| SEC-05 Pairing code strength | PASS | PASS | PASS |
| SEC-06 Pairing lifecycle | PASS | PASS | PASS |
| SEC-07 One-sided removal | PASS | PASS | PASS |
| SEC-08 Revocation reaches client | PASS | PASS | PASS |
| SEC-09 Revoked cannot sync | PASS | PASS | PASS |
| SEC-10 Re-pairing after reinstall | PASS | PASS | PASS |
| SEC-11 Device-loss recovery | — | PASS | PASS |
| SEC-12 SQLite encryption | PASS | PASS | PASS |
| SEC-13 Key storage | PASS | PASS | PASS |
| SEC-14 No-passcode behaviour | — | PASS | PASS |
| SEC-15 Uninstall behaviour | — | PASS | PASS |
| SEC-16 Excluded from cloud backup | PASS | PASS | PASS |
| SEC-17 TLS baseline | PASS | PASS | PASS |
| SEC-18 Certificate handling | PASS | PASS | PASS |
| SEC-19 Token storage | PASS | PASS | PASS |
| SEC-20 Replay protection | — | PASS | PASS |
| SEC-21 Queued-write contents | — | PASS | PASS |
| SEC-22 RLS enforcement location | PASS | PASS | PASS |
| SEC-23 Isolation policy | PASS | PASS | PASS |
| SEC-24 Negative authz test | PASS | PASS | PASS |
| SEC-25 Membership write path | PASS | PASS | PASS |
| SEC-26 Secrets management | PASS | PASS | PASS |
| SEC-27 Backup encryption & restore | — | PASS | PASS |
| SEC-28 Log hygiene | — | PASS | PASS |
| SEC-29 Lawful basis | — | PASS | PASS |
| SEC-30 Privacy notice | — | PASS | PASS |
| SEC-31 Consent capture | — | PASS | PASS |
| SEC-32 Access & correction | — | PASS | PASS |
| SEC-33 Erasure on shared record | — | PASS | PASS |
| SEC-34 Account deletion self-service | — | PASS | PASS |
| SEC-35 Breach notification runbook | — | PASS | PASS |
| SEC-36 Retention & disposal | — | — | PASS |
| SEC-37 NPC registration & DPO | — | — | PASS |
| SEC-38 Counsel review of erasure | — | — | PASS |
| SEC-39 Labels match reality | — | PASS | PASS |
| SEC-40 Account deletion published | — | PASS | PASS |
| SEC-41 Location not over-declared | — | PASS | PASS |

**Reading the gate.** Internal beta requires the auth, isolation, and at-rest core to be real, because a beta puts genuine data on genuine devices. Store submission adds the full privacy, compliance, and label surface, since both stores enforce it. Public launch adds the items that need external sign-off (counsel, NPC, retention operating over time). A dash means not yet required at that milestone, never "may be skipped."

---

## 8. Data flow summary

```
[Partner A device]                         [Partner B device]
 Flutter app                                Flutter app
 SQLCipher SQLite  <-- key in Keychain      SQLCipher SQLite <-- key in Keystore
   |  local reads (no network, REQ-PLT-2)      |
   |  outbound change_log queue                |
   v  TLS 1.2+ (SEC-17/18)                     v
 ============== Supabase =========================================
   Auth (SEC-01..04)   session tokens (SEC-19/21)
   RLS on every plan table (SEC-22/23), membership via plan_members
   append-only change_log, idempotent push (SEC-20)
   encrypted backups, owner+MFA restore (SEC-27)
   logs carry UUIDs only, no content (SEC-28)
 =================================================================
```

## 9. Explicitly out of scope for v1 security

Stated so their absence is a decision, not an oversight.

- **End-to-end encryption of plan content.** Not v1. Data is encrypted in transit (SEC-17) and at rest on device (SEC-12), but the server can read plan content, which is what makes RLS the load-bearing control. E2EE would break server-side validation and is disproportionate for this scope. Reconsider only if the threat model changes.
- **MFA for end users.** Provider supports it; not required for a wedding-budget account in v1. Owner/admin restore access does require MFA (SEC-27).
- **Jailbreak/root detection and anti-tampering.** Not v1. The at-rest and backup controls address the realistic threats (T2, T7); device-integrity attestation is disproportionate here.
- **Payment-rail security (PCI etc.).** Not applicable to v1 — v1 records that money moved, never moves it (REQ-LG-4, deferred REQ-AI-4). **Revised per ADR-28:** payments is no longer part of the AI phase; it is its own post-launch phase (development-phases §25). A dedicated SEC block must therefore be authored before that phase starts — covering rail authentication, tokenisation, reconciliation integrity, PCI applicability, and the DPA implications of holding transaction data. Tracked as **OQ-10**, which blocks phase 25. This is a gap, not a completed exclusion.

## 10. Verification tooling summary

For the checker, not the author. Each maps a SEC item to how a third party confirms it.

- **Code search / secret scan (CI):** SEC-01, 13, 18, 19, 26.
- **Live token/endpoint tests:** SEC-03, 04, 06, 09, 20, 21, 25.
- **Device forensics (pull file, `strings`, backup inspect):** SEC-12, 15, 16, 19.
- **Automated cross-tenant suite (CI, gate-blocking):** SEC-24.
- **Policy-catalog inspection:** SEC-22, 23.
- **Log scan on a seeded test plan:** SEC-28.
- **Manual on-device with/without passcode:** SEC-14, 41.
- **Document existence + counsel sign-off:** SEC-29..38.
- **Label diff against §6.1 inventory:** SEC-39, 40, 41.

## 11. Open items requiring a decision

1. **RESOLVED — One-sided removal scope (was SEC-07 vs REQ-SE-5 clause 4).** Decision 1: two-party confirmation is scoped to ownership transfer only; defensive partner removal does not require the removed party's consent. REQ-SE-5 clause 4 amended and REQ-SE-6 added; SEC-07 aligned. No longer open.
2. **RESOLVED — Mutual removal (was "non-creating partner's removal rights").** Decision 2: either paired partner may defensively remove the other. SEC-07 widened from creator-only to either-paired-partner; REQ-SE-6 clause 1 states the mutual right. No longer open.
3. **★ Force-wipe on revocation (SEC-08).** Still open. Whether the removed partner's local copy is force-wiped, wipe-offered, or left. This plan offers wipe and does not force it, on the grounds that the removed person may have a legitimate interest in records of their own wedding and that force-wipe is unenforceable offline anyway (REQ-SE-6 clauses 5, 7). This intersects the SEC-33 erasure model — confirm the two are consistent.
4. **★ Erasure model (SEC-33, SEC-38).** Still open. The de-identify-B's-shared-copy vs full-delete split is a genuine DPA question with two data subjects over one record. Flagged for counsel, not resolved here. **Mutual removal (Decision 2) sharpens this:** each partner now independently, unilaterally controls one shared financial record, so an erasure request from one data subject must be serviced without destroying the other's lawful record and without either being able to erase the other. See Open Questions.
5. **★ NPC registration threshold (SEC-37).** Still open. Applicability at student-project / early scale is uncertain. Verify; do not assume exemption.
