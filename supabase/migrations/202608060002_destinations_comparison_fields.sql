alter table public.destinations
  add column city text not null default '',
  add column uniqueness_score numeric not null default 0,
  add column accessibility_score numeric not null default 0,
  add column popularity text not null default 'medium',
  add column crowd_level text not null default 'medium',
  add column entrance_cost numeric,
  add column difficulty_level text,
  add column accessibility_tags text[],
  add column visit_duration_minutes integer,
  add column operating_hours text;

-- Give the seeded demo rows non-trivial scoring/comparison data instead of
-- leaving them all at the defaults above.
update public.destinations set
  city = 'George Town',
  uniqueness_score = 4.0,
  accessibility_score = 3.5,
  popularity = 'medium',
  crowd_level = 'medium',
  entrance_cost = 30,
  visit_duration_minutes = 90
where name = 'Penang Hill';

update public.destinations set
  city = 'George Town',
  uniqueness_score = 4.5,
  accessibility_score = 3.0,
  popularity = 'high',
  crowd_level = 'high',
  entrance_cost = 0,
  visit_duration_minutes = 60
where name = 'Kek Lok Si Temple';

update public.destinations set
  city = 'George Town',
  uniqueness_score = 4.2,
  accessibility_score = 4.5,
  popularity = 'high',
  crowd_level = 'high',
  entrance_cost = 0,
  visit_duration_minutes = 120
where name = 'George Town Street Art';

update public.destinations set
  city = 'George Town',
  uniqueness_score = 3.8,
  accessibility_score = 4.0,
  popularity = 'low',
  crowd_level = 'low',
  entrance_cost = 25,
  visit_duration_minutes = 60
where name = 'Penang Peranakan Mansion';

update public.destinations set
  city = 'Teluk Bahang',
  uniqueness_score = 3.6,
  accessibility_score = 2.5,
  popularity = 'medium',
  crowd_level = 'medium',
  entrance_cost = 68,
  visit_duration_minutes = 180
where name = 'Escape Penang';

update public.destinations set
  city = 'Batu Ferringhi',
  uniqueness_score = 3.0,
  accessibility_score = 4.5,
  popularity = 'high',
  crowd_level = 'high',
  entrance_cost = 0,
  visit_duration_minutes = 150
where name = 'Batu Ferringhi Beach';

update public.destinations set
  city = 'Balik Pulau',
  uniqueness_score = 4.1,
  accessibility_score = 2.0,
  popularity = 'low',
  crowd_level = 'low',
  entrance_cost = 38,
  visit_duration_minutes = 90
where name = 'Tropical Fruit Farm';

update public.destinations set
  city = 'Batu Ferringhi',
  uniqueness_score = 3.2,
  accessibility_score = 3.5,
  popularity = 'medium',
  crowd_level = 'high',
  entrance_cost = 0,
  visit_duration_minutes = 45
where name = 'Ban Zaan Wet Market';

update public.destinations set
  city = 'Teluk Bahang',
  uniqueness_score = 3.9,
  accessibility_score = 1.5,
  popularity = 'low',
  crowd_level = 'low',
  entrance_cost = 5,
  visit_duration_minutes = 75
where name = 'Air Terjun Titi Kerawang';

update public.destinations set
  city = 'George Town',
  uniqueness_score = 3.3,
  accessibility_score = 4.0,
  popularity = 'medium',
  crowd_level = 'medium',
  entrance_cost = 0,
  visit_duration_minutes = 60
where name = 'Seng Thor Restaurant';

update public.destinations set
  city = 'George Town',
  uniqueness_score = 3.5,
  accessibility_score = 4.2,
  popularity = 'medium',
  crowd_level = 'low',
  entrance_cost = 0,
  visit_duration_minutes = 50
where name = 'Nyonya Baba Cuisine Cafe';

update public.destinations set
  city = 'Teluk Bahang',
  uniqueness_score = 4.3,
  accessibility_score = 3.0,
  popularity = 'low',
  crowd_level = 'low',
  entrance_cost = 15,
  visit_duration_minutes = 90
where name = 'Penang Batik Craft Village';
