# Kasaran — Security & Privacy Plan

*Inputs: [decision-log.md](./decision-log.md), [design.md](./design.md), [requirements.md](./requirements.md). Checklist items carry an ID (SEC-n), a verifiable pass condition, and an owner. Every item is checkable by someone other than the author.*

## 0.0 Decision record

**`docs/decision-log.md` exists and is the decision authority.** In particular ADR-12 (Flutter), ADR-16 (Supabase), ADR-17 (local encryption), ADR-21 (server-assigned sync ordering), ADR-23/24 (partner removal), and ADR-27/28 (name/payments) inform this plan. The implementation detail is in design.md §3 (Supabase, RLS, append-only log) and §4 (`users`, `plan_members`, `invites` with `token_hash`, soft deletes). Open questions in the decision log, including OQ-01/03/07/10, are not silently resolved here.

**Owner roles used below.** `BACKEND` (Supabase config, RLS, endpoints), `CLIENT` (Flutter app), `DPO` (Data Protection Officer / privacy owner), `RELEASE` (store submission and gate sign-off). At student-project scale one person may hold several; the label marks accountability, not headcount.

---

## 0. Threat model

Assets and threats first. Controls are chosen to cover these, not the reverse.

| # | Asset | Threat actor | Attack | Impact | Mitigating controls |
|---|---|---|---|---|---|
| T1 | Shared plan data | Ex-partner after breakup / called-off wedding | Retains app access and keeps reading or editing the plan | Ongoing unauthorised access to finances and guest list; emotional harm | SEC-07, SEC-08, SEC-09; activity log REQ-SE-4 |
| T2 | Local SQLite store | Opportunistic finder / thief | Lost or stolen **unlocked** phone, opens app | Full read of budget, sponsor names, guest list | SEC-12…16 |
| T3 | Another couple's plan | Curious or malicious app user | Crafts requests for a `plan_id` they are not paired to; a broken authz check serves it | Cross-tenant financial data breach | SEC-22…25 |
| T4 | Plan membership | Anyone who obtains an invite link | Leaked/forwarded invite code used to join a plan | Unauthorised third party joins the couple's plan | SEC-05, SEC-06 |
| T5 | Entire database | Malicious or curious insider with backend DB access | Direct table reads bypassing the app | Mass breach across all couples | SEC-22, SEC-26, SEC-27, SEC-28 |
| T6 | Sync traffic | Network attacker on public wifi | Intercepts or replays sync requests | Token theft, data disclosure, duplicated writes | SEC-17…21 |
| T7 | Local store via backup | Attacker with cloud-backup or desktop-backup access | Extracts app DB from iCloud / Android backup or an unencrypted iTunes/Finder backup | Offline read of financial data | SEC-12, SEC-16 |

### 0.1 The called-off-wedding case — product behaviour, not a hypothetical

This is a first-class requirement (problem-brief describes real couples; REQ-SE-6 governs defensive removal, REQ-SE-5 governs the other lifecycle actions). The precise behaviour of **"revoke my partner's access and keep my data"**:

1. Removal of a partner is a **mutual, one-sided** action: **either** paired partner may remove the other, without the removed party's consent, and it takes effect on the server immediately (REQ-SE-6, Decisions 1 and 2). It is not creator-only, because if the creator were the hostile party the other partner would have no defensive move. Two-party confirmation applies to *ownership transfer* only (REQ-SE-5 clause 4), never to defensive removal. **Resolved — no longer flagged for confirmation.**
2. On removal, the server deletes the removed user's `plan_members` row. Their next sync (pull or push) is rejected: they are no longer a member, RLS returns nothing, and writes are refused (SEC-09).
3. **The removed partner keeps whatever was already on their device.** This is unavoidable and must be stated plainly: a local-first app (REQ-OF-1) means their SQLite copy already holds every figure they synced. No server action can reach into their phone. Pretending otherwise would be a false security claim.
4. What the retained partner gets: the plan continues under their account, the removed member can no longer read new changes or write anything, and the activity log records the removal with actor and timestamp (REQ-SE-4).
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
| SEC-04 | Sign-out revokes | Sign-out invalidates the selected device's refresh session server-side, not just locally; the signed-out device stops sync and offers a local wipe, while the same user's other devices remain signed in. Verify: sign out device A, then attempt refresh with its prior token → rejected; device B still syncs; an offline copy on A is not falsely claimed remotely wiped (ADR-50). | BACKEND |
| SEC-05 | Pairing code strength | Invite token ≥ 128 bits from a CSPRNG; only a hash is stored server-side (`invites.token_hash`, design.md §4.1); raw token never logged. Pasting a link and opening a deep link use identical single-use verification and must never send raw invite URLs to telemetry. Verify token generation/hash and both entry paths (ADR-52). | BACKEND |
| SEC-06 | Pairing code lifecycle | Invite is single-use and expires 7 days after issuance (REQ-SE-1); acceptance sets `accepted_at` and prevents reuse; revocation sets `revoked_at`. Verify: accept once → second accept refused; wait past expiry → refused; revoke → refused. | BACKEND |
| SEC-07 | Mutual one-sided defensive removal, with deterministic simultaneous-removal winner | **Either** paired partner can remove the other without the removed party's consent, effective on the removed party's next sync; the right is mutual, not creator-only (REQ-SE-6; Decisions D3, formerly ADR-18/19). The action is logged and attributed (REQ-SE-4). **Simultaneous mutual removal resolves to a deterministic winner** ordered by the server-assigned timestamp (D1/REQ-SE-2) and tiebroken on stable device id (D4/REQ-SE-6 clauses 9–11); the plan is never left with zero members. Verify all three: (a) creator removes partner B — B's `plan_members` row is gone and B's next sync is refused; (b) non-creating partner B removes the creator A — A's row is gone and A's next sync is refused; (c) two offline devices each remove the other, then both sync — exactly one partner survives, identical on both server and both devices, matching the server-timestamp/stable-id order. | BACKEND |
| SEC-08 | Revocation reaches the client | On membership loss, the client enters read-only terminal state and offers local wipe (ux-spec §3.3). Verify: remove B server-side; B's app on next foreground shows the revoked state and a wipe option. | CLIENT |
| SEC-09 | Revoked member cannot sync | After removal, both pull and push for that user return no data and are rejected by RLS, not by client-side checks alone. Verify by replaying B's last valid token directly against the sync endpoints post-removal → empty/refused. | BACKEND |
| SEC-10 | Re-pairing after reinstall | A reinstalled app re-authenticates with the existing account and re-pulls from the per-plan committed `cursor = 0`; no residual credential is needed from the old install. Verify: uninstall, reinstall, sign in, confirm full plan restored. | CLIENT |
| SEC-11 | Device-loss recovery | Losing a device requires no plan-side recovery beyond signing in on a new device; a lost device's local data is addressed by SEC-12 at-rest encryption. Verify: sign in on a second device, confirm access; confirm no plan secret is printed to logs during pairing. | CLIENT |

**Residual-copy statement (binding).** The removed partner retains the local data they had already synced. There is no technical means to guarantee its deletion from a device the operator does not control. This plan does not claim otherwise. SEC-08 offers wipe; it cannot enforce it against an offline or uncooperative device. This limit is disclosed to users in the privacy notice (SEC-30).

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
| SEC-21 | Queued-write contents | A queued write carries device sequence/ID and the acting plan_member_id alias, not a permanent FK to the auth user; the server validates the alias belongs to the currently authenticated plan member before assigning server_ts. Upload uses the current valid session, never a cached offline token. Pass: rotate session, reconnect and check alias/actor validation, stamp, and fresh auth header; forged aliases and signed-out device sessions are rejected (REQ-OF-5, REQ-SE-4, ADR-50/51). | BACKEND |

---

## 4. Backend authorization

**Tenant isolation rule, stated once, precisely:**

> A database row is readable or writable by a user **if and only if** it belongs to a `plan_id` for which a `plan_members` row exists linking that `plan_id` to the requesting user's authenticated `user_id`. No other path grants access.

| ID | Item | Pass condition | Owner |
|---|---|---|---|
| SEC-22 | Enforcement location | Isolation is enforced by Postgres Row-Level Security on **every** plan-scoped table, not by application code alone. Pass: RLS is enabled and forced on `plans`, `plan_members`, alias/mapping and per-device session metadata, `ledger_entries`, `fee_components`, `payment_schedule_items`, `payments`, `pledges`, `pledge_receipts`, `gifts_received`, `guests`, `crew_headcount`, `plan_allocations`, `hidden_fee_prompts`, **`checklist_items`**, **`measurement_consents`, `measurement_events`, `survey_consents`, `survey_responses` if persisted**, `invites`, `change_log`, `lifecycle_confirmations`. Verify each scoped relation and mapping has a policy and `FORCE ROW LEVEL SECURITY`; direct clients cannot rebind aliases or revoke another user's device. Future v1.1 `attachments` metadata needs the same plan-table coverage plus Storage object policy SEC-43 before release. | BACKEND |
| SEC-23 | The isolation policy | Every plan-scoped policy resolves membership through `plan_members`, keyed to `auth.uid()`. Pass: the policy predicate for each table reduces to "exists a `plan_members` row for this row's `plan_id` and `auth.uid()`". Verify by reading each policy definition. | BACKEND |
| SEC-24 | Negative authorization test | An automated test suite proves cross-tenant denial. Pass: user A cannot read, update, or delete any row of user B's plan via any endpoint, including direct REST with a crafted `plan_id` or forged measurement/survey plan binding; the suite includes at least read, write, delete, and a forged-`plan_id` sync pull plus cross-plan event/consent/response access. All return empty or denied. This is the single most important test in the project — a green suite is the pass condition, run in CI. | BACKEND |
| SEC-25 | Membership write path | Only the server-side invite-acceptance flow can insert a `plan_members` row; clients cannot insert membership directly. Pass: a direct client insert into `plan_members` is denied by RLS. Verify by attempting the insert with a normal user token → refused. | BACKEND |
| SEC-26 | Secrets management | Service-role keys, DB credentials, and signing secrets are held in environment/secret storage, never in the repo or the client binary. Pass: repo secret-scan is clean; the client bundle contains only the anon/public key, never the service-role key. Verify with a secret scanner in CI and by inspecting the built app. | BACKEND |
| SEC-27 | Backup encryption & restore access | Verify provider backup encryption and restore permissions, plus the daily encrypted 30-day off-provider copy covering Auth users (deployment-plan §2.6). Restore is limited to MFA-protected project owner and a specifically authorized, independently equipped break-glass alternate (ADR-65), with use logged and access revoked after an incident. Pass: check provider console roles, independently decrypt and restore to restricted scratch, verify Auth and plan data, and document who can restore without storing credentials here. | BACKEND |
| SEC-28 | Log hygiene | No operational log line — client, server, or provider request log — contains a ₱ amount tied to an identifiable user, a sponsor or guest name, an email, or any invite/session token or raw pasted invite URL. Pass: scan captured logs for amounts, emails, known test names, URL/token prefixes; structured operational logs carry only opaque IDs and non-content diagnostics. This does not exempt the access-controlled immutable change_log from retaining old/new domain values for audit (REQ-SE-4); do not emit those values to operational logs. | BACKEND |

**Note on SEC-24.** design.md §3 flags the RLS policy as "the whole security model" and warns it needs deliberate tests, not eyeballing. SEC-24 is that test, promoted to a gate item.

**SEC-16 and SEC-24 are unchanged by Decisions 1 and 2, and remain consistent.** SEC-16 (no cloud auto-backup of the local DB) is orthogonal to removal — it concerns backup exclusion, not membership. SEC-24 (cross-tenant denial, CI gate-blocker before internal beta) now additionally *covers the removal flow*: a removed partner is, from the moment of removal, a non-member attempting to reach a plan they no longer belong to — which is exactly the cross-tenant case SEC-24 already proves is denied by RLS. The removal-specific direction (a formerly-valid member post-removal) is exercised explicitly by SEC-07 and SEC-09 and by the test cases in testing-plan.md; SEC-24's forged-`plan_id` suite is the general guarantee behind them.

---

## 5. Philippine compliance — Data Privacy Act of 2012 (RA 10173) / NPC

Kasaran collects **personal data** (names, emails) and **financial and event data** (budgets, pledges with sponsor names, guest lists) from data subjects in the Philippines. The DPA applies. Items below list obligations; where applicability at this scale is genuinely uncertain, the pass condition is *verify with counsel* rather than a guess — the obligation is still listed.

| ID | Item | Pass condition | Owner |
|---|---|---|---|
| SEC-29 | Lawful basis | DPO and counsel document and approve a purpose-by-purpose lawful-basis analysis for account, shared-plan processing, Sentry diagnostics, optional measurement and survey, and the proposed 18+ declaration. Do not assume one signup checkbox legitimizes every purpose or that an age declaration is statutory verification. Pass: written basis and counsel sign-off for every live purpose in §6 before **real-data internal beta**; no asserted compliance while pending. | DPO |
| SEC-30 | Privacy notice content | A privacy notice is presented before or at collection and states controller identity, data and purposes (including diagnostics and optional measurement), the **OQ-07-approved** Supabase location (Singapore is proposed, not yet approved), Sentry EU Frankfurt event storage with possible US metadata/support transfer, recipients, retention, rights and request route, residual-copy limitation (§1), and that signup is for people declaring they are 18 or older. Distinguish optional consent and its withdrawal from necessary processing; disclose age-declaration retention. Pass: DPO/counsel-approved notice reachable pre-signup, accurate to enabled services and approved OQ-07 location before **real-data internal beta**. | DPO |
| SEC-31 | Consent capture | Record versioned notice acknowledgement, timestamp and 18+ self-declaration at signup; do not allow an under-18 or non-declaring applicant to create a real plan. Separate, default-off, freely revocable opt-ins for measurement and survey; declining does not block core planning. Pass: test signup and withdrawal demonstrate independently stored consent state and no optional event collection while off; DPO/counsel approve wording before **real-data internal beta**. | BACKEND / DPO |
| SEC-32 | Access & correction | A data subject can obtain a copy of their personal data and correct it. The project owner approved the **proposed design scope only** (ADR-60); no implementation or DPO approval is implied. SCR-23 supplies an offline, on-device full machine-readable export of **all locally held** account/profile and plan data, including gifts, receipts, checklists and attributed activity, separate from the curated/redactable PDFs and four CSVs (ADR-57). Label the copy as-of last sync; do not imply an offline snapshot includes server-only account fields or other devices' unsynced edits. The DPO must verify how an access request covers any server-only fields and shared-plan third-party data; do not claim that a redacted summary PDF alone satisfies this obligation. Pass: a test account can export the locally held full dataset, inspect it, and correct display name/email through the account path; coverage of server-only fields and shared-plan access is reviewed before marking this SEC item PASS. | CLIENT / BACKEND / DPO |
| SEC-33 | Erasure on a shared record | **BLOCKED on OQ-01 / ADR-26 pending counsel:** do not assert whether shared financial records or the other partner's copy are retained, de-identified or deleted. Technical prerequisite (ADR-51): immutable change_log references a stable per-plan alias rather than users; removal of the alias-to-user mapping can render Former member without rewriting log rows. Review all other user FKs and all personal content (including old_value/new_value) before an erasure flow; alias removal alone is NOT proof of full erasure. Pass condition and shared-record outcome require counsel's decision (SEC-38), not a guessed automated test. | BACKEND / DPO |
| SEC-34 | Account deletion self-service | Provide an in-app account-deletion request/confirmation path on SCR-18, with a clear counsel-pending explanation for shared-plan records and no false completion claim. **BLOCKED on OQ-01** for the shared-plan completion outcome; do not execute an irreversible shared-record deletion based on an assumed rule. Once counsel decides SEC-33, implement and test the approved path, including other-account access and attribution; no invented pass result now. | CLIENT |
| SEC-35 | Breach notification | A documented procedure assesses reportability, evidence preservation and timely notification to NPC and affected data subjects where required; counsel/DPO validate the trigger and deadline rather than treating every incident as automatically reportable. Pass before **real-data internal beta**: written incident-response runbook naming assessor, notifier, escalation/back-up owner and the applicable 72-hour clock, with a tabletop exercise. | DPO |
| SEC-36 | Retention & disposal | Data is retained only as long as the purpose requires; inactive-account and post-deletion disposal timelines are documented. Pass: a retention schedule exists and the deletion job honours it. | DPO |
| SEC-37 | NPC registration & DPO designation | Determine whether registration with the NPC and formal DPO designation apply at this scale. NPC registration thresholds turn on factors like number of records and sensitivity. **Pass: verify with counsel / NPC guidance whether registration is required; designate a DPO regardless, since the DPA expects a responsible person even for small controllers.** Do not assume exemption. | DPO |
| SEC-38 | Counsel review of erasure model | Counsel resolves OQ-01's shared-record retention/de-identification/deletion question and the treatment of immutable historical content before public launch. Pass: written decision and approved SEC-33/34 expected outcomes; no engineering assumption is substituted for review. | DPO |

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
| Payment schedule dates, amounts, and labels | Supplier payment planning; locally scheduled reminders | Yes | No | Supabase; OS notification scheduler holds due-date triggers on each device, not supplier names or amounts in default lock-screen copy |
| Recorded payment/refund dates, amounts, method, and notes | Ledger and reconciliation only; no in-app money movement or payment-rail credentials | Yes | No | Supabase |
| Sponsor names, roles (including secondary sponsor and candle/veil/cord sub-role), pledge amounts, receipts, dates, and notes | Core function (pledges and partial fulfillment) | Yes | No | Supabase |
| Gift source, amount, date, and notes | Day-of gifts and post-wedding reconciliation, separate from pledges | Yes | No | Supabase |
| Optional gift giver name | Third-party personal data supplied by a partner; identify a gift if provided | Yes (linked to the couple's plan, not necessarily a giver account) | No | Supabase |
| Guest names, RSVP, tier | Core function (guest math) | Yes | No | Supabase |
| Region / wedding location | Core function (regional cost) | Yes (coarse) | No | Supabase |
| Optional ceremony and venue type | Contextual hidden-fee hints; never an amount | Yes (linked to plan) | No | Supabase |
| Reminder enabled/offset settings | Schedule local reminders per plan; no server push for partner edits | Yes | No | Supabase; on-device notification scheduler |
| Device sync metadata (`server_ts`, `device_monotonic`, `device_id`) | Sync integrity | Yes | No | Supabase |
| Per-plan member alias and removable alias-to-user mapping | Attribution in the immutable change log; technical separation for deletion review (OQ-01) | Yes while mapping exists | No | Supabase |
| Per-device session/revocation metadata | List active devices and revoke a chosen device's session; local wipe offered only on that device | Yes | No | Supabase; OS key store on device |
| Immutable change-log old/new values and schema/group metadata | Auditable shared edits and version-safe projection; may contain historical names and financial content after account closure pending OQ-01 | Yes while shared plan or member mapping exists | No | Supabase; encrypted local store |
| Wedding-type template choice and checklist ticks (v1) | Unticked suggested expense types and couple-managed task state; no prices or verified legal claims | Yes when associated with a plan | No | Supabase for saved checklist state; bundled ruleset for template labels |
| Checklist manual dates, verification status and optional fee link (v1 target; presets blocked OQ-11) | Plan reminders and optional user-confirmed ledger entry; no authority claim for unverified legal/church timing | Yes | No | Supabase; device-local reminders if enabled |
| Transient PDF, CSV and full-data exports (v1) | Local export and OS sharing chosen by partner; may contain sensitive supplier, sponsor, guest or account data | Yes | No | Device temporary storage, then explicitly chosen OS share target (e.g. messaging or mail provider); no Kasaran-hosted link |
| Receipt/contract image bytes and metadata (v1.1 backlog only) | User-attached evidence; may expose embedded names, location or financial data | Yes | No | Encrypted local pending store; private Supabase Storage after authenticated upload; external target only if explicitly shared |
| Sentry crash events, stack traces, release/build, OS/device class and scrubbed diagnostics | Error diagnosis and release health only; not product analytics, ads, replay or profiling | Potentially (release/device context and event IDs can correlate); treat as linked for declaration pending payload audit | No advertising tracking | Sentry EU organization: event data at rest in Frankfurt; some account, project, usage and integration metadata may reside in US; support tickets containing shared data stored in US. No user content, email, tokens, amounts or invite URLs may be sent (SEC-28). |
| Optional product-measurement events (`net_comparison_viewed`, coarse client-version cohort) | Measure metric 3 and safe N−1 deprecation only after separate opt-in; no third-party analytics SDK | Yes if tied to plan/account pseudonym; minimize and aggregate | No advertising tracking | First-party Supabase only; default off; exclude financial values and names |
| Optional single survey answer (`only_wedding_budget_tool`: yes/no/prefer not to say) and survey consent | Measure metric 4 without requesting spreadsheet content | Yes if attached to a plan; release only aggregate cohorts | No advertising tracking | First-party Supabase only; default off; no free text |
| Versioned notice acknowledgement, 18+ self-declaration and optional consent/withdrawal records | Signup eligibility, proof of disclosures and independent opt-in state | Yes | No | Supabase; retention and legal basis counsel-approved |

**No advertising or third-party analytics SDK in v1; no advertising tracking or data brokers.** Sentry is **diagnostics**, not an analytics exemption: declare crash/diagnostic collection accurately. Optional product events and survey data stay first-party and disabled until independently opted in. Supabase's processor treatment, OS share-sheet transfers and Sentry's processing must be checked against each store's current definitions rather than asserted as a blanket no-sharing exemption. Any collection change requires notice and both store labels to be re-reviewed before shipping. Apple category definitions: https://developer.apple.com/app-store/app-privacy-details/ ; Play SDK/data-collection rules: https://support.google.com/googleplay/android-developer/answer/10787469 . Sentry location and US caveat: https://docs.sentry.io/organization/data-storage-location/ .

### 6.1.1 Privacy-first measurement (ADR-62; REQ-MT-1 / REQ-SV-1)

The five directional success metrics in project-brief §5 are **not** automatically measurable from the current sync model. DPO/counsel must approve the separate measurement purpose, lawful basis, notice, retention and consent/withdrawal handling under SEC-29..31 before any analysis of identifiable plan data for that purpose, including data already synced for core functionality. Existing sync permission is not blanket analytics consent. Until approval, use synthetic tests and do not report a real-couple metric.

| Metric | Minimal method after approval | Limitation / guardrail |
|---|---|---|
| 1. Budget accuracy | Compare recorded setup-end budget snapshot with final actual gross at wedding day, first-party aggregate over consenting eligible plans | A mutable current budget is **not** a setup snapshot and partial actuals are not final; no result without verified snapshot/completeness and denominator. |
| 2. Hidden-fee capture | Derive from `hidden_fee_prompts` resolution timestamps and wedding date for consenting plans; count ≥4 of 6 resolved >60 days before the date | A present-day state alone cannot prove when resolution happened; use immutable change history if complete, otherwise unknown. Define active-plan denominator before reporting. |
| 3. Pledge + net-view | Derive existence of a pledge from synced plan data; count ≥2 `net_comparison_viewed` events **only after** opt-in | Viewing is not inferable from a pledge or `change_log`; never infer it from sync. |
| 4. Spreadsheet displacement | One optional, dismissible in-app yes/no/prefer-not-to-say survey (REQ-SV-1), separately consented, no free text | No background inference about other apps/files; report response rate and self-selection caveat with aggregate. |
| 5. Two-partner use | From attributed `change_log` ledger edits within the final 30 days before wedding for consenting plans | Require two distinct current member aliases and authoritative server timestamps; offline edits not synced by wedding day remain unknown. |

Record only coarse plan pseudonym, event type, UTC day and consent-version for optional first-party events; no names, monetary values, free text, raw user ID, device advertising ID or third-party analytics SDK. Keep opt-in **off by default**, implement in Settings with grant/revoke and a plain-language purpose; stop future events immediately on withdrawal and apply the counsel-approved retention/deletion schedule to previously collected events. For a shared plan, require **both current partners' independent opt-in** before analyzing synced shared data; a withdrawal by either stops future plan-level analysis and the DPO-approved handling of prior observations applies. Separate survey permission and give a skip/permanent dismiss state; one answer per consenting plan, with a documented rule for conflicting answers. Show metric aggregates only above a DPO-approved minimum cohort; no individual dashboard or partner surveillance. Beta cohort denominators, survey response bias and OQ-04 calibration must be published alongside any result. Sentry diagnostics is separate and does not constitute measurement opt-in. Reconcile any coarse client-version deprecation signal under this opt-in: if there is insufficient consented coverage, retain the longer safe compatibility window and do not claim all old clients are gone.

### 6.2 Apple App Privacy

| Apple category | Applies? | Linked to user? | Tracking? |
|---|---|---|---|
| Contact Info (email, name) | Yes | Yes | No |
| Financial Info (budget, pledges, amounts) | Yes | Yes | No |
| User Content (supplier/sponsor/guest/gift-giver names, notes, self-selected ceremony/venue type) | Yes | Yes | No |
| Photos (receipt/contract images) | **No in v1**; reassess and declare before v1.1 attachments ship (SEC-44) | If v1.1 ships, yes | No |
| Identifiers (account/user id) | Yes | Yes | No |
| Diagnostics (Crash Data; Other Diagnostic Data and Performance Data only if actual SDK payloads contain them) | Yes if Sentry enabled; audit exact payload before submission | Conservatively Yes pending payload proof | No |
| Usage Data (Product Interaction) | Yes **only if** opt-in `net_comparison_viewed`/version events ship; label optional collection accurately, not “No in v1” | Yes if plan-correlated | No |
| Other Data / survey response | Review exact Apple data category against implemented yes/no survey and collection path | Conservatively Yes pending label review | No |
| Location | Coarse region only, self-selected, not device GPS — declare as User Content region, **not** Location. | Yes | No |

### 6.3 Google Play Data Safety

| Play question | Answer |
|---|---|
| Data collected | v1: Personal (name, email), Financial (budget, payment records, pledges/receipts, gifts), other user content (guest/sponsor/gift-giver names, notes, ceremony/venue type, checklist choices). v1.1 attachment images are **not** collected in v1 and require label review before collection (SEC-44). |
| Diagnostics and optional measurement | Declare Sentry crash logs and diagnostics/device or other IDs actually transmitted; optional first-party product interactions and survey yes/no as applicable, with collection and optionality matching shipped behavior. Audit SDK network payloads, not just intended configuration. |
| Data shared with third parties | Supabase processes on the developer's behalf; v1 OS share sheet can transfer user-selected exported data to a chosen outside app. Before Play submission, DPO/release owner must review Google Play's current Data safety guidance for user-directed transfers and declare each applicable data type accurately rather than assume a blanket “not shared” exemption (SEC-39/42). |
| Encrypted in transit | Yes (SEC-17) |
| Encrypted at rest (device) | Yes (SEC-12) |
| Can users request deletion | Yes, in-app (SEC-34) |
| Used for tracking | No |

| ID | Item | Pass condition | Owner |
|---|---|---|---|
| SEC-39 | Labels match reality | Apple App Privacy and Play Data Safety declarations match the §6.1 inventory exactly; no collected field is undeclared and no declared category is uncollected. Verify by diffing submitted labels against the inventory. | RELEASE |
| SEC-40 | Account deletion path published | Both stores' account-deletion requirement is met: in-app deletion (SEC-34) plus, for Apple, a publicly reachable deletion instruction URL. Verify both are live before submission. | RELEASE |
| SEC-41 | Location not over-declared | The app declares self-selected region as user content, requests no device-location permission, and links no GPS API. Verify by permission-manifest inspection. | CLIENT / RELEASE |
| SEC-42 | Offline export/share privacy | v1 PDFs and CSVs are generated locally with no live share links or server upload. Shared summary PDF defaults guest and sponsor names hidden with independent disclosure toggles; a statement selects one Ninong/Ninang pledge and contains no other sponsor or guest identity; full-data export is clearly marked sensitive. CSV text and formatted values with spreadsheet-formula prefixes `= + - @` (including after leading whitespace/control characters) are neutralized before RFC-4180 quoting. Pass: offline export test scans each output for redacted names, malicious formula cells and unexpected network calls; OS share sheet recipient sees only the selected file. Show an explicit warning that external recipients may keep a copy; remove the app's transient file after handoff, without promising guaranteed flash-storage erasure or remote recall (ADR-57). | CLIENT |
| SEC-43 | Private photo storage (v1.1 backlog; not v1) | A future private Supabase Storage bucket SHALL have membership-checked RLS on `storage.objects` for read/list/insert/delete under a plan ID; no public bucket or unauthenticated URL, and a removed partner cannot access bytes after revocation. Pass before v1.1 release: cross-tenant/removed-member negative tests against list, download, upload and delete, including forged object paths; no service-role key in the client (ADR-59, SEC-22/24). | BACKEND |
| SEC-44 | Photo limits, offline staging and labels (v1.1 backlog; not v1) | Define approved `max_attachment_bytes` and allowed image MIME types in versioned configuration before implementing upload; reject over-limit, unsupported or malformed files on device **and** storage path. Keep offline pending bytes encrypted, backup-excluded and unshared until successful authenticated upload; purge local transient bytes per retention policy. The DPO reviews the Photos privacy-label impact and image metadata handling before any v1.1 store submission. Pass: size/type rejection, interrupted upload, orphan deletion, wipe and label checks; **no numeric limit is invented here** (ADR-59, SEC-12/16/39). | CLIENT / BACKEND / DPO |

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
| SEC-27 Backup encryption & restore | PASS for real-data beta | PASS | PASS |
| SEC-28 Log hygiene | PASS for real-data beta | PASS | PASS |
| SEC-29 Lawful basis | PASS | PASS | PASS |
| SEC-30 Privacy notice | PASS | PASS | PASS |
| SEC-31 Consent capture | PASS | PASS | PASS |
| SEC-32 Access & correction | — | PASS | PASS |
| SEC-33 Erasure on shared record | — | PASS | PASS |
| SEC-34 Account deletion self-service | — | PASS | PASS |
| SEC-35 Breach notification runbook | PASS | PASS | PASS |
| SEC-36 Retention & disposal | — | — | PASS |
| SEC-37 NPC registration & DPO | — | — | PASS |
| SEC-38 Counsel review of erasure | — | — | PASS |
| SEC-39 Labels match reality | — | PASS | PASS |
| SEC-40 Account deletion published | — | PASS | PASS |
| SEC-41 Location not over-declared | — | PASS | PASS |
| SEC-42 Export/share privacy | — | PASS | PASS |
| SEC-43 Private photo storage | — | — | — (v1.1 release gate; not v1) |
| SEC-44 Photo limits and labels | — | — | — (v1.1 release gate; not v1) |

**Reading the gate.** Real-data internal beta requires SEC-29..31/35 **PASS** and OQ-07 production residency/privacy approval, in addition to auth, isolation and at-rest controls. Staging remains synthetic-only; no real-couple records there. If these gates are not met, run synthetic-only internal tests, not a real beta. SEC-32 remains separately DPO-pending despite ADR-60's design-scope approval. Store submission adds the full rights, compliance and label surface; public launch adds remaining external sign-offs. A dash means not yet required at that milestone, never “may be skipped.”

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
- **Payment-rail security (PCI etc.).** Not applicable to v1 — v1 records that money moved, never moves it (REQ-LG-4, deferred REQ-AI-4). **Revised per ADR-28:** payments is no longer part of the AI phase; it is its own post-launch phase (development-phases phase 22, formerly §25). A dedicated SEC block must therefore be authored before that phase starts — covering rail authentication, tokenisation, reconciliation integrity, PCI applicability, and the DPA implications of holding transaction data. Tracked as **OQ-10**, which blocks post-launch phase 22. This is a gap, not a completed exclusion.

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
4. **★ Erasure model (SEC-33/34/38, OQ-01).** Still counsel-blocked: whether to retain, de-identify, or delete the other partner's shared record and how to handle personal content inside immutable history are unresolved. Alias mapping removal alone does not erase free-text values or solve other user FKs. No shared-record erasure test has a guessed expected outcome (ADR-26). Resolve the model with counsel before claiming the account deletion flow works or submitting the app.
5. **★ NPC registration threshold (SEC-37).** Still open. Applicability at student-project / early scale is uncertain. Verify; do not assume exemption.
