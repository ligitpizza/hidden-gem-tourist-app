-- Replace location-based Mapillary transport previews with a deterministic,
-- licensed set of representative Malaysian transport images in Supabase
-- Storage. This migration is safe whether or not the previous image queue was
-- deployed.

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
) values (
  'eco-partner-previews',
  'eco-partner-previews',
  true,
  307200,
  array['image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.eco_partner_preview_assets (
  preview_key text primary key,
  display_name text not null,
  storage_path text not null,
  attribution text not null,
  source_url text not null,
  license text not null,
  captured_on date,
  unique (storage_path)
);

alter table public.eco_partner_preview_assets enable row level security;
revoke all on public.eco_partner_preview_assets from anon;
grant select on public.eco_partner_preview_assets to authenticated;

drop policy if exists "Authenticated users read Eco Partner preview assets"
  on public.eco_partner_preview_assets;
create policy "Authenticated users read Eco Partner preview assets"
  on public.eco_partner_preview_assets for select
  to authenticated using (true);

insert into public.eco_partner_preview_assets (
  preview_key, display_name, storage_path, attribution, source_url,
  license, captured_on
) values
  (
    'rapid-kl-bus', 'Rapid KL bus', 'transport/rapid-kl-bus.webp',
    'Representative Rapid KL bus image · Photo by CEphoto, Uwe Aranas · CC BY-SA 3.0 · cropped/compressed',
    'https://commons.wikimedia.org/wiki/File:Kuala_Lumpur_Malaysia_rapidKL-bus-01.jpg',
    'CC BY-SA 3.0', '2013-09-07'
  ),
  (
    'rapid-penang-bus', 'Rapid Penang bus', 'transport/rapid-penang-bus.webp',
    'Representative Rapid Penang bus image · damnsoft_09 · CC BY-SA 3.0 · cropped/compressed',
    'https://commons.wikimedia.org/wiki/File:Rapidpenangbus.jpg',
    'CC BY-SA 3.0', '2008-08-31'
  ),
  (
    'bas-my-bus', 'BAS.MY bus', 'transport/bas-my-bus.webp',
    'Representative BAS.MY bus image · JaventheAlderick · CC BY-SA 4.0 · cropped/compressed',
    'https://commons.wikimedia.org/wiki/File:BAS.MY_Johor_Bahru_Bus_J34_at_Sutera_Mall.jpg',
    'CC BY-SA 4.0', '2025-11-08'
  ),
  (
    'mrt', 'MRT train', 'transport/mrt.webp',
    'Representative MRT image · Sirap bandung · CC BY-SA 4.0 · cropped/compressed',
    'https://commons.wikimedia.org/wiki/File:Siemens_Inspiro_MRT_SBK.jpg',
    'CC BY-SA 4.0', '2016-08-30'
  ),
  (
    'lrt', 'LRT train', 'transport/lrt.webp',
    'Representative LRT image · A2613 · CC BY-SA 4.0 · cropped/compressed',
    'https://commons.wikimedia.org/wiki/File:LRT_Kuala_Lumpur.jpg',
    'CC BY-SA 4.0', '2024-08-09'
  ),
  (
    'monorail', 'KL Monorail train', 'transport/monorail.webp',
    'Representative KL Monorail image · Andrew Lawson · CC BY 2.0 · cropped/compressed',
    'https://commons.wikimedia.org/wiki/File:Kuala_Lumpur_Monorail_01.jpg',
    'CC BY 2.0', '2007-08-25'
  ),
  (
    'ktm', 'KTM Komuter train', 'transport/ktm.webp',
    'Representative KTM Komuter image · Two hundred percent · CC BY-SA 2.5 · cropped/compressed',
    'https://commons.wikimedia.org/wiki/File:Class_81_KTM_Komuter_train,_Kuala_Lumpur.jpg',
    'CC BY-SA 2.5', '2007-02-08'
  ),
  (
    'generic-bus', 'Malaysian public bus', 'transport/generic-bus.webp',
    'Representative Malaysian bus image · Photo by CEphoto, Uwe Aranas · CC BY-SA 3.0 · cropped/compressed',
    'https://commons.wikimedia.org/wiki/File:Kuala_Lumpur_Malaysia_rapidKL-bus-01.jpg',
    'CC BY-SA 3.0', '2013-09-07'
  ),
  (
    'generic-rail', 'Malaysian passenger train', 'transport/generic-rail.webp',
    'Representative Malaysian rail image · Two hundred percent · CC BY-SA 2.5 · cropped/compressed',
    'https://commons.wikimedia.org/wiki/File:Class_81_KTM_Komuter_train,_Kuala_Lumpur.jpg',
    'CC BY-SA 2.5', '2007-02-08'
  )
on conflict (preview_key) do update set
  display_name = excluded.display_name,
  storage_path = excluded.storage_path,
  attribution = excluded.attribution,
  source_url = excluded.source_url,
  license = excluded.license,
  captured_on = excluded.captured_on;

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
    when p_feed_id = 'ktmb' then 'ktm'
    when p_feed_id in (
      'prasarana-rapid-bus-kl',
      'prasarana-rapid-bus-mrtfeeder'
    ) then 'rapid-kl-bus'
    when p_feed_id = 'prasarana-rapid-bus-penang'
      then 'rapid-penang-bus'
    when p_feed_id like 'mybas-%' then 'bas-my-bus'
    when lower(coalesce(p_subtype, '')) = 'mrt' then 'mrt'
    when lower(coalesce(p_subtype, '')) in ('lrt', 'light rail') then 'lrt'
    when lower(coalesce(p_subtype, '')) = 'monorail' then 'monorail'
    when lower(coalesce(p_subtype, '')) = 'ktm' then 'ktm'
    when lower(coalesce(p_subtype, '')) = 'bus' then 'generic-bus'
    else 'generic-rail'
  end
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
    and a.preview_key = public.eco_partner_transport_preview_key(
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
    on a.preview_key = public.eco_partner_transport_preview_key(
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
before insert or update of source, source_id, subtype
on public.eco_partner_catalog
for each row execute function public.set_gtfs_transport_preview_image();

-- Remove all previously cached Mapillary metadata, including dining and EV.
update public.eco_partner_catalog
set image_url = null,
    image_source_name = null,
    image_source_url = null,
    image_captured_at = null
where coalesce(image_source_name, '') ilike '%mapillary%'
   or coalesce(image_source_url, '') ilike '%mapillary.com%';

select public.apply_gtfs_transport_preview_images(null);

drop function if exists public.claim_eco_partner_image_sync_batch(integer);
drop function if exists public.complete_eco_partner_image_sync(
  text, text, text, text, timestamptz
);
drop function if exists public.retry_eco_partner_image_sync(text);
drop index if exists public.eco_partner_catalog_transport_image_sync_idx;
alter table public.eco_partner_catalog
  drop column if exists image_checked_at;

revoke all on function public.eco_partner_transport_preview_key(text, text)
  from public, anon, authenticated;
revoke all on function public.apply_gtfs_transport_preview_images(text)
  from public, anon, authenticated;
revoke all on function public.set_gtfs_transport_preview_image()
  from public, anon, authenticated;
grant execute on function public.apply_gtfs_transport_preview_images(text)
  to service_role;
