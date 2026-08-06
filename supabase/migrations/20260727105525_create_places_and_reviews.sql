
create table public.places (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  state text,
  city text,
  latitude double precision not null,
  longitude double precision not null,
  source text not null default 'osm' check (source in ('osm', 'manual', 'user_submitted')),
  osm_id bigint,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index places_osm_id_key on public.places (osm_id) where source = 'osm';
create index places_state_idx on public.places (state);
create index places_category_idx on public.places (category);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create index reviews_place_id_idx on public.reviews (place_id);

-- Raw metrics per place; hidden-gem thresholds (rating cutoff, recency window,
-- review count) are decided app-side since they're still being finalized.
create view public.place_review_metrics as
select
  p.id as place_id,
  p.name,
  p.category,
  p.state,
  count(r.id) as review_count,
  avg(r.rating) as avg_rating,
  count(r.id) filter (where r.created_at > now() - interval '3 months') as recent_review_count
from public.places p
left join public.reviews r on r.place_id = p.id
group by p.id, p.name, p.category, p.state;

alter table public.places enable row level security;
alter table public.reviews enable row level security;

create policy "places are publicly readable" on public.places
  for select using (true);

create policy "reviews are publicly readable" on public.reviews
  for select using (true);

create policy "authenticated users can insert their own reviews" on public.reviews
  for insert with check (auth.uid() = user_id);

create policy "users can update their own reviews" on public.reviews
  for update using (auth.uid() = user_id);

create policy "users can delete their own reviews" on public.reviews
  for delete using (auth.uid() = user_id);
;
