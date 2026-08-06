create table public.destination_checkins (
  user_id uuid not null references auth.users(id),
  destination_id uuid not null references public.destinations(id),
  checked_in_at timestamptz not null default now(),
  primary key (user_id, destination_id)
);

alter table public.destination_checkins enable row level security;

create policy "Users manage their own check-ins" on public.destination_checkins
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.destination_ratings (
  id uuid primary key default gen_random_uuid(),
  destination_id uuid not null references public.destinations(id),
  user_id uuid not null references auth.users(id),
  difficulty_score int not null check (difficulty_score between 1 and 5),
  review_text text not null default '',
  generated_tags text[] not null default '{}',
  created_at timestamptz not null default now(),
  unique (user_id, destination_id)
);

alter table public.destination_ratings enable row level security;

create policy "Public read access" on public.destination_ratings
  for select using (true);

create policy "Users insert their own ratings" on public.destination_ratings
  for insert with check (auth.uid() = user_id);

create table public.user_trail_points (
  user_id uuid primary key references auth.users(id),
  total_points integer not null default 0
);

alter table public.user_trail_points enable row level security;

create policy "Users manage their own points" on public.user_trail_points
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.user_badges (
  user_id uuid not null references auth.users(id),
  badge_id text not null,
  region text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, badge_id, region)
);

alter table public.user_badges enable row level security;

create policy "Users manage their own badges" on public.user_badges
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
