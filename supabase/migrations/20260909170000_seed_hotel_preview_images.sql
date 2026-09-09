-- Curated preview images for the assignment's seeded GSTC hotels.
-- Each image was checked for a successful image response on 2026-09-09.

create temporary table hotel_preview_images (
  gstc_code text primary key,
  image_url text not null,
  image_source_name text not null,
  image_source_url text not null
) on commit drop;

insert into hotel_preview_images (
  gstc_code, image_url, image_source_name, image_source_url
) values
  (
    'GSTC HACU250103',
    'https://cdn-assets-eu.frontify.com/s3/frontify-enterprise-files-eu/eyJvYXV0aCI6eyJjbGllbnRfaWQiOiJzaXRlY29yZSJ9LCJwYXRoIjoibWFuZGFyaW4tb3JpZW50YWwtaG90ZWwtZ3JvdXBcL2ZpbGVcL1JZZVZiTjhBVUF5UW9TUkNLMXViLmpwZyJ9:mandarin-oriental-hotel-group:2nLPNHru3oy48n-YiVemcQmsf01QFb5JQQuI8pkghHU',
    'Mandarin Oriental',
    'https://www.mandarinoriental.com/en/kuala-lumpur/petronas-towers'
  ),
  (
    'GSTC HACU250338-1',
    'https://www.panpacific.com/content/dam/pphg-revamp/en/global/hotels-and-resorts/prckul-property-2.jpg',
    'Pan Pacific Hotels Group',
    'https://www.panpacific.com/en/hotels-and-resorts/pr-collection-kuala-lumpur.html'
  ),
  (
    'GSTC HACU250338-2',
    'https://www.panpacific.com/content/dam/pphg-revamp/en/global/serviced-suites/ppskul-property.jpg',
    'Pan Pacific Hotels Group',
    'https://www.panpacific.com/en/serviced-suites/pp-ss-kuala-lumpur.html'
  ),
  (
    'GSTC HACU250338-3',
    'https://www.panpacific.com/content/dam/pphg-revamp/en/global/serviced-suites/prskul-property.jpg',
    'Pan Pacific Hotels Group',
    'https://www.panpacific.com/en/serviced-suites/pr-ss-kuala-lumpur.html'
  ),
  (
    'GSTC HACU250338-4',
    'https://www.panpacific.com/content/dam/pphg-revamp/en/global/hotels-and-resorts/prpen-property.jpg',
    'Pan Pacific Hotels Group',
    'https://www.panpacific.com/en/hotels-and-resorts/pr-penang.html'
  ),
  (
    'GSTC HACU250343-3',
    'https://acdn.architizer.com/thumbnails-PRODUCTION/d9/2b/d92b826c9a226daba456668528d84abd.jpg',
    'Architizer / WATG',
    'https://architizer.com/projects/grand-hyatt-kuala-lumpur/'
  ),
  (
    'HAVR230192',
    'https://theruma.com/file/webpage/shared/the-ruma-birdcage-fb.jpg',
    'The RuMa Hotel and Residences',
    'https://theruma.com/en/'
  ),
  (
    'HAVR240218',
    'https://www.borneonaturetours.com/wp-content/uploads/2020/12/others-dining.jpg',
    'Borneo Rainforest Lodge',
    'https://www.borneonaturetours.com/borneorainforestlodge/'
  ),
  (
    'HAVR240228-2',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/kuala-lumpur/ascott-sentral-kuala-lumpur/overview/askl1-2880X860.jpg.transform/ascott-highres/image.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/ascott-the-residence/malaysia/ascott-sentral-kuala-lumpur'
  ),
  (
    'HAVR240228-3',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/kuala-lumpur/ascott-star-klcc-kuala-lumpur/overview/26410176.jpg.transform/ascott-highres/image.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/ascott-the-residence/malaysia/ascott-star-klcc-kuala-lumpur'
  ),
  (
    'HAVR240228-4',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/kuala-lumpur/somerset-kuala-lumpur/overview/skl3-2880x860.jpg.transform/ascott-highres/image.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/somerset-serviced-residence/malaysia/somerset-kuala-lumpur'
  ),
  (
    'HAVR240228-5',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/penang/ascott-gurney-penang/overview/Ascott%20Gurney%20Penang_Facade_2880x860%20%28Banner%20Image%20Desktop%29.jpg.transform/ascott-highres/image.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/ascott-the-residence/malaysia/ascott-gurney-penang'
  ),
  (
    'HAVR240228-6',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/kuala-lumpur/lyf-chinatown-kuala-lumpur/overview/lyf-rajachulan-kualalumpur-lyfguard2_temp.jpg.transform/ascott-highres/image.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/lyf/malaysia/lyf-chinatown-kuala-lumpur'
  ),
  (
    'HAVR240228-7',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/kuching/citadines-uplands-kuching/overview/cuk3-750x600.JPG.transform/ascott-lowres/image.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/citadines/malaysia/citadines-uplands-kuching'
  ),
  (
    'HAVR240228-8',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/iskandar-puteri/somerset-medini-iskandar-puteri/overview/26411176.jpg.transform/ascott-highres/image.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/somerset-serviced-residence/malaysia/somerset-medini-iskandar-puteri'
  ),
  (
    'HAVR240228-9',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/penang/citadines-connect-georgetown-penang/overview/2880x860%20Cit%20Con_2EXE%20Facade%20Night.jpg.transform/ascott-highres/image.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/citadines-connect/malaysia/citadines-connect-georgetown-penang'
  ),
  (
    'HAVR240228-10',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/penang/citadines-prai-penang/overview/2880x860%20CPP%20Facade.jpg.transform/ascott-highres/image.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/citadines/malaysia/citadines-prai-penang'
  ),
  (
    'HAVR250157',
    'https://sitecore-cd-imgr.shangri-la.com/MediaFiles/F/E/A/%7BFEA6B495-CE72-4E23-8074-008760C6B282%7D20240705_TAH_Homepage_Background_Image.jpg',
    'Shangri-La Hotels and Resorts',
    'https://www.shangri-la.com/kotakinabalu/tanjungaruresort/'
  ),
  (
    'GSTC HAVR240228-15',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/shah-alam/fox-hotel-glenmarie-shah-alam/overview/26461176.jpg.transform/ascott-highres/image.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/fox-hotels/malaysia/fox-hotel-glenmarie-shah-alam'
  ),
  (
    'GSTC HAVR240228-17',
    'https://www.discoverasr.com/content/dam/tal/media/images/properties/malaysia/penang/citadines-tanjung-tokong-penang/overview/760x428-MY-Penang-CTTP-2024%20%2829%29.jpg',
    'The Ascott Limited',
    'https://www.discoverasr.com/en/citadines/malaysia/citadines-tanjung-tokong-penang'
  );

-- Updating eco_hotels also activates the existing catalogue trigger.
update public.eco_hotels h
set image_url = i.image_url,
    updated_at = now()
from hotel_preview_images i
where h.gstc_code = i.gstc_code
  and h.image_url is distinct from i.image_url;

-- The hotel trigger copies the image itself.  Keep the preview attribution and
-- source page on the app-facing catalogue as well.
update public.eco_partner_catalog c
set image_url = i.image_url,
    image_source_name = i.image_source_name,
    image_source_url = i.image_source_url,
    image_captured_at = now(),
    last_synced_at = now()
from public.eco_hotels h
join hotel_preview_images i on i.gstc_code = h.gstc_code
where c.source = 'gstc'
  and c.source_id = h.id::text;

