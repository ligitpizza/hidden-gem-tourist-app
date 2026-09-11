-- Closes a real gap found while prepping the presentation: selecting a
-- travel style at onboarding/preference-setup never actually affected
-- ranking. get_personalized_recommendations()'s affinity boost came
-- entirely from user_category_affinity (a view over real, decayed
-- user_interactions rows) -- it never once read
-- user_travel_preferences.categories. Re-selecting your styles just
-- called recompute_hidden_gem_scores() (the *global*, non-personal
-- score) and reloaded the same personalized numbers, which is exactly
-- why the score never visibly moved.
--
-- Budget range and destination type are NOT wired here -- budget's only
-- real signal (places.entrance_cost) covers ~2% of places (the merged
-- destinations only), and destination type (urban/rural/nature
-- reserve/mixed) has no existing classification of places to hook into
-- at all. Wiring either "for real" right now would mean inventing data
-- that doesn't exist, the same tradeoff already declined for photos.

-- ---------------------------------------------------------------------
-- 1. Configurable baseline boost a place gets just for matching one of
--    the tourist's explicitly selected travel styles, even before any
--    real interaction history exists for that style. Roughly "a couple
--    of saves worth" (interaction_weights: save=2, itinerary_add=3) by
--    default -- meaningful on a fresh account, but small enough that
--    real behavior naturally outweighs it once it accumulates.
-- ---------------------------------------------------------------------
alter table public.hidden_gem_scoring_config
  add column if not exists preference_baseline_boost numeric not null default 3;

-- ---------------------------------------------------------------------
-- 2. get_personalized_recommendations() now blends real, decayed
--    affinity with a flat baseline for any explicitly selected style --
--    additive, not a replacement, so a style you've both selected AND
--    actually engaged with gets both. A style you've engaged with but
--    didn't select still works exactly as before (real behavior alone
--    is enough). Return signature is unchanged, so create or replace
--    works without dropping first this time.
-- ---------------------------------------------------------------------
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
  behavior_affinity as (
    select category, affinity_score
    from user_category_affinity
    where user_id = auth.uid()
  ),
  selected_styles as (
    select unnest(categories) as category
    from user_travel_preferences
    where user_id = auth.uid()
  ),
  cfg as (
    select preference_baseline_boost from hidden_gem_scoring_config where id = 1
  ),
  -- Full outer join: a style can have real behavior affinity, a
  -- baseline from being selected, both, or (for behavior_affinity rows
  -- whose category was never selected) just the real number unchanged.
  affinity as (
    select
      coalesce(b.category, s.category) as category,
      coalesce(b.affinity_score, 0)
        + case when s.category is not null then coalesce((select preference_baseline_boost from cfg), 3) else 0 end
        as affinity_score
    from behavior_affinity b
    full outer join selected_styles s on s.category = b.category
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
