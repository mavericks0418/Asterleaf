-- Run this script in Supabase Dashboard -> SQL Editor.
-- It is safe to rerun when the task UI reports a missing table or incomplete RLS policy.
-- Tasks are private: every query is restricted to the authenticated owner by RLS.

create table if not exists public.schedule_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 160),
  notes text not null default '' check (char_length(notes) <= 2000),
  due_date date,
  is_completed boolean not null default false,
  position integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists schedule_tasks_user_status_idx
  on public.schedule_tasks (user_id, is_completed, position, created_at);

alter table public.schedule_tasks enable row level security;

drop policy if exists "Users can view their own schedule tasks" on public.schedule_tasks;
create policy "Users can view their own schedule tasks"
  on public.schedule_tasks for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can create their own schedule tasks" on public.schedule_tasks;
create policy "Users can create their own schedule tasks"
  on public.schedule_tasks for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own schedule tasks" on public.schedule_tasks;
create policy "Users can update their own schedule tasks"
  on public.schedule_tasks for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own schedule tasks" on public.schedule_tasks;
create policy "Users can delete their own schedule tasks"
  on public.schedule_tasks for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.set_schedule_tasks_updated_at()
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

drop trigger if exists schedule_tasks_updated_at on public.schedule_tasks;
create trigger schedule_tasks_updated_at
before update on public.schedule_tasks
for each row execute function public.set_schedule_tasks_updated_at();

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.schedule_tasks to authenticated;
