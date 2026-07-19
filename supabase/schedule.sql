-- Run this script in Supabase Dashboard -> SQL Editor.
-- The anon key is intentionally used by the browser. RLS is the security boundary.

create table if not exists public.schedule_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 120),
  description text not null default '' check (char_length(description) <= 2000),
  event_date date not null,
  start_time time not null,
  end_time time not null,
  color text not null default 'teal' check (color in ('teal', 'violet', 'amber', 'rose')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint schedule_events_valid_time_range check (end_time > start_time)
);

create index if not exists schedule_events_user_date_idx
  on public.schedule_events (user_id, event_date, start_time);

alter table public.schedule_events enable row level security;

drop policy if exists "Users can view their own schedule events" on public.schedule_events;
create policy "Users can view their own schedule events"
  on public.schedule_events for select
  using (auth.uid() = user_id);

drop policy if exists "Users can create their own schedule events" on public.schedule_events;
create policy "Users can create their own schedule events"
  on public.schedule_events for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own schedule events" on public.schedule_events;
create policy "Users can update their own schedule events"
  on public.schedule_events for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own schedule events" on public.schedule_events;
create policy "Users can delete their own schedule events"
  on public.schedule_events for delete
  using (auth.uid() = user_id);

create or replace function public.set_schedule_events_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists schedule_events_updated_at on public.schedule_events;
create trigger schedule_events_updated_at
before update on public.schedule_events
for each row execute function public.set_schedule_events_updated_at();
