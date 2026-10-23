CREATE TABLE plans (
  id TEXT NOT NULL PRIMARY KEY, creator_user_id TEXT NOT NULL,
  wedding_date TEXT NOT NULL, total_budget_cents INTEGER NOT NULL CHECK (total_budget_cents > 0),
  guest_cap INTEGER NOT NULL CHECK (guest_cap >= 0), region_code TEXT NOT NULL,
  ceremony_type TEXT, venue_type TEXT,
  reminder_enabled INTEGER NOT NULL DEFAULT 1 CHECK (reminder_enabled IN (0,1)),
  reminder_window_days INTEGER NOT NULL DEFAULT 7 CHECK (reminder_window_days >= 0),
  reminder_days_before TEXT NOT NULL DEFAULT '[7,1]',
  reminder_overdue INTEGER NOT NULL DEFAULT 1 CHECK (reminder_overdue IN (0,1)),
  ruleset_version TEXT NOT NULL, driving_rsvp_status TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  setup_completed_at TEXT, created_at TEXT NOT NULL, deleted_at TEXT
);
CREATE UNIQUE INDEX one_active_created_plan ON plans (creator_user_id)
  WHERE is_active = 1;
CREATE TABLE plan_member_aliases (
  plan_member_id TEXT NOT NULL PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
  user_id TEXT, UNIQUE(plan_id,plan_member_id), UNIQUE(plan_id,user_id,plan_member_id)
);
CREATE TABLE plan_members (
  plan_id TEXT NOT NULL REFERENCES plans(id), user_id TEXT NOT NULL UNIQUE,
  plan_member_id TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL CHECK (role IN ('creator','partner')),
  joined_at TEXT NOT NULL, PRIMARY KEY(plan_id,user_id),
  FOREIGN KEY(plan_id,user_id,plan_member_id)
    REFERENCES plan_member_aliases(plan_id,user_id,plan_member_id)
);
CREATE TABLE ledger_entries (
  id TEXT NOT NULL PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
  category_code TEXT NOT NULL CHECK (category_code IN
    ('catering_venue','photo_video','attire_styling','coordination','entourage_misc','buffer')),
  entry_type TEXT NOT NULL CHECK (entry_type IN
    ('standard','crew_meals','oot_fees','church_aircon','corkage','overtime','venue_power')),
  supplier_name TEXT NOT NULL CHECK (length(trim(supplier_name)) BETWEEN 1 AND 200),
  estimated_cents INTEGER, actual_cents INTEGER CHECK (actual_cents >= 0),
  pricing_mode TEXT NOT NULL CHECK (pricing_mode IN ('flat','per_head')),
  per_head_rate_cents INTEGER, manually_valued INTEGER NOT NULL DEFAULT 0
    CHECK (manually_valued IN (0,1)),
  notes TEXT CHECK (length(notes)<=2000),
  template_suggestion_id TEXT, checklist_item_id TEXT,
  created_at TEXT NOT NULL, deleted_at TEXT,
  CHECK ((pricing_mode='flat' AND estimated_cents IS NOT NULL
    AND estimated_cents >= 0 AND per_head_rate_cents IS NULL)
    OR (pricing_mode='per_head' AND estimated_cents IS NULL
    AND per_head_rate_cents IS NOT NULL AND per_head_rate_cents >= 0))
);
CREATE TABLE change_log (
  id TEXT NOT NULL PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
  entity_type TEXT NOT NULL CHECK(length(entity_type)>0), entity_id TEXT NOT NULL,
  field_name TEXT NOT NULL CHECK(length(field_name)>0), change_group_id TEXT,
  schema_version INTEGER NOT NULL CHECK(schema_version>0),
  old_value TEXT, new_value TEXT, server_ts INTEGER,
  device_monotonic INTEGER NOT NULL CHECK(device_monotonic>=0),
  device_id TEXT NOT NULL, plan_member_id TEXT NOT NULL, created_at TEXT NOT NULL,
  FOREIGN KEY(plan_id,plan_member_id)
    REFERENCES plan_member_aliases(plan_id,plan_member_id),
  UNIQUE(id,plan_id)
);
CREATE TABLE sync_state (
  device_id TEXT NOT NULL, plan_id TEXT NOT NULL REFERENCES plans(id),
  last_pushed_server_ts INTEGER, last_pulled_server_ts INTEGER,
  device_monotonic INTEGER NOT NULL DEFAULT 0 CHECK(device_monotonic>=0),
  PRIMARY KEY(device_id,plan_id)
);
CREATE TABLE outbox (
  event_id TEXT NOT NULL PRIMARY KEY,
  plan_id TEXT NOT NULL REFERENCES plans(id), device_id TEXT NOT NULL,
  queued_at TEXT NOT NULL,
  FOREIGN KEY(event_id,plan_id) REFERENCES change_log(id,plan_id)
);

CREATE UNIQUE INDEX one_membership_user ON plan_members(user_id);
PRAGMA user_version = 2;
