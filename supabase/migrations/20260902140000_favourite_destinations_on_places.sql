-- Lets Module 1's "Save" bookmark write into the same shared Saved screen
-- that Module 2's "Add to Favourites" already uses.
--
-- This was blocked before (see the NOTE in
-- lib/features/destination_exploration/model/favourite_destination_repository.dart)
-- because destination_favourites.destination_id only referenced
-- public.destinations, a separate id space from public.places -- every
-- insert from a Module 1 place failed its foreign key silently.
--
-- 20260902120000_merge_destinations_and_add_photos.sql already copied all
-- 72 destinations rows into places WITH THE SAME IDS, which makes
-- places.id a strict superset of destinations.id today. That's what makes
-- this safe: every existing destination_favourites row still points at a
-- valid id after this change (it's a subset), and now a places-only id
-- (the ~3,760 OSM-imported ones) is valid here too.
-- Look up the real constraint name rather than assuming Postgres's default
-- naming convention, so this doesn't fail if it was ever created or
-- renamed differently.
do $$
declare
  fk_name text;
begin
  select conname into fk_name
  from pg_constraint
  where conrelid = 'public.destination_favourites'::regclass
    and confrelid = 'public.destinations'::regclass
    and contype = 'f';

  if fk_name is not null then
    execute format('alter table public.destination_favourites drop constraint %I', fk_name);
  end if;
end $$;

alter table public.destination_favourites
  add constraint destination_favourites_destination_id_fkey
  foreign key (destination_id) references public.places(id);
