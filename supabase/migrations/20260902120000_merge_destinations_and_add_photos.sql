-- Module 1 requests:
--   1. Bring the team's 72 `destinations` rows into `places`, so Module 1's
--      recommendation engine can surface them too.
--   2. Give `places` real photos — currently every place renders the same
--      gradient placeholder because `places` has never had an image column.
--
-- This is a one-way COPY, not a merge: `destinations` itself is untouched
-- and keeps working exactly as before for the other three modules built on
-- top of it (destination_exploration, travel_prep, gamification_journal).
-- IDs are preserved on the way in — verified zero collisions against the
-- existing 3,762 `places` rows before writing this migration — so nothing
-- in either table's foreign keys needs to change.
--
-- Ratings are deliberately NOT carried over. `places` computes its rating
-- live from real rows in `reviews` (see `place_review_metrics` /
-- `place_hidden_gem_candidates`), while `destinations.avg_rating` is a
-- stored summary fed by a different table (`destination_ratings`).
-- Fabricating `reviews` rows from that summary would misrepresent real
-- review counts, so these 72 places start with zero reviews here and earn
-- real ones the same way every other place does.

-- ---------------------------------------------------------------------
-- 1. Give `places` the columns `destinations` already has, so nothing is
--    dropped on the way in. `images` is the one that actually matters for
--    photos; the rest just come along for free since they're already
--    populated on the 72 rows being copied.
-- ---------------------------------------------------------------------
alter table public.places
  add column if not exists images text[] not null default '{}',
  add column if not exists crowd_level text,
  add column if not exists entrance_cost numeric,
  add column if not exists difficulty_level text,
  add column if not exists accessibility_tags text[],
  add column if not exists visit_duration_minutes integer,
  add column if not exists operating_hours text;

-- ---------------------------------------------------------------------
-- 2. Copy the 72 rows across. `source = 'manual'` (not 'osm') so the
--    `places_osm_id_key` partial unique index — which only applies to
--    source = 'osm' rows — is never touched by this insert.
-- ---------------------------------------------------------------------
insert into public.places (
  id, name, description, category, city, latitude, longitude, source,
  uniqueness_score, accessibility_score, popularity,
  images, crowd_level, entrance_cost, difficulty_level, accessibility_tags,
  visit_duration_minutes, operating_hours, created_at, updated_at
)
select
  d.id, d.name, d.description, d.category, d.city, d.latitude, d.longitude,
  'manual',
  d.uniqueness_score, d.accessibility_score, d.popularity,
  d.images, d.crowd_level, d.entrance_cost, d.difficulty_level, d.accessibility_tags,
  d.visit_duration_minutes, d.operating_hours, d.created_at, now()
from public.destinations d
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 3. Expose `images` (and the score/trending columns already on `places`
--    but missing from the view before now) through
--    `place_hidden_gem_candidates`, the view every Module 1 screen reads
--    from — this is the full column list from the last version of this
--    view (20260825120000) plus `p.images`.
-- ---------------------------------------------------------------------
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
  p.engagement_growth_rate,
  p.images
from public.places p
left join public.reviews r on r.place_id = p.id
group by p.id, p.name, p.description, p.category, p.latitude, p.longitude,
  p.uniqueness_score, p.accessibility_score, p.popularity, p.city, p.state,
  p.hidden_gem_score, p.score_updated_at, p.is_trending, p.trending_since,
  p.engagement_growth_rate, p.images;

-- ---------------------------------------------------------------------
-- 4. Thread `images` through the two RPCs the app actually calls for its
--    main surfaces (personalized recommendations, recently viewed) --
--    reading `place_hidden_gem_candidates` directly (step 3) isn't enough
--    on its own, since these are the primary, higher-traffic paths.
--    Changing either return table's column list is a new function
--    signature as far as Postgres is concerned, so `create or replace`
--    alone won't do -- drop the old one first, same as the p_month fix in
--    20260831090000.
-- ---------------------------------------------------------------------
drop function if exists public.get_personalized_recommendations(int, int);

create or replace function public.get_personalized_recommendations(
  p_limit int default 20,
  p_month int default null
)
returns table (
  id uuid,
  name text,
  description text,
  category text,
  city text,
  state text,
  latitude double precision,
  longitude double precision,
  avg_rating numeric,
  uniqueness_score numeric,
  accessibility_score numeric,
  popularity text,
  hidden_gem_score numeric,
  is_trending boolean,
  engagement_growth_rate numeric,
  images text[],
  personalized_score numeric
)
language sql
security definer
set search_path = public
as $$
  with month as (
    select coalesce(
      p_month,
      (select intended_travel_month from user_travel_preferences where user_id = auth.uid()),
      extract(month from now())::smallint
    ) as m
  ),
  affinity as (
    select category, affinity_score
    from user_category_affinity
    where user_id = auth.uid()
  ),
  max_affinity as (
    select greatest(max(affinity_score), 0.0001) as m from affinity
  )
  select
    c.id, c.name, c.description, c.category, c.city, c.state, c.latitude, c.longitude,
    c.avg_rating, c.uniqueness_score, c.accessibility_score, c.popularity,
    c.hidden_gem_score, c.is_trending, c.engagement_growth_rate, c.images,
    coalesce(c.hidden_gem_score, 0)
      * (1 + coalesce((
          select a.affinity_score
          from affinity a
          join place_travel_style_map ps on ps.style = a.category
          where ps.place_id = c.id
        ), 0) / (select m from max_affinity) * 0.5)
      * (1 + (coalesce((
          select s.suitability_score
          from place_seasonality s, month
          where s.place_id = c.id and s.month = month.m
        ), 2.5) - 2.5) / 10.0)
      as personalized_score
  from place_hidden_gem_candidates c
  order by personalized_score desc nulls last, c.name asc
  limit p_limit;
$$;

grant execute on function public.get_personalized_recommendations(int, int) to authenticated;

drop function if exists public.recently_viewed_places(int);

create or replace function public.recently_viewed_places(p_limit int default 5)
returns table (
  place_id uuid,
  viewed_at timestamptz,
  name text,
  category text,
  city text,
  state text,
  hidden_gem_score numeric,
  images text[]
)
language sql
stable
set search_path = public
as $$
  select place_id, viewed_at, name, category, city, state, hidden_gem_score, images
  from (
    select distinct on (ui.place_id)
      ui.place_id,
      ui.created_at as viewed_at,
      p.name, p.category, p.city, p.state, p.hidden_gem_score, p.images
    from user_interactions ui
    join place_hidden_gem_candidates p on p.id = ui.place_id
    where ui.user_id = auth.uid() and ui.interaction_type = 'view'
    order by ui.place_id, ui.created_at desc
  ) recent
  order by viewed_at desc
  limit p_limit;
$$;

grant execute on function public.recently_viewed_places(int) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Recompute scores/trending for the newly-copied rows right away,
--    rather than waiting for the next hourly pg_cron tick, so they show up
--    correctly scored the moment this migration finishes.
-- ---------------------------------------------------------------------
select public.recompute_hidden_gem_scores();
select public.detect_trending_destinations();
