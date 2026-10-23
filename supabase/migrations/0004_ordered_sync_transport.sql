-- Phase08 immutable transport only: no financial projection/replay.
alter table public.change_log add column original_event jsonb;
create unique index change_log_plan_stamp on public.change_log(plan_id, server_ts)
  where server_ts is not null;
create table public.sync_plan_sequences (
  plan_id uuid primary key references public.plans(id),
  server_ts_high bigint not null default 0 check (server_ts_high >= 0)
);
alter table public.sync_plan_sequences enable row level security;
alter table public.sync_plan_sequences force row level security;
create policy sync_sequence_member_read on public.sync_plan_sequences for select to authenticated
  using (public.identity_member(plan_id));
revoke all on public.sync_plan_sequences from public, anon, authenticated;
grant select on public.sync_plan_sequences to authenticated;
grant select, insert, update on public.sync_plan_sequences to service_role;

create function public.sync_decimal_v1(value jsonb) returns boolean
language plpgsql immutable set search_path = '' as $$
begin
  return coalesce(pg_catalog.jsonb_typeof(value) = 'string'
    and (value #>> '{}') ~ '^(0|[1-9][0-9]{0,18})$'
    and (value #>> '{}')::numeric <= 9223372036854775807, false);
exception when others then return false;
end; $$;
create function public.sync_uuid_v1(value jsonb, v7 boolean default false) returns boolean
language sql immutable set search_path = '' as $$
  select coalesce(pg_catalog.jsonb_typeof(value) = 'string' and
    (value #>> '{}') ~ case when v7 then
    '^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    else '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' end, false);
$$;
create function public.sync_authorize_v1(payload jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare p uuid; uid uuid := auth.uid();
begin
  if uid is null or not public.identity_verified() or not exists (
    select 1 from auth.sessions s where s.id::text = (auth.jwt()->>'session_id')
      and s.user_id = uid and (s.not_after is null or s.not_after > pg_catalog.now())
  ) then raise sqlstate 'PT401' using message = 'authentication_required'; end if;
  if pg_catalog.jsonb_typeof(payload) is distinct from 'object'
    or pg_catalog.jsonb_typeof(payload->'protocol_version') is distinct from 'object'
    or pg_catalog.jsonb_typeof(payload->'protocol_version'->'major') is distinct from 'number'
    or (payload->'protocol_version'->>'major') !~ '^[0-9]+$'
    or pg_catalog.jsonb_typeof(payload->'protocol_version'->'minor') is distinct from 'number'
    or (payload->'protocol_version'->>'minor') !~ '^[0-9]+$'
  then raise sqlstate 'PT400' using message = 'invalid_protocol'; end if;
  if payload->'protocol_version'->>'major' <> '1' then
    raise sqlstate 'PT426' using message = 'unsupported_protocol'; end if;
  if not public.sync_uuid_v1(payload->'plan_id') then
    raise sqlstate 'PT400' using message = 'invalid_plan_id'; end if;
  p := (payload->>'plan_id')::uuid;
  -- Same denial for foreign, removed, inactive and nonexistent plans.
  if not exists (select 1 from public.plan_members m join public.plans x on x.id=m.plan_id
    where m.plan_id=p and m.user_id=uid and x.is_active and x.deleted_at is null)
  then raise sqlstate 'PT403' using message = 'plan_unavailable'; end if;
  return p;
end; $$;

create function public.sync_push_v1(payload_text text) returns text
language plpgsql security definer set search_path = '' as $$
declare payload jsonb; p uuid; event jsonb; stored public.change_log%rowtype;
  high bigint; stamp bigint; accepted jsonb := '[]'; seen jsonb := '{}';
  version constant jsonb := '{"major":1,"minor":0}';
begin
  begin payload := payload_text::jsonb;
  exception when others then raise sqlstate 'PT400' using message='invalid_json'; end;
  p := public.sync_authorize_v1(payload);
  if pg_catalog.jsonb_typeof(payload->'rows') is distinct from 'array' then
    raise sqlstate 'PT400' using message='invalid_rows'; end if;
  if pg_catalog.jsonb_array_length(payload->'rows') > 100 then
    raise sqlstate 'PT400' using message='invalid_rows'; end if;
  -- The row lock is held until the RPC transaction commits, not just allocation.
  insert into public.sync_plan_sequences(plan_id,server_ts_high)
    select p, coalesce(max(server_ts),0) from public.change_log where plan_id=p
    on conflict (plan_id) do nothing;
  select server_ts_high into high from public.sync_plan_sequences where plan_id=p for update;
  -- Lock waits are await boundaries: an earlier session/membership check is
  -- not authority to accept after revocation while queued behind this plan.
  perform public.sync_authorize_v1(payload);
  perform 1 from public.plans where id=p and is_active and deleted_at is null for share;
  if not found then raise sqlstate 'PT403' using message='plan_unavailable'; end if;
  -- Lock authorization records through commit; removal cannot race acceptance.
  perform 1 from public.plan_members where plan_id=p and user_id=auth.uid() for share;
  if not found then raise sqlstate 'PT403' using message='plan_unavailable'; end if;
  for event in select value from pg_catalog.jsonb_array_elements(payload->'rows') loop
    if pg_catalog.jsonb_typeof(event) is distinct from 'object'
      or not public.sync_uuid_v1(event->'id',true)
      or not public.sync_uuid_v1(event->'entity_id',true)
      or not public.sync_uuid_v1(event->'plan_id')
      or event->>'plan_id' <> p::text
      or not public.sync_uuid_v1(event->'device_id')
      or not public.sync_uuid_v1(event->'plan_member_id')
      or not (event ? 'change_group_id')
      or (event->'change_group_id' <> 'null'::jsonb and not public.sync_uuid_v1(event->'change_group_id'))
      or event->>'entity_type' is distinct from 'ledger_entries'
      or event->'schema_version' is distinct from '1'::jsonb
      or event->>'schema_version' is distinct from '1'
      or pg_catalog.jsonb_typeof(event->'field_name') is distinct from 'string'
      or pg_catalog.length(pg_catalog.btrim(event->>'field_name')) not between 1 and 200
      or not (event ? 'old_value') or not (event ? 'new_value')
      or not public.sync_decimal_v1(event->'device_monotonic')
      or event ? 'server_ts' or event ? 'actor_user_id'
      or pg_catalog.jsonb_typeof(event->'created_at') is distinct from 'string'
      or (event->>'created_at') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$'
    then raise sqlstate 'PT400' using message='invalid_event'; end if;
    begin perform (event->>'created_at')::timestamptz;
    exception when others then raise sqlstate 'PT400' using message='invalid_event'; end;
    if not exists (select 1 from public.plan_member_aliases a
      where a.plan_id=p and a.plan_member_id=(event->>'plan_member_id')::uuid and a.user_id=auth.uid())
    then raise sqlstate 'PT403' using message='invalid_attribution'; end if;
    if seen ? (event->>'id') and (seen->(event->>'id'))::text is distinct from event::text then
      raise sqlstate 'PT409' using message='event_conflict'; end if;
    seen := seen || pg_catalog.jsonb_build_object(event->>'id',event);
    select * into stored from public.change_log where id=(event->>'id')::uuid;
    if found and (stored.plan_id <> p or stored.original_event::text is distinct from event::text) then
      raise sqlstate 'PT409' using message='event_conflict'; end if;
  end loop;
  perform public.sync_authorize_v1(payload);
  for event in select value from pg_catalog.jsonb_array_elements(payload->'rows') loop
    select server_ts into stamp from public.change_log where id=(event->>'id')::uuid;
    if not found then
      high := high + 1; stamp := high;
      insert into public.change_log(id,plan_id,entity_type,entity_id,field_name,change_group_id,
        schema_version,old_value,new_value,server_ts,device_monotonic,device_id,plan_member_id,created_at,original_event)
      values ((event->>'id')::uuid,p,event->>'entity_type',(event->>'entity_id')::uuid,event->>'field_name',
        (event->>'change_group_id')::uuid,1,event->'old_value',event->'new_value',stamp,
        (event->>'device_monotonic')::bigint,(event->>'device_id')::uuid,
        (event->>'plan_member_id')::uuid,(event->>'created_at')::timestamptz,event);
    end if;
    accepted := accepted || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('id',event->>'id','server_ts',stamp::text));
  end loop;
  update public.sync_plan_sequences set server_ts_high=high where plan_id=p;
  return pg_catalog.jsonb_build_object('protocol_version',version,'accepted',accepted,'server_ts_high',high::text)::text;
exception when numeric_value_out_of_range then raise sqlstate 'PT400' using message='sequence_exhausted';
end; $$;

create function public.sync_pull_v1(payload_text text) returns text
language plpgsql security definer set search_path = '' as $$
declare payload jsonb; p uuid; cursor_value bigint; page_limit integer; rows jsonb; next_value text; more boolean;
begin
  begin payload := payload_text::jsonb;
  exception when others then raise sqlstate 'PT400' using message='invalid_json'; end;
  p := public.sync_authorize_v1(payload);
  if not public.sync_decimal_v1(payload->'cursor') then
    raise sqlstate 'PT400' using message='invalid_cursor'; end if;
  if pg_catalog.jsonb_typeof(payload->'limit') is distinct from 'number'
    or (payload->>'limit') !~ '^[0-9]{1,4}$' then
    raise sqlstate 'PT400' using message='invalid_limit'; end if;
  page_limit := (payload->>'limit')::integer;
  if page_limit not between 1 and 1000 then raise sqlstate 'PT400' using message='invalid_limit'; end if;
  cursor_value := (payload->>'cursor')::bigint;
  -- One statement snapshot: rows and has_more cannot disagree under concurrent commits.
  with bounded as (
    select c.*, row_number() over(order by server_ts) as position
    from public.change_log c where plan_id=p and server_ts > cursor_value
    order by server_ts limit page_limit+1
  ) select coalesce(pg_catalog.jsonb_agg(
      (coalesce(original_event,pg_catalog.to_jsonb(b)-'original_event'-'position'-'server_ts'-'device_monotonic')
        || pg_catalog.jsonb_build_object('server_ts',server_ts::text,'device_monotonic',device_monotonic::text,
          'created_at',pg_catalog.to_char(created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')))
      order by server_ts) filter(where position<=page_limit),'[]'::jsonb),
      coalesce(max(server_ts) filter(where position<=page_limit),cursor_value)::text,
      count(*) > page_limit into rows,next_value,more from bounded b;
  return pg_catalog.jsonb_build_object('protocol_version','{"major":1,"minor":0}'::jsonb,
    'rows',rows,'next_cursor',next_value,'has_more',more)::text;
end; $$;
revoke all on function public.sync_decimal_v1(jsonb),public.sync_uuid_v1(jsonb,boolean),
  public.sync_authorize_v1(jsonb),public.sync_push_v1(text),public.sync_pull_v1(text) from public,anon,authenticated;
grant execute on function public.sync_push_v1(text),public.sync_pull_v1(text) to authenticated;
