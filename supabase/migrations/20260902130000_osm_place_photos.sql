-- Real photos for OSM-imported places whose original OSM element had a
-- linked Wikidata/Wikipedia/Commons entry -- found by cross-referencing
-- every OSM-sourced place's osm_id against Overpass, then resolving
-- wikimedia_commons / wikidata (P18) / wikipedia tags to a real Commons
-- file, in that priority order.
--
-- Coverage: ~2% of the ~3,690 OSM-imported places actually had a linked
-- photo source on OSM at all -- the rest genuinely have no photo data
-- anywhere to find, and keep the existing gradient placeholder rather
-- than a fake/generic substitute (per product decision).
--
-- 70 rows below, manually spot-checked one by one against their
-- place name before inclusion -- 3 automated matches were dropped for
-- resolving to the wrong subject entirely (two were photos of a real
-- person rather than the place, one of a deceased individual), not just
-- a loosely-related building.

update public.places as p set images = v.images
from (values
  ('a6cf798c-53f7-491b-9509-503e7f6e1c6a'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Chin%20Swee%20Caves%20Temple%20KL29.JPG']::text[]),
  ('d58e5b74-26c8-4685-8d47-a157693628ec'::uuid, array['https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/Signboard%2C_Muzium_Perang_-_Pantai_Cahaya_Bulan_-_Muzium_Islam_-_Istana_Balai_Besar_-_Masjid_Muhammadi_-_panoramio.jpg/330px-Signboard%2C_Muzium_Perang_-_Pantai_Cahaya_Bulan_-_Muzium_Islam_-_Istana_Balai_Besar_-_Masjid_Muhammadi_-_panoramio.jpg?utm_source=ms.wikipedia.org&utm_campaign=api&utm_content=thumbnail']::text[]),
  ('b0c1b5fe-facc-4259-88a8-0dd97da118df'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Sandakan%20Sabah%20Sepilok-Orangutan-Rehabilitation-Centre-02.jpg']::text[]),
  ('576e7eba-eeb0-4b3e-85d4-cf200dd7ffff'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Kota%20Tinggi%20Waterfalls.JPG']::text[]),
  ('3c98bc58-f5f9-4a9b-81cb-4199bc1d6b62'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/A%20story%20of%20a%20cat%20and%20fox.jpg']::text[]),
  ('d5f1e629-dfe2-46d5-a927-2a944a538253'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Beauty%20Museum.JPG']::text[]),
  ('aa15dc98-586d-4dd1-98eb-93a41842cf10'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/2016%20Malakka%2C%20Muzeum%20Znaczk%C3%B3w%20Pocztowych%20%2801%29.jpg']::text[]),
  ('2ee8ddca-5e2c-4adb-94ca-1604a3fb2bd9'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Kite%20Museum.JPG']::text[]),
  ('2e6ad5c6-9ac7-403b-8d69-f21829dacab6'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Petaling%20Jaya%20Museum%20-%20Exhibition%20Hall.JPG']::text[]),
  ('19cd0c31-e681-463d-8c1c-976185f6d2b8'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Cenotaph%20in%20George%20Town%2C%20Penang.jpg']::text[]),
  ('6de135c8-f7aa-4633-b97d-6f718e755db5'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Legenda%20Langkawi%20entrance.JPG']::text[]),
  ('da11dd0f-6d76-4328-867b-df5eb5349b5f'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Muzium%20Negeri%20Terengganu%2C%20Kampung%20Bukit%20Losong%2020240227%20095051.jpg']::text[]),
  ('bd6741fb-89bc-4022-a38a-9294b3482de8'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/KotaKinabalu%20Sabah%20TuguPeringatan%20DoubleSix-1.jpg']::text[]),
  ('0750b745-afd7-411c-aabf-41193b0a5810'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Sandakan%20Sabah%20SandakanMassacreMemorial-01.jpg']::text[]),
  ('8049ff7e-8463-466c-a6e1-fd1f3d789da1'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Antique%20Camera%20with%20Attendant%20-%20Camera%20Museum%20-%20George%20Town%20-%20Penang%20-%20Malaysia%20%2835355062311%29.jpg']::text[]),
  ('9bb422d4-c6bc-419d-a11a-a4a1664be32e'::uuid, array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Brooke_Memorial_Kuching.jpeg/330px-Brooke_Memorial_Kuching.jpeg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail']::text[]),
  ('b4465b01-de65-4988-afe6-a9c01518edf9'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Istana%20Ulu%20Kuala%20Kangsar.jpg']::text[]),
  ('877e3a48-013b-4b30-8900-cdcee3376a0c'::uuid, array['https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Gunung-Lambak-Johor-Malaysia.jpg/330px-Gunung-Lambak-Johor-Malaysia.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail']::text[]),
  ('9c70620b-9e57-4df0-bd60-a410ca690035'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Sam%20Poh%20Tong%20Temple.jpg']::text[]),
  ('b7692e01-9e66-401f-a372-b135f73b88fc'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Democratic%20Government%20Museum.JPG']::text[]),
  ('abcd63fb-ee6a-4545-b709-6b59b184a014'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Baba%20Nyonya%20Heritage%20Museum.JPG']::text[]),
  ('3ebf2467-9c56-4f6e-a695-a72980822ee0'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Kota%20Tinggi%20Museum.JPG']::text[]),
  ('f21d43e2-850d-47f9-86fa-da63410b74c2'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/2016%20Kuala%20Lumpur%2C%20Galeria%20Miejska.jpg']::text[]),
  ('899c387d-b70c-4a88-b823-d80d94d028d0'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Royal%20Malaysian%20Police%20Museum.JPG']::text[]),
  ('bd1d9e25-fe15-4785-bb0e-c32fc4605920'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Birch%20Memorial%20Clocktower.JPG']::text[]),
  ('d3410d5e-a88b-4b56-bb66-48f6a87736c4'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/TIME%20TUNNEL%20museum2.jpg']::text[]),
  ('35537d40-20d7-4f3d-8b16-ee8216d92966'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/KotaKinabalu_Sabah_NorthBorneoWarMemorial-05.jpg']::text[]),
  ('8db4b7ad-e750-4891-a759-9614ad04c559'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/20190823%20Logan%20Memorial-1.jpg']::text[]),
  ('7a472f7a-626b-4416-a12c-1f84174be71c'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Wei-Ling%20Gallery%20Brickfields%20%28%20Interior%20%29.png']::text[]),
  ('34ea98d9-5d7c-4b0a-abdf-8d0f8f0a7572'::uuid, array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/Suria_KLCC_%28park_entrance%29%2C_Kuala_Lumpur.jpg/330px-Suria_KLCC_%28park_entrance%29%2C_Kuala_Lumpur.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail']::text[]),
  ('43050cd5-e9e6-48e8-b9a2-986ca7d4dabe'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/YosriMuziumPekan.JPG']::text[]),
  ('ec2605ef-3452-4c4f-a3db-fa76c6e6b3ae'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Batu%20Lawi%20from%20Gunung%20Murud.jpg']::text[]),
  ('287eeb34-6236-47ba-be72-26a062a30f47'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Kudat%20Sabah%20Tanjung%20Simpang%20Mengayau-21.jpg']::text[]),
  ('8a487eff-89f0-4db1-9c23-7d9ada875af1'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Kite%20Museum%20%28Johor%29.JPG']::text[]),
  ('abfa3408-6e94-4fbb-91c4-ae872d0e4f33'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Pineapple%20Museum.jpg']::text[]),
  ('c831de2e-bb6e-463c-a3b6-0425b02d943e'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/010875-%20Skyline%20of%20Kuala%20Lumpur.jpg']::text[]),
  ('cbf5b488-634b-4819-8242-29c1b3402995'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Melaka%20Folks%20Art%20Gallery.jpg']::text[]),
  ('83fa2a4a-f938-422f-9fb6-ee3d2d2a0c2b'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Berkelah%20Falls%2C%20Fifth%20Tier.jpg']::text[]),
  ('93266ed1-5872-4eb8-8f35-c4c36cfe022f'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Melaka%20Butterfly%20%26%20Reptile%20Sanctuary.jpg']::text[]),
  ('bd7faf01-02e6-4de0-b053-b9300b84be95'::uuid, array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/df/Angsi_Mountain.jpg/330px-Angsi_Mountain.jpg?utm_source=ms.wikipedia.org&utm_campaign=api&utm_content=thumbnail']::text[]),
  ('ea571df0-cebf-4c69-96c6-fd506f6644eb'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Tawau%20Sabah%20Belfry-01.jpg']::text[]),
  ('afb7fc49-8888-4ea5-ab60-9a2f905732a1'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Tawau%20Sabah%20Twin-Town-Memorial-01.jpg']::text[]),
  ('c43a56c3-a005-4136-84e1-c8e458182fbf'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Tawau%20Sabah%20JapaneseCemetery-01.jpg']::text[]),
  ('32321125-023b-454b-b16c-3575386d7cfd'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Stadthuys.JPG']::text[]),
  ('281097c1-5fc6-48e3-b420-9d4d6f9879ce'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Malaysia%20Youth%20Museum%20and%20Melaka%20Art%20Gallery.jpg']::text[]),
  ('825c8673-424f-485f-87c6-75535a0aa053'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Sofea%20Jane%20Waterfall%2001.jpg']::text[]),
  ('8856c843-4641-4805-b28b-240707ed579f'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Istana%20evening.jpg']::text[]),
  ('4c5a96a3-a6c2-43bf-8c02-34e460f21df5'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Galeria%20Sri%20Perdana%20%28194%29.jpg']::text[]),
  ('a6caf1dd-a1cb-4726-96ca-7e1ae99d4ca4'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Islamic%20Museum%20Penang%20Dec%202006%20001.jpg']::text[]),
  ('868d14a0-81e4-4e87-9b50-132824d5edea'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Sun%20Yat-sen%20Penang%20Base.JPG']::text[]),
  ('3bbea8e6-8658-4dcf-bd40-263f7c66ab3f'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Berjaya%20Times%20Square%20Indoor%20Theme%20Park.JPG']::text[]),
  ('194c254a-c07a-4f77-b120-b161124e3195'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Desaru%20Ostrich%20Farm.jpg']::text[]),
  ('fccd0d74-2345-44f7-8bd4-f0e3f6a0c497'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Jomis%20Old%20Jetty.jpg']::text[]),
  ('3a28fe43-de1b-4ddd-8850-8a4935f40777'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Little%20India%20%28Melaka%29.jpg']::text[]),
  ('c3c43e21-edd8-4fb2-be11-3ff963ade807'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/KotaKinabalu-Sabah%20Dataran-Deasoka-01.jpg']::text[]),
  ('b3de3cb7-96b6-4acf-a4ae-f58fcb1db5d5'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Sandakan%20Sabah%20WilliamPryerMemorial-01.jpg']::text[]),
  ('d7f7e4b3-deef-4e86-a8d1-abd2de017502'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Sandakan%20Sabah%20CharteredCompanyMemorial-02.jpg']::text[]),
  ('7295b7f1-2576-4aee-9812-d9b038b0e9bb'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Sandakan%20Sabah%20SandakanWarMemorial-01.jpg']::text[]),
  ('ad514afd-7b18-43d9-ae5a-552b297e2530'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Keningau%20Sabah%20MuziumWarisan-02.jpg']::text[]),
  ('e25307f3-ffa8-4b7b-b6b9-9f991a48db3e'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Keningau%20Sabah%20BatuSumpahKeningau-01.jpg']::text[]),
  ('fef65410-f559-471f-8306-f08d3abb5c68'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Keningau%20Sabah%20ChoHuanLaiMemorial-06.jpg']::text[]),
  ('e0c183fc-75e0-4b26-b26e-c50c057e34d5'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Bank%20Negara%20Malaysia%20Museum%20and%20Art%20Gallery.jpg']::text[]),
  ('9a89e769-f764-4c49-b19e-146b937286f3'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/2016%20Kuala%20Lumpur%2C%20Narodowe%20Muzeum%20W%C5%82%C3%B3kiennictwa.jpg']::text[]),
  ('19bcfba0-018a-404e-8bf1-7cf5da8a6e04'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Kubu%20kecil%20Perang%20Dunia%20Kedua%20di%20Titi%20Gajah.jpg']::text[]),
  ('072f3cfe-8a84-4caf-8a47-8a4a1bc87375'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Beaufort%20Sabah%20StarcevichMemorialMonument-01.jpg']::text[]),
  ('778f9c7f-a305-425c-af2f-421aaaa403d8'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/HCPS%20Dining%20hall.jpg']::text[]),
  ('3c9fd0fc-395a-4b31-9e1e-e527e99c8b4f'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Kek%20Lok%20Si%201.jpg']::text[]),
  ('3d0c97d1-df9c-4054-8e49-48f1e54e32c9'::uuid, array['https://commons.wikimedia.org/wiki/Special:FilePath/Planetarium%20Negara%20%28exterior%29%2C%20Kuala%20Lumpur%2020241026%20111406.jpg']::text[]),
  ('82f113db-ed9d-48c2-a780-8aa984e8ebcd'::uuid, array['https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/Air_Terjun_Chamang_yang_terletak_dalam_daerah_Bentong%2C_Pahang.JPG/330px-Air_Terjun_Chamang_yang_terletak_dalam_daerah_Bentong%2C_Pahang.JPG?utm_source=ms.wikipedia.org&utm_campaign=api&utm_content=thumbnail']::text[]),
  ('69acc768-4b4b-42db-9736-39373fa2b789'::uuid, array['https://thumb.wikimedia.org/wikipedia/commons/thumb/a/ad/Bukit_Keluang_Terengganu_May_2026.jpg/330px-Bukit_Keluang_Terengganu_May_2026.jpg?utm_source=ms.wikipedia.org&utm_campaign=api&utm_content=thumbnail']::text[])
) as v(id, images)
where p.id = v.id;
