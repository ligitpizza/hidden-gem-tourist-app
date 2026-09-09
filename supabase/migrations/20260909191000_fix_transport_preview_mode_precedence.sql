-- Explicit rail modes must win over bus-feed branding. Some GTFS bus feeds
-- contain shared or interchange stops whose catalogue subtype is MRT/LRT.
-- Those stops should display the train mode, not a representative bus.

create or replace function public.eco_partner_transport_preview_key(
  p_feed_id text,
  p_subtype text
)
returns text
language sql
immutable
parallel safe
as $$
  select case
    when lower(coalesce(p_subtype, '')) = 'mrt' then 'mrt'
    when lower(coalesce(p_subtype, '')) in ('lrt', 'light rail') then 'lrt'
    when lower(coalesce(p_subtype, '')) = 'monorail' then 'monorail'
    when lower(coalesce(p_subtype, '')) = 'ktm' then 'ktm'
    when p_feed_id = 'ktmb' then 'ktm'
    when p_feed_id in (
      'prasarana-rapid-bus-kl',
      'prasarana-rapid-bus-mrtfeeder'
    ) then 'rapid-kl-bus'
    when p_feed_id = 'prasarana-rapid-bus-penang'
      then 'rapid-penang-bus'
    when p_feed_id like 'mybas-%' then 'bas-my-bus'
    when lower(coalesce(p_subtype, '')) = 'bus' then 'generic-bus'
    else 'generic-rail'
  end
$$;

-- Correct existing catalogue rows immediately. The trigger installed by the
-- previous migration automatically uses this updated function for new feeds.
select public.apply_gtfs_transport_preview_images(null);

revoke all on function public.eco_partner_transport_preview_key(text, text)
  from public, anon, authenticated;
