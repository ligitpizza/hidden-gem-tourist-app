begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(23);

select has_table('public', 'eco_partner_catalog', 'catalogue table exists');
select has_index(
  'public',
  'eco_partner_catalog',
  'eco_partner_catalog_location_idx',
  'catalogue has a spatial index'
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
