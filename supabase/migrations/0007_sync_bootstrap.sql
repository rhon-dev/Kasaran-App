-- Explicit read-only second-device metadata bootstrap. Applied 0001–0006 stay immutable.
create function public.sync_bootstrap_v1(payload_text text) returns text
language plpgsql security definer set search_path = '' as $$
declare payload jsonb; p uuid; snapshot jsonb;
begin
  begin payload := payload_text::jsonb;
  exception when others then raise sqlstate 'PT400' using message='invalid_json'; end;
  p := public.sync_authorize_v1(payload);
  -- Retain the same active parent and actual caller membership through return.
  -- Lock waits are authority boundaries, so reauthorize after acquiring them.
  perform 1 from public.plans where id=p and is_active and deleted_at is null for share;
  if not found then raise sqlstate 'PT403' using message='plan_unavailable'; end if;
  perform 1 from public.plan_members where plan_id=p and user_id=auth.uid() for share;
  if not found then raise sqlstate 'PT403' using message='plan_unavailable'; end if;
  perform public.sync_authorize_v1(payload);
  -- One SQL statement supplies one coherent relational snapshot. All historical
  -- aliases remain visible for later log attribution; membership is caller-only.
  -- bigint money is decimal text, never a JavaScript number in any intermediary.
  select pg_catalog.jsonb_build_object(
    'protocol_version',pg_catalog.jsonb_build_object('major',1,'minor',0),
    'plan',pg_catalog.to_jsonb(x) || pg_catalog.jsonb_build_object(
      'total_budget_cents',x.total_budget_cents::text,
      'created_at',pg_catalog.to_char(x.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'setup_completed_at',pg_catalog.to_char(x.setup_completed_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'deleted_at',pg_catalog.to_char(x.deleted_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')),
    'aliases',(select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(a) order by a.plan_member_id),'[]'::jsonb)
      from public.plan_member_aliases a where a.plan_id=p),
    'member',pg_catalog.to_jsonb(m) || pg_catalog.jsonb_build_object(
      'joined_at',pg_catalog.to_char(m.joined_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')))
    into snapshot from public.plans x join public.plan_members m on m.plan_id=x.id
      where x.id=p and x.is_active and x.deleted_at is null and m.user_id=auth.uid();
  if snapshot is null then raise sqlstate 'PT403' using message='plan_unavailable'; end if;
  perform public.sync_authorize_v1(payload);
  return snapshot::text;
end; $$;
revoke all on function public.sync_bootstrap_v1(text) from public, anon, authenticated;
grant execute on function public.sync_bootstrap_v1(text) to authenticated;
