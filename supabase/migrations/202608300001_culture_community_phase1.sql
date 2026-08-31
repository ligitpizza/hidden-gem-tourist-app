-- Visit Malaysia 2026 - Local Culture & Community (Phase 1)
-- Additive schema aligned with the existing team database.
-- Reuses public.places for restaurant/food-location coordinates instead of
-- creating a third location catalogue.

-- ---------------------------------------------------------------------
-- 1. Cultural events
-- ---------------------------------------------------------------------
create table if not exists public.cultural_events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('festival', 'cultural_show', 'community_activity')),
  description text not null default '',
  start_at timestamptz not null,
  end_at timestamptz,
  venue_name text not null,
  address text,
  state text not null,
  city text,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  image_url text,
  travel_styles public.travel_style[] not null default '{culture}'::public.travel_style[],
  is_featured boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cultural_events_end_after_start check (end_at is null or end_at >= start_at)
);

create index if not exists cultural_events_category_idx
  on public.cultural_events (category);
create index if not exists cultural_events_start_at_idx
  on public.cultural_events (start_at);
create index if not exists cultural_events_state_city_idx
  on public.cultural_events (state, city);
create index if not exists cultural_events_coordinates_idx
  on public.cultural_events (latitude, longitude);
create index if not exists cultural_events_travel_styles_idx
  on public.cultural_events using gin (travel_styles);

-- ---------------------------------------------------------------------
-- 2. Traditional foods
-- ---------------------------------------------------------------------
create table if not exists public.traditional_foods (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text not null default '',
  ingredients text[] not null default '{}',
  image_url text,
  cultural_history text not null default '',
  state text not null,
  region text,
  cultural_category text not null,
  dietary_tags text[] not null default '{}',
  allergens text[] not null default '{}',
  allergy_notes text,
  travel_styles public.travel_style[] not null default '{localFood}'::public.travel_style[],
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists traditional_foods_state_idx
  on public.traditional_foods (state);
create index if not exists traditional_foods_cultural_category_idx
  on public.traditional_foods (cultural_category);
create index if not exists traditional_foods_dietary_tags_idx
  on public.traditional_foods using gin (dietary_tags);
create index if not exists traditional_foods_allergens_idx
  on public.traditional_foods using gin (allergens);
create index if not exists traditional_foods_travel_styles_idx
  on public.traditional_foods using gin (travel_styles);

-- ---------------------------------------------------------------------
-- 3. Traditional food <-> existing places relationship
-- A place can serve many foods; a food can be served at many places.
-- ---------------------------------------------------------------------
create table if not exists public.traditional_food_places (
  food_id uuid not null references public.traditional_foods (id) on delete cascade,
  place_id uuid not null references public.places (id) on delete cascade,
  serving_notes text,
  halal_status text not null default 'unknown'
    check (halal_status in ('certified', 'muslim_friendly', 'non_halal', 'unknown')),
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (food_id, place_id)
);

create index if not exists traditional_food_places_place_id_idx
  on public.traditional_food_places (place_id);

-- ---------------------------------------------------------------------
-- 4. User favourites
-- ---------------------------------------------------------------------
create table if not exists public.cultural_event_favourites (
  user_id uuid not null references auth.users (id) on delete cascade,
  event_id uuid not null references public.cultural_events (id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, event_id)
);

create index if not exists cultural_event_favourites_event_id_idx
  on public.cultural_event_favourites (event_id);

create table if not exists public.traditional_food_favourites (
  user_id uuid not null references auth.users (id) on delete cascade,
  food_id uuid not null references public.traditional_foods (id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, food_id)
);

create index if not exists traditional_food_favourites_food_id_idx
  on public.traditional_food_favourites (food_id);

-- ---------------------------------------------------------------------
-- 5. Cultural-event itinerary items
-- Kept separate from saved_itineraries.plan because that JSONB is owned by
-- the itinerary-planning module and has a fixed generated-route structure.
-- The Saved module can aggregate these rows later without breaking that codec.
-- ---------------------------------------------------------------------
create table if not exists public.cultural_event_itinerary_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  event_id uuid not null references public.cultural_events (id) on delete cascade,
  planned_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  unique (user_id, event_id)
);

create index if not exists cultural_event_itinerary_user_idx
  on public.cultural_event_itinerary_items (user_id, planned_at);
create index if not exists cultural_event_itinerary_event_idx
  on public.cultural_event_itinerary_items (event_id);

-- ---------------------------------------------------------------------
-- 6. updated_at trigger used only by this module
-- ---------------------------------------------------------------------
create or replace function public.culture_community_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists cultural_events_touch_updated_at on public.cultural_events;
create trigger cultural_events_touch_updated_at
before update on public.cultural_events
for each row execute function public.culture_community_touch_updated_at();

drop trigger if exists traditional_foods_touch_updated_at on public.traditional_foods;
create trigger traditional_foods_touch_updated_at
before update on public.traditional_foods
for each row execute function public.culture_community_touch_updated_at();

-- ---------------------------------------------------------------------
-- 7. RLS
-- Existing project style: catalogue content is readable; user-owned rows
-- are restricted to auth.uid().
-- ---------------------------------------------------------------------
alter table public.cultural_events enable row level security;
alter table public.traditional_foods enable row level security;
alter table public.traditional_food_places enable row level security;
alter table public.cultural_event_favourites enable row level security;
alter table public.traditional_food_favourites enable row level security;
alter table public.cultural_event_itinerary_items enable row level security;

-- Explicit client privileges. RLS still decides which individual rows are allowed.
grant select on public.cultural_events to anon, authenticated;
grant select on public.traditional_foods to anon, authenticated;
grant select on public.traditional_food_places to anon, authenticated;
grant select, insert, delete on public.cultural_event_favourites to authenticated;
grant select, insert, delete on public.traditional_food_favourites to authenticated;
grant select, insert, update, delete on public.cultural_event_itinerary_items to authenticated;

drop policy if exists "Public read active cultural events" on public.cultural_events;
create policy "Public read active cultural events"
  on public.cultural_events for select
  using (is_active);

drop policy if exists "Public read active traditional foods" on public.traditional_foods;
create policy "Public read active traditional foods"
  on public.traditional_foods for select
  using (is_active);

drop policy if exists "Public read traditional food places" on public.traditional_food_places;
create policy "Public read traditional food places"
  on public.traditional_food_places for select
  using (true);

drop policy if exists "Users manage their own cultural event favourites"
  on public.cultural_event_favourites;
create policy "Users manage their own cultural event favourites"
  on public.cultural_event_favourites for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their own traditional food favourites"
  on public.traditional_food_favourites;
create policy "Users manage their own traditional food favourites"
  on public.traditional_food_favourites for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users manage their own cultural event itinerary"
  on public.cultural_event_itinerary_items;
create policy "Users manage their own cultural event itinerary"
  on public.cultural_event_itinerary_items for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- 8. Phase 1 sample data
-- Demo/development schedules only; replace with verified official event
-- information before production.
-- ---------------------------------------------------------------------
insert into public.cultural_events (
  id, name, category, description, start_at, end_at, venue_name, address,
  state, city, latitude, longitude, travel_styles, is_featured
) values
(
  'c1000000-0000-4000-8000-000000000001',
  'George Town Heritage Festival',
  'festival',
  'A demo heritage celebration featuring local arts, performances and community activities around George Town.',
  '2026-09-12 10:00:00+08',
  '2026-09-13 22:00:00+08',
  'George Town UNESCO World Heritage Area',
  'George Town, Penang',
  'Penang',
  'George Town',
  5.4141,
  100.3288,
  '{culture,heritage}'::public.travel_style[],
  true
),
(
  'c1000000-0000-4000-8000-000000000002',
  'Borneo Traditional Dance Showcase',
  'cultural_show',
  'A demo evening showcase introducing visitors to traditional dances, music and costumes from communities across Sarawak.',
  '2026-09-20 19:30:00+08',
  '2026-09-20 21:30:00+08',
  'Kuching Waterfront',
  'Kuching Waterfront, Kuching',
  'Sarawak',
  'Kuching',
  1.5583,
  110.3492,
  '{culture}'::public.travel_style[],
  true
),
(
  'c1000000-0000-4000-8000-000000000003',
  'Melaka Community Batik Workshop',
  'community_activity',
  'A demo hands-on workshop where visitors learn basic Malaysian batik techniques with local makers.',
  '2026-09-27 10:00:00+08',
  '2026-09-27 15:00:00+08',
  'Melaka Cultural Centre',
  'Bandar Hilir, Melaka',
  'Melaka',
  'Melaka City',
  2.1896,
  102.2501,
  '{culture,heritage}'::public.travel_style[],
  false
),
(
  'c1000000-0000-4000-8000-000000000004',
  'Sarawak Community Handicraft Market',
  'community_activity',
  'A demo community market featuring handmade crafts, local products and cultural demonstrations by artisans.',
  '2026-10-03 09:00:00+08',
  '2026-10-04 18:00:00+08',
  'Kuching Community Hall',
  'Kuching, Sarawak',
  'Sarawak',
  'Kuching',
  1.5533,
  110.3592,
  '{culture}'::public.travel_style[],
  false
),
(
  'c1000000-0000-4000-8000-000000000005',
  'Sabah Harvest Culture Showcase',
  'cultural_show',
  'A demo tourism showcase inspired by Sabah harvest traditions with costumes, dance, music and cultural demonstrations.',
  '2026-10-10 18:00:00+08',
  '2026-10-10 21:00:00+08',
  'Kota Kinabalu Cultural Centre',
  'Kota Kinabalu, Sabah',
  'Sabah',
  'Kota Kinabalu',
  5.9804,
  116.0735,
  '{culture,heritage}'::public.travel_style[],
  true
),
(
  'c1000000-0000-4000-8000-000000000006',
  'Brickfields Cultural Bazaar',
  'festival',
  'A demo festive community bazaar featuring Malaysian Indian food, decorations, cultural products and performances.',
  '2026-11-06 11:00:00+08',
  '2026-11-08 22:00:00+08',
  'Brickfields',
  'Brickfields, Kuala Lumpur',
  'Kuala Lumpur',
  'Kuala Lumpur',
  3.1310,
  101.6869,
  '{culture,localFood}'::public.travel_style[],
  false
),
(
  'c1000000-0000-4000-8000-000000000007',
  'Kelantan Traditional Arts Weekend',
  'festival',
  'A demo weekend programme introducing visitors to Kelantanese traditional arts, music, crafts and community culture.',
  '2026-12-05 09:00:00+08',
  '2026-12-06 18:00:00+08',
  'Kota Bharu Cultural Centre',
  'Kota Bharu, Kelantan',
  'Kelantan',
  'Kota Bharu',
  6.1254,
  102.2386,
  '{culture,heritage}'::public.travel_style[],
  false
)
on conflict (id) do nothing;

insert into public.traditional_foods (
  id, name, description, ingredients, cultural_history, state, region,
  cultural_category, dietary_tags, allergens, allergy_notes
) values
(
  'f1000000-0000-4000-8000-000000000001',
  'Nasi Lemak',
  'Fragrant coconut rice traditionally served with sambal, anchovies, peanuts, cucumber and egg.',
  array['Rice','Coconut milk','Pandan leaves','Sambal','Anchovies','Peanuts','Cucumber','Egg'],
  'One of Malaysia''s best-known dishes, commonly associated with Malay food culture and enjoyed nationwide.',
  'Kuala Lumpur',
  'Nationwide',
  'Malay',
  array['Halal'],
  array['Peanuts','Fish','Egg'],
  'The standard version commonly contains peanuts, anchovies and egg.'
),
(
  'f1000000-0000-4000-8000-000000000002',
  'Penang Asam Laksa',
  'A tangy and spicy rice-noodle soup traditionally prepared with fish, tamarind, herbs and fresh garnishes.',
  array['Rice noodles','Mackerel','Tamarind','Chilli','Mint','Onion','Cucumber'],
  'Closely associated with Penang food heritage and known for its sour tamarind-based fish broth.',
  'Penang',
  'George Town',
  'Peranakan',
  array['Halal'],
  array['Fish'],
  'Contains fish.'
),
(
  'f1000000-0000-4000-8000-000000000003',
  'Char Kway Teow',
  'Flat rice noodles stir-fried at high heat with soy sauce, bean sprouts, egg and other ingredients.',
  array['Flat rice noodles','Soy sauce','Bean sprouts','Egg','Prawns','Chinese sausage'],
  'Strongly associated with Penang street-food culture and Malaysian Chinese culinary traditions.',
  'Penang',
  'George Town',
  'Malaysian Chinese',
  array['Non-Halal'],
  array['Shellfish','Egg','Soy'],
  'Traditional versions may contain pork products; halal variants also exist.'
),
(
  'f1000000-0000-4000-8000-000000000004',
  'Rendang',
  'Slow-cooked meat prepared with coconut milk and an aromatic mixture of spices and herbs.',
  array['Beef','Coconut milk','Lemongrass','Galangal','Chilli','Turmeric','Kaffir lime leaves'],
  'Rendang has deep roots in Malay and Minangkabau culinary traditions and is often prepared for celebrations.',
  'Negeri Sembilan',
  'West Malaysia',
  'Malay / Minangkabau',
  array['Halal'],
  array[]::text[],
  'Preparation varies by cook and restaurant.'
),
(
  'f1000000-0000-4000-8000-000000000005',
  'Laksa Sarawak',
  'A Sarawak noodle dish with a rich aromatic broth, rice vermicelli, chicken, prawns and egg.',
  array['Rice vermicelli','Chicken','Prawns','Egg','Coconut milk','Laksa spices'],
  'A signature Sarawak dish that represents the distinctive culinary identity of the state.',
  'Sarawak',
  'Kuching',
  'Sarawakian',
  array['Halal'],
  array['Shellfish','Egg'],
  'Usually contains prawns and egg.'
),
(
  'f1000000-0000-4000-8000-000000000006',
  'Hinava',
  'A traditional Sabah dish commonly prepared with fresh fish cured using lime juice and mixed with ginger, chilli and shallots.',
  array['Fresh fish','Lime juice','Ginger','Chilli','Shallots'],
  'Strongly associated with Kadazan-Dusun food culture in Sabah and commonly served during cultural gatherings.',
  'Sabah',
  'Kota Kinabalu',
  'Kadazan-Dusun',
  array['Allergy-sensitive information available'],
  array['Fish'],
  'Contains fish; preparation may use raw or citrus-cured fish.'
),
(
  'f1000000-0000-4000-8000-000000000007',
  'Chicken Rice',
  'Poached or roasted chicken served with fragrant seasoned rice, chilli sauce and condiments.',
  array['Chicken','Rice','Ginger','Garlic','Chilli','Soy sauce'],
  'Malaysian chicken rice developed through Hainanese Chinese culinary traditions and is now enjoyed nationwide.',
  'Kuala Lumpur',
  'Nationwide',
  'Malaysian Chinese',
  array['Halal'],
  array['Soy'],
  'Halal status depends on the restaurant and ingredients used.'
),
(
  'f1000000-0000-4000-8000-000000000008',
  'Roti Canai',
  'A flaky flatbread usually served with dhal, curry or sambal.',
  array['Wheat flour','Water','Salt','Oil'],
  'Closely associated with Malaysia''s Indian Muslim community and popular for breakfast and supper.',
  'Selangor',
  'Nationwide',
  'Indian Muslim',
  array['Halal','Vegetarian'],
  array['Gluten'],
  'Contains wheat; some preparations may also contain dairy or egg.'
),
(
  'f1000000-0000-4000-8000-000000000009',
  'Nasi Kerabu',
  'A Kelantanese rice dish known for blue-tinted rice, herbs, vegetables, sambal and accompanying proteins.',
  array['Rice','Butterfly pea flower','Fresh herbs','Vegetables','Sambal','Fish or chicken'],
  'Strongly associated with Kelantan and the east coast of Peninsular Malaysia.',
  'Kelantan',
  'East Coast',
  'Kelantanese Malay',
  array['Halal'],
  array['Fish'],
  'Allergens vary according to the selected protein and sambal.'
)
on conflict (id) do nothing;
