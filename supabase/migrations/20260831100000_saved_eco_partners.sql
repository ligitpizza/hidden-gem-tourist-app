create table if not exists public.saved_eco_partners (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  partner_id text not null,
  partner jsonb not null,
  created_at timestamptz not null default now(),
  unique (user_id, partner_id)
);

create index if not exists saved_eco_partners_user_created_idx
  on public.saved_eco_partners(user_id, created_at desc);

alter table public.saved_eco_partners enable row level security;

drop policy if exists "Users read their saved Eco Partners"
  on public.saved_eco_partners;
create policy "Users read their saved Eco Partners"
  on public.saved_eco_partners for select
  to authenticated using (auth.uid() = user_id);

drop policy if exists "Users save their Eco Partners"
  on public.saved_eco_partners;
create policy "Users save their Eco Partners"
  on public.saved_eco_partners for insert
  to authenticated with check (auth.uid() = user_id);

drop policy if exists "Users update their saved Eco Partners"
  on public.saved_eco_partners;
create policy "Users update their saved Eco Partners"
  on public.saved_eco_partners for update
  to authenticated using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete their saved Eco Partners"
  on public.saved_eco_partners;
create policy "Users delete their saved Eco Partners"
  on public.saved_eco_partners for delete
  to authenticated using (auth.uid() = user_id);
