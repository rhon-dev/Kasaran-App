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
  clock/                 hybrid logical clock (section 2.2)
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
  budget → date → guest-cap → region → hidden-fees
  hidden-fees blocks completion until all six touched (REQ-HF-1 clause 6)
(app)                         tabs
  dashboard                   gross, net, exposure, buffer, adequacy, outstanding fees
  ledger                      list, filter by derived status
  guests                      RSVP × tier matrix
  pledges                     list, status transitions
  more                        change log, allocations, settings, plan lifecycle
modals
  entry-editor, fee-editor, pledge-editor, guest-editor,
  what-if-preview, allocation-override, explain-figure
```

The setup wizard is a distinct stack rather than tabs because REQ-HF-1 clause 6 requires it to gate completion. Tabs would let a user escape the gate.

### 1.4 Derived values are never stored

REQ-LG-5 clause 6 forbids persisting payment status. The same reasoning extends to every computed figure: two devices that disagree would generate a sync conflict on a value that is not actually user input.

**Computed on read, never in a table:** payment status, balance due, gross event total, net out-of-pocket, outstanding pledge exposure, buffer remaining, category variance, per-head derived amounts, budget adequacy.

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
write path:   user edit → one change_log row per changed field
                        → apply to projection table
                        → enqueue log row for push

read path:    projection tables (fast queries)

sync:         push local log rows, pull remote log rows,
              apply in clock order, last write per field wins
```

Consequences that fall out for free:

- **REQ-SE-2 clause 1 and 2** — different fields and different entries never collide, because log rows are keyed by `(entity_type, entity_id, field_name)`.
- **REQ-SE-2 clause 5** — a losing write is never discarded; it is already in the log, marked superseded.
- **REQ-SE-4 clause 3** — superseded writes are visible with their values intact.
- **REQ-SE-3 clause 1** — convergence is order-independent, because applying a set of log rows sorted by clock yields the same projection regardless of arrival order.
- **REQ-OF-5 clause 2** — idempotency is a primary-key conflict on the log row's client-generated ID.

The alternative — sync whole rows and keep the log as a side audit table — cannot satisfy field-level LWW without a second mechanism, and lets the log drift out of agreement with state.

### 2.2 Clocks: hybrid logical clock, not wall time

REQ-SE-2 clause 3 resolves conflicts by "later timestamp" and clause 4 requires a deterministic tiebreaker. Device wall clocks make this unsafe: a phone running ten minutes fast wins every conflict regardless of actual causality, and REQ-OF-4 explicitly anticipates devices disagreeing about the date.

**Use a hybrid logical clock.** Each log row carries `hlc = (physical_ms, counter, device_id)`, compared lexicographically in that order.

- `physical_ms` — max of local wall clock and highest observed remote physical time
- `counter` — increments when physical time does not advance
- `device_id` — stable UUID, the tiebreaker required by REQ-SE-2 clause 4

Both devices independently compute the same winner from the same triple, and modest clock skew stops silently deciding outcomes. A device with a badly wrong clock still distorts ordering; HLC bounds the damage rather than eliminating it.

**Expensive to reverse.** The HLC lives in a column on every log row and in every comparison. Retrofitting it after shipping wall-clock timestamps means a migration plus re-deriving order for existing data.

### 2.3 Identifiers and tombstones

**Client-generated UUIDv7 primary keys, everywhere.** Offline creation is required by REQ-OF-1, so the client must mint IDs without asking the server. Server-side autoincrement makes offline creates impossible. UUIDv7 sorts by creation time, which keeps index locality reasonable.

**Soft deletes via `deleted_at`.** A hard delete cannot propagate — the row simply vanishes locally, and the next pull from a peer that has not yet seen the delete resurrects it. Deletion is a field change like any other, so it flows through the log and resolves under the same LWW rule.

Both are expensive to reverse. See sections 7.3 and 7.4.

### 2.4 Push and pull

Two operations, both idempotent:

```
POST /sync/push   { plan_id, rows: ChangeLogRow[] }
                  → { accepted: [ids], server_hlc }
                  insert-ignore on primary key

GET  /sync/pull   ?plan_id&since_hlc&limit
                  → { rows: ChangeLogRow[], next_cursor, has_more }
```

- Pull is cursor-paged on HLC so a long offline period syncs incrementally rather than in one oversized response.
- Push batches with a cap; partial success is fine because retry is idempotent.
- Original `hlc` is preserved on push, never rewritten to server receipt time — required by REQ-OF-5 clause 3.
- `sync_state` holds `last_pushed_hlc` and `last_pulled_hlc` per device per plan.

### 2.5 First login on a second device

REQ-SE-1 clause 5 requires the joining partner to see every existing figure identically, including overrides. With log-based sync this is a full replay:

1. Partner B accepts the invite deep link. Server validates the token against `invites` — unexpired per REQ-SE-1 clause 4, not revoked, not already accepted.
2. Server inserts the `plan_members` row. Membership is the one write that does not flow through the change log, because it is an access-control fact rather than plan content, and it must be authoritative before any data is readable.
3. Client creates the local database and pulls from `since_hlc = 0`, paged.
4. Client applies rows in HLC order, building projections from empty.
5. Client computes all derived figures locally per section 1.4.
6. Dashboard renders. B's figures now match A's exactly, because both are projections of the same log.

Bootstrapping a long-lived plan means replaying every field change ever made. For a wedding budget — hundreds of entries, a few thousand log rows — this is fine. If it ever is not, add a periodic server-side snapshot and pull `snapshot + log since snapshot`. **Do not build snapshots for v1.** The seam is the `since_hlc` cursor, which already accommodates them.

### 2.6 What is deliberately not built

- **No realtime push.** Sync on app foreground, on reconnect, and after a debounce following local writes. Two users who are usually in the same room do not need websockets, and REQ-SE-3 only demands convergence, not immediacy.
- **No CRDTs.** The requirements specify LWW. A CRDT would be a heavier mechanism satisfying a guarantee nobody asked for. Noted in section 7.2 as the reversal path if LWW proves insufficient.
- **No operational transform.** No collaborative text editing here.

---

## 3. Backend and data store

### Option A — Supabase *(recommended)*

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

### Option B — Managed Postgres plus a thin API

Neon, Railway, or Fly Postgres behind a small Hono or Fastify service.

**Fit:** total control over the sync endpoints, auth, and validation. No vendor semantics to work around. Better if the sync protocol needs to diverge from what a BaaS assumes.

**Costs:** auth is now yours to build and keep secure — sessions, refresh rotation, reset flows, rate limiting. That is a large, security-sensitive surface for a scope that is otherwise domain logic. Plus a service to deploy, monitor, and keep patched.

### Recommendation

**Supabase.** The backend here is genuinely thin — two idempotent endpoints over an append-only table — and almost all remaining server work is authentication, which is exactly what the BaaS supplies. Option B buys control this protocol does not need.

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
  region_code          text not null references regions,
  ruleset_version      text not null,            -- pinned, REQ-AE-3
  driving_rsvp_status  text not null,            -- REQ-GM-1 clause 6
  remainder_category   text not null default 'buffer',
  is_active            boolean not null default true,   -- REQ-PLT-3
  setup_completed_at   timestamptz,
  created_at           timestamptz not null,
  deleted_at           timestamptz               -- soft delete, creator only
)

plan_members (
  plan_id   uuid references plans,
  user_id   uuid references users,
  role      text not null check (role in ('creator','partner')),
  joined_at timestamptz not null,
  primary key (plan_id, user_id)
)
-- REQ-SE-1 clause 1: at most two rows per plan, enforced by trigger.
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

`lifecycle_confirmations` exists because ownership transfer (REQ-SE-5 clauses 4, 6, 7) needs a pending two-party state that can expire. Without a row to hold it, "pending" has nowhere to live. **Defensive partner removal does not use this table:** per REQ-SE-6 it is immediate and one-sided, executed as a direct delete of the removed partner's `plan_members` row (below) with an attributed `change_log` entry — there is no pending confirmation to store.

### 4.2 Ruleset configuration

Versioned and immutable once published, so REQ-AE-3 clause 2 holds.

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
-- REQ-AE-1 clause 4: sum(baseline_bp) = 10000 per version, validated on publish.

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
  primary key (ruleset_version, code)
)

region_category_skew (                       -- REQ-AE-2 clauses 7, 8
  ruleset_version text,
  region_code     text,
  category_code   text,
  skew_bp         integer not null default 10000,   -- 1.0, no-op
  primary key (ruleset_version, region_code, category_code)
)

reference_costs (                            -- REQ-AE-2 clause 2
  ruleset_version    text,
  tier_code          text,
  per_head_cents     bigint not null,
  fixed_base_cents   bigint not null,
  primary key (ruleset_version, tier_code)
)
```

`reference_costs` is the table for the still-missing benchmark noted in requirements section 13 item 1. The schema is ready; the values are not. Budget adequacy stays hidden until it is populated.

### 4.3 Allocations

```sql
plan_allocations (
  plan_id           uuid references plans,
  category_code     text references allocation_categories,
  engine_cents      bigint not null,     -- what the engine produced
  override_cents    bigint,              -- null unless overridden, REQ-AE-5
  allocator_kind    text not null,       -- 'rule_based' | future
  allocator_version text not null,
  explanation       jsonb not null,      -- REQ-AE-4, opaque
  computed_at       timestamptz not null,
  primary key (plan_id, category_code)
)
```

Keeping `engine_cents` alongside `override_cents` satisfies REQ-AE-5 clause 2 — both values displayed — and makes clause 5 revert a null-out rather than a recomputation.

`allocator_kind`, `allocator_version`, and an opaque `explanation` are the AI seam. See section 5.3.

### 4.4 Ledger

```sql
ledger_entries (
  id                 uuid pk,
  plan_id            uuid not null references plans,
  category_code      text not null references allocation_categories,
  entry_type         text not null,     -- 'standard' or a hidden-fee subtype
  supplier_name      text not null,
  estimated_cents    bigint not null check (estimated_cents >= 0),
  actual_cents       bigint check (actual_cents >= 0),      -- nullable
  deposit_paid_cents bigint not null default 0,
  due_date           date,
  pricing_mode       text not null check (pricing_mode in ('per_head','flat')),
  per_head_rate_cents bigint,           -- required when per_head
  manually_valued    boolean not null default false,        -- REQ-GM-2 clause 5
  notes              text,
  created_at         timestamptz not null,
  deleted_at         timestamptz
)
-- entry_type in ('standard','crew_meals','oot_fees','church_aircon',
--                'corkage','overtime','venue_power')
-- NOT stored: payment_status, balance_due, effective_amount. All derived.

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

One generic `fee_components` table covers all six hidden-fee shapes from REQ-HF-2 rather than six subtype tables:

| Subtype | Mapping |
|---|---|
| Crew meals | one row per supplier; `quantity` = crew headcount, `unit_rate_cents` = per-meal rate |
| OOT fees | three rows per supplier: `travel`, `lodging`, `per_diem`, each with `amount_cents` |
| Church aircon | single row, `amount_cents` |
| Corkage | one row per item type (`cake`, `wine`, `liquor`, `lechon`, `other`) |
| Overtime | one row per supplier; `quantity` = projected hours, `unit_rate_cents` = hourly rate |
| Venue power | three rows: `generator`, `surcharge`, `electrical` |

Component total is `quantity × unit_rate_cents` when both are present, otherwise `amount_cents`. Entry total is the sum. This trades some compile-time type safety for schema stability, and it is cheap to reverse in either direction because the change is additive.

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

A separate table because REQ-HF-1 clause 2 requires `prompted_unfilled` to be distinguishable from a filled zero. Absence of a ledger entry cannot express that, and clause 6 needs to name untouched categories to block setup completion. Clause 4 needs the dismissing partner and timestamp.

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
                       ('ninong','ninang','family','friend','other')),
  pledge_type        text not null check (pledge_type in ('cash','item')),
  item_description   text,
  value_cents        bigint not null check (value_cents >= 0),
  status             text not null check (status in ('tentative','confirmed','received')),
  linked_category_code text references allocation_categories,
  linked_entry_id    uuid references ledger_entries,
  created_at         timestamptz not null,
  deleted_at         timestamptz
)
```

Two orthogonal columns on `guests`, per REQ-GM-1 clauses 1, 2, and 5. `crew_headcount` is a separate table specifically so no query can accidentally sweep crew into a guest count.

### 4.6 Change log and sync state

```sql
change_log (
  id            uuid pk,          -- client-generated; idempotency key
  plan_id       uuid not null references plans,
  entity_type   text not null,
  entity_id     uuid not null,
  field_name    text not null,
  old_value     jsonb,
  new_value     jsonb,
  hlc_physical  bigint not null,
  hlc_counter   integer not null,
  device_id     uuid not null,
  actor_user_id uuid not null references users,
  created_at    timestamptz not null
)
-- Append-only. No UPDATE, no DELETE, enforced by permission and trigger.
-- Ordering key: (hlc_physical, hlc_counter, device_id).

-- Projection index: newest write per field
create index change_log_field_idx
  on change_log (plan_id, entity_type, entity_id, field_name,
                 hlc_physical desc, hlc_counter desc, device_id desc);

sync_state (                     -- local only, never synced
  device_id       uuid,
  plan_id         uuid,
  last_pushed_hlc text,
  last_pulled_hlc text,
  primary key (device_id, plan_id)
)
```

`superseded` is deliberately not a column. It is derivable — a row is superseded when a higher-ordered row exists for the same `(entity, field)` — and storing it would mean rewriting log rows, which contradicts append-only and REQ-SE-4 clause 4. REQ-SE-4 clause 3 is satisfied by computing it at read time.

---

## 5. Allocation engine design

### 5.1 A pure function

```ts
interface BudgetAllocator {
  readonly kind: string;       // persisted to plan_allocations.allocator_kind
  readonly version: string;

  allocate(input: AllocationInput, ruleset: Ruleset): AllocationResult;
}

type AllocationInput = {
  totalBudgetCents: number;
  regionCode: string;
  drivingGuestCount: number;
  guestCap: number;
  weddingDate: string;
};

type AllocationResult = {
  categories: Array<{
    categoryCode: string;
    amountCents: number;
    explanation: Explanation;     // REQ-AE-4, opaque JSON
  }>;
  expectedTotalCostCents: number; // REQ-AE-2 clause 2
  suggestions: RateSuggestion[];  // REQ-AE-2 clauses 5, 6
};
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

An AI-driven allocator replaces the rule-based one with **no schema change**, because:

1. **The interface is the boundary.** A future `AiAssistedAllocator` implements the same `BudgetAllocator`. Callers are unaffected.
2. **Only the output is persisted.** `plan_allocations` stores amounts, not how they were derived. Engine internals never reach the schema.
3. **`explanation` is opaque JSONB.** A rule-based allocator writes rule ids and basis points; an AI one writes model id, features, confidence. Neither the column type nor the reader changes — the UI renders whatever the explanation contains.
4. **`allocator_kind` and `allocator_version` already exist.** Every allocation records what produced it, so mixed-provenance data is legible and a rollback is a re-run, not a migration.
5. **`ruleset_version` stays pinned.** Even an AI allocator records the configuration in force, so REQ-AE-3 clause 2 continues to hold.

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

### 6.4 Payments → REQ-AI-4

Not designed here beyond one boundary: v1's `deposit_paid_cents` records that money moved, per REQ-LG-4 clause 5. A future payment integration would write to a **separate** `payment_transactions` table with its own reconciliation, and update `deposit_paid_cents` only as a consequence of a settled transaction. The ledger stays the system of record for intent; the payment table becomes the system of record for movement. Do not overload `deposit_paid_cents` to mean both.

---

## 7. Decisions that are expensive to reverse

Ordered by cost.

### 7.1 Platform — resolved as Flutter

**Cost to reverse: total rewrite of the client.** Everything in section 1, all UI, all local persistence wiring. Sections 2 through 6 survive, which is roughly the sync protocol, schema, and domain logic — real value, but the client is the bulk of the work.

**Resolved: Flutter + SQLite/`drift` (section 0).** No longer a live decision. Recorded here only so the reversal cost stays on the ledger: switching frameworks after code exists is a client rewrite. The `domain/` purity rule in section 1.2 is the hedge — the allocation engine, calculations, and validation are plain Dart with no Flutter import, so that layer at least would port.

### 7.2 Change log as the sync unit

**Cost to reverse: high.** Moving to row-based sync or CRDTs means a new schema, a new protocol, and a migration of existing log data into whatever replaces it.

Confidence is high that this is right, because REQ-SE-2 and REQ-SE-4 together essentially describe it. The reversal path, if per-field LWW proves too lossy in practice, is a CRDT per field — which would still be log-shaped, limiting the damage.

### 7.3 Client-generated UUIDv7 keys

**Cost to reverse: very high, and effectively one-way.** Switching to server-assigned IDs breaks offline creation outright. Switching *from* server IDs to client IDs means rewriting every foreign key in existing data.

Low risk, because offline-first leaves no real alternative. Worth stating explicitly so nobody "simplifies" it to autoincrement later.

### 7.4 Soft deletes everywhere

**Cost to reverse: high.** Retrofitting tombstones after shipping hard deletes means every already-deleted row is unrecoverable and every peer may hold resurrected copies. Retrofitting requires reconciling divergent devices with no record of what was removed.

Non-negotiable for offline sync. The cost is that every query must filter `deleted_at is null`, and one forgotten filter silently inflates a total. Mitigate with repository-level views rather than relying on discipline at each call site.

### 7.5 Hybrid logical clock instead of wall time

**Cost to reverse: moderate.** Adding HLC later is a migration plus rewriting every comparison, and historical ordering cannot be reconstructed for data already written with wall clocks.

Cheap now, so do it now.

### 7.6 Derived values never persisted

**Cost to reverse: moderate, and asymmetric.** Adding a persisted cache later is straightforward. Removing one after shipping means finding every consumer that trusted it and every sync conflict it caused.

Start strict. REQ-LG-5 clause 6 requires it for payment status regardless.

### 7.7 Supabase as the backend

**Cost to reverse: moderate.** The Postgres schema and all data are portable. Auth is not — migrating identities means a password reset for every user. With a small user base that is an inconvenience; at scale it is a migration project.

Keep application code free of Supabase-specific calls outside `sync/transport/` and the auth adapter, so a swap touches two directories.

### 7.8 Generic `fee_components` table

**Cost to reverse: low.** Splitting into six typed tables later is a mechanical migration, and the reverse is equally mechanical. Called out only to note it is *not* expensive, so it should not attract early debate.

---

## 8. Open items carried into implementation

1. **Reference cost values.** `reference_costs` exists but is unpopulated, so budget adequacy (REQ-AE-2 clause 3) cannot ship. Every other allocation requirement can. This is now the only item blocking a specific feature.
2. **Designated driving RSVP status default.** Requirements section 13 item 2 is still open. `invited` remains the safer default.
3. **Ownership-transfer confirmation expiry.** `lifecycle_confirmations.expires_at` needs a duration. Now applies to ownership transfer only (Decisions 1, 2); defensive removal (REQ-SE-6) is immediate and has no expiry. Seven days matches the invite window.
4. **Local database encryption.** Not required by any requirement, but the local store holds names, a wedding date, and financial detail. With Flutter/SQLite this means SQLCipher (via `drift`'s encryption support) or platform keystore-backed encryption, worth deciding before launch rather than after.
5. **RLS policy test suite.** If Supabase is chosen, the plan-isolation policy is the entire security boundary between couples. It needs adversarial tests, not review by inspection.

*Resolved since first draft: platform (Flutter + SQLite/`drift`, section 0), monetary representation (Dart `int`, section 1.5), and ruleset config management (bundled JSON asset validated at load, per requirements REQ-AE-1).*
