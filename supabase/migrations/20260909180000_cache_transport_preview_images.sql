-- Cache Mapillary metadata for public-transport stops without making external
-- image requests from Flutter. Rail stops are processed before bus stops.

alter table public.eco_partner_catalog
  add column if not exists image_checked_at timestamptz;

create index if not exists eco_partner_catalog_transport_image_sync_idx
  on public.eco_partner_catalog(image_checked_at, subtype, id)
  where active and source = 'gtfs' and category = 'transport';

create or replace function public.claim_eco_partner_image_sync_batch(
  p_limit integer default 16
)
returns table(
  id text,
  name text,
  latitude double precision,
  longitude double precision,
  subtype text
)
language sql
security definer
set search_path = public
as $$
  with candidates as materialized (
    select c.id
    from public.eco_partner_catalog c
    where c.active
      and c.source = 'gtfs'
      and c.category = 'transport'
      and (
        c.image_checked_at is null
        or c.image_checked_at < now() - interval '30 days'
      )
    order by
      case lower(c.subtype)
        when 'mrt' then 1
        when 'lrt' then 2
        when 'monorail' then 3
        when 'ktm' then 4
        when 'light rail' then 5
        when 'rail' then 6
        else 7
      end,
      c.image_checked_at asc nulls first,
      c.id
    for update skip locked
    limit least(greatest(coalesce(p_limit, 16), 1), 24)
  ), claimed as (
    update public.eco_partner_catalog c
    set image_checked_at = now()
    from candidates
    where c.id = candidates.id
    returning c.id, c.name, c.latitude, c.longitude, c.subtype
  )
  select claimed.id, claimed.name, claimed.latitude,
         claimed.longitude, claimed.subtype
  from claimed
$$;

create or replace function public.complete_eco_partner_image_sync(
  p_id text,
  p_image_url text default null,
  p_image_source_name text default null,
  p_image_source_url text default null,
  p_image_captured_at timestamptz default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_image_url is not null and p_image_url !~* '^https://' then
    raise exception 'Cached image URLs must use HTTPS';
  end if;

  update public.eco_partner_catalog
  set image_url = p_image_url,
      image_source_name = p_image_source_name,
      image_source_url = p_image_source_url,
      image_captured_at = p_image_captured_at,
      image_checked_at = now()
  where id = p_id
    and active
    and source = 'gtfs';

  return found;
end
$$;

create or replace function public.retry_eco_partner_image_sync(p_id text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.eco_partner_catalog
  set image_checked_at = now() - interval '29 days 23 hours'
  where id = p_id
    and active
    and source = 'gtfs'
$$;

revoke all on function public.claim_eco_partner_image_sync_batch(integer)
  from public, anon, authenticated;
revoke all on function public.complete_eco_partner_image_sync(
  text, text, text, text, timestamptz
) from public, anon, authenticated;
revoke all on function public.retry_eco_partner_image_sync(text)
  from public, anon, authenticated;
grant execute on function public.claim_eco_partner_image_sync_batch(integer)
  to service_role;
grant execute on function public.complete_eco_partner_image_sync(
  text, text, text, text, timestamptz
) to service_role;
grant execute on function public.retry_eco_partner_image_sync(text)
  to service_role;

-- Upsert current stops so cached images survive future GTFS replacements.
create or replace function public.refresh_gtfs_eco_partner_catalog(p_feed_id text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  insert into public.eco_partner_catalog (
    id, source, source_id, name, category, subtype, state, address,
    latitude, longitude, sustainability_label, evidence, source_name,
    source_url, source_updated_at, last_synced_at, transit_routes
  )
  select
    'stop:' || s.id,
    'gtfs', s.id, s.name, 'transport',
    coalesce((array_agg(r.mode order by case r.mode
      when 'MRT' then 1 when 'LRT' then 2 when 'Monorail' then 3
      when 'KTM' then 4 else 5 end
    ) filter (where r.mode is not null))[1], 'Bus'),
    coalesce(
      public.malaysia_state_for_coordinates(s.latitude, s.longitude),
      public.malaysia_state_for_gtfs_feed(s.feed_id),
      public.malaysia_state_from_text(s.address)
    ),
    s.address,
    s.latitude, s.longitude,
    coalesce((array_agg(r.mode) filter (where r.mode is not null))[1], 'Bus')
      || ' public transport',
    case when count(r.id) = 0 then 'Official public transport stop.'
         else 'Scheduled services include: ' || string_agg(
           distinct coalesce(nullif(r.long_name, ''), nullif(r.short_name, ''), r.mode),
           ', '
         ) end,
    s.source_name, s.source_url, s.updated_at, now(),
    coalesce(jsonb_agg(distinct jsonb_build_object(
      'mode', r.mode, 'shortName', r.short_name, 'longName', r.long_name
    )) filter (where r.id is not null), '[]'::jsonb)
  from public.gtfs_stops s
  left join public.gtfs_stop_routes sr on sr.stop_id = s.id
  left join public.gtfs_routes r on r.id = sr.route_id
  where s.feed_id = p_feed_id
  group by s.id
  on conflict (id) do update set
    source_id = excluded.source_id,
    name = excluded.name,
    category = excluded.category,
    subtype = excluded.subtype,
    state = excluded.state,
    address = excluded.address,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    sustainability_label = excluded.sustainability_label,
    evidence = excluded.evidence,
    source_name = excluded.source_name,
    source_url = excluded.source_url,
    source_updated_at = excluded.source_updated_at,
    last_synced_at = excluded.last_synced_at,
    transit_routes = excluded.transit_routes,
    active = true;

  delete from public.eco_partner_catalog c
  where c.source = 'gtfs'
    and c.source_id like p_feed_id || ':%'
    and not exists (
      select 1 from public.gtfs_stops s
      where s.feed_id = p_feed_id and s.id = c.source_id
    );
end
$$;

create or replace function public.replace_gtfs_feed(
  p_feed_id text, p_source_url text, p_agencies jsonb, p_stops jsonb,
  p_routes jsonb, p_stop_routes jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.gtfs_stop_routes
  where stop_id in (select id from public.gtfs_stops where feed_id = p_feed_id);
  delete from public.gtfs_routes where feed_id = p_feed_id;
  delete from public.gtfs_stops where feed_id = p_feed_id;
  delete from public.gtfs_agencies where feed_id = p_feed_id;

  insert into public.gtfs_agencies(id, feed_id, agency_id, name, url, timezone)
  select id, feed_id, agency_id, name, url, timezone
  from jsonb_to_recordset(p_agencies)
    as x(id text, feed_id text, agency_id text, name text, url text, timezone text);
  insert into public.gtfs_stops(
    id, feed_id, stop_id, name, address, latitude, longitude,
    source_name, source_url
  )
  select id, feed_id, stop_id, name, coalesce(address, ''), latitude,
         longitude, source_name, source_url
  from jsonb_to_recordset(p_stops)
    as x(id text, feed_id text, stop_id text, name text, address text,
         latitude double precision, longitude double precision,
         source_name text, source_url text);
  insert into public.gtfs_routes(
    id, feed_id, route_id, agency_id, short_name, long_name, route_type, mode
  )
  select id, feed_id, route_id, agency_id, short_name, long_name,
         route_type, mode
  from jsonb_to_recordset(p_routes)
    as x(id text, feed_id text, route_id text, agency_id text,
         short_name text, long_name text, route_type integer, mode text);
  insert into public.gtfs_stop_routes(stop_id, route_id)
  select stop_id, route_id
  from jsonb_to_recordset(p_stop_routes)
    as x(stop_id text, route_id text);

  insert into public.gtfs_feed_status(
    feed_id, source_url, status, last_attempt_at, last_success_at, error
  ) values (p_feed_id, p_source_url, 'success', now(), now(), null)
  on conflict(feed_id) do update set
    source_url = excluded.source_url,
    status = 'success',
    last_attempt_at = now(),
    last_success_at = now(),
    error = null;

  perform public.refresh_gtfs_eco_partner_catalog(p_feed_id);
end
$$;

revoke all on function public.refresh_gtfs_eco_partner_catalog(text)
  from public, anon, authenticated;
revoke all on function public.replace_gtfs_feed(
  text, text, jsonb, jsonb, jsonb, jsonb
) from public, anon, authenticated;
grant execute on function public.refresh_gtfs_eco_partner_catalog(text)
  to service_role;
grant execute on function public.replace_gtfs_feed(
  text, text, jsonb, jsonb, jsonb, jsonb
) to service_role;
