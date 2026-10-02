# Kasaran — Technical Design

*Derived from [requirements.md](./requirements.md). Requirement IDs referenced as REQ-XX-N.*

---

## 0. Platform — resolved

**Resolved: Flutter, Android and iOS, SQLite via `drift` (or `sqflite`).** This matches REQ-PLT-1 and REQ-PLT-2 clause 4. The earlier React Native draft of section 1 has been replaced with the Flutter stack below.

One consequence worth keeping visible: the money-representation caveat that the React Native draft carried in section 1.5 **no longer applies**. Dart's `int` is natively 64-bit, so REQ-GEN-1's signed-64-bit-centavo requirement is satisfied by the language directly, with no `MAX_SAFE_INTEGER` guard and no `BigInt` gymnastics. This was a real point in Flutter's favour and it is now banked. See section 1.5.

Sections 2 through 6 — sync, backend, data model, allocation engine, AI seams — were written platform-agnostic and are unaffected by this resolution.

---

## 1. Client architecture

### 1.1 Stack

| Concern | Choice | Reason |
|---|---|---|
| Framework | Flutter, targeting Android and iOS | REQ-PLT-1. One codebase, both stores. Builds cleanly on the M1 Pro dev machine. |
| Navigation | `go_router` | Declarative typed routes, deep links for invite acceptance, redirect guards for auth and active-plan state. |
| Local database | SQLite via `drift` | REQ-PLT-2 clause 4. `drift` gives typed queries, real migrations, and reactive `Stream` results so the dashboard recomputes when a row changes. `sqflite` is the fallback if `drift`'s codegen proves heavy, at the cost of hand-written queries. |
| App state | Riverpod | Ephemeral and derived-read state only — wizard step, open modal, preview buffer, reactive query providers. Never a second copy of persistent data. |
| Server-state cache | None | Deliberate. The local DB is the source of truth per REQ-PLT-2 clause 1; there is no remote cache to reconcile, so no equivalent of a fetch-cache layer exists. |

**No remote-state cache layer.** In a networked app a library like this reconciles server responses with a client cache. Here reads never touch the network (REQ-PLT-2 clause 1), so such a layer would be a second source of truth competing with SQLite. Riverpod providers wrapping `drift`'s reactive queries do the job — the UI rebuilds from the database, not from a cache of a server.

### 1.2 Layering

```
ui/                      widgets and screens, no SQL, no business rules
  presenters/            formatting only (₱ display per REQ-GEN-2, REQ-GEN-2A)
domain/                  pure Dart, no Flutter or drift imports
  allocation/            pure allocation engine (section 5)
  calculations/          gross, net, exposure, variance, buffer, per-head
  validation/            REQ-BS-2, REQ-LG-1 field rules
data/
  repositories/          the only code that touches SQL
  db/                    drift table definitions and migrations
  changelog/             append-only writer (section 2)
sync/
  queue/                 outbound cursor and batching
  clock/                 device monotonic counter; server assigns ordering ts (D1, section 2.2)
  transport/             HTTP client, retry, idempotency
platform/
  db/                    SQLite open, migrate, encrypt
```

**Rule enforced by review:** the `domain/` layer imports neither Flutter nor `drift` — pure Dart functions over plain value types. This is what makes the allocation engine swappable in section 5 and unit-testable against the acceptance criteria without a widget or a database.

### 1.3 Navigation

```
(auth)
  sign-in, sign-up
(invite)
  accept/[token]              deep link, 7-day expiry per REQ-SE-1
(onboarding)                  setup wizard, REQ-BS-1
  budget-and-date → guest-cap-region-and-optional-types → hidden-fees   (SCR-03 → SCR-04 → SCR-05)
  hidden-fees blocks completion until all six touched (REQ-HF-1 clause 6)
(app)                         tabs
  dashboard                   gross, net, exposure, buffer, adequacy, due soon, outstanding fees
  ledger                      list, due soon, filter by derived status; entry schedules/payments
  guests                      RSVP × tier matrix
  pledges                     list, receipt history, withdrawal, gifts received
  more                        reconciliation, change log, allocations, reminder settings, plan lifecycle
modals
  entry-editor, schedule-editor, payment-editor, fee-editor, pledge-editor, receipt-editor, gift-editor, guest-editor,
  what-if-preview, allocation-override, explain-figure
```

The setup wizard is a distinct stack rather than tabs because REQ-HF-1 clause 6 requires it to gate completion. Tabs would let a user escape the gate.

### 1.4 Derived values are never stored

REQ-LG-5 clause 6 forbids persisting payment status. The same reasoning extends to every computed figure: two devices that disagree would generate a sync conflict on a value that is not actually user input.

**Computed on read, never synced or persisted as plan data:** entry effective amount (including actual-price discounts and per-head rules); per-entry deposit/net paid (`Σ active payment rows − Σ active refund rows`), plan deposits/net payments, per-entry balance due (`max(0, effective − net paid)`), plan balance due, and overpayment; schedule-item allocated paid and residual, item states (`paid`, `partially paid`, `due soon`, `overdue`, otherwise pending), entry payment status (`paid`, `pending`, `due soon`, `overdue`) and separately indicated partial coverage; gross event total, net received pledge support (including receipt-derived `received` status), expected remaining pledge support, outstanding confirmed pledge exposure, net out-of-pocket (gross minus received support), gifts total, net after gifts (net out-of-pocket minus gifts total), post-wedding reconciliation of gifts against remaining balances and any orphan support; buffer remaining, category variance, per-head derived amounts, and budget adequacy. Do not persist a running payment, receipt, or gift total. Negative net and net-after-gifts values remain negative, not floored (ADR-37/40). Details and attribution rules are in §4.4–4.5.

Per-head `estimated_cents` is a **flat-mode input only**; for an unvalued per-head entry derive `driving_guest_count × per_head_rate_cents` on every read, including after guest-count sync. Never write a recomputed estimate. The pinned immutable bundled ruleset and synced plan inputs likewise produce engine allocations and traceable explanations locally; only manual `override_cents` syncs (§4.3, §5.3, ADR-46). Missing pinned ruleset assets block the dependent derived view with needs-attention/update copy rather than fabricating an amount. A what-if preview never persists derived changes.

For an entry without explicit schedule items, render **one virtual undated balance** for its effective amount; it has no row, no date, no reminder, and cannot become overdue. When an explicit schedule exists, allocate its dated items first, then render a virtual undated residual only for any remaining effective amount not covered by the items (ADR-36). All payment allocations, item states and reminders derive locally on read from the active rows and the device's calendar date; they are not synced as status writes (REQ-OF-4). A refund can reopen a paid item or entry.

Cheap because SQLite is local — these are millisecond aggregates over hundreds of rows, not thousands.

### 1.5 Money in Dart — no wrinkle

REQ-GEN-1 requires signed 64-bit integer centavos and forbids floating point. Dart's `int` is natively 64-bit on both mobile targets, so this is satisfied by the language: money is `int` centavos end to end, stored as SQLite `INTEGER`, with no wrapper type and no upper-bound guard needed for any realistic value. This is the caveat that would have existed under React Native and does not exist here.

Two rules hold this in place:

- **No `double` in any monetary path.** Allocation, variance, buffer, and pledge arithmetic operate on `int` centavos. Percentages and multipliers are basis points (`int`), per section 4, so even ratio math stays integer until a final divide.
- **Formatting is the only place a value becomes a string**, in `ui/presenters/`, applying REQ-GEN-2 (full form) and REQ-GEN-2A (constrained bento form: centavos dropped below ₱1M, `₱1.25M` above, truncated toward zero). The presenter is the single chokepoint, so the constrained form cannot leak into a ledger row, editor, or accessibility label.

---

## 2. Sync architecture

### 2.1 The change log is the sync unit

The pivotal decision in this design. REQ-SE-2 requires field-level last-write-wins, and REQ-SE-4 requires an immutable log with previous and new values including writes that lost. One structure satisfies both: **an append-only log of field-level changes is the thing that syncs, and row state is a materialised projection of it.**

```
write path:   user edit → one change_log row per changed ordinary field,
                        or one atomic full-snapshot group/create event
                        → apply to projection table
                        → enqueue log row for push

read path:    projection tables (fast queries)

sync:         push local log rows, pull remote log rows,
              apply in server-assigned order, last write per field wins
```

Consequences that fall out for free:

- **REQ-SE-2 clause 1 and 2** — different ordinary fields and different entries never collide, because log rows are keyed by `(entity_type, entity_id, field_name)`; the two explicitly grouped fields sets resolve atomically (§2.2).
- **REQ-SE-2 clause 6** — a losing write is never discarded; it is already in the log and reads as superseded.
- **REQ-SE-4 clause 3** — superseded writes are visible with their values intact.
- **REQ-SE-3 clause 1** — convergence is order-independent, because applying a set of log rows sorted by clock yields the same projection regardless of arrival order.
- **REQ-OF-5 clause 2** — idempotency is a primary-key conflict on the log row's client-generated ID.

The alternative — sync whole rows and keep the log as a side audit table — cannot satisfy field-level LWW without a second mechanism, and lets the log drift out of agreement with state.

**Stale-write visibility (ADR-43).** For each accepted *update* write, compare its typed `old_value` (null included) against the effective value it *actually replaces* immediately before applying it in authoritative server order; a create event initializes state and is not compared against a prior field. A mismatch is a derived conflict, not a stored flag; an old offline write can win while still conflicting. Replay all rows and groups to derive conflict records on **both** devices; show winning and superseded values in SCR-16's Conflicts filter and a dismissible banner to both users. A superseded row alone is not proof of a stale write: the mismatch test is decisive. Neither detection nor notification changes ADR-21 ordering.

### 2.2 Clocks: server-assigned ordering (D1)

REQ-SE-2 (amended per Decision D1) resolves conflicts by a **server-assigned timestamp applied at sync time**, with a device-side monotonic counter as tiebreaker. Device wall clocks are never authoritative for ordering: a phone running ten minutes fast must not win a conflict, and REQ-OF-4 explicitly anticipates devices disagreeing about the date.

**The ordering source of record is the server.** When the server accepts a change-log row at sync, it stamps `server_ts` (a monotonic server clock / commit sequence). That value, not any device time, orders writes to the same field.

Each log row carries an ordering key `(server_ts, device_monotonic, device_id)`, compared lexicographically:

- `server_ts` — assigned by the server on acceptance; the authoritative order. Null on the device until the row has synced.
- `device_monotonic` — a per-device counter that only ever increases, recorded at write time. Used as a tiebreaker when two rows share a `server_ts`, and to order a device's own not-yet-synced writes locally.
- `device_id` — stable UUID, the final deterministic tiebreaker required by REQ-SE-2 clause 4.

**Why not a hybrid logical clock seeded from the wall clock (prior design):** an HLC still folds the device wall clock into `physical_ms`, so a badly-set clock still distorts ordering — HLC only bounds the damage. D1 removes device time from the authority chain entirely by deferring the ordering stamp to the server. The device monotonic counter carries no wall-clock meaning; it is a pure sequence.

**Consequence for offline writes.** A write made offline has no `server_ts` until it syncs (REQ-SE-2 clause 5). Locally its provisional value is visible immediately, with the device's own unsynced writes sequenced by `device_monotonic`; on sync the server assigns `server_ts` and settles the authoritative order. **The same-field write that syncs last wins, even if it was made offline days earlier.** If A's same-field write synced first and B's older offline edit syncs later, B wins because B receives the later server timestamp. The age of the offline edit and either device's wall clock do not determine the winner. Both writes remain in the immutable log; A's becomes superseded.

**Two compound LWW groups (ADR-44).** `(ledger_entries.pricing_mode, per_head_rate_cents)` and `(fee_components.quantity, unit_rate_cents, amount_cents)` are indivisible. Each edit emits one row with a fresh `change_group_id`, `field_name` naming the group and `old_value`/`new_value` containing the **complete typed snapshot**, including explicit nulls and unchanged members. Choose the highest `(server_ts, device_monotonic, device_id)` group event and apply its entire snapshot atomically; do not merge constituent fields or accept an incomplete group. Conflict comparison uses the prior full-group snapshot. Other fields retain field LWW, and losing group events remain in the immutable log. This is LWW over a larger validation unit, not a CRDT.

**Expensive to reverse.** The ordering key lives in a column on every log row and in every comparison. This is a change from the earlier HLC design; the schema (§4.6) reflects `server_ts` + `device_monotonic` rather than `hlc_physical` + `hlc_counter`.

### 2.3 Identifiers and tombstones

**Client-generated UUIDv7 primary keys, everywhere.** Offline creation is required by REQ-OF-1, so the client must mint IDs without asking the server. Server-side autoincrement makes offline creates impossible. UUIDv7 sorts by creation time, which keeps index locality reasonable.

**Full-snapshot creation and parent-gated soft deletes (ADR-47).** Each entity is introduced by **one** `create` log event containing the complete validated initial snapshot (including parent ID and nullable fields). Replay materialises it atomically, never a partly created row across pull pages; a child waits for its parent's create, and an incomplete/unknown snapshot is retained but not projected. A later `deleted_at` tombstone gates visibility over ordinary edits regardless of their later ordering keys: edits accepted while deleted are retained as suppressed/superseded history, trigger the conflict banner, and **do not update effective fields**. Only an explicit later LWW write `deleted_at = null` (Restore) reopens the **last effective pre-delete field values**, revalidating them and eligible children; suppressed edits do not silently become effective. Restore is distinct from reverting a value. A concurrent delete wins over an ordinary edit even if the edit is accepted later. Children (fee components, schedule items, payments, receipts as applicable) remain logged but do not contribute to live totals while a parent is deleted; no cascade writes. A pledge linked to a deleted entry retains its value and link, visibly says “linked entry deleted”, and its orphan in-kind support remains excluded from live net. Schedule items, payments, receipts and gifts have independent UUID rows and tombstones; corrections tombstone the old monetary event and insert a new UUID event. Domain dates such as `paid_on` and `received_on` never order sync.

Both are expensive to reverse. See sections 7.3 and 7.4.

### 2.4 Push and pull

Two operations, both idempotent:

```
POST /sync/push   { protocol_version, plan_id, rows: ChangeLogRow[] }  -- no client server_ts
                  → { protocol_version, accepted: [{id, server_ts}], server_ts_high }
                  insert-ignore on primary key; server assigns server_ts on accept (D1)

POST /sync/pull   { protocol_version, plan_id, cursor, limit }
                  → { protocol_version, rows: ChangeLogRow[], next_cursor, has_more }
```

- Pull is cursor-paged on a **per-plan commit-ordered** `server_ts`, not a wall-clock timestamp. Server sequence assignment and log insertion hold a transactional per-plan lock **through commit**; another transaction cannot commit a higher key ahead of a still-uncommitted lower key. Return only committed rows up to the committed high-water mark, in order; advance `next_cursor` only past returned committed rows. Rollback gaps are harmless. A client advances its durable cursor only after transactional local persistence of the whole page (including unknown rows), so restart/retry cannot skip or half-apply a page (ADR-48).
- Push batches with a cap; partial success across **independent** events is fine because retry is idempotent. A sponsor-direct payment and its paired receipt are an indivisible accept/reject unit even if the surrounding batch is interrupted (§4.5); group and create snapshots are single indivisible events.
- **The server assigns `server_ts` on acceptance (D1); the device never sends an authoritative ordering timestamp.** The device sends `device_monotonic` and `device_id`, which the server preserves for tiebreaking. This differs from a preserved-client-timestamp scheme: the ordering authority is the server, per Decision D1, so REQ-OF-5 clause 3's "preserve original ordering" means preserving the device sequence, with `server_ts` settled at first acceptance and never rewritten thereafter. A later-accepted offline edit wins a same-field conflict over an earlier-accepted online edit.
- `sync_state` holds `last_pushed_server_ts`, `last_pulled_server_ts` (the per-plan committed cursor), and the device's `device_monotonic` per device per plan.

**Mixed versions and local migrations (ADR-49).** Every push/pull request and response carries `protocol_version` (major/minor), and every immutable event carries `schema_version`. The server refuses unsupported majors with a structured `min_supported_build` response; pending local rows stay queued and the client shows update-required, never silently drops them. Compatible additive unknown `entity_type`/`field_name` rows are stored intact in the local log but omitted from projections; if a known calculation depends on unknown data, suppress its derived view and flag needs attention instead of showing a misleading total. On upgrade, migrate drift schema transactionally before sync, retain the entire log and queue/cursors, rebuild projections in ordering-key order from log (including formerly unknown rows), validate invariants, and only then swap to new projections and resume; rollback leaves the old schema/data usable. Migrations are versioned and idempotent, not destructive resets.

**Multiple devices and sessions (ADR-50).** A member may have multiple device IDs, device-local counters, cursors and queues; attribution distinguishes another device of the same member from the partner. Each device has an independently revocable refresh session. Sign-out revokes that device's session on the server and stops its sync; offer a confirmed local SQLCipher/key wipe, never silently remove unsynced work. Revoke another device from SCR-18 without terminating the current/other sessions. An offline or uncooperative device cannot be remotely force-wiped; on reconnect reject its revoked session before accepting pushes. Local copies remain until voluntarily wiped; do not promise erasure elsewhere.

### 2.5 First login on a second device

REQ-SE-1 clause 5 requires the joining partner to see every existing figure identically, including overrides. With log-based sync this is a full replay:

1. After sign-up with no plan, show “Start our plan” or “Join my partner's plan” (ADR-52); joining opens SCR-02 by tapped deep link **or pasted invite URL**. Both parse the same token and server validation path (≥128-bit CSPRNG token, hash-only storage per SEC-05): unexpired per REQ-SE-1 clause 4, not revoked, not already accepted. Never implicitly create a second plan.
2. Server atomically inserts the stable `plan_member_aliases` row and live `plan_members` row. Membership is the one write that does not flow through the change log, because it is an access-control fact rather than plan content, and it must be authoritative before any data is readable.
3. Client creates the local database and pulls from per-plan `cursor = 0`, paged.
4. Client applies rows in `server_ts` order, building projections from empty.
5. Client computes all derived figures locally per section 1.4.
6. Dashboard renders. B's figures now match A's exactly, because both are projections of the same log.

Bootstrapping a long-lived plan means replaying every field change ever made. For a wedding budget — hundreds of entries, a few thousand log rows — this is fine. If it ever is not, add a periodic server-side snapshot and pull `snapshot + log since snapshot`. **Do not build server projection snapshots for v1.** A per-entity `$create` event's full initial snapshot (§2.3) is different from a periodic server checkpoint. The seam is the per-plan committed cursor.

### 2.6 What is deliberately not built

- **No realtime push or partner-edit push notifications.** Sync on app foreground, on reconnect, and after a debounce following local writes. Each device may schedule its own due-date **local notifications** from its local schedule and plan reminder settings, including offline; these are not a remote sync transport (§4.4, REQ-LG-9).
- **No CRDTs.** The requirements specify LWW. A CRDT would be a heavier mechanism satisfying a guarantee nobody asked for. Noted in section 7.2 as the reversal path if LWW proves insufficient.
- **No operational transform.** No collaborative text editing here.

---

## 3. Backend and data store

### Decided backend — Supabase (ADR-16)

Managed Postgres with built-in auth, row-level security, and generated REST.

**Fit:**
- Auth, email verification, session refresh, and password reset are free. For a two-person sharing model this is most of the non-domain work.
- RLS enforces plan isolation at the database rather than in application code. One policy — *a user may read and write log rows for plans they are a member of* — covers the entire surface.
- Push and pull are two RPCs over one table. Little custom server code.
- Postgres underneath, so the schema and data are portable.

**Costs:**
- RLS policies are subtle. Getting the `plan_members` join right is the whole security model, and a bad policy leaks another couple's budget. Needs deliberate tests, not eyeballing.
- Auth is the lock-in. The database migrates cleanly; user identities and password hashes do not.
- Free tier pauses idle projects. Fine for a student project, surprising in a demo.

### Considered alternative — Managed Postgres plus a thin API (not selected)

Neon, Railway, or Fly Postgres behind a small Hono or Fastify service.

**Fit:** total control over the sync endpoints, auth, and validation. No vendor semantics to work around. Better if the sync protocol needs to diverge from what a BaaS assumes.

**Costs:** auth is now yours to build and keep secure — sessions, refresh rotation, reset flows, rate limiting. That is a large, security-sensitive surface for a scope that is otherwise domain logic. Plus a service to deploy, monitor, and keep patched.

### Decision

**Supabase (Postgres + Auth + forced RLS on every plan table), decided by ADR-16.** The backend here is genuinely thin — two idempotent sync operations over an append-only table — and almost all remaining server work is authentication, which is exactly what the BaaS supplies. Option B buys control this protocol does not need. Plan isolation is enforced server-side with forced RLS, not merely with client membership checks.

Note the tradeoff honestly: it trades a build-it-yourself auth risk for a vendor-migration risk. Given the alternative is hand-rolling auth, the vendor risk is the smaller one.

### Considered and rejected

- **PowerSync or ElectricSQL** — turnkey Postgres-to-SQLite sync. Genuinely capable, but both impose their own conflict semantics, and REQ-SE-2's field-level LWW plus REQ-SE-4's superseded-write visibility are specific enough that fighting the framework is likely. Reconsider if hand-rolled sync stalls.
- **Isar with built-in sync, or `drift`'s network extensions** — now that the platform is Flutter, these are the on-platform equivalents to consider. Both default to row-level rather than field-level resolution, so field-level LWW plus superseded-write visibility would mean working against the grain either way. `drift` is retained for local persistence per section 1.1; its sync helpers are not used.
- **Firebase** — Firestore's document model fits the relational shape of variance and change-log queries poorly, and pushes toward denormalisation that conflicts with never storing derived values.

---

## 4. Data model

Integer money throughout, per REQ-GEN-1. Percentages and multipliers as **basis points** (`10000 = 100% = 1.0`) for the same reason — no floats anywhere, including configuration.

### 4.1 Identity and access

```sql
users (
  id            uuid pk,          -- from auth provider
  email         text unique not null,
  display_name  text not null,
  created_at    timestamptz not null
)

plans (
  id                   uuid pk,          -- UUIDv7, client-generated
  creator_user_id      uuid not null references users,
  wedding_date         date not null,            -- REQ-BS-1
  total_budget_cents   bigint not null check (total_budget_cents > 0),
  guest_cap            integer not null check (guest_cap >= 0),
  region_code          text not null,                    -- with ruleset_version: composite FK to regions
  ceremony_type        text check (ceremony_type in
                         ('church','civil','other_religious','garden_beach_officiant','other')),
  venue_type           text check (venue_type in
                         ('hotel','garden','beach_resort','restaurant','events_place','other')),
  reminder_enabled     boolean not null default true,
  reminder_window_days integer not null default 7 check (reminder_window_days >= 0),
  reminder_days_before jsonb not null default '[7,1]', -- distinct nonnegative integer offsets
  reminder_overdue     boolean not null default true,
  ruleset_version      text not null,            -- pinned, REQ-AE-3
  driving_rsvp_status  text not null,            -- REQ-GM-1 clause 6
  is_active            boolean not null default true,   -- REQ-PLT-3
  setup_completed_at   timestamptz,
  created_at           timestamptz not null,
  deleted_at           timestamptz,              -- soft delete, creator only
  foreign key (ruleset_version, region_code) references regions (ruleset_version, code)
)
-- Null ceremony_type or venue_type = "Not sure yet"; these optional fields
-- select fee-card hint copy only. They do not create entries or decide any of
-- the six mandatory hidden-fee prompts (REQ-BS-1, REQ-HF-1, ADR-42).
-- Reminder preferences sync per plan; delivered notifications stay device-local.

plan_member_aliases (
  plan_member_id uuid pk,        -- stable attribution alias, never reused
  plan_id   uuid not null references plans,
  user_id   uuid references users, -- removable alias-to-account mapping
  unique (plan_id, plan_member_id)
)
plan_members (                  -- only LIVE memberships grant plan access
  plan_id        uuid references plans,
  user_id        uuid references users,
  plan_member_id uuid not null references plan_member_aliases(plan_member_id),
  role           text not null check (role in ('creator','partner')),
  joined_at      timestamptz not null,
  primary key (plan_id, user_id)
)
-- REQ-SE-1 clause 1: at most two active plan_members rows per plan, enforced by trigger.
-- REQ-PLT-3: at most one plan per user where is_active and role = 'creator'.

invites (
  id              uuid pk,
  plan_id         uuid not null references plans,
  inviter_user_id uuid not null references users,
  token_hash      text not null,     -- hash only, never the raw token
  expires_at      timestamptz not null,   -- issued_at + 7 days, REQ-SE-1
  accepted_at     timestamptz,
  revoked_at      timestamptz
)

lifecycle_confirmations (          -- REQ-SE-5 (ownership transfer only)
  id           uuid pk,
  plan_id      uuid not null references plans,
  action       text not null check (action = 'transfer_ownership'),
  initiated_by uuid not null references users,
  target_user  uuid references users,
  confirmed_by jsonb not null default '[]',   -- user ids
  expires_at   timestamptz not null,
  completed_at timestamptz
)
-- Amended per Decisions 1 & 2: partner removal is NO LONGER a two-party
-- action, so 'remove_partner' is removed from this table. Defensive
-- removal (REQ-SE-6) is a direct, immediate delete of the target's
-- plan_members row plus a change_log entry — it has no pending state.
```

**Attribution and account deletion (ADR-51).** The immutable log references `plan_member_aliases.plan_member_id`, not `users`. Keep the stable alias when an account is deleted, sever its removable `user_id` mapping and remove the separate live membership; history then renders “Former member” without editing a log row. RLS requires a live `plan_members` row and matching authenticated user; aliases alone grant no access and do not count toward the two-person active-member cap. Defensive removal deletes the target's live membership without erasing its attribution alias. Validate alias plan/user correspondence on every accepted write. `plans.creator_user_id`, `invites.inviter_user_id`, `lifecycle_confirmations.initiated_by/target_user/confirmed_by`, `hidden_fee_prompts.dismissed_by` and any other user FKs require an explicit delete-safe retention/de-identification migration before account deletion; do **not** rely on an implicit cascade, dangling FK, or immutable-log rewrite. SCR-18 exposes the technically required account deletion request/confirmation path (SEC-33/34), but execution on a shared plan and the fate of identifiable shared records remain **blocked pending counsel under OQ-01/ADR-26**. No claimed legal erasure outcome or invented automatic resolution.

`lifecycle_confirmations` exists because ownership transfer (REQ-SE-5 clauses 4, 6, 7) needs a pending two-party state that can expire. Without a row to hold it, "pending" has nowhere to live. **Defensive partner removal does not use this table:** per REQ-SE-6 it is immediate and one-sided, executed as a direct delete of the removed partner's `plan_members` row (below) with an attributed `change_log` entry — there is no pending confirmation to store.

### 4.2 Ruleset configuration

**Source of truth in v1: a versioned JSON asset bundled in the app binary (ADR-15, REQ-AE-1 clause 3), validated at app load.** The SQL-shaped relations below describe the data shape and keys for implementation and version pinning; they are **not** a remote-authoring or publish-time database workflow, nor a substitute source of ruleset values. Published/bundled versions remain immutable so REQ-AE-3 clause 2 holds. Changing the asset requires an app release; remote ruleset delivery is still OQ-08, not a v1 feature. Buffer is the fixed destination for rounding remainder (REQ-AE-1 clause 6), not a per-plan setting.

```sql
rulesets (
  version      text pk,
  published_at timestamptz not null,
  is_active    boolean not null
)

allocation_categories (
  code       text pk,        -- catering_venue, photo_video, attire_styling,
  name       text not null,  -- coordination, entourage_misc, buffer
  sort_order integer not null
)

ruleset_baselines (                         -- REQ-AE-1
  ruleset_version text references rulesets,
  category_code   text references allocation_categories,
  baseline_bp     integer not null,         -- 4000 = 40%
  primary key (ruleset_version, category_code)
)
-- REQ-AE-1 clause 4: sum(baseline_bp) = 10000 per version, validated at app load.

cost_tiers (                                -- REQ-BS-4
  ruleset_version text references rulesets,
  tier_code       text,                     -- metro | provincial | destination
  cost_index_bp   integer not null,         -- 10000 | 8500 | 12000
  primary key (ruleset_version, tier_code)
)

regions (
  ruleset_version text references rulesets,
  code            text,
  name            text not null,
  tier_code       text not null,
  is_destination  boolean not null,          -- REQ-HF-3 defaulting
  primary key (ruleset_version, code),
  foreign key (ruleset_version, tier_code) references cost_tiers (ruleset_version, tier_code)
)

region_category_skew (                       -- REQ-AE-2 clauses 7, 8
  ruleset_version text,
  region_code     text,
  category_code   text,
  skew_bp         integer not null default 10000,   -- 1.0, no-op
  primary key (ruleset_version, region_code, category_code),
  foreign key (ruleset_version, region_code) references regions (ruleset_version, code)
)

reference_costs (                            -- REQ-AE-2 clause 2
  ruleset_version    text,
  tier_code          text,
  per_head_cents     bigint not null,
  fixed_base_cents   bigint not null,
  primary key (ruleset_version, tier_code),
  foreign key (ruleset_version, tier_code) references cost_tiers (ruleset_version, tier_code)
)
```

The bundled taxonomy maps Bohol to **Provincial (0.85 / 8500 bp)** with `is_destination = true`; Boracay/Aklan, Palawan, and Siargao are Destination (1.20 / 12000 bp) with the same flag. NCR is Metro (1.00 / 10000 bp) with the flag false. The **flag**, not the tier, defaults the OOT prompt to enabled (REQ-HF-3); neither creates an amount. The cost-tier index affects cost expectations and suggested rates, **never allocation shares** (REQ-AE-2). `reference_costs` is the shape for the still-missing benchmark noted in requirements §13 item 1. Values are not yet supplied; budget adequacy renders unavailable until they are, rather than implying a computed result.

### 4.3 Allocations

```sql
plan_allocations (
  plan_id           uuid references plans,
  category_code     text references allocation_categories,
  override_cents    bigint,              -- null unless overridden, REQ-AE-5
  primary key (plan_id, category_code)
)
```

Only `override_cents` is user input and flows through the log. `engine_cents`, `allocator_kind`, `allocator_version` and `explanation` are a **local, read-time** `BudgetAllocator` result from the pinned bundled ruleset plus synced inputs, never columns, log rows, or server values. Display engine and override together (REQ-AE-5 clause 2); revert writes null override and immediately reveals the recomputed engine amount (clause 5). Any optional device-local cache must be disposable, invalidated by input/ruleset changes and never synced.

The result still includes allocator kind/version and a traceable explanation; see §5.3.

### 4.4 Ledger

```sql
ledger_entries (
  id                 uuid pk,
  plan_id            uuid not null references plans,
  category_code      text not null references allocation_categories,
  entry_type         text not null,     -- 'standard' or a hidden-fee subtype
  supplier_name      text not null,
  estimated_cents    bigint check (estimated_cents >= 0), -- flat input; null for derived per-head
  actual_cents       bigint check (actual_cents >= 0),      -- nullable
  pricing_mode       text not null check (pricing_mode in ('per_head','flat')),
  per_head_rate_cents bigint,           -- required when per_head
  manually_valued    boolean not null default false,        -- REQ-GM-2 clause 5
  notes              text,
  created_at         timestamptz not null,
  deleted_at         timestamptz
)
-- entry_type in ('standard','crew_meals','oot_fees','church_aircon',
--                'corkage','overtime','venue_power')
-- NOT stored: deposit_paid, entry due_date, payment_status, balance_due,
-- effective_amount. These are derived or separately recorded below.

payment_schedule_items (                     -- REQ-LG-7; explicit schedule only
  id            uuid pk,
  entry_id      uuid not null references ledger_entries,
  kind          text not null check (kind in
                  ('reservation','downpayment','installment','balance','custom')),
  label         text not null,
  due_date      date not null,
  amount_cents  bigint not null check (amount_cents > 0),
  sort_order    integer not null,
  deleted_at    timestamptz
)

payments (                                  -- REQ-LG-8; records, not payment rails
  id                 uuid pk,
  entry_id           uuid not null references ledger_entries,
  schedule_item_id   uuid references payment_schedule_items, -- nullable
  kind               text not null check (kind in ('payment','refund')),
  amount_cents       bigint not null check (amount_cents > 0),
  paid_on            date not null,
  method             text not null check (method in
                       ('cash','bank_transfer','gcash','maya','check','other')),
  paid_by_pledge_id  uuid references pledges,       -- null = couple paid
  note               text,
  deleted_at         timestamptz
)
-- Validate schedule_item_id belongs to entry_id; sponsor payments reference
-- an active item pledge in the same plan. The pledges FK is declared forward
-- here; resolve table creation order in the initial schema, not a migration.

fee_components (
  id             uuid pk,
  entry_id       uuid not null references ledger_entries,
  component_type text not null,
  label          text,              -- supplier or item name
  quantity       integer,           -- crew headcount, overtime hours
  unit_rate_cents bigint,           -- per-meal rate, hourly rate
  amount_cents   bigint,            -- for flat components
  sort_order     integer not null,
  deleted_at     timestamptz
)
```

Each hidden fee remains a `ledger_entries` line with a category from the six-category allocation taxonomy (REQ-LG-1 clause 1); `entry_type` is a separate subtype, **not** a seventh allocation category. The fixed subtype-to-category mapping is: crew meals → Catering & Venue; OOT fees → Coordination; church aircon → Catering & Venue; corkage → Catering & Venue; overtime → Coordination; venue power → Catering & Venue. The fee editor shows the mapped category read-only (REQ-HF-2 clause 9). Totals and variance accrue to that category while the fee remains its own attributable ledger line (REQ-HF-2 clause 7). No category is inferred from a component amount.

**Schedule and allocation (ADR-36, REQ-LG-5/7/8).** Without live schedule rows, display a single virtual undated balance for the effective amount. With explicit rows, a virtual undated residual covers `max(0, effective − Σ live scheduled amounts)`; refuse an edit that makes the scheduled sum exceed effective, showing a schedule-over-total validation error (including on actual-cost edits) without deleting payment history. Sort explicit obligations by `(due_date, sort_order, id)`, virtual residual last. Allocate the **aggregate net paid** to obligations in that chronological order; `schedule_item_id` records attribution only and does not override allocation order (REQ-LG-5 clause 8). Refunds reverse net paid and can reopen obligations; recalculate from all live events rather than persisting allocations. Cap allocated coverage at effective amount, retaining any overpayment with a warning, never creating phantom obligations. Effective amount uses actual when present (including discounts); schedule rows do not override it. A dated obligation fully covered is `paid`; if outstanding, `overdue` when due before the device-local today, `due soon` when due within `reminder_window_days` inclusive, `partially paid` when > 0 is allocated and neither urgent condition holds, otherwise pending. Show a partial-coverage sublabel even for an urgent item. An entry is `paid` if balance is zero, otherwise `overdue` if any item is overdue, `due soon` if any is due soon, otherwise `pending`, with partial indicator independent of status. No virtual undated obligation becomes overdue or due soon. These are derived local reads, not ADR-21 conflict fields.

**Local reminders (REQ-LG-9, ADR-41).** Each device schedules from its own local projection and plan `reminder_enabled`, `reminder_window_days` (default 7 for Due soon, independent of delivery), `reminder_days_before` (default 7 and 1) and `reminder_overdue` (default on). Notify only for live dated items with remaining amount, at the configured day offsets and once after overdue; dedupe by `(plan_id, schedule_item_id, offset_or_overdue)` and cancel/reschedule on payment, refund, date change, row deletion, configuration change or sync. The Due soon list/status still uses the configured window even when notifications are off. Never notify for undated virtual balances or paid items. With reminders off or OS permission denied, budgeting still works offline. Default lock-screen text is generic, e.g. “A supplier payment is due in 7 days”; no supplier, amount, sponsor or giver names. This is not partner-edit push or funds transfer.

One generic `fee_components` table covers all six hidden-fee shapes from REQ-HF-2 rather than six subtype tables:

| Subtype | Mapping |
|---|---|
| Crew meals | one row per supplier; `quantity` = crew headcount, `unit_rate_cents` = per-meal rate |
| OOT fees | three rows per supplier: `travel`, `lodging`, `per_diem`, each with `amount_cents` |
| Church aircon | single row, `amount_cents` |
| Corkage | one row per item type (`cake`, `wine`, `liquor`, `lechon`, `other`) |
| Overtime | one row per supplier; `quantity` = projected hours, `unit_rate_cents` = hourly rate |
| Venue power | three rows: `generator`, `surcharge`, `electrical` |

Component total is `quantity × unit_rate_cents` when both are present, otherwise `amount_cents`. Entry total is the sum. These three component values travel as a full-snapshot LWW group (§2.2); one row cannot combine quantity from one editor and rate from another. This trades some compile-time type safety for schema stability, and it is cheap to reverse in either direction because the change is additive.

**Post-merge invariant gate (ADR-45).** Validate on every replay/read, including restored entities; do not emit automatic repair writes. The gate covers: REQ-LG-1 (category in the six-category taxonomy, nonblank supplier, nonnegative flat estimate/actual, 2,000-character notes limit and valid mode/rate); REQ-GM-2 clause 4–5 (per-head effective amount equals driving count × rate unless explicitly `manually_valued` by actual, with no synced derived estimate); REQ-HF-2 (required subtype-specific component shapes, complete quantity/rate pairs **or** flat amounts, nonnegative components, subtype-specific sums and fixed subtype→category mapping); plan budget > 0, cap/crew headcount ≥ 0, valid region/pinned ruleset and RSVP/tier axes, plus all six hidden-fee decisions before setup completion; scheduled sum ≤ live effective entry amount with valid same-entry schedule/payment attribution and positive dated monetary events; valid sponsor role/sub-role, positive receipt, receipt-backed pledge status, withdrawn precedence, in-kind shared cap and live linked entry; direct supplier payment↔receipt pair present, unique, same pledge/plan and equal positive amount; gifts positive with allowed source; and per-plan overrides ≥ 0 with valid category. **Over-allocation, overpayment and zero eligible support are warnings/derived values, not invalidity** (ADR-36–42). Parent tombstones exclude dependent rows from all live totals (gross/net, expected/exposure, deposits/balances, variance/buffer, gifts/net-after-gifts and reconciliation) regardless of child validity. Invalid dependent contributions are excluded deterministically from live financial aggregates and their raw preserved fields remain inspectable; valid independent rows stay visible. SCR-19 state 5 names entity/constraint and links to deliberate user correction; both devices derive the same interpretation from the same log. Do not clamp, clear, invent a missing pair, or silently count an invalid amount. Device-local date affects only due-status/reminder presentation (REQ-OF-4), not this gate.

```sql
hidden_fee_prompts (                       -- REQ-HF-1
  plan_id       uuid references plans,
  fee_type      text,
  state         text not null,   -- 'prompted_unfilled' | 'filled' | 'dismissed'
  dismissed_at  timestamptz,
  dismissed_by  uuid references users,
  primary key (plan_id, fee_type)
)
```

A separate table because REQ-HF-1 clause 2 requires `prompted_unfilled` to be distinguishable from a filled zero. Absence of a ledger entry cannot express that, and clause 6 needs to name untouched categories to block setup completion. Clause 4 needs the dismissing partner and timestamp. Optional `plans.ceremony_type`/`venue_type` select **copy only**: civil can hint that church aircon usually does not apply; garden/beach context can hint that venue power is often needed. “Not sure yet” (null) retains neutral hints. No choice fills, dismisses, waives, or assigns an amount to any of the six prompts (ADR-42).

### 4.5 Guests and pledges

```sql
guests (
  id            uuid pk,
  plan_id       uuid not null references plans,
  name          text not null,
  rsvp_status   text not null check (rsvp_status in ('confirmed','invited','tentative')),
  priority_tier text not null default 'tier_2'
                check (priority_tier in ('tier_1','tier_2')),   -- REQ-GM-1 clause 3
  created_at    timestamptz not null,
  deleted_at    timestamptz
)

crew_headcount (            -- REQ-GM-4, deliberately not a guest
  plan_id   uuid pk references plans,
  headcount integer not null default 0
)

pledges (
  id                 uuid pk,
  plan_id            uuid not null references plans,
  sponsor_name       text not null,
  sponsor_role       text not null check (sponsor_role in
                       ('ninong','ninang','family','friend','secondary_sponsor','other')),
  secondary_subrole  text check (secondary_subrole in ('candle','veil','cord')),
  check ((sponsor_role = 'secondary_sponsor' and secondary_subrole is not null)
      or (sponsor_role <> 'secondary_sponsor' and secondary_subrole is null)),
  pledge_type        text not null check (pledge_type in ('cash','item')),
  item_description   text,
  value_cents        bigint not null check (value_cents >= 0),
  status             text not null check (status in ('tentative','confirmed','withdrawn')),
  -- "received" needs >= 1 live receipt AND sum(receipts) >= value; never stored.
  linked_category_code text references allocation_categories,
  linked_entry_id    uuid references ledger_entries,
  created_at         timestamptz not null,
  deleted_at         timestamptz
)
pledge_receipts (                           -- REQ-PL-6; independent insert-only events
  id            uuid pk,
  pledge_id     uuid not null references pledges,
  amount_cents  bigint not null check (amount_cents > 0),
  received_on   date not null,
  note          text,
  payment_id    uuid unique references payments,       -- null for cash receipt
  deleted_at    timestamptz
)
-- For direct supplier payments, payment_id is unique and non-null, its
-- payment.paid_by_pledge_id equals pledge_id, and amounts match exactly.
-- One receipt per direct payment, created atomically in one local transaction.
-- A cash receipt has payment_id null. Tombstones propagate offline deletion.

gifts_received (                            -- REQ-GF-1; third-party names optional
  id            uuid pk,
  plan_id       uuid not null references plans,
  source        text not null check (source in
                  ('sobre','money_dance','cash','bank_transfer','other')),
  amount_cents  bigint not null check (amount_cents > 0),
  received_on   date not null,
  giver_name    text,
  note          text,
  deleted_at    timestamptz
)
```

Two orthogonal columns on `guests`, per REQ-GM-1 clauses 1, 2, and 5. `crew_headcount` is a separate table specifically so no query can accidentally sweep crew into a guest count.

**Pledge accounting (ADR-37–39, REQ-PL-2–7).** Every receipt is a distinct UUID event; two offline receipts do not overwrite a cumulative `received` amount. A live pledge derives `received` only when **at least one** live receipt exists and `Σ live receipt amounts ≥ value_cents`; otherwise it keeps its explicitly selected tentative/confirmed state. `withdrawn` is an explicit display-status override even after full receipt: it is absent from expected remaining and exposure, but historical live receipts still reduce net. Withdrawal never substitutes for a refund/correction. For each non-withdrawn pledge, expected remaining = `max(0, value − Σ receipts)` if tentative or confirmed; confirmed exposure is the same remainder only when confirmed. Net support uses **recorded live receipts**, not promises or the full face value, including partial receipts, and must not double-count direct supplier payments. For a cash pledge, use received receipts; for item pledges linked to a live entry, **all** such pledges share a single cap equal to that entry's effective amount, consumed by eligible receipts in `(received_on, receipt_id)` order (ADR-39), and never separately capped per pledge. The entry link wins if both entry and category links exist. An item with only a category link uses its receipt-backed value, not an inferred category discount. If a linked entry is tombstoned, exclude its item support from live net and flag the preserved pledge/receipt/payment history as orphaned on reconciliation rather than silently reassigning the link. A sponsor's direct supplier payment creates both a `payments` row with `paid_by_pledge_id` and a `pledge_receipts` row whose unique `payment_id` references it, amounts equal, in **one offline local transaction** (both rows and their change-log writes enqueue together, and the server accepts/rejects the pair atomically as a unit even if a larger sync batch is interrupted). Validate same pledge/plan/linked entry and equal amount; replay the pair idempotently, and if a second offline writer tries to bind a different receipt to the same payment, count at most one pair and show a reconciliation conflict. The receipt reduces net once; the payment reduces the linked entry balance once. If supplier refunds sponsor-paid coverage, correct/tombstone its linked receipt in the same local transaction so support is not counted after return. A cash gift has no pledge link and never masquerades as a receipt. Gross remains the full entry cost; no amount in the ledger or pledge is mutated by a derived net figure. Net may be negative (ADR-37).

**Gifts and reconciliation (REQ-GF-1/2).** Sum live gift rows independently. `net_after_gifts = net_out_of_pocket − gifts_total` is an additional figure once gifts exist; never change the meaning of net or legacy fixture outputs. Reconciliation compares gifts total, plan remaining supplier balances, net received pledge support and any orphan in-kind support, with explicit detail and a difference (`gifts_total − remaining_balances`, signed). It does not create a payment or automatically apply gifts to balances: recording how a gift was spent requires a separate payment event. Both partners can record these offline, with UUID identity, soft deletion, change-log attribution and server-assigned ordering per ADR-21.

### 4.6 Change log and sync state

```sql
change_log (
  id            uuid pk,          -- client-generated; idempotency key
  plan_id       uuid not null references plans,
  entity_type   text not null,
  entity_id     uuid not null,
  field_name    text not null,    -- ordinary field, group name, or '$create'
  change_group_id uuid,          -- required for compound full-snapshot events
  schema_version integer not null,
  old_value       jsonb,
  new_value       jsonb,
  server_ts       bigint,          -- assigned by server at sync (D1); null until synced
  device_monotonic bigint not null, -- per-device increasing counter, tiebreaker
  device_id       uuid not null,
  plan_member_id  uuid not null references plan_member_aliases(plan_member_id),
  created_at      timestamptz not null
)
-- Append-only. No UPDATE, no DELETE, enforced by permission and trigger.
-- Ordering key: (server_ts, device_monotonic, device_id) per Decision D1.
-- server_ts is the authority; device_monotonic/device_id only break ties or
-- order a device's own not-yet-synced rows locally.

-- Projection index: newest write per field
create index change_log_field_idx
  on change_log (plan_id, entity_type, entity_id, field_name,
                 server_ts desc, device_monotonic desc, device_id desc);

sync_state (                     -- local only, never synced
  device_id       uuid,
  plan_id         uuid,
  last_pushed_server_ts  bigint,
  last_pulled_server_ts  bigint,
  device_monotonic       bigint not null default 0,
  primary key (device_id, plan_id)
)
```

`superseded` and `conflict` are deliberately not columns. A row is superseded when a higher-ordered accepted ordinary field/group write controls its value, or a tombstone suppresses its visibility; a stale-write conflict is detected by comparing typed `old_value` with the effective pre-write field/group snapshot in server order (§2.1). Compute both at read time without rewriting immutable rows. `new_value` on `$create` is the full validated initial snapshot; group events contain all group members and one `change_group_id`, not separate independently winning field rows. `schema_version` identifies the event shape independently of envelope `protocol_version`; unknown additive events survive local storage and later projection rebuild.

---

## 5. Allocation engine design

### 5.1 A pure function

```dart
abstract interface class BudgetAllocator {
  String get kind;             // returned with local explanation; never synced
  String get version;

  AllocationResult allocate(AllocationInput input, Ruleset ruleset);
}

class AllocationInput {
  final int totalBudgetCents;
  final String regionCode;
  final int drivingGuestCount;
  const AllocationInput(this.totalBudgetCents, this.regionCode,
      this.drivingGuestCount);
}

class CategoryAllocation {
  final String categoryCode;
  final int amountCents;
  final Explanation explanation; // REQ-AE-4, serialised as opaque JSON
  const CategoryAllocation(this.categoryCode, this.amountCents, this.explanation);
}

class AllocationResult {
  final List<CategoryAllocation> categories;
  final int? expectedTotalCostCents; // null while benchmarks are unavailable
  final List<RateSuggestion> suggestions;
  const AllocationResult(this.categories, this.expectedTotalCostCents, this.suggestions);
}
```

No I/O, no clock, no randomness, no network. The ruleset is passed in, already loaded. This is what makes REQ-AE-1 clause 1 testable: call it twice, compare, and the determinism criterion is a unit test rather than a manual observation.

### 5.2 Rule-based implementation

```
1. Load baselines for the pinned ruleset version.
2. Load region → tier, cost index, and per-category skew.
3. Apply skew:      weighted_bp[i] = baseline_bp[i] × skew_bp[i] / 10000
4. Renormalise:     share_bp[i]    = weighted_bp[i] × 10000 / Σ weighted_bp
5. Distribute:      amount[i]      = total_cents × share_bp[i] / 10000   (integer floor)
6. Remainder:       buffer        += total_cents − Σ amount[i]           REQ-AE-1 clause 6
7. Expected cost:   fixed_base + (per_head × guest_count), × cost_index  REQ-AE-2 clause 2
8. Suggestions:     reference rates × cost_index                         REQ-AE-2 clause 5
9. Explanation per category: rule id, baseline_bp, skew_bp, share_bp, amount
```

Integer arithmetic throughout. Step 6 makes the total exact rather than approximately exact, which is what REQ-AE-1 clause 5 demands.

Steps 3 and 4 are where REQ-AE-2's correction lives. With every `skew_bp` at its 10000 default, step 4 returns the baselines unchanged — the uniform cost index provably cannot alter shares. The index is used only in steps 7 and 8, where it affects cost expectation and suggested rates. Skew is the mechanism that genuinely shifts shares, and it is inert until real per-category data exists.

### 5.3 The swap seam

The interface permits a future allocator implementation without changing the **override schema**; v1 does not silently make nondeterministic AI output shared authoritative state:

1. **The interface is the boundary.** A future `AiAssistedAllocator` implements the same `BudgetAllocator`. Callers are unaffected.
2. **Only manual overrides persist and sync.** `plan_allocations` stores `override_cents` alone; engine amounts and explanations are locally recomputed from pinned inputs and ruleset, never emitted as log rows. A future nondeterministic allocator would need a separate explicit decision and provenance protocol, not a silent v1 schema swap.
3. **`explanation` is a local result payload.** A rule-based allocator returns rule ids and basis points; the UI renders that trace alongside the amount without a synced JSONB column.
4. **`allocator_kind` and `allocator_version` travel with the local result.** Both identify the producing implementation for explanation, not persisted shared state; rollback reruns the pinned rule-based implementation.
5. **`ruleset_version` stays pinned.** The rule-based v1 allocator always uses the pinned configuration, so REQ-AE-3 clause 2 holds. Any future AI allocator must establish a separate deterministic shared-output/provenance policy before replacing this contract.

The constraint an AI allocator must respect is REQ-AE-4 clause 4: no figure may display without a traceable explanation. That is a contract on the `Explanation` payload, not on the schema. Both types of allocator must fill it.

---

## 6. AI-phase seams

Architecture only. None of this is built in v1, per REQ-AI-1 through REQ-AI-5.

### 6.1 OCR contract parsing → REQ-AI-1

```
image → OcrExtractor → DraftEntry[] → user review → existing repository write
```

**The seam is a draft producer, never a writer.** OCR emits `DraftEntry` values that must pass through the same validation and the same repository as manual entry, so REQ-LG-1's field rules apply identically and every resulting write still lands in the change log with a real actor.

```ts
interface DraftSource {
  readonly kind: 'manual' | 'ocr' | string;
  produce(input: unknown): Promise<DraftEntry[]>;
}
```

Storage: a local-only `entry_drafts` table that never syncs. Drafts are not plan data until confirmed. This keeps unconfirmed machine output out of shared state and out of every total.

### 6.2 On-device categorisation → REQ-AI-2

```ts
interface CategorySuggester {
  suggest(partial: PartialEntry): Promise<Array<{ categoryCode: string; confidence: number }>>;
}
```

v1 ships a null implementation returning `[]`. Call site is the entry editor, and the return value **only reorders the category picker**. It never sets `category_code`, because REQ-LG-1 clause 1 requires user selection from the fixed taxonomy.

The model file sits in `platform/ml/`, loaded lazily, absent in v1 builds. No network, no plan data leaving the device.

### 6.3 Cloud AI reasoning → REQ-AI-3

```ts
interface PlanAdvisor {
  advise(snapshot: ReadOnlyPlanSnapshot): Promise<Advisory[]>;
}
```

Three hard constraints:

1. **Read-only input.** The advisor receives an immutable snapshot and has no repository access.
2. **Writes land elsewhere.** Advisories persist to a separate `advisories` table, never into `plan_allocations`, `ledger_entries`, or `pledges`. Model output cannot corrupt budget data or move a total.
3. **Outside the sync path.** Advisory generation never blocks a write, a sync, or a dashboard render. Failure is invisible to budgeting.

**Privacy, flagged deliberately.** A plan snapshot contains sponsor names, guest names, a wedding date, and a location. Sending it to a third-party model is personal-data egress, and personal data of Philippine residents is covered by the Data Privacy Act of 2012. This needs explicit opt-in consent, a documented processor, and ideally field-level redaction of names before egress. It is a legal question as much as an architectural one, and it should be settled before the AI phase begins rather than during it.

### 6.4 Payment rails → REQ-AI-4 (post-launch, not v1)

In v1, `payments` and `pledge_receipts` are manual **records of external events**, never instructions to move money; `method` records cash, bank transfer, GCash, Maya, check or other. REQ-AI-4 is a separate post-launch payment-rail phase per ADR-28. A future integration can use a separate `payment_transactions` reconciliation table and create an idempotent `payments` event **only after settlement**, using the existing UUID row and atomic receipt link for sponsor-direct settlement. Do not update a cumulative `deposit_paid_cents` field: it does not exist. Ledger payment events remain the system of record for recorded coverage; rail transactions are the external settlement record. No v1 notification or schedule event authorises a payment.

---

## 7. Decisions that are expensive to reverse

Ordered by cost.

### 7.1 Platform — resolved as Flutter

**Cost to reverse: total rewrite of the client.** Everything in section 1, all UI, all local persistence wiring. Sections 2 through 6 survive, which is roughly the sync protocol, schema, and domain logic — real value, but the client is the bulk of the work.

**Resolved: Flutter + SQLite/`drift` (section 0).** No longer a live decision. Recorded here only so the reversal cost stays on the ledger: switching frameworks after code exists is a client rewrite. The `domain/` purity rule in section 1.2 is the hedge — the allocation engine, calculations, and validation are plain Dart with no Flutter import, so that layer at least would port.

### 7.2 Change log as the sync unit

**Cost to reverse: high.** Moving to row-based sync or CRDTs means a new schema, a new protocol, and a migration of existing log data into whatever replaces it.

Confidence is high that this is right, because REQ-SE-2 and REQ-SE-4 together essentially describe it. ADR-43–45 add read-time stale-write disclosure, two atomic full-snapshot LWW groups and a non-writing invariant gate within GIV-04. A hypothetical move to CRDTs is outside v1 and would require a new decision, schema and protocol.

### 7.3 Client-generated UUIDv7 keys

**Cost to reverse: very high, and effectively one-way.** Switching to server-assigned IDs breaks offline creation outright. Switching *from* server IDs to client IDs means rewriting every foreign key in existing data.

Low risk, because offline-first leaves no real alternative. Worth stating explicitly so nobody "simplifies" it to autoincrement later.

### 7.4 Soft deletes everywhere

**Cost to reverse: high.** Retrofitting tombstones after shipping hard deletes means every already-deleted row is unrecoverable and every peer may hold resurrected copies. Retrofitting requires reconciling divergent devices with no record of what was removed. ADR-47 adds full-snapshot creates and tombstone precedence over later ordinary edits; only explicit Restore clears the gate.

Non-negotiable for offline sync. The cost is that every query must filter `deleted_at is null`, and one forgotten filter silently inflates a total. Mitigate with repository-level views rather than relying on discipline at each call site.

### 7.5 Server-assigned ordering timestamp instead of device time (D1)

**Cost to reverse: moderate.** The ordering key `(server_ts, device_monotonic, device_id)` lives in a column on every log row and in every comparison. Changing the authority again means a migration plus rewriting every comparison, and historical ordering cannot be reconstructed for data written under a different scheme.

Decided (D1): the server is the ordering authority; device wall clocks never decide a conflict. This is stronger than the earlier hybrid-logical-clock design, which still folded the device wall clock into the ordering value. Do it from the first schema so no migration is needed.

### 7.6 Derived values never persisted

**Cost to reverse: moderate, and asymmetric.** Adding a persisted cache later is straightforward. Removing one after shipping means finding every consumer that trusted it and every sync conflict it caused.

Start strict. REQ-LG-5 clause 6 requires it for payment status regardless. ADR-46 extends this to per-head estimates and engine allocations/explanations: only source inputs and overrides sync.

### 7.7 Supabase as the backend

**Cost to reverse: moderate.** The Postgres schema and all data are portable. Auth is not — migrating identities means a password reset for every user. With a small user base that is an inconvenience; at scale it is a migration project.

Keep application code free of Supabase-specific calls outside `sync/transport/` and the auth adapter, so a swap touches two directories.

### 7.8 Generic `fee_components` table

**Cost to reverse: low.** Splitting into six typed tables later is a mechanical migration, and the reverse is equally mechanical. Called out only to note it is *not* expensive, so it should not attract early debate.

---

## 8. Open items carried into implementation

1. **Reference cost values.** The `reference_costs` shape is defined but benchmarks are not populated in the bundled ruleset, so budget adequacy (REQ-AE-2 clause 3) cannot render yet. Every other allocation requirement can. This is now the only item blocking a specific feature.
2. **RLS policy test suite.** Supabase is decided (ADR-16); forced RLS plan isolation is the security boundary between couples. It needs adversarial tests, not review by inspection.

*Resolved since first draft: platform (Flutter + SQLite/`drift`, section 0), monetary representation (Dart `int`, section 1.5), ruleset config management (bundled JSON asset validated at load, ADR-15), backend (Supabase, ADR-16), local database encryption (SQLCipher with key held in Keychain/Keystore, no cloud auto-backup, ADR-17), driving RSVP default (`invited`), and ownership-transfer confirmation expiry (7 days).*
