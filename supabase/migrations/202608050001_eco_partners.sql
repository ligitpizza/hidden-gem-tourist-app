create extension if not exists pgcrypto;

create table if not exists public.eco_hotels (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null default '',
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  price_band text,
  website_url text,
  image_url text,
  gstc_certified boolean not null default false,
  certification_body text,
  certification_evidence_url text,
  certification_verified_at timestamptz,
  certification_expires_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.gtfs_agencies (
  id text primary key, feed_id text not null, agency_id text not null,
  name text not null, url text, timezone text, updated_at timestamptz not null default now()
);
create table if not exists public.gtfs_stops (
  id text primary key, feed_id text not null, stop_id text not null, name text not null,
  address text not null default '', latitude double precision not null,
  longitude double precision not null, source_name text not null default 'Official Malaysia GTFS',
  source_url text not null, updated_at timestamptz not null default now()
);
create table if not exists public.gtfs_routes (
  id text primary key, feed_id text not null, route_id text not null,
  agency_id text, short_name text, long_name text, route_type integer,
  mode text not null, updated_at timestamptz not null default now()
);
create table if not exists public.gtfs_stop_routes (
  stop_id text not null references public.gtfs_stops(id) on delete cascade,
  route_id text not null references public.gtfs_routes(id) on delete cascade,
  primary key (stop_id, route_id)
);
create table if not exists public.gtfs_feed_status (
  feed_id text primary key, source_url text not null, status text not null default 'pending',
  last_attempt_at timestamptz, last_success_at timestamptz, error text
);

create index if not exists eco_hotels_geo_idx on public.eco_hotels(latitude, longitude);
create index if not exists gtfs_stops_geo_idx on public.gtfs_stops(latitude, longitude);
create index if not exists gtfs_stops_feed_idx on public.gtfs_stops(feed_id);
create index if not exists gtfs_routes_feed_idx on public.gtfs_routes(feed_id);

alter table public.eco_hotels enable row level security;
alter table public.gtfs_agencies enable row level security;
alter table public.gtfs_stops enable row level security;
alter table public.gtfs_routes enable row level security;
alter table public.gtfs_stop_routes enable row level security;
alter table public.gtfs_feed_status enable row level security;

do $$ begin
  create policy "Authenticated users read eco hotels" on public.eco_hotels for select to authenticated using (true);
  create policy "Authenticated users read GTFS agencies" on public.gtfs_agencies for select to authenticated using (true);
  create policy "Authenticated users read GTFS stops" on public.gtfs_stops for select to authenticated using (true);
  create policy "Authenticated users read GTFS routes" on public.gtfs_routes for select to authenticated using (true);
  create policy "Authenticated users read GTFS mappings" on public.gtfs_stop_routes for select to authenticated using (true);
  create policy "Authenticated users read GTFS status" on public.gtfs_feed_status for select to authenticated using (true);
exception when duplicate_object then null; end $$;

-- One RPC replaces a fully parsed feed atomically. If parsing/download fails,
-- the Edge Function never invokes this RPC and the previous dataset remains.
create or replace function public.replace_gtfs_feed(
  p_feed_id text, p_source_url text, p_agencies jsonb, p_stops jsonb,
  p_routes jsonb, p_stop_routes jsonb
) returns void language plpgsql security definer set search_path = public as $$
begin
  delete from gtfs_stop_routes where stop_id in (select id from gtfs_stops where feed_id = p_feed_id);
  delete from gtfs_routes where feed_id = p_feed_id;
  delete from gtfs_stops where feed_id = p_feed_id;
  delete from gtfs_agencies where feed_id = p_feed_id;

  insert into gtfs_agencies(id, feed_id, agency_id, name, url, timezone)
    select id, feed_id, agency_id, name, url, timezone from jsonb_to_recordset(p_agencies)
    as x(id text, feed_id text, agency_id text, name text, url text, timezone text);
  insert into gtfs_stops(id, feed_id, stop_id, name, address, latitude, longitude, source_name, source_url)
    select id, feed_id, stop_id, name, coalesce(address,''), latitude, longitude, source_name, source_url
    from jsonb_to_recordset(p_stops) as x(id text, feed_id text, stop_id text, name text, address text, latitude double precision, longitude double precision, source_name text, source_url text);
  insert into gtfs_routes(id, feed_id, route_id, agency_id, short_name, long_name, route_type, mode)
    select id, feed_id, route_id, agency_id, short_name, long_name, route_type, mode
    from jsonb_to_recordset(p_routes) as x(id text, feed_id text, route_id text, agency_id text, short_name text, long_name text, route_type integer, mode text);
  insert into gtfs_stop_routes(stop_id, route_id)
    select stop_id, route_id from jsonb_to_recordset(p_stop_routes) as x(stop_id text, route_id text);
  insert into gtfs_feed_status(feed_id, source_url, status, last_attempt_at, last_success_at, error)
    values(p_feed_id, p_source_url, 'success', now(), now(), null)
    on conflict(feed_id) do update set source_url=excluded.source_url, status='success', last_attempt_at=now(), last_success_at=now(), error=null;
end $$;

revoke all on function public.replace_gtfs_feed(text,text,jsonb,jsonb,jsonb,jsonb) from public, anon, authenticated;
grant execute on function public.replace_gtfs_feed(text,text,jsonb,jsonb,jsonb,jsonb) to service_role;
