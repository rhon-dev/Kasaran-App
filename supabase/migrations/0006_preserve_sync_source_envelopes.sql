-- Preserve immutable original envelopes; 0004/0005 remain unchanged.
create or replace function public.sync_pull_v1(payload_text text) returns text
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
  -- Keep pagination's single-statement snapshot. Only trusted historical rows
  -- without an original envelope need relational -> UTC-Z wire conversion.
  with bounded as (
    select c.*, row_number() over(order by server_ts) as position
    from public.change_log c where plan_id=p and server_ts > cursor_value
    order by server_ts limit page_limit+1
  ) select coalesce(pg_catalog.jsonb_agg(
      ((case when original_event is not null then original_event
        else (pg_catalog.to_jsonb(b)-'original_event'-'position'-'server_ts'-'device_monotonic')
          || pg_catalog.jsonb_build_object('device_monotonic',device_monotonic::text,
            'created_at',pg_catalog.to_char(created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))
        end) || pg_catalog.jsonb_build_object('server_ts',server_ts::text))
      order by server_ts) filter(where position<=page_limit),'[]'::jsonb),
      coalesce(max(server_ts) filter(where position<=page_limit),cursor_value)::text,
      count(*) > page_limit into rows,next_value,more from bounded b;
  return pg_catalog.jsonb_build_object('protocol_version','{"major":1,"minor":0}'::jsonb,
    'rows',rows,'next_cursor',next_value,'has_more',more)::text;
end; $$;
-- CREATE OR REPLACE preserves the existing ACL; assert the intended boundary.
revoke all on function public.sync_pull_v1(text) from public,anon,authenticated;
grant execute on function public.sync_pull_v1(text) to authenticated;
