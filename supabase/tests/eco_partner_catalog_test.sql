begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(44);

select has_table('public', 'eco_partner_catalog', 'catalogue table exists');
select has_index(
  'public',
  'eco_partner_catalog',
  'eco_partner_catalog_location_idx',
  'catalogue has a spatial index'
);
select has_table(
  'public',
  'eco_partner_preview_assets',
  'transport preview mapping table exists'
);
select is(
  (select count(*) from public.eco_partner_preview_assets),
  37::bigint,
  'all representative preview assets are registered'
);
select has_index(
  'public',
  'eco_partner_catalog',
  'eco_partner_catalog_active_category_subtype_idx',
  'catalogue has an active category/subtype index'
);
select has_index(
  'public',
  'eco_partner_catalog',
  'eco_partner_catalog_name_trgm_idx',
  'catalogue has a trigram name index'
);
select has_table(
  'public',
  'malaysia_state_boundaries',
  'Malaysia state boundaries table exists'
);
select has_index(
  'public',
  'malaysia_state_boundaries',
  'malaysia_state_boundaries_boundary_idx',
  'state boundaries have a spatial index'
);
select is(
  public.canonical_malaysia_state_name('W.P. Kuala Lumpur'),
  'Kuala Lumpur'::text,
  'official boundary state names are canonicalized for the app'
);
select is(
  public.malaysia_state_for_gtfs_feed('mybas-seremban-a'),
  'Negeri Sembilan'::text,
  'single-state GTFS feeds have a safe fallback state'
);
select is(
  public.eco_partner_transport_preview_key(
    'prasarana-rapid-bus-kl',
    'Bus'
  ),
  'rapid-kl-bus'::text,
  'an actual Rapid KL bus receives its operator preview'
);
select is(
  public.eco_partner_transport_preview_key(
    'prasarana-rapid-bus-kl',
    'LRT'
  ),
  'lrt'::text,
  'an LRT subtype overrides bus-feed branding'
);
select is(
  public.eco_partner_transport_preview_key(
    'prasarana-rapid-bus-mrtfeeder',
    'MRT'
  ),
  'mrt'::text,
  'an MRT subtype overrides feeder-bus branding'
);
select is(
  public.eco_partner_transport_preview_key('unknown-feed', 'LRT'),
  'lrt'::text,
  'unknown feeds fall back to their transport mode'
);
select is(
  public.eco_partner_transport_preview_key('ktmb', 'Bus'),
  'ktm'::text,
  'KTMB feed takes precedence over a stop subtype'
);
select is(
  public.eco_partner_transport_preview_key(
    'prasarana-rapid-bus-penang',
    'Bus'
  ),
  'rapid-penang-bus'::text,
  'Rapid Penang receives its operator preview'
);
select is(
  public.eco_partner_transport_preview_key('mybas-johor', 'Bus'),
  'bas-my-bus'::text,
  'BAS.MY feeds receive their operator preview'
);
select ok(
  public.eco_partner_transport_preview_key_for_partner(
    'stop:stable-preview-test', 'unknown-feed', 'LRT'
  ) in ('lrt', 'lrt-2', 'lrt-3'),
  'a transport partner receives one of three previews for its mode'
);
select is(
  public.eco_partner_transport_preview_key_for_partner(
    'stop:stable-preview-test', 'unknown-feed', 'LRT'
  ),
  public.eco_partner_transport_preview_key_for_partner(
    'stop:stable-preview-test', 'unknown-feed', 'LRT'
  ),
  'transport preview assignment is stable for the same partner'
);
select like(
  public.eco_partner_category_preview_key(
    'osm:node:dining-preview-test', 'dining', 'Restaurant'
  ),
  'dining-%',
  'dining partners receive a deterministic dining preview key'
);
select like(
  public.eco_partner_category_preview_key(
    'osm:node:ev-preview-test', 'transport', 'EV charging'
  ),
  'ev-%',
  'EV partners receive a deterministic EV preview key'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.eco_partner_preview_assets'::regclass
  ),
  true,
  'transport preview mapping table has RLS enabled'
);
select is(
  (
    select public
    from storage.buckets
    where id = 'eco-partner-previews'
  ),
  true,
  'transport preview bucket is publicly readable'
);

delete from public.malaysia_state_boundaries where state = 'Kuala Lumpur';
insert into public.malaysia_state_boundaries(
  state, code_state, boundary, source_url
) values (
  'Kuala Lumpur', 14,
  extensions.st_geomfromtext(
    'MULTIPOLYGON(((101.6 3.0,101.8 3.0,101.8 3.3,101.6 3.3,101.6 3.0)))',
    4326
  ),
  'test fixture'
);
select is(
  public.malaysia_state_for_coordinates(3.1390, 101.6869),
  'Kuala Lumpur'::text,
  'coordinates are assigned through point-in-polygon matching'
);
select ok(
  has_table_privilege('authenticated', 'public.eco_partner_catalog', 'select'),
  'authenticated users can read the catalogue'
);

select ok(
  not has_table_privilege('anon', 'public.eco_partner_catalog', 'select'),
  'anonymous users cannot read the catalogue'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.replace_eco_partner_region(text,text,jsonb)',
    'execute'
  ),
  'only the backend role receives replacement access'
);

do $setup$
begin
perform public.replace_gtfs_feed(
  'preview-test-feed',
  'https://example.com/preview-feed.zip',
  '[]'::jsonb,
  '[{
    "id":"preview-test-feed:stop-1",
    "feed_id":"preview-test-feed",
    "stop_id":"stop-1",
    "name":"Preview test stop",
    "address":"Kuala Lumpur",
    "latitude":3.1390,
    "longitude":101.6869,
    "source_name":"Official Malaysia GTFS",
    "source_url":"https://example.com/preview-feed.zip"
  }]'::jsonb,
  '[{
    "id":"preview-test-feed:route-1",
    "feed_id":"preview-test-feed",
    "route_id":"route-1",
    "short_name":"T1",
    "long_name":"Preview line",
    "route_type":0,
    "mode":"LRT"
  }]'::jsonb,
  '[{
    "stop_id":"preview-test-feed:stop-1",
    "route_id":"preview-test-feed:route-1"
  }]'::jsonb
);
end
$setup$;

select like(
  (
    select image_url
    from public.eco_partner_catalog
    where id = 'stop:preview-test-feed:stop-1'
  ),
  'storage://eco-partner-previews/transport/lrt%.webp',
  'new GTFS catalogue rows receive their mode preview'
);

update public.gtfs_stops
set name = 'Updated preview test stop'
where id = 'preview-test-feed:stop-1';
do $setup$
begin
  perform public.refresh_gtfs_eco_partner_catalog('preview-test-feed');
end
$setup$;

select like(
  (
    select image_url
    from public.eco_partner_catalog
    where id = 'stop:preview-test-feed:stop-1'
  ),
  'storage://eco-partner-previews/transport/lrt%.webp',
  'GTFS refresh preserves and reapplies its curated preview'
);

select results_eq(
  $$
    select id
    from public.search_eco_partners(
      null, null, 'transport_lrt', null, null, null,
      'recommended', 10, 0
    )
    where id = 'stop:preview-test-feed:stop-1'
  $$,
  $$ values ('stop:preview-test-feed:stop-1'::text) $$,
  'LRT filter includes a matching GTFS row'
);

select is(
  (
    select count(*)
    from public.search_eco_partners(
      null, null, 'transport_bus', null, null, null,
      'recommended', 10, 0
    )
    where id = 'stop:preview-test-feed:stop-1'
  ),
  0::bigint,
  'bus filter excludes an LRT GTFS row'
);

select is(
  (
    select count(*)
    from public.eco_hotels
    where gstc_code is not null
      and image_url is not null
  ),
  20::bigint,
  'all seeded GSTC hotels have curated preview images'
);

select is(
  public.replace_eco_partner_region(
    'osm',
    'Sabah',
    '[{
      "id":"osm:node:catalog-test",
      "source_id":"node:catalog-test",
      "name":"Sabah Green Table",
      "category":"dining",
      "subtype":"Restaurant",
      "address":"Kota Kinabalu",
      "latitude":5.9804,
      "longitude":116.0735,
      "sustainability_label":"Vegan-friendly dining",
      "evidence":"OpenStreetMap diet:vegan tag",
      "source_name":"OpenStreetMap contributors",
      "source_url":"https://www.openstreetmap.org/node/catalog-test",
      "vegan_classification":"Vegan"
    }]'::jsonb
  ),
  1,
  'a complete state payload is stored transactionally'
);

select like(
  (
    select image_url from public.eco_partner_catalog
    where id = 'osm:node:catalog-test'
  ),
  'storage://eco-partner-previews/dining/dining-%.webp',
  'OSM dining rows receive bucket-hosted previews during replacement'
);

select results_eq(
  $$
    select name
    from public.search_eco_partners(
      'green table', 'Sabah', null, null, null, null,
      'recommended', 10, 0
    )
  $$,
  $$ values ('Sabah Green Table'::text) $$,
  'name and state search is case-insensitive'
);

select is(
  public.malaysia_state_from_text('JLN PAHANG'),
  null::text,
  'a road named after a state is not treated as that state'
);

select is(
  (
    select distance_km
    from public.search_eco_partners(
      'Sabah Green', null, null, null, null, null,
      'recommended', 10, 0
    )
    limit 1
  ),
  null::double precision,
  'distance is null when no origin is supplied'
);

insert into public.eco_partner_catalog (
  id, source, source_id, name, category, subtype, state, address,
  latitude, longitude, sustainability_label, evidence, source_name
) values (
  'manual:catalog-ev-test', 'manual', 'catalog-ev-test', 'Catalogue EV Test',
  'transport', 'EV charging', 'Sabah', 'Kota Kinabalu, Sabah',
  5.9805, 116.0736, 'Electric vehicle charging', 'Test fixture', 'Test fixture'
);

select like(
  (
    select image_url from public.eco_partner_catalog
    where id = 'manual:catalog-ev-test'
  ),
  'storage://eco-partner-previews/ev/ev-%.webp',
  'EV rows receive bucket-hosted previews during insertion'
);

select results_eq(
  $$
    select name
    from public.search_eco_partners(
      null, null, 'ev', null, null, null,
      'recommended', 10, 0
    )
    where id = 'manual:catalog-ev-test'
  $$,
  $$ values ('Catalogue EV Test'::text) $$,
  'nationwide EV filtering returns canonical EV rows'
);

select results_eq(
  $$
    select name
    from public.search_eco_partners(
      null, null, null, 5.9804, 116.0735, 0.1,
      'recommended', 10, 0
    )
    where id = 'osm:node:catalog-test'
  $$,
  $$ values ('Sabah Green Table'::text) $$,
  'nearby search uses the geography radius'
);

select is(
  (
    select total_count
    from public.search_eco_partners(
      'Sabah Green', null, null, null, null, null,
      'name_asc', 1, 0
    )
    limit 1
  ),
  1::bigint,
  'paged results include their complete match count'
);

select ok(
  (public.eco_partner_home('Sabah', null, null, null, 8) ? 'dining'),
  'home RPC returns a dining section'
);

select throws_ok(
  $$ select public.replace_eco_partner_region('invalid', 'Sabah', '[]'::jsonb) $$,
  'replace_eco_partner_region only accepts the osm source',
  'invalid replacement sources are rejected before deleting data'
);

select is(
  (select count(*) from public.eco_partner_catalog where id = 'osm:node:catalog-test'),
  1::bigint,
  'a rejected replacement preserves the last successful row'
);

select * from finish();
rollback;
