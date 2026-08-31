-- Closes two gaps in Module 1: FR3.4/3.5 (seasonal suitability) had the
-- scoring mechanism wired but no real data and no way for a tourist to
-- set their intended travel period; "Recently Viewed" on the Travel
-- Pulse mockup was never built.

-- ---------------------------------------------------------------------
-- 1. Let a tourist store their intended travel month as part of their
--    profile (FR3.4: "compare against the user's intended travel
--    period"). Nullable -- "no preference" falls back to the current
--    month, same as before this migration.
-- ---------------------------------------------------------------------
alter table public.user_travel_preferences
  add column if not exists intended_travel_month smallint check (intended_travel_month between 1 and 12);

-- ---------------------------------------------------------------------
-- 2. Heuristic seasonal suitability for every Penang place, one row per
--    month. Placeholder in the same spirit as the original
--    uniqueness_score/accessibility_score seed
--    (20260728080815_add_hidden_gem_scoring_attributes.sql) -- swap for
--    real data (a weather API, local knowledge) once available. Outdoor/
--    exposed categories score lower during Penang's wetter Sept-Nov
--    window (Sumatra squalls / monsoon transition); indoor or covered
--    categories are treated as weather-insensitive and stay flat.
-- ---------------------------------------------------------------------
insert into public.place_seasonality (place_id, month, suitability_score)
select
  p.id,
  m.month,
  case
    when p.category in ('waterfall', 'mountain', 'park', 'beach', 'island', 'viewpoint')
      then case when m.month in (9, 10, 11) then 2.0 else 4.2 end
    else 4.5
  end
from public.places p
cross join generate_series(1, 12) as m(month)
where p.state = 'Penang'
on conflict (place_id, month) do nothing;

-- ---------------------------------------------------------------------
-- 3. get_personalized_recommendations now defaults to the tourist's own
--    stored intended_travel_month (if set) instead of always assuming
--    "right now" -- an explicit p_month argument still overrides both.
--
--    Also fixes p_month's type from smallint to int (see the parameter
--    comment below). Changing a parameter's type is a different function
--    signature as far as Postgres is concerned, so `create or replace`
--    alone would leave the old (int, smallint) overload sitting
--    alongside this one instead of actually replacing it -- drop it
--    explicitly first.
-- ---------------------------------------------------------------------
drop function if exists public.get_personalized_recommendations(int, smallint);

create or replace function public.get_personalized_recommendations(
  p_limit int default 20,
  -- Plain int, not smallint -- see the same fix in the original
  -- 20260825120500 migration's function comment for why.
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
    c.hidden_gem_score, c.is_trending, c.engagement_growth_rate,
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

-- ---------------------------------------------------------------------
-- 4. "Recently Viewed" (Travel Pulse mockup) -- the caller's own most
--    recent view per place, newest first. Deliberately plain SECURITY
--    INVOKER (the default for a `language sql` function): it only ever
--    needs to see the caller's own user_interactions rows, which
--    that table's existing RLS policy already grants -- no elevated
--    privilege required, unlike the scoring/trending engine functions
--    which must see every tourist's data to do their job.
-- ---------------------------------------------------------------------
create or replace function public.recently_viewed_places(p_limit int default 5)
returns table (
  place_id uuid,
  viewed_at timestamptz,
  name text,
  category text,
  city text,
  state text,
  hidden_gem_score numeric
)
language sql
stable
set search_path = public
as $$
  select place_id, viewed_at, name, category, city, state, hidden_gem_score
  from (
    select distinct on (ui.place_id)
      ui.place_id,
      ui.created_at as viewed_at,
      p.name, p.category, p.city, p.state, p.hidden_gem_score
    from user_interactions ui
    join place_hidden_gem_candidates p on p.id = ui.place_id
    where ui.user_id = auth.uid() and ui.interaction_type = 'view'
    order by ui.place_id, ui.created_at desc
  ) recent
  order by viewed_at desc
  limit p_limit;
$$;

grant execute on function public.recently_viewed_places(int) to authenticated;
