# Kasaran — Support FAQ and privacy-safe intake

*Draft support copy and internal handling, ADR-66. Do not publish as a live support promise until the domain/mailbox, privacy notice, deletion workflow and DPO/counsel review are complete. The project has no verified production support channel yet.*

## Contact and response

For account, privacy or safety questions, use **support@kasaran.app** when this address is live. We aim to send an **initial response within two business days** (Philippine business days); investigation and rights-request completion may take longer under applicable law. The in-app Get help link should open this address and the approved privacy/deletion pages. If the domain is not owned or mailbox not tested, do not display this as an active channel.

**Please do not put passwords, sign-in links, verification codes, invite links, government IDs, bank/payment details, guest lists, sponsor names, screenshots of your plan, or financial figures in plain email.** We will never ask you to send a password or verification code to support. Include only the general issue and the email used for your account; if proof is needed, we will provide a secure, account-bound verification route. A screenshot containing personal data is not a prerequisite to help.

## Common questions

**Can I use Kasaran while offline?** After your first online sign-in and plan download, you can keep planning offline; changes sync when the app reconnects. An unsynced edit on a lost device may not be recoverable. Do not sign out or uninstall solely to troubleshoot a sync issue before checking that your changes have synced.

**What happens if I remove a partner?** Either paired partner may remove the other through the in-app control (SEC-07). Server access to future changes stops on that person's next sync. **Copies already saved on their device or exported elsewhere cannot be recalled or guaranteed erased.** If you are worried about immediate safety or coercion, use a device and account the other person cannot access; support can explain your own controls but will not reveal the other person's account details. Avoid sending a dispute narrative or sensitive documents in plain email.

**Can support reverse a partner removal or decide who owns a shared plan?** No automatic reinstatement or disclosure based on an email request. Support does not arbitrate a relationship dispute, silently move ownership or give one person the other's records. A disputed ownership, coercion, unauthorized access or safety concern is escalated privately to the designated privacy/security owner for review. We may preserve minimal incident evidence under the approved retention policy; no promise of immediate deletion of a shared record while OQ-01 remains unresolved.

**How do I get or correct my data?** Use the in-app full local-data export for a copy of what is on **this device as of its last sync**; it does not necessarily include server-only account fields or edits from another device that have not synced. For an access/correction request covering the server, email support with only your account email and request type. We verify your identity through a signed-in in-app action or a fresh, expiring single-use account-bound link before releasing data. The DPO reviews shared-plan and third-party information (SEC-32); ADR-60 approved only the proposed design scope, not its implementation or compliance.

**How do I delete my account?** Use the in-app account deletion request when available, or request instructions from support. The outcome for shared history and another partner's retained copy is still subject to counsel's OQ-01 decision (SEC-33/34/38); submitting a request is **not** a claim that shared content or an offline copy has already been erased. A public deletion-instructions page and tested in-app workflow are required before store submission.

**What information does Kasaran send for diagnostics and measurement?** If enabled after the release gate, Sentry receives scrubbed crash diagnostics for app reliability, not advertising tracking. Its EU organization stores events in Frankfurt, Germany; some organizational metadata and information shared in Sentry support may be held in the US (https://docs.sentry.io/organization/data-storage-location/). Product measurement and the one-question survey are separate **default-off opt-ins**; you may decline or withdraw without losing core planning. The privacy notice must explain all purposes, recipients, locations and retention before real-data beta (SEC-29..31).

**Who can sign up?** The proposed signup flow requires you to declare you are **18 or older**. It is a self-declaration, not identity or age verification. This wording and its lawful basis require counsel/DPO approval before real-data beta.

## Internal intake and escalation (not public copy)

1. Auto-acknowledge with a ticket ID and links to the **approved** notice/deletion page; repeat the no-sensitive-email warning. Restrict mailbox/ticket access and retention to authorized personnel. Never ask for IDs or secrets in ordinary email. If the address or page is not live, keep the gate NOT MET.
2. Triage as routine support, access/correction, erasure, ex-partner safety, suspected unauthorized access, or breach. Record receipt timestamp, request category, identity-check outcome, assigned owner, counsel/DPO review, applicable statutory deadline and final action in a restricted ticket. A two-day initial response is not a rights completion deadline.
3. Before disclosing account/server data, verify the requesting account in an authenticated session or fresh, expiring, single-use, account-bound link; verify scope, redact third-party/shared data according to DPO's decision, use a secure download channel with expiry rather than an email attachment. Never confirm another person's membership to an unverified requester. Escalate server-only access and shared-record erasure to DPO; do not mark SEC-32/33 PASS by issuing the local export alone.
4. For ex-partner threats or possible cross-tenant access, route to incident owner promptly and preserve minimal non-content evidence. Do not contact the other partner automatically or promise remote deletion of their old local copy. Assess breach reportability under the SEC-35 runbook and counsel advice; report through approved channels if required.

References: [Security and Privacy Plan](./security-plan.md) §§1, 5–7; [Deployment Plan](./deployment-plan.md) §§1.1, 7.3–8.2; ADR-61–66; OQ-01/OQ-07. This FAQ is not a substitute for a legally approved privacy notice.
