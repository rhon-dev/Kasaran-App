-- Additive Phase 07 core schema. Local synthetic development only (ADR-77).
-- Migration 0001 retains ownership of plans, aliases, membership and RPCs.
create table public.ledger_entries (
  id uuid primary key,
  plan_id uuid not null references public.plans(id),
  category_code text not null check (category_code in
    ('catering_venue','photo_video','attire_styling','coordination','entourage_misc','buffer')),
  entry_type text not null check (entry_type in
    ('standard','crew_meals','oot_fees','church_aircon','corkage','overtime','venue_power')),
  supplier_name text not null check (char_length(btrim(supplier_name)) between 1 and 200),
  estimated_cents bigint,
  actual_cents bigint check (actual_cents >= 0),
  pricing_mode text not null check (pricing_mode in ('flat','per_head')),
  per_head_rate_cents bigint,
  manually_valued boolean not null default false,
  notes text check (char_length(notes) <= 2000),
  template_suggestion_id text,
  checklist_item_id text,
  created_at timestamptz not null,
  deleted_at timestamptz,
  check (
    (pricing_mode = 'flat' and estimated_cents is not null
     and estimated_cents >= 0 and per_head_rate_cents is null)
    or
    (pricing_mode = 'per_head' and estimated_cents is null
     and per_head_rate_cents is not null and per_head_rate_cents >= 0)
  )
);
create index ledger_entries_plan_idx on public.ledger_entries(plan_id, id);

create table public.change_log (
  id uuid primary key,
  plan_id uuid not null references public.plans(id),
  entity_type text not null check (length(entity_type) > 0),
  entity_id uuid not null,
  field_name text not null check (length(field_name) > 0),
  change_group_id uuid,
  schema_version integer not null check (schema_version > 0),
  old_value jsonb,
  new_value jsonb,
  server_ts bigint,
  device_monotonic bigint not null check (device_monotonic >= 0),
  device_id uuid not null,
  plan_member_id uuid not null,
  created_at timestamptz not null,
  foreign key (plan_id, plan_member_id)
    references public.plan_member_aliases(plan_id, plan_member_id)
);
create index change_log_field_idx on public.change_log
  (plan_id, entity_type, entity_id, field_name,
   server_ts desc, device_monotonic desc, device_id desc);

-- UPDATE/DELETE are forbidden even through a trusted writer. The future sync
-- transaction must assign server_ts on INSERT rather than mutate a log row.
create function public.reject_change_log_mutation() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'change log is immutable';
end; $$;
create trigger reject_change_log_mutation
before update or delete on public.change_log
for each row execute function public.reject_change_log_mutation();

alter table public.ledger_entries enable row level security;
alter table public.ledger_entries force row level security;
alter table public.change_log enable row level security;
alter table public.change_log force row level security;
create policy ledger_member_read on public.ledger_entries for select to authenticated
  using (public.identity_member(plan_id));
create policy log_member_read on public.change_log for select to authenticated
  using (public.identity_member(plan_id));
revoke all on public.ledger_entries, public.change_log from public, anon, authenticated;
grant select on public.ledger_entries, public.change_log to authenticated;
revoke all on function public.reject_change_log_mutation() from public, anon, authenticated;
