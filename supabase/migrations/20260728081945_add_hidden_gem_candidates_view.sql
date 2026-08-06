
-- Single view combining a place's location/attributes with its real review
-- metrics, so a bounding-box "gems along this route corridor" search is one
-- request instead of a bbox query + a huge id-list join (which breaks once
-- a corridor spans 1000+ candidate places).
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
  coalesce(avg(r.rating), 0) as avg_rating
from places p
left join reviews r on r.place_id = p.id
group by p.id, p.name, p.description, p.category, p.latitude, p.longitude,
  p.uniqueness_score, p.accessibility_score, p.popularity;
;
