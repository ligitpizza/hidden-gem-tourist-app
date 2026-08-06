
alter table places
  add column if not exists uniqueness_score numeric,
  add column if not exists accessibility_score numeric,
  add column if not exists popularity text check (popularity in ('low','medium','high'));

-- Placeholder hidden-gem attributes for every Penang place: uniqueness and
-- accessibility are heuristic (category baseline + randomness) until a real
-- signal exists; popularity is data-driven from real review volume so it
-- reflects genuine discovery levels, not a guess.
with base as (
  select
    id,
    case category
      when 'waterfall' then 4.5
      when 'viewpoint' then 4.2
      when 'craft' then 4.3
      when 'art' then 4.0
      when 'heritage_site' then 4.0
      when 'museum' then 3.8
      when 'park' then 3.5
      when 'beach' then 3.5
      when 'attraction' then 3.0
      when 'cafe' then 2.0
      when 'restaurant' then 1.8
      else 2.5
    end as uniqueness_base,
    case category
      when 'restaurant' then 4.2
      when 'cafe' then 4.2
      when 'museum' then 4.0
      when 'attraction' then 3.8
      when 'heritage_site' then 3.8
      when 'art' then 3.5
      when 'beach' then 3.2
      when 'craft' then 3.3
      when 'park' then 3.0
      when 'viewpoint' then 2.8
      when 'waterfall' then 2.0
      else 3.0
    end as accessibility_base
  from places
  where state = 'Penang'
)
update places p
set
  uniqueness_score = round(least(5.0, greatest(0.0, base.uniqueness_base + (random() * 2 - 1)))::numeric, 1),
  accessibility_score = round(least(5.0, greatest(0.0, base.accessibility_base + (random() * 2 - 1)))::numeric, 1)
from base
where p.id = base.id;

update places p
set popularity = case
  when m.review_count >= 18 then 'high'
  when m.review_count >= 14 then 'medium'
  else 'low'
end
from place_review_metrics m
where m.place_id = p.id and p.state = 'Penang';
;
