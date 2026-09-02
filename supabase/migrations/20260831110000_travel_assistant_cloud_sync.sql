-- Travel Assistant cloud persistence. Everything used here is available on the
-- Supabase Free plan: Postgres, Auth and a private Storage bucket.
create table if not exists public.travel_documents (
  id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  category text not null,
  original_file_name text not null,
  storage_path text not null,
  extension text not null default '',
  file_size bigint not null check (file_size between 0 and 10485760),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  unique (user_id, storage_path)
);
create index if not exists travel_documents_user_created_idx
  on public.travel_documents(user_id, created_at desc);
alter table public.travel_documents enable row level security;

drop policy if exists "Users read travel documents" on public.travel_documents;
create policy "Users read travel documents" on public.travel_documents for select
  to authenticated using (auth.uid() = user_id);
drop policy if exists "Users add travel documents" on public.travel_documents;
create policy "Users add travel documents" on public.travel_documents for insert
  to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users update travel documents" on public.travel_documents;
create policy "Users update travel documents" on public.travel_documents for update
  to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users delete travel documents" on public.travel_documents;
create policy "Users delete travel documents" on public.travel_documents for delete
  to authenticated using (auth.uid() = user_id);

insert into storage.buckets (id, name, public, file_size_limit)
values ('travel-documents', 'travel-documents', false, 10485760)
on conflict (id) do update set public = false, file_size_limit = 10485760;

drop policy if exists "Users read own travel document files" on storage.objects;
create policy "Users read own travel document files" on storage.objects for select
  to authenticated using (
    bucket_id = 'travel-documents' and (storage.foldername(name))[1] = auth.uid()::text
  );
drop policy if exists "Users upload own travel document files" on storage.objects;
create policy "Users upload own travel document files" on storage.objects for insert
  to authenticated with check (
    bucket_id = 'travel-documents' and (storage.foldername(name))[1] = auth.uid()::text
  );
drop policy if exists "Users update own travel document files" on storage.objects;
create policy "Users update own travel document files" on storage.objects for update
  to authenticated using (
    bucket_id = 'travel-documents' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'travel-documents' and (storage.foldername(name))[1] = auth.uid()::text
  );
drop policy if exists "Users delete own travel document files" on storage.objects;
create policy "Users delete own travel document files" on storage.objects for delete
  to authenticated using (
    bucket_id = 'travel-documents' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- RLS hides other users' rows, so this function performs the global quota check
-- without exposing anybody else's document metadata.
create or replace function public.can_upload_travel_document(p_file_size bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null
    and p_file_size between 0 and 10485760
    and coalesce((select sum(file_size) from travel_documents where user_id = auth.uid()), 0)
          + p_file_size <= 52428800
    and coalesce((select sum(file_size) from travel_documents), 0)
          + p_file_size <= 262144000;
$$;
revoke all on function public.can_upload_travel_document(bigint) from public, anon;
grant execute on function public.can_upload_travel_document(bigint) to authenticated;

create table if not exists public.packing_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  selected_location_id text,
  updated_at timestamptz not null default now()
);
create table if not exists public.packing_custom_items (
  user_id uuid primary key references auth.users(id) on delete cascade,
  items jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.packing_checklist_states (
  user_id uuid not null references auth.users(id) on delete cascade,
  location_id text not null,
  packed_ids text[] not null default '{}',
  updated_at timestamptz not null default now(),
  primary key (user_id, location_id)
);

alter table public.packing_preferences enable row level security;
alter table public.packing_custom_items enable row level security;
alter table public.packing_checklist_states enable row level security;
do $$
declare table_name text;
begin
  foreach table_name in array array['packing_preferences','packing_custom_items','packing_checklist_states'] loop
    execute format('drop policy if exists "Users manage own %s" on public.%I', table_name, table_name);
    execute format(
      'create policy "Users manage own %s" on public.%I for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      table_name, table_name
    );
  end loop;
end $$;

create table if not exists public.emergency_contacts (
  id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  relationship text not null,
  phone text not null,
  country text not null,
  email text not null default '',
  notes text not null default '',
  available_when_locked boolean not null default false,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists emergency_contacts_user_position_idx
  on public.emergency_contacts(user_id, position);

alter table public.emergency_contacts enable row level security;

drop policy if exists "Users read own emergency contacts"
  on public.emergency_contacts;
create policy "Users read own emergency contacts"
  on public.emergency_contacts for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users add own emergency contacts"
  on public.emergency_contacts;
create policy "Users add own emergency contacts"
  on public.emergency_contacts for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users update own emergency contacts"
  on public.emergency_contacts;
create policy "Users update own emergency contacts"
  on public.emergency_contacts for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own emergency contacts"
  on public.emergency_contacts;
create policy "Users delete own emergency contacts"
  on public.emergency_contacts for delete to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete
  on public.emergency_contacts to authenticated;
