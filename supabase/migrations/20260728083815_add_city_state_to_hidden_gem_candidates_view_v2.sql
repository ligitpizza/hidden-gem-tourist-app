
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
  p.state
from places p
left join reviews r on r.place_id = p.id
group by p.id, p.name, p.description, p.category, p.latitude, p.longitude,
  p.uniqueness_score, p.accessibility_score, p.popularity, p.city, p.state;
;
