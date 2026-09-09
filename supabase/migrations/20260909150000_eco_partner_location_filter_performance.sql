-- Eco Partner browsing polish: nullable distances, canonical EV filtering,
-- conservative state inference, and an active category/subtype index.

create or replace function public.malaysia_state_from_text(p_value text)
returns text
language sql
immutable
parallel safe
as $$
  with components as (
    select lower(trim(component)) as value
    from regexp_split_to_table(coalesce(p_value, ''), ',') as parts(component)
  )
  select case
    when exists (select 1 from components where value = 'johor') then 'Johor'
    when exists (select 1 from components where value = 'kedah') then 'Kedah'
    when exists (select 1 from components where value = 'kelantan') then 'Kelantan'
    when exists (select 1 from components where value in ('kuala lumpur', 'wilayah persekutuan kuala lumpur')) then 'Kuala Lumpur'
    when exists (select 1 from components where value in ('labuan', 'wilayah persekutuan labuan')) then 'Labuan'
    when exists (select 1 from components where value in ('melaka', 'malacca')) then 'Melaka'
    when exists (select 1 from components where value = 'negeri sembilan') then 'Negeri Sembilan'
    when exists (select 1 from components where value = 'pahang') then 'Pahang'
    when exists (select 1 from components where value in ('penang', 'pulau pinang')) then 'Penang'
    when exists (select 1 from components where value = 'perak') then 'Perak'
    when exists (select 1 from components where value = 'perlis') then 'Perlis'
    when exists (select 1 from components where value in ('putrajaya', 'wilayah persekutuan putrajaya')) then 'Putrajaya'
    when exists (select 1 from components where value = 'sabah') then 'Sabah'
    when exists (select 1 from components where value = 'sarawak') then 'Sarawak'
    when exists (select 1 from components where value = 'selangor') then 'Selangor'
    when exists (select 1 from components where value in ('terengganu', 'trengganu')) then 'Terengganu'
    else null
  end
$$;

-- OSM states come from the trusted ISO3166-2 sync region and are deliberately
-- left untouched. Only address-derived catalogue rows are repaired.
update public.eco_partner_catalog
set state = public.malaysia_state_from_text(address)
where source in ('gstc', 'gtfs')
  and state is distinct from public.malaysia_state_from_text(address);

update public.eco_partner_catalog
set subtype = 'EV charging'
where active
  and category = 'transport'
  and (
    charging_details is not null
    or regexp_replace(lower(subtype), '[^a-z0-9]+', '', 'g')
       in ('ev', 'evcharging', 'chargingstation', 'vehiclecharging')
  )
  and subtype is distinct from 'EV charging';

update public.eco_partner_catalog
set evidence = case
  when lower(trim(evidence)) = 'openstreetmap diet:vegan tag'
    then 'Listed as vegan-friendly.'
  when lower(trim(evidence)) = 'openstreetmap diet:vegetarian tag'
    then 'Listed as vegetarian-friendly.'
  when lower(trim(evidence)) = 'openstreetmap charging station tags'
    then 'Listed as an electric vehicle charging station.'
  when lower(trim(evidence)) = 'official gtfs stop'
    then 'Official public transport stop.'
  when lower(evidence) like 'routes:%'
    then 'Scheduled services include:' || substring(evidence from position(':' in evidence) + 1)
  else evidence
end
where lower(trim(evidence)) in (
    'openstreetmap diet:vegan tag',
    'openstreetmap diet:vegetarian tag',
    'openstreetmap charging station tags',
    'official gtfs stop'
  )
  or lower(evidence) like 'routes:%';

create index if not exists eco_partner_catalog_active_category_subtype_idx
  on public.eco_partner_catalog(category, lower(subtype))
  where active;

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
      else null::double precision end as computed_distance,
      case
        when c.gstc_verified then 100
        when c.vegan_classification = 'Vegan' then 90
        when c.subtype in ('MRT', 'LRT', 'Monorail', 'KTM') then 85
        when lower(c.subtype) = 'ev charging' then 80
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
        or (lower(p_category) = 'ev' and c.category = 'transport' and lower(c.subtype) = 'ev charging')
        or (lower(p_category) = 'public_transport' and c.category = 'transport' and lower(c.subtype) <> 'ev charging')
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
    case when p_sort = 'recommended' then c.computed_distance end asc nulls last,
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
      else null::double precision end as distance_km,
      case
        when c.gstc_verified then 100
        when c.vegan_classification = 'Vegan' then 90
        when c.subtype in ('MRT', 'LRT', 'Monorail', 'KTM') then 85
        when lower(c.subtype) = 'ev charging' then 80
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
    'recommended', coalesce((select jsonb_agg(to_jsonb(x) - 'location' - 'score') from (select * from scoped order by score desc, distance_km asc nulls last, name limit least(greatest(p_per_section, 1), 20)) x), '[]'::jsonb),
    'hotel', coalesce((select jsonb_agg(to_jsonb(x) - 'location' - 'score') from (select * from scoped where category = 'stay' order by score desc, distance_km asc nulls last, name limit least(greatest(p_per_section, 1), 20)) x), '[]'::jsonb),
    'dining', coalesce((select jsonb_agg(to_jsonb(x) - 'location' - 'score') from (select * from scoped where category = 'dining' order by score desc, distance_km asc nulls last, name limit least(greatest(p_per_section, 1), 20)) x), '[]'::jsonb),
    'transport', coalesce((select jsonb_agg(to_jsonb(x) - 'location' - 'score') from (select * from scoped where category = 'transport' and lower(subtype) <> 'ev charging' order by score desc, distance_km asc nulls last, name limit least(greatest(p_per_section, 1), 20)) x), '[]'::jsonb),
    'ev', coalesce((select jsonb_agg(to_jsonb(x) - 'location' - 'score') from (select * from scoped where category = 'transport' and lower(subtype) = 'ev charging' order by score desc, distance_km asc nulls last, name limit least(greatest(p_per_section, 1), 20)) x), '[]'::jsonb)
  )
$$;

revoke all on function public.search_eco_partners(text, text, text, double precision, double precision, double precision, text, integer, integer) from public, anon;
revoke all on function public.eco_partner_home(text, double precision, double precision, double precision, integer) from public, anon;
grant execute on function public.search_eco_partners(text, text, text, double precision, double precision, double precision, text, integer, integer) to authenticated;
grant execute on function public.eco_partner_home(text, double precision, double precision, double precision, integer) to authenticated;
