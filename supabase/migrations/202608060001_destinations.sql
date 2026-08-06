create table public.destinations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  category text not null,
  latitude double precision not null,
  longitude double precision not null,
  avg_rating numeric not null default 0,
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.destinations enable row level security;

create policy "Public read access" on public.destinations
  for select using (true);

-- Seed data so the map isn't empty on first run (NFR14). Categories use the
-- same raw vocabulary as DestinationCategory.dbValue / destinationCategoryFromDb
-- so HiddenGemScoring.categoryFromDb keeps mapping them correctly.
insert into public.destinations (name, description, category, latitude, longitude, avg_rating, images) values
  ('Penang Hill', 'A funicular railway up to cool hilltop views over George Town.', 'viewpoint', 5.4225, 100.2769, 4.6, '{}'),
  ('Kek Lok Si Temple', 'One of the largest Buddhist temples in Southeast Asia.', 'heritage_site', 5.3994, 100.2735, 4.5, '{}'),
  ('George Town Street Art', 'Murals and wrought-iron caricatures scattered through the old town.', 'art', 5.4164, 100.3327, 4.4, '{}'),
  ('Penang Peranakan Mansion', 'A restored 19th-century Peranakan mansion turned museum.', 'museum', 5.4145, 100.3384, 4.5, '{}'),
  ('Escape Penang', 'An outdoor adventure and jungle obstacle park.', 'park', 5.4489, 100.2492, 4.3, '{}'),
  ('Batu Ferringhi Beach', 'A popular sandy beach lined with resorts and night markets.', 'beach', 5.4747, 100.2440, 4.1, '{}'),
  ('Tropical Fruit Farm', 'A guided tour through a working tropical fruit orchard.', 'attraction', 5.2503, 100.5928, 4.4, '{}'),
  ('Ban Zaan Wet Market', 'A bustling local seafood and produce market.', 'attraction', 5.4720, 100.2419, 4.0, '{}'),
  ('Air Terjun Titi Kerawang', 'A roadside waterfall on the way around the island.', 'waterfall', 5.4046, 100.2100, 4.2, '{}'),
  ('Seng Thor Restaurant', 'A local favourite for Penang-style seafood.', 'restaurant', 5.4030, 100.3070, 4.3, '{}'),
  ('Nyonya Baba Cuisine Cafe', 'A cosy cafe serving traditional Peranakan dishes.', 'cafe', 5.4180, 100.3300, 4.2, '{}'),
  ('Penang Batik Craft Village', 'Hands-on batik painting workshops in a small craft village.', 'craft', 5.4600, 100.2050, 4.1, '{}');
