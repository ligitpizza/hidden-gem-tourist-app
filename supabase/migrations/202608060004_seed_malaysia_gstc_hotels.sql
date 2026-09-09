alter table public.eco_hotels
  add column if not exists gstc_code text,
  add column if not exists certification_program text,
  add column if not exists certification_status text,
  add column if not exists certification_date date;

create unique index if not exists eco_hotels_gstc_code_idx
  on public.eco_hotels(gstc_code)
  where gstc_code is not null;

-- Curated from GSTC's official Certified Hotels Directory on 2026-08-06.
-- Coordinates/addresses are matched through OpenStreetMap Nominatim. This is
-- deliberately an admin-maintained snapshot, not a runtime scrape.
insert into public.eco_hotels (
  name, address, latitude, longitude, website_url, gstc_certified,
  gstc_code, certification_body, certification_program,
  certification_status, certification_date, certification_evidence_url,
  certification_verified_at, certification_expires_at, updated_at
) values
  ('Mandarin Oriental Kuala Lumpur', 'Persiaran Petronas, Kuala Lumpur City Centre, Kuala Lumpur', 3.1557412, 101.7118967, 'https://www.mandarinoriental.com/en/kuala-lumpur/petronas-towers', true, 'GSTC HACU250103', 'Control Union Singapore', 'GSTC Standard', 'Active', '2025-02-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2028-02-10T23:59:59Z', now()),
  ('PARKROYAL COLLECTION Kuala Lumpur', 'Jalan Sultan Ismail, Bukit Bintang, Kuala Lumpur', 3.1443335, 101.7121987, 'https://www.panpacific.com/en/hotels-and-resorts/pr-collection-kuala-lumpur.html', true, 'GSTC HACU250338-1', 'Control Union Singapore', 'GSTC Standard', 'Active', '2026-01-15', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2029-01-14T23:59:59Z', now()),
  ('Pan Pacific Serviced Suites Kuala Lumpur', 'Jalan Sultan Ismail, Bukit Bintang, Kuala Lumpur', 3.1446137, 101.7121165, 'https://www.panpacific.com/en/serviced-suites/pp-ss-kuala-lumpur.html', true, 'GSTC HACU250338-2', 'Control Union Singapore', 'GSTC Standard', 'Active', '2026-01-15', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2029-01-14T23:59:59Z', now()),
  ('PARKROYAL Serviced Suites Kuala Lumpur', 'Jalan Nagasari, Bukit Bintang, Kuala Lumpur', 3.1490862, 101.7088775, 'https://www.panpacific.com/en/serviced-suites/pr-ss-kuala-lumpur.html', true, 'GSTC HACU250338-3', 'Control Union Singapore', 'GSTC Standard', 'Active', '2026-01-15', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2029-01-14T23:59:59Z', now()),
  ('PARKROYAL Penang Resort', 'Jalan Batu Ferringgi, George Town, Pulau Pinang', 5.4723649, 100.2463260, 'https://www.panpacific.com/en/hotels-and-resorts/pr-penang.html', true, 'GSTC HACU250338-4', 'Control Union Singapore', 'GSTC Standard', 'Active', '2026-01-15', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2029-01-14T23:59:59Z', now()),
  ('Grand Hyatt Kuala Lumpur', '12 Jalan Pinang, Kuala Lumpur', 3.1536113, 101.7121373, 'https://www.hyatt.com/grand-hyatt/en-US/kuagh-grand-hyatt-kuala-lumpur', true, 'GSTC HACU250343-3', 'Control Union Singapore', 'GSTC Standard', 'Active', '2026-05-12', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2029-05-11T23:59:59Z', now()),
  ('The RuMa Hotel & Residences', '7 Jalan Kia Peng, Kuala Lumpur', 3.1524155, 101.7143738, 'https://theruma.com/en/', true, 'HAVR230192', 'Vireo Srl', 'GSTC Standard', 'Active', '2023-12-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2026-12-10T23:59:59Z', now()),
  ('Borneo Rainforest Lodge', 'Danum Valley Conservation Area, Lahad Datu, Sabah', 5.0196725, 117.7460505, 'https://www.borneonaturetours.com/', true, 'HAVR240218', 'Vireo Srl', 'GSTC Standard', 'Active', '2024-10-23', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-10-22T23:59:59Z', now()),
  ('Ascott Sentral Kuala Lumpur', '211 Jalan Tun Sambanthan, Kuala Lumpur', 3.1311009, 101.6849956, 'https://www.discoverasr.com/en/ascott-the-residence/malaysia/ascott-sentral-kuala-lumpur', true, 'HAVR240228-2', 'Vireo Srl', 'GSTC Standard', 'Active', '2024-11-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-10T23:59:59Z', now()),
  ('Ascott Star KLCC', 'Jalan Mayang, Kuala Lumpur', 3.1610013, 101.7125631, 'https://www.discoverasr.com/en/ascott-the-residence/malaysia/ascott-star-klcc-kuala-lumpur', true, 'HAVR240228-3', 'Vireo Srl', 'GSTC Standard', 'Active', '2024-11-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-10T23:59:59Z', now()),
  ('Somerset Kuala Lumpur', '187 Jalan Ampang, Kuala Lumpur', 3.1600206, 101.7230115, 'https://www.discoverasr.com/en/somerset-serviced-residence/malaysia/somerset-kuala-lumpur', true, 'HAVR240228-4', 'Vireo Srl', 'GSTC Standard', 'Active', '2024-11-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-10T23:59:59Z', now()),
  ('Ascott Gurney Penang', 'Persiaran Gurney, George Town, Pulau Pinang', 5.4301077, 100.3191251, 'https://www.discoverasr.com/en/ascott-the-residence/malaysia/ascott-gurney-penang', true, 'HAVR240228-5', 'Vireo Srl', 'GSTC Standard', 'Active', '2024-11-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-10T23:59:59Z', now()),
  ('lyf Chinatown Kuala Lumpur', '13 Jalan Raja Chulan, Kuala Lumpur', 3.1482072, 101.6991582, 'https://www.discoverasr.com/en/lyf/malaysia/lyf-chinatown-kuala-lumpur', true, 'HAVR240228-6', 'Vireo Srl', 'GSTC Standard', 'Active', '2024-11-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-10T23:59:59Z', now()),
  ('Citadines Uplands Kuching', 'Jalan Simpang Tiga, Kuching, Sarawak', 1.5360911, 110.3558176, 'https://www.discoverasr.com/en/citadines/malaysia/citadines-uplands-kuching', true, 'HAVR240228-7', 'Vireo Srl', 'GSTC Standard', 'Active', '2024-11-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-10T23:59:59Z', now()),
  ('Somerset Medini Iskandar Puteri', 'Jalan Medini Utara 4, Iskandar Puteri, Johor', 1.4272840, 103.6348681, 'https://www.discoverasr.com/en/somerset-serviced-residence/malaysia/somerset-medini-iskandar-puteri', true, 'HAVR240228-8', 'Vireo Srl', 'GSTC Standard', 'Active', '2024-11-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-10T23:59:59Z', now()),
  ('Citadines Connect Georgetown Penang', '428 Jalan Penang, George Town, Pulau Pinang', 5.4155672, 100.3290690, 'https://www.discoverasr.com/en/citadines-connect/malaysia/citadines-connect-georgetown-penang', true, 'HAVR240228-9', 'Vireo Srl', 'GSTC Standard', 'Active', '2024-11-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-10T23:59:59Z', now()),
  ('Citadines Prai Penang', 'Jalan Kebun Nenas, Juru, Pulau Pinang', 5.3421335, 100.4348684, 'https://www.discoverasr.com/en/citadines/malaysia/citadines-prai-penang', true, 'HAVR240228-10', 'Vireo Srl', 'GSTC Standard', 'Active', '2024-11-11', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-10T23:59:59Z', now()),
  ('Shangri-La Tanjung Aru', 'Kota Kinabalu, Sabah', 5.9409170, 116.0587040, 'https://www.shangri-la.com/kotakinabalu/tanjungaruresort/', true, 'HAVR250157', 'Vireo Srl', 'GSTC Standard', 'Active', '2025-10-14', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2028-10-13T23:59:59Z', now()),
  ('FOX Hotel Glenmarie Shah Alam', '6 Jalan Juruanalisis U1/35, Shah Alam, Selangor', 3.0814436, 101.5628525, 'https://www.discoverasr.com/en/fox-hotels/malaysia/fox-hotel-glenmarie-shah-alam', true, 'GSTC HAVR240228-15', 'Vireo Srl', 'GSTC Standard', 'Active', '2025-12-19', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-11T23:59:59Z', now()),
  ('Citadines Tanjung Tokong Penang', 'Jalan Batu Bukit, Tanjung Tokong, Pulau Pinang', 5.4544390, 100.3064336, 'https://www.discoverasr.com/en/citadines/malaysia/citadines-tanjung-tokong-penang', true, 'GSTC HAVR240228-17', 'Vireo Srl', 'GSTC Standard', 'Active', '2025-12-19', 'https://www.gstc.org/certified-hotels-directory/', '2026-08-06T00:00:00Z', '2027-11-11T23:59:59Z', now())
on conflict (gstc_code) where gstc_code is not null do update set
  name = excluded.name,
  address = excluded.address,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  website_url = excluded.website_url,
  gstc_certified = excluded.gstc_certified,
  certification_body = excluded.certification_body,
  certification_program = excluded.certification_program,
  certification_status = excluded.certification_status,
  certification_date = excluded.certification_date,
  certification_evidence_url = excluded.certification_evidence_url,
  certification_verified_at = excluded.certification_verified_at,
  certification_expires_at = excluded.certification_expires_at,
  updated_at = now();
