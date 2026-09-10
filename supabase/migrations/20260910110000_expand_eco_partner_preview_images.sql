-- Expand deterministic Eco Partner previews without adding any runtime image
-- provider calls. Transport partners receive one of three images for their
-- mode; dining and EV partners receive one of eight category images.

insert into public.eco_partner_preview_assets (
  preview_key, display_name, storage_path, attribution, source_url,
  license, captured_on
) values
  (
    'generic-bus-2', 'Public bus', 'transport/generic-bus-2.webp',
    'Representative bus image - Photo by nana liu - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/dubai-public-bus-at-a-city-street-stop-31413028/',
    'Pexels License', null
  ),
  (
    'generic-bus-3', 'Public bus', 'transport/generic-bus-3.webp',
    'Representative bus image - Photo by FranDany - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/a-bus-on-a-street-19886953/',
    'Pexels License', null
  ),
  (
    'mrt-2', 'MRT train', 'transport/mrt-2.webp',
    'Representative MRT image - Photo by Vika Glitter - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/metro-train-on-station-14567020/',
    'Pexels License', null
  ),
  (
    'mrt-3', 'MRT train', 'transport/mrt-3.webp',
    'Representative MRT image - Photo by Elena Saharova - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/metro-station-with-passengers-on-platform-5098043/',
    'Pexels License', null
  ),
  (
    'lrt-2', 'LRT train', 'transport/lrt-2.webp',
    'Representative LRT image - Photo by Valeria Palesska - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/tram-in-city-11440117/',
    'Pexels License', null
  ),
  (
    'lrt-3', 'LRT train', 'transport/lrt-3.webp',
    'Representative LRT image - Photo by Masood Aslami - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/modern-tram-in-a-city-street-19969200/',
    'Pexels License', null
  ),
  (
    'monorail-2', 'KL Monorail train', 'transport/monorail-2.webp',
    'Representative KL Monorail image - Photo by Raveender Nagaraju - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/monorail-in-kuala-lumpur-13459238/',
    'Pexels License', null
  ),
  (
    'monorail-3', 'KL Monorail train', 'transport/monorail-3.webp',
    'Representative KL Monorail image - Photo by Theodore Nguyen - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/low-angle-shot-of-a-train-27088155/',
    'Pexels License', null
  ),
  (
    'ktm-2', 'Commuter train', 'transport/ktm-2.webp',
    'Representative KTM image - Photo by el jusuf - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/view-of-a-railway-station-14815541/',
    'Pexels License', null
  ),
  (
    'ktm-3', 'Commuter train', 'transport/ktm-3.webp',
    'Representative KTM image - Photo by Kristina Chuprina - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/front-of-a-train-arriving-at-a-station-10188084/',
    'Pexels License', null
  ),
  (
    'generic-rail-2', 'Passenger train', 'transport/generic-rail-2.webp',
    'Representative rail image - Photo by ERFIN EKARANA - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/train-approaching-platform-in-heavy-rain-30345921/',
    'Pexels License', null
  ),
  (
    'generic-rail-3', 'Passenger train', 'transport/generic-rail-3.webp',
    'Representative rail image - Photo by Syafirdaus Adam - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/people-waiting-on-the-train-station-14430656/',
    'Pexels License', null
  ),
  (
    'dining-6', 'Plant-friendly dining', 'dining/dining-6.webp',
    'Representative dining image - Photo by Laura oliveira - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/healthy-vegan-buddha-bowl-with-tofu-and-rice-34429488/',
    'Pexels License', null
  ),
  (
    'dining-7', 'Plant-friendly dining', 'dining/dining-7.webp',
    'Representative dining image - Photo by Amine Kubranur Cakiroglu - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/colorful-vegan-bowl-at-a-cozy-cafe-38935356/',
    'Pexels License', null
  ),
  (
    'dining-8', 'Plant-friendly dining', 'dining/dining-8.webp',
    'Representative dining image - Photo by ROMAN ODINTSOV - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/appetizing-assorted-asian-dishes-served-on-table-with-glass-of-cold-drink-4552106/',
    'Pexels License', null
  ),
  (
    'ev-6', 'Electric vehicle charging', 'ev/ev-6.webp',
    'Representative EV charging image - Photo by Sasha Vukovic - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/electric-car-charging-station-with-vehicle-plugged-in-36339137/',
    'Pexels License', null
  ),
  (
    'ev-7', 'Electric vehicle charging', 'ev/ev-7.webp',
    'Representative EV charging image - Photo by Giant Asparagus - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/electric-car-charging-at-station-with-multiple-chargers-37576187/',
    'Pexels License', null
  ),
  (
    'ev-8', 'Electric vehicle charging', 'ev/ev-8.webp',
    'Representative EV charging image - Photo by Arlind D - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/electric-car-charging-station-at-supermarket-31538378/',
    'Pexels License', null
  )
on conflict (preview_key) do update set
  display_name = excluded.display_name,
  storage_path = excluded.storage_path,
  attribution = excluded.attribution,
  source_url = excluded.source_url,
  license = excluded.license,
  captured_on = excluded.captured_on;

create or replace function public.eco_partner_transport_preview_key_for_partner(
  p_partner_id text,
  p_feed_id text,
  p_subtype text
)
returns text
language sql
immutable
parallel safe
as $$
  with selected as (
    select
      public.eco_partner_transport_preview_key(
        p_feed_id,
        p_subtype
      ) as base_key,
      1 + get_byte(
        decode(md5(coalesce(p_partner_id, '')), 'hex'),
        0
      ) % 3 as variant
  )
  select case
    when variant = 1 then base_key
    when base_key in (
      'rapid-kl-bus', 'rapid-penang-bus', 'bas-my-bus', 'generic-bus'
    ) then 'generic-bus-' || variant::text
    else base_key || '-' || variant::text
  end
  from selected
$$;

create or replace function public.apply_gtfs_transport_preview_images(
  p_feed_id text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.eco_partner_catalog c
  set image_url = 'storage://eco-partner-previews/' || a.storage_path,
      image_source_name = a.attribution,
      image_source_url = a.source_url,
      image_captured_at = a.captured_on::timestamptz
  from public.gtfs_stops s, public.eco_partner_preview_assets a
  where c.active
    and c.source = 'gtfs'
    and c.source_id = s.id
    and (p_feed_id is null or s.feed_id = p_feed_id)
    and a.preview_key = public.eco_partner_transport_preview_key_for_partner(
      c.id,
      s.feed_id,
      c.subtype
    );

  get diagnostics v_count = row_count;
  return v_count;
end
$$;

create or replace function public.set_gtfs_transport_preview_image()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_asset public.eco_partner_preview_assets%rowtype;
begin
  if new.source <> 'gtfs' then return new; end if;

  select a.* into v_asset
  from public.gtfs_stops s
  join public.eco_partner_preview_assets a
    on a.preview_key = public.eco_partner_transport_preview_key_for_partner(
      new.id,
      s.feed_id,
      new.subtype
    )
  where s.id = new.source_id
  limit 1;

  if found then
    new.image_url := 'storage://eco-partner-previews/' || v_asset.storage_path;
    new.image_source_name := v_asset.attribution;
    new.image_source_url := v_asset.source_url;
    new.image_captured_at := v_asset.captured_on::timestamptz;
  end if;
  return new;
end
$$;

drop trigger if exists eco_partner_gtfs_preview_image
  on public.eco_partner_catalog;
create trigger eco_partner_gtfs_preview_image
before insert or update of id, source, source_id, subtype
on public.eco_partner_catalog
for each row execute function public.set_gtfs_transport_preview_image();

create or replace function public.eco_partner_category_preview_key(
  p_partner_id text,
  p_category text,
  p_subtype text
)
returns text
language sql
immutable
parallel safe
as $$
  select case
    when lower(trim(coalesce(p_category, ''))) = 'dining' then
      'dining-' || (
        1 + get_byte(decode(md5(coalesce(p_partner_id, '')), 'hex'), 0) % 8
      )::text
    when lower(trim(coalesce(p_category, ''))) = 'transport'
      and lower(trim(coalesce(p_subtype, ''))) in (
        'ev charging', 'ev_charging', 'charging station', 'charging_station'
      ) then
      'ev-' || (
        1 + get_byte(decode(md5(coalesce(p_partner_id, '')), 'hex'), 0) % 8
      )::text
    else null
  end
$$;

-- Reassign existing rows immediately. The triggers keep the same deterministic
-- mapping during later GTFS and OSM replacements.
select public.apply_gtfs_transport_preview_images(null);
select public.apply_eco_partner_category_preview_images();

revoke all on function public.eco_partner_transport_preview_key_for_partner(
  text, text, text
) from public, anon, authenticated;
revoke all on function public.eco_partner_category_preview_key(text, text, text)
  from public, anon, authenticated;
revoke all on function public.apply_gtfs_transport_preview_images(text)
  from public, anon, authenticated;
revoke all on function public.set_gtfs_transport_preview_image()
  from public, anon, authenticated;
grant execute on function public.apply_gtfs_transport_preview_images(text)
  to service_role;
