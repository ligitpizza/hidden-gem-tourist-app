create extension if not exists postgis with schema extensions;
create extension if not exists pg_trgm with schema extensions;

create table if not exists public.eco_partner_catalog (
  id text primary key,
  source text not null check (source in ('gstc', 'gtfs', 'osm', 'manual')),
  source_id text not null,
  name text not null,
  category text not null check (category in ('stay', 'dining', 'transport')),
  subtype text not null,
  state text,
  address text not null default '',
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  location extensions.geography(point, 4326)
    generated always as (
      extensions.st_setsrid(extensions.st_makepoint(longitude, latitude), 4326)::extensions.geography
    ) stored,
  sustainability_label text not null default '',
  evidence text not null default '',
  source_name text not null,
  source_url text not null default '',
  source_updated_at timestamptz not null default now(),
  last_synced_at timestamptz not null default now(),
  price_band text,
  website text,
  image_url text,
  image_source_name text,
  image_source_url text,
  image_captured_at timestamptz,
  transit_routes jsonb not null default '[]'::jsonb check (jsonb_typeof(transit_routes) = 'array'),
  vegan_classification text check (vegan_classification in ('Vegan', 'Vegetarian')),
  charging_details jsonb check (charging_details is null or jsonb_typeof(charging_details) = 'object'),
  gstc_verified boolean not null default false,
  active boolean not null default true,
  unique (source, source_id)
);

create index if not exists eco_partner_catalog_location_idx
  on public.eco_partner_catalog using gist(location);
create index if not exists eco_partner_catalog_state_category_idx
  on public.eco_partner_catalog(state, category, subtype)
  where active;
create index if not exists eco_partner_catalog_name_trgm_idx
  on public.eco_partner_catalog using gin(lower(name) extensions.gin_trgm_ops)
  where active;

alter table public.eco_partner_catalog enable row level security;
revoke all on public.eco_partner_catalog from anon;
grant select on public.eco_partner_catalog to authenticated;

drop policy if exists "Authenticated users read Eco Partner catalogue"
  on public.eco_partner_catalog;
create policy "Authenticated users read Eco Partner catalogue"
  on public.eco_partner_catalog for select
  to authenticated using (active);

create or replace function public.malaysia_state_from_text(p_value text)
returns text
language sql
immutable
parallel safe
as $$
  select case
    when p_value ~* '(^|[^a-z])johor([^a-z]|$)' then 'Johor'
    when p_value ~* '(^|[^a-z])kedah([^a-z]|$)' then 'Kedah'
    when p_value ~* '(^|[^a-z])kelantan([^a-z]|$)' then 'Kelantan'
    when p_value ~* '(^|[^a-z])kuala[[:space:]]+lumpur([^a-z]|$)' then 'Kuala Lumpur'
    when p_value ~* '(^|[^a-z])labuan([^a-z]|$)' then 'Labuan'
    when p_value ~* '(^|[^a-z])(melaka|malacca)([^a-z]|$)' then 'Melaka'
    when p_value ~* '(^|[^a-z])negeri[[:space:]]+sembilan([^a-z]|$)' then 'Negeri Sembilan'
    when p_value ~* '(^|[^a-z])pahang([^a-z]|$)' then 'Pahang'
    when p_value ~* '(^|[^a-z])(penang|pulau[[:space:]]+pinang)([^a-z]|$)' then 'Penang'
    when p_value ~* '(^|[^a-z])perak([^a-z]|$)' then 'Perak'
    when p_value ~* '(^|[^a-z])perlis([^a-z]|$)' then 'Perlis'
    when p_value ~* '(^|[^a-z])putrajaya([^a-z]|$)' then 'Putrajaya'
    when p_value ~* '(^|[^a-z])sabah([^a-z]|$)' then 'Sabah'
    when p_value ~* '(^|[^a-z])sarawak([^a-z]|$)' then 'Sarawak'
    when p_value ~* '(^|[^a-z])selangor([^a-z]|$)' then 'Selangor'
    when p_value ~* '(^|[^a-z])(terengganu|trengganu)([^a-z]|$)' then 'Terengganu'
    else null
  end
$$;

insert into public.eco_partner_catalog (
  id, source, source_id, name, category, subtype, state, address,
  latitude, longitude, sustainability_label, evidence, source_name,
  source_url, source_updated_at, last_synced_at, price_band, website,
  image_url, gstc_verified
)
select
  'hotel:' || h.id::text,
  'gstc', h.id::text, h.name, 'stay', 'Hotel',
  public.malaysia_state_from_text(h.address), h.address,
  h.latitude, h.longitude,
  case when h.gstc_certified then 'GSTC verified' else 'Certification not verified' end,
  concat_ws(' · ', h.certification_body, h.certification_evidence_url),
  'GSTC Certified Hotels Directory',
  coalesce(h.certification_evidence_url, ''), h.updated_at, now(),
  h.price_band, h.website_url, h.image_url, h.gstc_certified
from public.eco_hotels h
on conflict (id) do update set
  name = excluded.name,
  state = excluded.state,
  address = excluded.address,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  sustainability_label = excluded.sustainability_label,
  evidence = excluded.evidence,
  source_url = excluded.source_url,
  source_updated_at = excluded.source_updated_at,
  last_synced_at = excluded.last_synced_at,
  price_band = excluded.price_band,
  website = excluded.website,
  image_url = excluded.image_url,
  gstc_verified = excluded.gstc_verified,
  active = true;

insert into public.eco_partner_catalog (
  id, source, source_id, name, category, subtype, state, address,
  latitude, longitude, sustainability_label, evidence, source_name,
  source_url, source_updated_at, last_synced_at, transit_routes
)
select
  'stop:' || s.id,
  'gtfs', s.id, s.name, 'transport',
  coalesce((array_agg(r.mode order by case r.mode when 'MRT' then 1 when 'LRT' then 2 when 'Monorail' then 3 when 'KTM' then 4 else 5 end)
    filter (where r.mode is not null))[1], 'Bus'),
  public.malaysia_state_from_text(s.address), s.address,
  s.latitude, s.longitude, 'Public transport',
  case when count(r.id) = 0 then 'Official GTFS stop'
       else 'Routes: ' || string_agg(distinct coalesce(nullif(r.long_name, ''), nullif(r.short_name, ''), r.mode), ', ') end,
  s.source_name, s.source_url, s.updated_at, now(),
  coalesce(jsonb_agg(distinct jsonb_build_object(
    'mode', r.mode, 'shortName', r.short_name, 'longName', r.long_name
  )) filter (where r.id is not null), '[]'::jsonb)
from public.gtfs_stops s
left join public.gtfs_stop_routes sr on sr.stop_id = s.id
left join public.gtfs_routes r on r.id = sr.route_id
group by s.id
on conflict (id) do update set
  name = excluded.name,
  subtype = excluded.subtype,
  state = excluded.state,
  address = excluded.address,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  evidence = excluded.evidence,
  source_name = excluded.source_name,
  source_url = excluded.source_url,
  source_updated_at = excluded.source_updated_at,
  last_synced_at = excluded.last_synced_at,
  transit_routes = excluded.transit_routes,
  active = true;

create or replace function public.sync_eco_hotel_catalog()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.eco_partner_catalog where id = 'hotel:' || old.id::text;
    return old;
  end if;
  insert into public.eco_partner_catalog (
    id, source, source_id, name, category, subtype, state, address,
    latitude, longitude, sustainability_label, evidence, source_name,
    source_url, source_updated_at, last_synced_at, price_band, website,
    image_url, gstc_verified
  ) values (
    'hotel:' || new.id::text, 'gstc', new.id::text, new.name, 'stay', 'Hotel',
    public.malaysia_state_from_text(new.address), new.address,
    new.latitude, new.longitude,
    case when new.gstc_certified then 'GSTC verified' else 'Certification not verified' end,
    concat_ws(' · ', new.certification_body, new.certification_evidence_url),
    'GSTC Certified Hotels Directory', coalesce(new.certification_evidence_url, ''),
    new.updated_at, now(), new.price_band, new.website_url, new.image_url,
    new.gstc_certified
  )
  on conflict (id) do update set
    name = excluded.name, state = excluded.state, address = excluded.address,
    latitude = excluded.latitude, longitude = excluded.longitude,
    sustainability_label = excluded.sustainability_label,
    evidence = excluded.evidence, source_url = excluded.source_url,
    source_updated_at = excluded.source_updated_at,
    last_synced_at = excluded.last_synced_at, price_band = excluded.price_band,
    website = excluded.website, image_url = excluded.image_url,
    gstc_verified = excluded.gstc_verified, active = true;
  return new;
end
$$;

drop trigger if exists eco_hotels_sync_catalog on public.eco_hotels;
create trigger eco_hotels_sync_catalog
after insert or update or delete on public.eco_hotels
for each row execute function public.sync_eco_hotel_catalog();

create or replace function public.refresh_gtfs_eco_partner_catalog(p_feed_id text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  delete from public.eco_partner_catalog c
  where c.source = 'gtfs'
    and c.source_id in (
      select s.id from public.gtfs_stops s where s.feed_id = p_feed_id
    );

  insert into public.eco_partner_catalog (
    id, source, source_id, name, category, subtype, state, address,
    latitude, longitude, sustainability_label, evidence, source_name,
    source_url, source_updated_at, last_synced_at, transit_routes
  )
  select
    'stop:' || s.id,
    'gtfs', s.id, s.name, 'transport',
    coalesce((array_agg(r.mode order by case r.mode when 'MRT' then 1 when 'LRT' then 2 when 'Monorail' then 3 when 'KTM' then 4 else 5 end)
      filter (where r.mode is not null))[1], 'Bus'),
    public.malaysia_state_from_text(s.address), s.address,
    s.latitude, s.longitude,
    coalesce((array_agg(r.mode) filter (where r.mode is not null))[1], 'Bus') || ' public transport',
    case when count(r.id) = 0 then 'Official GTFS stop'
         else 'Routes: ' || string_agg(distinct coalesce(nullif(r.long_name, ''), nullif(r.short_name, ''), r.mode), ', ') end,
    s.source_name, s.source_url, s.updated_at, now(),
    coalesce(jsonb_agg(distinct jsonb_build_object(
      'mode', r.mode, 'shortName', r.short_name, 'longName', r.long_name
    )) filter (where r.id is not null), '[]'::jsonb)
  from public.gtfs_stops s
  left join public.gtfs_stop_routes sr on sr.stop_id = s.id
  left join public.gtfs_routes r on r.id = sr.route_id
  where s.feed_id = p_feed_id
  group by s.id;
end
$$;

create or replace function public.replace_gtfs_feed(
  p_feed_id text, p_source_url text, p_agencies jsonb, p_stops jsonb,
  p_routes jsonb, p_stop_routes jsonb
) returns void language plpgsql security definer set search_path = public as $$
begin
  delete from eco_partner_catalog
  where source = 'gtfs'
    and source_id in (select id from gtfs_stops where feed_id = p_feed_id);
  delete from gtfs_stop_routes where stop_id in (select id from gtfs_stops where feed_id = p_feed_id);
  delete from gtfs_routes where feed_id = p_feed_id;
  delete from gtfs_stops where feed_id = p_feed_id;
  delete from gtfs_agencies where feed_id = p_feed_id;

  insert into gtfs_agencies(id, feed_id, agency_id, name, url, timezone)
    select id, feed_id, agency_id, name, url, timezone from jsonb_to_recordset(p_agencies)
    as x(id text, feed_id text, agency_id text, name text, url text, timezone text);
  insert into gtfs_stops(id, feed_id, stop_id, name, address, latitude, longitude, source_name, source_url)
    select id, feed_id, stop_id, name, coalesce(address,''), latitude, longitude, source_name, source_url
    from jsonb_to_recordset(p_stops) as x(id text, feed_id text, stop_id text, name text, address text, latitude double precision, longitude double precision, source_name text, source_url text);
  insert into gtfs_routes(id, feed_id, route_id, agency_id, short_name, long_name, route_type, mode)
    select id, feed_id, route_id, agency_id, short_name, long_name, route_type, mode
    from jsonb_to_recordset(p_routes) as x(id text, feed_id text, route_id text, agency_id text, short_name text, long_name text, route_type integer, mode text);
  insert into gtfs_stop_routes(stop_id, route_id)
    select stop_id, route_id from jsonb_to_recordset(p_stop_routes) as x(stop_id text, route_id text);
  insert into gtfs_feed_status(feed_id, source_url, status, last_attempt_at, last_success_at, error)
    values(p_feed_id, p_source_url, 'success', now(), now(), null)
    on conflict(feed_id) do update set source_url=excluded.source_url, status='success', last_attempt_at=now(), last_success_at=now(), error=null;

  perform public.refresh_gtfs_eco_partner_catalog(p_feed_id);
end $$;

revoke all on function public.refresh_gtfs_eco_partner_catalog(text) from public, anon, authenticated;
revoke all on function public.replace_gtfs_feed(text,text,jsonb,jsonb,jsonb,jsonb) from public, anon, authenticated;
grant execute on function public.refresh_gtfs_eco_partner_catalog(text) to service_role;
grant execute on function public.replace_gtfs_feed(text,text,jsonb,jsonb,jsonb,jsonb) to service_role;

create table if not exists public.eco_partner_sync_regions (
  state text primary key,
  iso_code text not null unique,
  status text not null default 'pending' check (status in ('pending', 'running', 'success', 'failed')),
  next_sync_at timestamptz not null default now(),
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  error text
);

insert into public.eco_partner_sync_regions(state, iso_code) values
  ('Johor', 'MY-01'), ('Kedah', 'MY-02'), ('Kelantan', 'MY-03'),
  ('Melaka', 'MY-04'), ('Negeri Sembilan', 'MY-05'), ('Pahang', 'MY-06'),
  ('Penang', 'MY-07'), ('Perak', 'MY-08'), ('Perlis', 'MY-09'),
  ('Selangor', 'MY-10'), ('Terengganu', 'MY-11'), ('Sabah', 'MY-12'),
  ('Sarawak', 'MY-13'), ('Kuala Lumpur', 'MY-14'), ('Labuan', 'MY-15'),
  ('Putrajaya', 'MY-16')
on conflict (state) do update set iso_code = excluded.iso_code;

alter table public.eco_partner_sync_regions enable row level security;
revoke all on public.eco_partner_sync_regions from anon, authenticated;

create or replace function public.claim_eco_partner_sync_region()
returns table(state text, iso_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  selected public.eco_partner_sync_regions%rowtype;
begin
  select * into selected
  from public.eco_partner_sync_regions r
  where r.next_sync_at <= now()
    and (r.status <> 'running' or r.last_attempt_at < now() - interval '20 minutes')
  order by r.next_sync_at, r.state
  for update skip locked
  limit 1;

  if not found then return; end if;

  update public.eco_partner_sync_regions r
  set status = 'running', last_attempt_at = now(), error = null
  where r.state = selected.state;

  return query select selected.state, selected.iso_code;
end
$$;

create or replace function public.replace_eco_partner_region(
  p_source text,
  p_state text,
  p_rows jsonb
)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  inserted_count integer;
begin
  if p_source <> 'osm' then
    raise exception 'replace_eco_partner_region only accepts the osm source';
  end if;
  if not exists (select 1 from public.eco_partner_sync_regions where state = p_state) then
    raise exception 'Unknown Malaysian state: %', p_state;
  end if;
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'p_rows must be a JSON array';
  end if;

  insert into public.eco_partner_catalog (
    id, source, source_id, name, category, subtype, state, address,
    latitude, longitude, sustainability_label, evidence, source_name,
    source_url, source_updated_at, last_synced_at, website,
    image_url, image_source_name, image_source_url, image_captured_at,
    vegan_classification, charging_details
  )
  select
    x.id, p_source, x.source_id, x.name, x.category, x.subtype, p_state,
    coalesce(x.address, ''), x.latitude, x.longitude,
    coalesce(x.sustainability_label, ''), coalesce(x.evidence, ''),
    coalesce(x.source_name, 'OpenStreetMap contributors'),
    coalesce(x.source_url, ''), coalesce(x.source_updated_at, now()), now(),
    x.website, x.image_url, x.image_source_name, x.image_source_url,
    x.image_captured_at, x.vegan_classification, x.charging_details
  from jsonb_to_recordset(p_rows) as x(
    id text, source_id text, name text, category text, subtype text,
    address text, latitude double precision, longitude double precision,
    sustainability_label text, evidence text, source_name text,
    source_url text, source_updated_at timestamptz, website text,
    image_url text, image_source_name text, image_source_url text,
    image_captured_at timestamptz, vegan_classification text,
    charging_details jsonb
  )
  on conflict (id) do update set
    name = excluded.name, category = excluded.category,
    subtype = excluded.subtype, state = excluded.state,
    address = excluded.address, latitude = excluded.latitude,
    longitude = excluded.longitude,
    sustainability_label = excluded.sustainability_label,
    evidence = excluded.evidence, source_name = excluded.source_name,
    source_url = excluded.source_url,
    source_updated_at = excluded.source_updated_at,
    last_synced_at = excluded.last_synced_at,
    website = excluded.website,
    image_url = coalesce(excluded.image_url, eco_partner_catalog.image_url),
    image_source_name = coalesce(excluded.image_source_name, eco_partner_catalog.image_source_name),
    image_source_url = coalesce(excluded.image_source_url, eco_partner_catalog.image_source_url),
    image_captured_at = coalesce(excluded.image_captured_at, eco_partner_catalog.image_captured_at),
    vegan_classification = excluded.vegan_classification,
    charging_details = excluded.charging_details,
    active = true;
  get diagnostics inserted_count = row_count;

  delete from public.eco_partner_catalog c
  where c.source = p_source
    and c.state = p_state
    and not exists (
      select 1
      from jsonb_array_elements(p_rows) row_value
      where row_value ->> 'id' = c.id
    );
  return inserted_count;
end
$$;

revoke all on function public.claim_eco_partner_sync_region() from public, anon, authenticated;
revoke all on function public.replace_eco_partner_region(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.claim_eco_partner_sync_region() to service_role;
grant execute on function public.replace_eco_partner_region(text, text, jsonb) to service_role;

create or replace function public.invoke_eco_partner_sync()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  sync_url text;
  sync_secret text;
begin
  begin
    execute 'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
      into sync_url using 'eco_partner_sync_url';
    execute 'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
      into sync_secret using 'eco_partner_sync_secret';
  exception when undefined_table or undefined_function then
    return;
  end;
  if sync_url is null or sync_secret is null then return; end if;
  execute 'select net.http_post(url := $1, headers := $2::jsonb, body := $3::jsonb)'
    using sync_url,
      jsonb_build_object('content-type', 'application/json', 'x-sync-secret', sync_secret),
      '{}'::jsonb;
exception when undefined_function then
  return;
end
$$;

revoke all on function public.invoke_eco_partner_sync() from public, anon, authenticated;
grant execute on function public.invoke_eco_partner_sync() to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'sync-eco-partners') then
      perform cron.unschedule('sync-eco-partners');
    end if;
    perform cron.schedule(
      'sync-eco-partners',
      '*/10 * * * *',
      $cron$select public.invoke_eco_partner_sync();$cron$
    );
  end if;
end
$$;

create or replace function public.search_eco_partners(
  p_query text default null,
  p_state text default null,
  p_category text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km double precision default null,
  p_sort text default 'recommended',
  p_limit integer default 50,
  p_offset integer default 0
)
returns table(
  id text, name text, category text, subtype text, state text, address text,
  latitude double precision, longitude double precision,
  sustainability_label text, evidence text, source_name text, source_url text,
  source_updated_at timestamptz, price_band text, website text,
  image_url text, image_source_name text, image_source_url text,
  image_captured_at timestamptz, transit_routes jsonb,
  vegan_classification text, charging_details jsonb, gstc_verified boolean,
  distance_km double precision, total_count bigint
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with candidates as (
    select
      c.*,
      case when p_latitude is not null and p_longitude is not null then
        extensions.st_distance(
          c.location,
          extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography
        ) / 1000.0
      else 0.0 end as computed_distance,
      case
        when c.gstc_verified then 100
        when c.vegan_classification = 'Vegan' then 90
        when c.subtype in ('MRT', 'LRT', 'Monorail', 'KTM') then 85
        when c.subtype = 'EV charging' then 80
        when c.vegan_classification = 'Vegetarian' then 75
        when c.subtype = 'Bus' then 70
        else 50
      end as recommendation_score
    from public.eco_partner_catalog c
    where c.active
      and (nullif(trim(p_query), '') is null or lower(c.name) like '%' || lower(trim(p_query)) || '%')
      and (p_state is null or c.state = p_state)
      and (
        p_category is null
        or p_category = c.category
        or (p_category = 'ev' and c.subtype = 'EV charging')
        or (p_category = 'public_transport' and c.category = 'transport' and c.subtype <> 'EV charging')
      )
      and (
        p_radius_km is null
        or (
          p_latitude is not null and p_longitude is not null
          and extensions.st_dwithin(
            c.location,
            extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography,
            p_radius_km * 1000.0
          )
        )
      )
  ), counted as (
    select candidates.*, count(*) over() as match_count
    from candidates
  )
  select
    c.id, c.name, c.category, c.subtype, c.state, c.address,
    c.latitude, c.longitude, c.sustainability_label, c.evidence,
    c.source_name, c.source_url, c.source_updated_at, c.price_band,
    c.website, c.image_url, c.image_source_name, c.image_source_url,
    c.image_captured_at, c.transit_routes, c.vegan_classification,
    c.charging_details, c.gstc_verified, c.computed_distance,
    c.match_count
  from counted c
  order by
    case when p_sort = 'name_asc' then lower(c.name) end asc,
    case when p_sort = 'name_desc' then lower(c.name) end desc,
    case when p_sort = 'recommended' then c.recommendation_score end desc,
    case when p_sort = 'recommended' then c.computed_distance end asc,
    lower(c.name) asc
  limit least(greatest(coalesce(p_limit, 50), 1), 500)
  offset greatest(coalesce(p_offset, 0), 0)
$$;

create or replace function public.eco_partner_home(
  p_state text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km double precision default null,
  p_per_section integer default 8
)
returns jsonb
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with scoped as (
    select
      c.*,
      case when p_latitude is not null and p_longitude is not null then
        extensions.st_distance(
          c.location,
          extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography
        ) / 1000.0
      else 0.0 end as distance_km,
      case
        when c.gstc_verified then 100
        when c.vegan_classification = 'Vegan' then 90
        when c.subtype in ('MRT', 'LRT', 'Monorail', 'KTM') then 85
        when c.subtype = 'EV charging' then 80
        when c.vegan_classification = 'Vegetarian' then 75
        when c.subtype = 'Bus' then 70
        else 50
      end as score
    from public.eco_partner_catalog c
    where c.active
      and (p_state is null or c.state = p_state)
      and (
        p_radius_km is null
        or (
          p_latitude is not null and p_longitude is not null
          and extensions.st_dwithin(
            c.location,
            extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography,
            p_radius_km * 1000.0
          )
        )
      )
  )
  select jsonb_build_object(
    'recommended', coalesce((select jsonb_agg(to_jsonb(x) - 'location' - 'score') from (select * from scoped order by score desc, distance_km, name limit least(greatest(p_per_section, 1), 20)) x), '[]'::jsonb),
    'hotel', coalesce((select jsonb_agg(to_jsonb(x) - 'location' - 'score') from (select * from scoped where category = 'stay' order by score desc, distance_km, name limit least(greatest(p_per_section, 1), 20)) x), '[]'::jsonb),
    'dining', coalesce((select jsonb_agg(to_jsonb(x) - 'location' - 'score') from (select * from scoped where category = 'dining' order by score desc, distance_km, name limit least(greatest(p_per_section, 1), 20)) x), '[]'::jsonb),
    'transport', coalesce((select jsonb_agg(to_jsonb(x) - 'location' - 'score') from (select * from scoped where category = 'transport' and subtype <> 'EV charging' order by score desc, distance_km, name limit least(greatest(p_per_section, 1), 20)) x), '[]'::jsonb),
    'ev', coalesce((select jsonb_agg(to_jsonb(x) - 'location' - 'score') from (select * from scoped where subtype = 'EV charging' order by score desc, distance_km, name limit least(greatest(p_per_section, 1), 20)) x), '[]'::jsonb)
  )
$$;

revoke all on function public.search_eco_partners(text, text, text, double precision, double precision, double precision, text, integer, integer) from public, anon;
revoke all on function public.eco_partner_home(text, double precision, double precision, double precision, integer) from public, anon;
grant execute on function public.search_eco_partners(text, text, text, double precision, double precision, double precision, text, integer, integer) to authenticated;
grant execute on function public.eco_partner_home(text, double precision, double precision, double precision, integer) to authenticated;
