-- Bug fix: FavouriteDestinationRepository.fetchAll() queries `places`
-- directly to resolve a favourited place's details (see
-- 20260902140000_favourite_destinations_on_places.sql), but `places` has
-- no `avg_rating` column at all -- it's only ever computed by this view
-- from real `reviews` rows. Every favourited place was showing 0.0 stars
-- regardless of its real rating, confirmed live for Seng Thor Restaurant.
--
-- Fix: add the remaining ComparisonDestination columns this view was
-- still missing (crowd_level, entrance_cost, difficulty_level,
-- accessibility_tags, visit_duration_minutes, operating_hours -- already
-- on `places` itself, just never exposed through this view), so
-- fetchAll() can query this view instead of the raw table and get a
-- correctly-computed avg_rating along with everything else, in one query.
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
  p.images,
  p.crowd_level,
  p.entrance_cost,
  p.difficulty_level,
  p.accessibility_tags,
  p.visit_duration_minutes,
  p.operating_hours
from public.places p
left join public.reviews r on r.place_id = p.id
group by p.id, p.name, p.description, p.category, p.latitude, p.longitude,
  p.uniqueness_score, p.accessibility_score, p.popularity, p.city, p.state,
  p.hidden_gem_score, p.score_updated_at, p.is_trending, p.trending_since,
  p.engagement_growth_rate, p.images, p.crowd_level, p.entrance_cost,
  p.difficulty_level, p.accessibility_tags, p.visit_duration_minutes,
  p.operating_hours;
