-- Module 1: Hidden Gem Recommendations — core schema.
--
-- Adds everything the four Module 1 features need that didn't exist yet:
--   FR1 Personalized Hidden Gem Recommendations -> user_travel_preferences
--   FR2 Hidden Gem Scoring Engine               -> hidden_gem_scoring_config
--                                                   + places.hidden_gem_score
--   FR3 Smart Preference Learning                -> user_interactions,
--                                                   interaction_weights,
--                                                   preference_decay_config,
--                                                   user_category_affinity,
--                                                   place_seasonality
--   FR4 Trending Hidden Destination Detection     -> trending_config
--                                                   + places.is_trending
--
-- NFR5.1/5.2 (weights/thresholds configurable without code changes): every
-- *_config table below is publicly *readable* (the app needs the numbers to
-- explain itself) but has no insert/update/delete policy, so only a row
-- edited via the Supabase dashboard/SQL editor can change them — never a
-- code change or an app rebuild.

-- ---------------------------------------------------------------------
-- 1. Travel style vocabulary — matches lib/features/recommendations's
--    TravelStyle enum exactly (.name values), which the app already ships.
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'travel_style') then
    create type public.travel_style as enum (
      'nature', 'culture', 'adventure', 'localFood', 'heritage',
      'wellness', 'urbanExploration', 'fauna', 'flora'
    );
  end if;
end $$;

-- Single source of truth for "which travel style does this OSM place
-- category belong to" — used both to auto-tag interactions (trigger below)
-- and to score a place against a tourist's preference profile
-- (get_personalized_recommendations, added in the next migration).
create or replace view public.place_travel_style_map as
select
  id as place_id,
  (case category
    when 'restaurant' then 'localFood'
    when 'cafe' then 'localFood'
    when 'park' then 'nature'
    when 'beach' then 'nature'
    when 'island' then 'nature'
    when 'waterfall' then 'nature'
    when 'mountain' then 'nature'
    when 'viewpoint' then 'adventure'
    when 'theme_park' then 'adventure'
    when 'attraction' then 'adventure'
    when 'craft' then 'culture'
    when 'art' then 'culture'
    when 'museum' then 'culture'
    when 'heritage_site' then 'heritage'
    when 'mall' then 'urbanExploration'
    else 'culture'
  end)::travel_style as style
from public.places;

-- ---------------------------------------------------------------------
-- 2. FR1 — per-user preference profile (replaces the SharedPreferences-only
--    placeholder; NFR4.1 requires this live in Supabase behind RLS).
-- ---------------------------------------------------------------------
create table if not exists public.user_travel_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  categories travel_style[] not null default '{}',
  budget_range text check (budget_range in ('budget', 'mid_range', 'luxury')),
  destination_types text[] not null default '{}',
  onboarded_at timestamptz,
  updated_at timestamptz not null default now(),
  -- Preference Selection And Preference Update activity diagram: "Select
  -- Travel Style / Interests (Maximum 3 preferences)".
  constraint user_travel_preferences_max_three
    check (array_length(categories, 1) is null or array_length(categories, 1) <= 3)
);

alter table public.user_travel_preferences enable row level security;

create policy "tourists manage their own travel preferences"
  on public.user_travel_preferences
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- 3. FR3 — interaction log (views/searches/saves/itinerary adds), the raw
--    signal Smart Preference Learning and trending detection both read.
-- ---------------------------------------------------------------------
create table if not exists public.user_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  place_id uuid not null references public.places (id) on delete cascade,
  interaction_type text not null check (interaction_type in ('view', 'search', 'save', 'itinerary_add')),
  -- Auto-filled from place_travel_style_map by the trigger below when the
  -- caller doesn't supply one — kept nullable/overridable rather than
  -- generated so a place with no clean category mapping doesn't block the
  -- insert (E1 in the "Interact with Destination" use case: log the
  -- interaction, just skip the preference-score update for it).
  category travel_style,
  created_at timestamptz not null default now()
);

create index if not exists user_interactions_user_category_idx
  on public.user_interactions (user_id, category, created_at desc);
create index if not exists user_interactions_place_idx
  on public.user_interactions (place_id, created_at desc);

alter table public.user_interactions enable row level security;

create policy "tourists insert their own interactions"
  on public.user_interactions
  for insert
  with check (auth.uid() = user_id);

create policy "tourists read their own interactions"
  on public.user_interactions
  for select
  using (auth.uid() = user_id);

create or replace function public.set_interaction_category()
returns trigger
language plpgsql
as $$
begin
  if new.category is null then
    select style into new.category
    from public.place_travel_style_map
    where place_id = new.place_id;
  end if;
  return new;
end;
$$;

drop trigger if exists user_interactions_set_category on public.user_interactions;
create trigger user_interactions_set_category
  before insert on public.user_interactions
  for each row execute function public.set_interaction_category();

-- ---------------------------------------------------------------------
-- 4. FR3 config — rule-based interaction weights + decay half-life. Kept as
--    data, not code, per NFR5.2 ("rules can be updated ... with minimal
--    effort") and the constraint that preference learning stays rule-based,
--    no ML model.
-- ---------------------------------------------------------------------
create table if not exists public.interaction_weights (
  interaction_type text primary key check (interaction_type in ('view', 'search', 'save', 'itinerary_add')),
  points numeric not null
);

insert into public.interaction_weights (interaction_type, points) values
  ('view', 1), ('search', 0.5), ('save', 2), ('itinerary_add', 3)
on conflict (interaction_type) do nothing;

create table if not exists public.preference_decay_config (
  id smallint primary key default 1 check (id = 1),
  half_life_days numeric not null default 14,
  -- "Your interest in Heritage is cooling off" on the Travel Pulse screen
  -- fires once a category has gone this many days without an interaction.
  cooling_off_days numeric not null default 14
);

insert into public.preference_decay_config (id) values (1) on conflict (id) do nothing;

alter table public.interaction_weights enable row level security;
create policy "interaction weights are publicly readable"
  on public.interaction_weights for select using (true);

alter table public.preference_decay_config enable row level security;
create policy "preference decay config is publicly readable"
  on public.preference_decay_config for select using (true);

-- Recency-weighted affinity per (user, category) — exponential decay with
-- configurable half-life, computed on read so there's no separate weights
-- table to keep in sync. security_invoker means it inherits
-- user_interactions' own RLS: a tourist can only ever see their own rows,
-- same pattern already used for place_review_metrics.
create or replace view public.user_category_affinity
with (security_invoker = true) as
select
  ui.user_id,
  ui.category,
  sum(
    iw.points * exp(
      - ln(2) * (extract(epoch from (now() - ui.created_at)) / 86400.0) / d.half_life_days
    )
  ) as affinity_score,
  max(ui.created_at) as last_interacted_at
from public.user_interactions ui
join public.interaction_weights iw on iw.interaction_type = ui.interaction_type
cross join public.preference_decay_config d
where ui.category is not null
group by ui.user_id, ui.category;

-- ---------------------------------------------------------------------
-- 5. FR3.4/3.5 — seasonal suitability per place. One row per applicable
--    month; a place with no rows is treated as suitable year-round.
-- ---------------------------------------------------------------------
create table if not exists public.place_seasonality (
  place_id uuid not null references public.places (id) on delete cascade,
  month smallint not null check (month between 1 and 12),
  suitability_score numeric not null check (suitability_score between 0 and 5),
  primary key (place_id, month)
);

alter table public.place_seasonality enable row level security;
create policy "place seasonality is publicly readable"
  on public.place_seasonality for select using (true);

-- ---------------------------------------------------------------------
-- 6. FR2 — scoring engine weights, now data instead of Dart constants.
-- ---------------------------------------------------------------------
create table if not exists public.hidden_gem_scoring_config (
  id smallint primary key default 1 check (id = 1),
  rating_weight numeric not null default 0.40,
  uniqueness_weight numeric not null default 0.25,
  accessibility_weight numeric not null default 0.20,
  popularity_weight numeric not null default 0.15,
  popularity_bonus_low numeric not null default 1.0,
  popularity_bonus_medium numeric not null default 0.6,
  popularity_bonus_high numeric not null default 0.25,
  qualifying_threshold numeric not null default 0.8,
  -- Activity diagram: "Number Of Interactions > Popularity Threshold? ->
  -- Deduct Low Popularity Score Points". Counted over a rolling window so
  -- an old spike doesn't permanently penalise a place.
  popularity_interaction_threshold int not null default 50,
  popularity_interaction_window_days int not null default 30,
  popularity_deduction_points numeric not null default 0.05,
  updated_at timestamptz not null default now()
);

insert into public.hidden_gem_scoring_config (id) values (1) on conflict (id) do nothing;

alter table public.hidden_gem_scoring_config enable row level security;
create policy "scoring config is publicly readable"
  on public.hidden_gem_scoring_config for select using (true);

-- ---------------------------------------------------------------------
-- 7. FR4 — trending detection thresholds.
-- ---------------------------------------------------------------------
create table if not exists public.trending_config (
  id smallint primary key default 1 check (id = 1),
  growth_threshold_pct numeric not null default 0.30,
  rolling_window_days int not null default 7,
  -- Below this many engagement events in the current window, a growth rate
  -- is too noisy to call "trending" (mirrors the client-side
  -- _minRecentReviewsForTrending guard the team's placeholder feed used).
  min_engagement_count int not null default 5,
  updated_at timestamptz not null default now()
);

insert into public.trending_config (id) values (1) on conflict (id) do nothing;

alter table public.trending_config enable row level security;
create policy "trending config is publicly readable"
  on public.trending_config for select using (true);

-- ---------------------------------------------------------------------
-- 8. Persisted score/trending outputs on places itself — the "Score All
--    Hidden Gems" and "Detect Trending Destinations" use cases both end
--    with "... stored in Supabase", not just computed at read time.
-- ---------------------------------------------------------------------
alter table public.places
  add column if not exists hidden_gem_score numeric,
  add column if not exists score_updated_at timestamptz,
  add column if not exists is_trending boolean not null default false,
  add column if not exists trending_since timestamptz,
  add column if not exists engagement_growth_rate numeric;

create index if not exists places_hidden_gem_score_idx
  on public.places (hidden_gem_score desc nulls last);
create index if not exists places_is_trending_idx
  on public.places (is_trending) where is_trending;

-- Carry the new columns through to the candidates view the app already
-- reads from, so existing callers (Assistant feed, itinerary planning) see
-- persisted scores/trending without switching views.
create or replace view public.place_hidden_gem_candidates as
select
  p.id,
  p.name,
  p.description,
  p.category,
  p.latitude,
  p.longitude,
  p.uniqueness_score,
  p.accessibility_score,
  p.popularity,
  coalesce(avg(r.rating), 0) as avg_rating,
  p.city,
  p.state,
  count(r.id) as review_count,
  count(r.id) filter (where r.created_at > (now() - interval '3 months')) as recent_review_count,
  p.hidden_gem_score,
  p.score_updated_at,
  p.is_trending,
  p.trending_since,
  p.engagement_growth_rate
from public.places p
left join public.reviews r on r.place_id = p.id
group by p.id, p.name, p.description, p.category, p.latitude, p.longitude,
  p.uniqueness_score, p.accessibility_score, p.popularity, p.city, p.state,
  p.hidden_gem_score, p.score_updated_at, p.is_trending, p.trending_since,
  p.engagement_growth_rate;
