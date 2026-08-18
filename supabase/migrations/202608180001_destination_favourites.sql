create table public.destination_favourites (
  user_id uuid not null references auth.users(id),
  destination_id uuid not null references public.destinations(id),
  saved_at timestamptz not null default now(),
  primary key (user_id, destination_id)
);

alter table public.destination_favourites enable row level security;

create policy "Users manage their own favourites" on public.destination_favourites
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
