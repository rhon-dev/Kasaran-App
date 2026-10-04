-- Phase 06 identity and pairing. Phase 07 will add regions/rulesets and budget tables.
create extension if not exists pgcrypto with schema extensions;

create table public.users (
  id uuid primary key references auth.users(id),
  email text not null unique,
  display_name text not null default '',
  created_at timestamptz not null default now()
);
create function public.identity_valid_reminder_days(p_days jsonb) returns boolean
language plpgsql immutable strict set search_path = '' as $$
declare v_day jsonb; v_number numeric; v_seen numeric[] := '{}'::numeric[];
begin
  if pg_catalog.jsonb_typeof(p_days) <> 'array' then return false; end if;
  for v_day in select value from pg_catalog.jsonb_array_elements(p_days) loop
    if pg_catalog.jsonb_typeof(v_day) <> 'number' then return false; end if;
    v_number := (v_day #>> '{}')::numeric;
    if v_number < 0 or v_number <> pg_catalog.trunc(v_number)
       or pg_catalog.array_position(v_seen, v_number) is not null then
      return false;
    end if;
    v_seen := pg_catalog.array_append(v_seen, v_number);
  end loop;
  return true;
end; $$;
create table public.plans (
  id uuid primary key,
  creator_user_id uuid not null references public.users(id),
  wedding_date date not null,
  total_budget_cents bigint not null check (total_budget_cents > 0),
  guest_cap integer not null check (guest_cap >= 0),
  region_code text not null,
  ceremony_type text check (ceremony_type in ('church','civil','other_religious','garden_beach_officiant','other')),
  venue_type text check (venue_type in ('hotel','garden','beach_resort','restaurant','events_place','other')),
  reminder_enabled boolean not null default true,
  reminder_window_days integer not null default 7 check (reminder_window_days >= 0),
  reminder_days_before jsonb not null default '[7,1]'::jsonb
    check (public.identity_valid_reminder_days(reminder_days_before)),
  reminder_overdue boolean not null default true,
  ruleset_version text not null,
  driving_rsvp_status text not null,
  is_active boolean not null default true,
  setup_completed_at timestamptz,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint inactive_when_deleted check (deleted_at is null or not is_active)
);
create unique index one_active_created_plan on public.plans(creator_user_id) where is_active;
create table public.plan_member_aliases (
  plan_member_id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id),
  user_id uuid references public.users(id),
  unique (plan_id, plan_member_id),
  unique (plan_id, user_id, plan_member_id)
);
create table public.plan_members (
  plan_id uuid not null references public.plans(id),
  user_id uuid not null references public.users(id),
  plan_member_id uuid not null unique,
  role text not null check (role in ('creator','partner')),
  joined_at timestamptz not null default now(),
  primary key (plan_id, user_id),
  foreign key (plan_id, user_id, plan_member_id)
    references public.plan_member_aliases(plan_id, user_id, plan_member_id),
  unique (user_id)
);
create table public.invites (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id),
  inviter_user_id uuid not null references public.users(id),
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  check (expires_at = issued_at + interval '7 days'),
  check (accepted_at is null or revoked_at is null)
);

create function public.identity_auth_user() returns trigger language plpgsql security definer
set search_path = '' as $$
begin
  insert into public.users(id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  return new;
end; $$;
create trigger identity_auth_user_created after insert on auth.users
for each row execute function public.identity_auth_user();
create function public.identity_auth_user_changed() returns trigger language plpgsql security definer
set search_path = '' as $$
begin
  update public.users set email = new.email,
    display_name = coalesce(new.raw_user_meta_data ->> 'display_name', '')
  where id = new.id;
  return new;
end; $$;
create trigger identity_auth_user_changed after update of email, raw_user_meta_data on auth.users
for each row when (old.email is distinct from new.email or
                   old.raw_user_meta_data is distinct from new.raw_user_meta_data)
execute function public.identity_auth_user_changed();
-- Existing Auth accounts may predate this migration in local environments.
insert into public.users(id, email, display_name)
select id, email, coalesce(raw_user_meta_data ->> 'display_name', '') from auth.users
where email is not null on conflict (id) do nothing;

create function public.identity_member(p_plan_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.plan_members m
    where m.plan_id = p_plan_id and m.user_id = auth.uid()
  );
$$;
create function public.identity_verified() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null
  );
$$;

create function public.identity_limit_members() returns trigger language plpgsql
set search_path = '' as $$
begin
  -- Lock the parent to serialize concurrent joins even across separate RPC transactions.
  perform 1 from public.plans where id = new.plan_id for update;
  if (select count(*) from public.plan_members where plan_id = new.plan_id) >= 2 then
    raise exception 'plan already has two members';
  end if;
  if exists (select 1 from public.plan_members where user_id = new.user_id) then
    raise exception 'account already has an active plan';
  end if;
  return new;
end; $$;
create trigger identity_limit_members before insert on public.plan_members
for each row execute function public.identity_limit_members();

alter table public.users enable row level security;
alter table public.users force row level security;
alter table public.plans enable row level security;
alter table public.plans force row level security;
alter table public.plan_member_aliases enable row level security;
alter table public.plan_member_aliases force row level security;
alter table public.plan_members enable row level security;
alter table public.plan_members force row level security;
alter table public.invites enable row level security;
alter table public.invites force row level security;
create policy user_self_read on public.users for select to authenticated using (id = auth.uid());
create policy plan_member_read on public.plans for select to authenticated using (public.identity_member(id));
create policy alias_member_read on public.plan_member_aliases for select to authenticated using (public.identity_member(plan_id));
create policy membership_member_read on public.plan_members for select to authenticated using (public.identity_member(plan_id));
create policy invite_member_read on public.invites for select to authenticated using (public.identity_member(plan_id));

-- Revoke every direct mutation, including role defaults, independently of RLS.
revoke all on public.users, public.plans, public.plan_member_aliases, public.plan_members, public.invites from public, anon, authenticated;
grant select on public.users, public.plans, public.plan_member_aliases, public.plan_members to authenticated;
-- No direct token_hash read, even for a plan member.
grant select (id, plan_id, inviter_user_id, issued_at, expires_at, accepted_at, revoked_at)
  on public.invites to authenticated;
revoke all on function public.identity_valid_reminder_days(jsonb) from public, anon, authenticated;
grant execute on function public.identity_valid_reminder_days(jsonb) to service_role;
revoke all on function public.identity_auth_user() from public, anon, authenticated;
revoke all on function public.identity_auth_user_changed() from public, anon, authenticated;
revoke all on function public.identity_limit_members() from public, anon, authenticated;
revoke all on function public.identity_member(uuid), public.identity_verified() from public, anon;
grant execute on function public.identity_member(uuid), public.identity_verified() to authenticated;

create function public.create_plan(
  p_id uuid, p_wedding_date date, p_total_budget_cents bigint, p_guest_cap integer,
  p_region_code text, p_ruleset_version text, p_driving_rsvp_status text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if not public.identity_verified() then raise exception 'verified email required'; end if;
  -- Serialize both competing create/join operations for the same account.
  perform 1 from public.users where id = v_uid for update;
  if exists (select 1 from public.plan_members where user_id = v_uid) then
    raise exception 'account already has an active plan';
  end if;
  insert into public.plans(id, creator_user_id, wedding_date, total_budget_cents,
    guest_cap, region_code, ruleset_version, driving_rsvp_status)
  values (p_id, v_uid, p_wedding_date, p_total_budget_cents,
    p_guest_cap, p_region_code, p_ruleset_version, p_driving_rsvp_status);
  insert into public.plan_member_aliases(plan_id, user_id) values (p_id, v_uid);
  insert into public.plan_members(plan_id, user_id, plan_member_id, role)
  select p_id, v_uid, plan_member_id, 'creator' from public.plan_member_aliases
  where plan_id = p_id and user_id = v_uid;
  return jsonb_build_object('id', p_id);
end; $$;

create function public.issue_invite(p_plan_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_token text; v_id uuid; v_expiry timestamptz;
begin
  if v_uid is null or not public.identity_member(p_plan_id) then
    raise exception 'plan membership required';
  end if;
  perform 1 from public.plans where id = p_plan_id and is_active for update;
  if not found or (select count(*) from public.plan_members where plan_id = p_plan_id) >= 2 then
    raise exception 'plan unavailable for pairing';
  end if;
  v_token := encode(extensions.gen_random_bytes(16), 'hex');
  insert into public.invites(plan_id, inviter_user_id, token_hash, issued_at, expires_at)
  values (p_plan_id, v_uid, encode(extensions.digest(v_token, 'sha256'), 'hex'), now(), now() + interval '7 days')
  returning id, expires_at into v_id, v_expiry;
  -- The raw token exists in this single authorized response, never persisted.
  return jsonb_build_object('id', v_id, 'token', v_token, 'expires_at', v_expiry);
end; $$;

create function public.accept_invite(p_token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_invite public.invites%rowtype; v_alias uuid;
begin
  if not public.identity_verified() then raise exception 'verified email required'; end if;
  if p_token is null or p_token !~ '^[0-9a-f]{32}$' then
    raise exception 'invalid invite';
  end if;
  perform 1 from public.users where id = v_uid for update;
  if exists (select 1 from public.plan_members where user_id = v_uid) then
    raise exception 'account already has an active plan';
  end if;
  select * into v_invite from public.invites
  where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex') for update;
  if not found then raise exception 'invalid invite'; end if;
  if v_invite.revoked_at is not null then raise exception 'invite revoked'; end if;
  if v_invite.accepted_at is not null then raise exception 'invite already accepted'; end if;
  if v_invite.expires_at <= now() then raise exception 'invite expired'; end if;
  if v_invite.inviter_user_id = v_uid then raise exception 'cannot accept own invite'; end if;
  perform 1 from public.plans where id = v_invite.plan_id and is_active for update;
  if not found then raise exception 'plan unavailable'; end if;
  insert into public.plan_member_aliases(plan_id, user_id)
  values (v_invite.plan_id, v_uid) returning plan_member_id into v_alias;
  insert into public.plan_members(plan_id, user_id, plan_member_id, role)
  values (v_invite.plan_id, v_uid, v_alias, 'partner');
  update public.invites set accepted_at = now() where id = v_invite.id;
  return jsonb_build_object('plan_id', v_invite.plan_id, 'plan_member_id', v_alias);
end; $$;

create function public.revoke_invite(p_invite_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_invite public.invites%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into v_invite from public.invites where id = p_invite_id for update;
  if not found or not public.identity_member(v_invite.plan_id) then
    raise exception 'invite unavailable';
  end if;
  if v_invite.accepted_at is not null then raise exception 'invite already accepted'; end if;
  if v_invite.revoked_at is not null then raise exception 'invite revoked'; end if;
  update public.invites set revoked_at = now() where id = p_invite_id;
  return jsonb_build_object('id', p_invite_id, 'revoked', true);
end; $$;
revoke all on function public.create_plan(uuid,date,bigint,integer,text,text,text),
  public.issue_invite(uuid), public.accept_invite(text), public.revoke_invite(uuid)
  from public, anon;
grant execute on function public.create_plan(uuid,date,bigint,integer,text,text,text),
  public.issue_invite(uuid), public.accept_invite(text), public.revoke_invite(uuid) to authenticated;
