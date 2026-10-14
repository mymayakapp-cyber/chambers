-- =====================================================================
-- Chambers — shared case planning for lawyers
-- Run this whole file once in Supabase: Dashboard → SQL Editor → New query → Run
--
-- Access rule enforced by the database itself (Row Level Security):
--   • every signed-in lawyer can VIEW all cases, plans and notes
--   • a lawyer can CREATE, EDIT and DELETE only rows they own
--   • plan steps can only be added to a case you own
-- Even someone calling the API directly cannot edit another lawyer's data.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------- Profiles (one per signed-up lawyer) ----------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null default '',
  firm        text not null default '',
  email       text not null default '',
  created_at  timestamptz not null default now()
);

-- Create a profile automatically when someone signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, firm, email)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'full_name', ''),
          coalesce(new.raw_user_meta_data->>'firm', ''),
          coalesce(new.email, ''))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Cases ----------
create table if not exists public.cases (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  title          text not null,
  suit_number    text not null default '',
  court          text not null default '',
  judge          text not null default '',
  case_type      text not null default 'Civil',
  status         text not null default 'Open'
                 check (status in ('Open','Adjourned','Judgment reserved','Closed')),
  client         text not null default '',
  client_role    text not null default 'Plaintiff',
  opposing_party text not null default '',
  next_hearing   date,
  hearing_time   text not null default '',
  summary        text not null default '',
  strategy       text not null default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- ---------- Plan steps (what to do next on a case) ----------
create table if not exists public.plan_items (
  id          uuid primary key default gen_random_uuid(),
  case_id     uuid not null references public.cases(id) on delete cascade,
  owner_id    uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  title       text not null,
  kind        text not null default 'Filing',
  due_date    date,
  done        boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------- Notes (any lawyer can add their own note to any case) ----------
create table if not exists public.notes (
  id          uuid primary key default gen_random_uuid(),
  case_id     uuid not null references public.cases(id) on delete cascade,
  owner_id    uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  body        text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists cases_owner_idx   on public.cases(owner_id);
create index if not exists cases_hearing_idx on public.cases(next_hearing);
create index if not exists plan_case_idx     on public.plan_items(case_id);
create index if not exists notes_case_idx    on public.notes(case_id);

-- Keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists cases_touch on public.cases;
create trigger cases_touch before update on public.cases
  for each row execute function public.touch_updated_at();
drop trigger if exists plan_touch on public.plan_items;
create trigger plan_touch before update on public.plan_items
  for each row execute function public.touch_updated_at();
drop trigger if exists notes_touch on public.notes;
create trigger notes_touch before update on public.notes
  for each row execute function public.touch_updated_at();

-- =====================================================================
-- Row Level Security
-- =====================================================================
alter table public.profiles   enable row level security;
alter table public.cases      enable row level security;
alter table public.plan_items enable row level security;
alter table public.notes      enable row level security;

-- Profiles: everyone signed in can see names; you can only edit yourself
drop policy if exists "profiles read"   on public.profiles;
drop policy if exists "profiles update" on public.profiles;
create policy "profiles read"   on public.profiles for select to authenticated using (true);
create policy "profiles update" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Cases
drop policy if exists "cases read"   on public.cases;
drop policy if exists "cases insert" on public.cases;
drop policy if exists "cases update" on public.cases;
drop policy if exists "cases delete" on public.cases;
create policy "cases read"   on public.cases for select to authenticated using (true);
create policy "cases insert" on public.cases for insert to authenticated with check (owner_id = auth.uid());
create policy "cases update" on public.cases for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "cases delete" on public.cases for delete to authenticated using (owner_id = auth.uid());

-- Plan steps: only the case owner plans the case
drop policy if exists "plan read"   on public.plan_items;
drop policy if exists "plan insert" on public.plan_items;
drop policy if exists "plan update" on public.plan_items;
drop policy if exists "plan delete" on public.plan_items;
create policy "plan read"   on public.plan_items for select to authenticated using (true);
create policy "plan insert" on public.plan_items for insert to authenticated
  with check (owner_id = auth.uid()
              and exists (select 1 from public.cases c where c.id = case_id and c.owner_id = auth.uid()));
create policy "plan update" on public.plan_items for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "plan delete" on public.plan_items for delete to authenticated using (owner_id = auth.uid());

-- Notes: anyone can add their own note to any case; only the author edits it
drop policy if exists "notes read"   on public.notes;
drop policy if exists "notes insert" on public.notes;
drop policy if exists "notes update" on public.notes;
drop policy if exists "notes delete" on public.notes;
create policy "notes read"   on public.notes for select to authenticated using (true);
create policy "notes insert" on public.notes for insert to authenticated with check (owner_id = auth.uid());
create policy "notes update" on public.notes for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "notes delete" on public.notes for delete to authenticated using (owner_id = auth.uid());
