-- Assign GTFS stops to Malaysian states from their coordinates.  Feed names
-- alone are not sufficient because the Klang Valley and KTMB feeds cross state
-- boundaries, while stop descriptions are often only road names.

create table if not exists public.malaysia_state_boundaries (
  state text primary key,
  code_state integer not null unique,
  boundary extensions.geometry(MultiPolygon, 4326) not null,
  source_url text not null,
  updated_at timestamptz not null default now()
);

create index if not exists malaysia_state_boundaries_boundary_idx
  on public.malaysia_state_boundaries using gist(boundary);

alter table public.malaysia_state_boundaries enable row level security;
revoke all on public.malaysia_state_boundaries from public, anon, authenticated;
grant select, insert, update, delete on public.malaysia_state_boundaries to service_role;

create or replace function public.canonical_malaysia_state_name(p_value text)
returns text
language sql
immutable
parallel safe
as $$
  select case lower(trim(coalesce(p_value, '')))
    when 'johor' then 'Johor'
    when 'kedah' then 'Kedah'
    when 'kelantan' then 'Kelantan'
    when 'melaka' then 'Melaka'
    when 'malacca' then 'Melaka'
    when 'negeri sembilan' then 'Negeri Sembilan'
    when 'pahang' then 'Pahang'
    when 'pulau pinang' then 'Penang'
    when 'penang' then 'Penang'
    when 'perak' then 'Perak'
    when 'perlis' then 'Perlis'
    when 'sabah' then 'Sabah'
    when 'sarawak' then 'Sarawak'
    when 'selangor' then 'Selangor'
    when 'terengganu' then 'Terengganu'
    when 'w.p. kuala lumpur' then 'Kuala Lumpur'
    when 'wilayah persekutuan kuala lumpur' then 'Kuala Lumpur'
    when 'kuala lumpur' then 'Kuala Lumpur'
    when 'w.p. labuan' then 'Labuan'
    when 'wilayah persekutuan labuan' then 'Labuan'
    when 'labuan' then 'Labuan'
    when 'w.p. putrajaya' then 'Putrajaya'
    when 'wilayah persekutuan putrajaya' then 'Putrajaya'
    when 'putrajaya' then 'Putrajaya'
    else null
  end
$$;

create or replace function public.malaysia_state_for_coordinates(
  p_latitude double precision,
  p_longitude double precision
)
returns text
language sql
stable
parallel safe
set search_path = public, extensions
as $$
  select b.state
  from public.malaysia_state_boundaries b
  where p_latitude between -90 and 90
    and p_longitude between -180 and 180
    and extensions.st_covers(
      b.boundary,
      extensions.st_setsrid(
        extensions.st_makepoint(p_longitude, p_latitude),
        4326
      )
    )
  order by extensions.st_area(b.boundary) asc
  limit 1
$$;

create or replace function public.malaysia_state_for_gtfs_feed(p_feed_id text)
returns text
language sql
immutable
parallel safe
as $$
  select case p_feed_id
    when 'prasarana-rapid-bus-penang' then 'Penang'
    when 'prasarana-rapid-bus-kuantan' then 'Pahang'
    when 'mybas-kangar' then 'Perlis'
    when 'mybas-alor-setar' then 'Kedah'
    when 'mybas-kota-bharu' then 'Kelantan'
    when 'mybas-kuala-terengganu' then 'Terengganu'
    when 'mybas-ipoh' then 'Perak'
    when 'mybas-seremban-a' then 'Negeri Sembilan'
    when 'mybas-seremban-b' then 'Negeri Sembilan'
    when 'mybas-melaka' then 'Melaka'
    when 'mybas-johor' then 'Johor'
    when 'mybas-kuching' then 'Sarawak'
    else null
  end
$$;

-- Restore state filtering immediately for feeds whose entire service area is
-- known to be within one state.  Cross-state feeds are deliberately left for
-- the boundary import below.
update public.eco_partner_catalog c
set state = public.malaysia_state_for_gtfs_feed(s.feed_id)
from public.gtfs_stops s
where c.source = 'gtfs'
  and c.source_id = s.id
  and public.malaysia_state_for_gtfs_feed(s.feed_id) is not null
  and c.state is distinct from public.malaysia_state_for_gtfs_feed(s.feed_id);

create or replace function public.replace_malaysia_state_boundaries(p_geojson jsonb)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_count integer;
begin
  if jsonb_typeof(p_geojson) <> 'object'
     or jsonb_typeof(p_geojson -> 'features') <> 'array' then
    raise exception 'A GeoJSON FeatureCollection is required';
  end if;

  create temporary table incoming_malaysia_state_boundaries (
    state text primary key,
    code_state integer not null unique,
    boundary extensions.geometry(MultiPolygon, 4326) not null
  ) on commit drop;

  insert into incoming_malaysia_state_boundaries(state, code_state, boundary)
  select
    public.canonical_malaysia_state_name(feature -> 'properties' ->> 'state'),
    (feature -> 'properties' ->> 'code_state')::integer,
    extensions.st_multi(
      extensions.st_collectionextract(
        extensions.st_makevalid(
          extensions.st_setsrid(
            extensions.st_geomfromgeojson((feature -> 'geometry')::text),
            4326
          )
        ),
        3
      )
    )::extensions.geometry(MultiPolygon, 4326)
  from jsonb_array_elements(p_geojson -> 'features') as item(feature)
  where public.canonical_malaysia_state_name(
    feature -> 'properties' ->> 'state'
  ) is not null;

  select count(*) into v_count from incoming_malaysia_state_boundaries;
  if v_count <> 16 then
    raise exception 'Expected all 16 Malaysian state boundaries, received %', v_count;
  end if;

  if exists (
    select 1
    from incoming_malaysia_state_boundaries
    where extensions.st_isempty(boundary)
       or not extensions.st_isvalid(boundary)
  ) then
    raise exception 'The state boundary payload contains invalid geometry';
  end if;

  -- Replace only after the complete payload has passed validation.
  delete from public.malaysia_state_boundaries;
  insert into public.malaysia_state_boundaries(
    state, code_state, boundary, source_url, updated_at
  )
  select
    state,
    code_state,
    boundary,
    'https://github.com/dosm-malaysia/data-open/blob/main/datasets/geodata/administrative_1_state.geojson',
    now()
  from incoming_malaysia_state_boundaries;

  -- Repair all existing GTFS catalogue rows immediately.  Coordinate matching
  -- is authoritative; a feed fallback is used only for single-state feeds.
  update public.eco_partner_catalog c
  set state = coalesce(
    public.malaysia_state_for_coordinates(s.latitude, s.longitude),
    public.malaysia_state_for_gtfs_feed(s.feed_id),
    public.malaysia_state_from_text(s.address)
  )
  from public.gtfs_stops s
  where c.source = 'gtfs'
    and c.source_id = s.id;

  return v_count;
end
$$;

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
    coalesce(
      public.malaysia_state_for_coordinates(s.latitude, s.longitude),
      public.malaysia_state_for_gtfs_feed(s.feed_id),
      public.malaysia_state_from_text(s.address)
    ),
    s.address,
    s.latitude, s.longitude,
    coalesce((array_agg(r.mode) filter (where r.mode is not null))[1], 'Bus') || ' public transport',
    case when count(r.id) = 0 then 'Official public transport stop.'
         else 'Scheduled services include: ' || string_agg(distinct coalesce(nullif(r.long_name, ''), nullif(r.short_name, ''), r.mode), ', ') end,
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

revoke all on function public.canonical_malaysia_state_name(text) from public, anon, authenticated;
revoke all on function public.malaysia_state_for_coordinates(double precision, double precision) from public, anon, authenticated;
revoke all on function public.malaysia_state_for_gtfs_feed(text) from public, anon, authenticated;
revoke all on function public.replace_malaysia_state_boundaries(jsonb) from public, anon, authenticated;
grant execute on function public.replace_malaysia_state_boundaries(jsonb) to service_role;
