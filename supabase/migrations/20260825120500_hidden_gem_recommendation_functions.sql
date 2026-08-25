-- Module 1: Hidden Gem Recommendations — engine functions.
--
-- These three functions are the "System Timer" actor and the
-- Recommendation Engine from the team's use case diagram / activity
-- diagrams:
--   recompute_hidden_gem_scores()      <- "Score All Hidden Gems"
--   detect_trending_destinations()     <- "Detect Trending Destinations"
--   get_personalized_recommendations() <- "View Recommended Destinations"
--     (called directly by the app on demand; the first two are also
--     scheduled via pg_cron at the bottom of this file so they run
--     without the app asking, matching "Triggered automatically ... on a
--     scheduled basis").

-- ---------------------------------------------------------------------
-- Score All Hidden Gems (FR2.1-FR2.3)
-- ---------------------------------------------------------------------
create or replace function public.recompute_hidden_gem_scores()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  cfg record;
begin
  select * into cfg from hidden_gem_scoring_config where id = 1;
  if not found then
    -- E2 in "Score All Hidden Gems": nothing configured yet, skip this run
    -- rather than fail the whole scheduled job.
    return;
  end if;

  with metrics as (
    select
      p.id,
      p.uniqueness_score,
      p.accessibility_score,
      p.popularity,
      coalesce(m.avg_rating, 0) as avg_rating
    from places p
    left join place_review_metrics m on m.place_id = p.id
  ),
  engagement as (
    select place_id, count(*) as interaction_count
    from user_interactions
    where created_at > now() - make_interval(days => cfg.popularity_interaction_window_days)
    group by place_id
  ),
  scored as (
    select
      me.id,
      -- A1 in "Score All Hidden Gems": missing rating/uniqueness/
      -- accessibility default to 0 via coalesce, so a place with gaps
      -- still gets scored instead of blocking the whole run.
      (coalesce(me.avg_rating, 0) / 5.0) * cfg.rating_weight
        + (coalesce(me.uniqueness_score, 0) / 5.0) * cfg.uniqueness_weight
        + (coalesce(me.accessibility_score, 0) / 5.0) * cfg.accessibility_weight
        + (case me.popularity
             when 'low' then cfg.popularity_bonus_low
             when 'medium' then cfg.popularity_bonus_medium
             when 'high' then cfg.popularity_bonus_high
             else cfg.popularity_bonus_medium
           end) * cfg.popularity_weight
        - (case
             when coalesce(e.interaction_count, 0) > cfg.popularity_interaction_threshold
             then cfg.popularity_deduction_points
             else 0
           end) as raw_score
    from metrics me
    left join engagement e on e.place_id = me.id
  )
  update places p
  set hidden_gem_score = greatest(0, least(1, s.raw_score)),
      score_updated_at = now()
  from scored s
  where p.id = s.id;
end;
$$;

-- ---------------------------------------------------------------------
-- Detect Trending Destinations (FR4.1-FR4.3)
-- ---------------------------------------------------------------------
create or replace function public.detect_trending_destinations()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  cfg record;
begin
  select * into cfg from trending_config where id = 1;
  if not found then
    -- E2 in "Detect Trending Destinations": halt this run, keep existing
    -- labels untouched, and try again on the next scheduled trigger.
    return;
  end if;

  with engagement_events as (
    select place_id, created_at from user_interactions
    union all
    select place_id, created_at from reviews
  ),
  current_period as (
    select place_id, count(*) as cnt
    from engagement_events
    where created_at > now() - make_interval(days => cfg.rolling_window_days)
    group by place_id
  ),
  previous_period as (
    select place_id, count(*) as cnt
    from engagement_events
    where created_at <= now() - make_interval(days => cfg.rolling_window_days)
      and created_at > now() - make_interval(days => cfg.rolling_window_days * 2)
    group by place_id
  ),
  growth as (
    select
      p.id as place_id,
      coalesce(c.cnt, 0) as current_count,
      coalesce(pr.cnt, 0) as previous_count,
      case
        when coalesce(pr.cnt, 0) = 0
          then case when coalesce(c.cnt, 0) >= cfg.min_engagement_count then 1.0 else 0 end
        else (coalesce(c.cnt, 0) - pr.cnt)::numeric / pr.cnt
      end as growth_rate
    from places p
    left join current_period c on c.place_id = p.id
    left join previous_period pr on pr.place_id = p.id
  ),
  qualifies as (
    select
      g.*,
      (g.growth_rate >= cfg.growth_threshold_pct and g.current_count >= cfg.min_engagement_count) as trending
    from growth g
  )
  update places p
  set
    engagement_growth_rate = q.growth_rate,
    -- A2 in "Detect Trending Destinations": a place that drops back below
    -- threshold loses the label on this same update (trending = false).
    is_trending = q.trending,
    trending_since = case
      when q.trending and not p.is_trending then now()
      when q.trending then p.trending_since
      else null
    end
  from qualifies q
  where p.id = q.place_id;
end;
$$;

-- ---------------------------------------------------------------------
-- View Recommended Destinations (FR1.2-FR1.3) — combines the persisted
-- global hidden_gem_score with the caller's own recency-weighted category
-- affinity (Smart Preference Learning) and the given month's seasonal
-- suitability (FR3.4/3.5) into one ranked, personalized list.
-- ---------------------------------------------------------------------
create or replace function public.get_personalized_recommendations(
  p_limit int default 20,
  p_month smallint default null
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
    select coalesce(p_month, extract(month from now())::smallint) as m
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
    -- Base score (0-1) boosted up to +50% by how strongly this place's
    -- style matches the tourist's learned interests, and up to +25% by
    -- how suitable it is for their travel month — unmatched/unrated
    -- dimensions contribute their neutral midpoint instead of zeroing the
    -- place out entirely.
    coalesce(c.hidden_gem_score, 0)
      * (1 + coalesce((
          select a.affinity_score
          from affinity a
          join place_travel_style_map ps on ps.style = a.category
          where ps.place_id = c.id
        ), 0) / (select m from max_affinity) * 0.5)
      -- Neutral (multiplier exactly 1.0) whenever this place has no
      -- seasonality row for the given month — coalescing straight to 2.5
      -- here would silently give *every* unrated place the same "half of
      -- max" +25% boost, which is what was happening before this fix,
      -- since place_seasonality isn't seeded with any data yet. Only a
      -- real suitability_score should move the multiplier off 1.0.
      * (1 + (coalesce((
          select s.suitability_score
          from place_seasonality s, month
          where s.place_id = c.id and s.month = month.m
        ), 2.5) - 2.5) / 10.0)
      as personalized_score
  from place_hidden_gem_candidates c
  -- Tiebreaker (E2 in "View Recommended Destinations" / "Score All Hidden
  -- Gems"): equal scores fall back to alphabetical order.
  order by personalized_score desc nulls last, c.name asc
  limit p_limit;
$$;

grant execute on function public.get_personalized_recommendations(int, smallint) to authenticated;

-- ---------------------------------------------------------------------
-- System Timer — schedule both engine functions via pg_cron, if the
-- extension is enabled on this project (Dashboard -> Database ->
-- Extensions -> pg_cron). If it isn't enabled yet, this block is a no-op;
-- enable the extension and rerun just this section, or call the two
-- functions from an external scheduler (e.g. a scheduled Edge Function or
-- GitHub Action hitting the Supabase REST RPC endpoint) instead.
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'recompute-hidden-gem-scores') then
      perform cron.unschedule('recompute-hidden-gem-scores');
    end if;
    if exists (select 1 from cron.job where jobname = 'detect-trending-destinations') then
      perform cron.unschedule('detect-trending-destinations');
    end if;

    perform cron.schedule(
      'recompute-hidden-gem-scores',
      '15 * * * *',
      $cron$select public.recompute_hidden_gem_scores();$cron$
    );
    perform cron.schedule(
      'detect-trending-destinations',
      '30 * * * *',
      $cron$select public.detect_trending_destinations();$cron$
    );
  end if;
end $$;
