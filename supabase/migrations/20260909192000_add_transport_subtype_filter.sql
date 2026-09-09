-- Add server-side public-transport mode filters without changing the RPC
-- signature, so already-released clients remain compatible.

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
          extensions.st_setsrid(
            extensions.st_makepoint(p_longitude, p_latitude), 4326
          )::extensions.geography
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
      and (
        nullif(trim(p_query), '') is null
        or lower(c.name) like '%' || lower(trim(p_query)) || '%'
      )
      and (p_state is null or c.state = p_state)
      and (
        p_category is null
        or p_category = c.category
        or (
          lower(p_category) = 'ev'
          and c.category = 'transport'
          and lower(c.subtype) = 'ev charging'
        )
        or (
          lower(p_category) = 'public_transport'
          and c.category = 'transport'
          and lower(c.subtype) <> 'ev charging'
        )
        or (
          lower(p_category) = 'transport_bus'
          and c.category = 'transport'
          and lower(c.subtype) = 'bus'
        )
        or (
          lower(p_category) = 'transport_mrt'
          and c.category = 'transport'
          and lower(c.subtype) = 'mrt'
        )
        or (
          lower(p_category) = 'transport_lrt'
          and c.category = 'transport'
          and lower(c.subtype) in ('lrt', 'light rail')
        )
        or (
          lower(p_category) = 'transport_monorail'
          and c.category = 'transport'
          and lower(c.subtype) = 'monorail'
        )
        or (
          lower(p_category) = 'transport_ktm'
          and c.category = 'transport'
          and lower(c.subtype) = 'ktm'
        )
        or (
          lower(p_category) = 'transport_rail'
          and c.category = 'transport'
          and lower(c.subtype) = 'rail'
        )
      )
      and (
        p_radius_km is null
        or (
          p_latitude is not null and p_longitude is not null
          and extensions.st_dwithin(
            c.location,
            extensions.st_setsrid(
              extensions.st_makepoint(p_longitude, p_latitude), 4326
            )::extensions.geography,
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

revoke all on function public.search_eco_partners(
  text, text, text, double precision, double precision, double precision,
  text, integer, integer
) from public, anon;
grant execute on function public.search_eco_partners(
  text, text, text, double precision, double precision, double precision,
  text, integer, integer
) to authenticated;
