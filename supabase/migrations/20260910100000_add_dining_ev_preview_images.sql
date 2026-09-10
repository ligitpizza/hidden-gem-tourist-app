-- Add deterministic, bucket-hosted previews for dining and EV partners.
-- The app never loads the original Pexels files at runtime; source pages are
-- retained only for attribution in Partner Details.

insert into public.eco_partner_preview_assets (
  preview_key, display_name, storage_path, attribution, source_url,
  license, captured_on
) values
  (
    'dining-1', 'Plant-friendly dining', 'dining/dining-1.webp',
    'Representative dining image - Photo by Tima Miroshnichenko - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/a-vegan-food-with-sliced-tomatoes-and-cucumbers-on-the-side-6327660/',
    'Pexels License', null
  ),
  (
    'dining-2', 'Plant-friendly dining', 'dining/dining-2.webp',
    'Representative dining image - Photo by Jose Lopez - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/soup-with-vegetables-20161079/',
    'Pexels License', null
  ),
  (
    'dining-3', 'Plant-friendly dining', 'dining/dining-3.webp',
    'Representative dining image - Photo by Tima Miroshnichenko - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/a-vegan-foods-on-a-ceramic-plate-6327595/',
    'Pexels License', null
  ),
  (
    'dining-4', 'Plant-friendly dining', 'dining/dining-4.webp',
    'Representative dining image - Photo by Karography - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/delicious-dish-on-plate-on-restaurant-table-18446102/',
    'Pexels License', null
  ),
  (
    'dining-5', 'Plant-friendly dining', 'dining/dining-5.webp',
    'Representative dining image - Photo by Lucille Conde - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/vibrant-vegan-feast-with-fresh-ingredients-36161761/',
    'Pexels License', null
  ),
  (
    'ev-1', 'Electric vehicle charging', 'ev/ev-1.webp',
    'Representative EV charging image - Photo by Dean Fugate - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/electric-car-charger-17748317/',
    'Pexels License', null
  ),
  (
    'ev-2', 'Electric vehicle charging', 'ev/ev-2.webp',
    'Representative EV charging image - Photo by Kindel Media - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/electric-car-charging-station-9800000/',
    'Pexels License', null
  ),
  (
    'ev-3', 'Electric vehicle charging', 'ev/ev-3.webp',
    'Representative EV charging image - Photo by smart-me AG - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/electric-car-charging-station-in-outdoor-setting-34800931/',
    'Pexels License', null
  ),
  (
    'ev-4', 'Electric vehicle charging', 'ev/ev-4.webp',
    'Representative EV charging image - Photo by Harry Tucker - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/electric-car-charging-at-station-in-australia-33083246/',
    'Pexels License', null
  ),
  (
    'ev-5', 'Electric vehicle charging', 'ev/ev-5.webp',
    'Representative EV charging image - Photo by Magda Ehlers - Pexels License - cropped/compressed',
    'https://www.pexels.com/photo/charging-station-for-electric-cars-15158968/',
    'Pexels License', null
  )
on conflict (preview_key) do update set
  display_name = excluded.display_name,
  storage_path = excluded.storage_path,
  attribution = excluded.attribution,
  source_url = excluded.source_url,
  license = excluded.license,
  captured_on = excluded.captured_on;

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
        1 + get_byte(decode(md5(coalesce(p_partner_id, '')), 'hex'), 0) % 5
      )::text
    when lower(trim(coalesce(p_category, ''))) = 'transport'
      and lower(trim(coalesce(p_subtype, ''))) in (
        'ev charging', 'ev_charging', 'charging station', 'charging_station'
      ) then
      'ev-' || (
        1 + get_byte(decode(md5(coalesce(p_partner_id, '')), 'hex'), 0) % 5
      )::text
    else null
  end
$$;

create or replace function public.apply_eco_partner_category_preview_images()
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
  from public.eco_partner_preview_assets a
  where c.active
    and a.preview_key = public.eco_partner_category_preview_key(
      c.id,
      c.category,
      c.subtype
    );

  get diagnostics v_count = row_count;
  return v_count;
end
$$;

create or replace function public.set_eco_partner_category_preview_image()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_asset public.eco_partner_preview_assets%rowtype;
  v_preview_key text;
begin
  v_preview_key := public.eco_partner_category_preview_key(
    new.id,
    new.category,
    new.subtype
  );
  if v_preview_key is null then return new; end if;

  select a.* into v_asset
  from public.eco_partner_preview_assets a
  where a.preview_key = v_preview_key;

  if found then
    new.image_url := 'storage://eco-partner-previews/' || v_asset.storage_path;
    new.image_source_name := v_asset.attribution;
    new.image_source_url := v_asset.source_url;
    new.image_captured_at := v_asset.captured_on::timestamptz;
  end if;
  return new;
end
$$;

drop trigger if exists eco_partner_category_preview_image
  on public.eco_partner_catalog;
create trigger eco_partner_category_preview_image
before insert or update of id, category, subtype
on public.eco_partner_catalog
for each row execute function public.set_eco_partner_category_preview_image();

-- Backfill existing dining and EV rows immediately. The trigger above keeps
-- future OSM replacements deterministic without changing the sync function.
select public.apply_eco_partner_category_preview_images();

revoke all on function public.eco_partner_category_preview_key(text, text, text)
  from public, anon, authenticated;
revoke all on function public.apply_eco_partner_category_preview_images()
  from public, anon, authenticated;
revoke all on function public.set_eco_partner_category_preview_image()
  from public, anon, authenticated;
grant execute on function public.apply_eco_partner_category_preview_images()
  to service_role;
