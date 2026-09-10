-- دفتر المعلم — Supabase schema
--
-- Run this in the Supabase SQL editor once, on a fresh project.
--
-- The point of this file is the row-level security policies. Every table carries an
-- owner_id, every policy demands owner_id = auth.uid(), and RLS is enabled on all of
-- them. After this, one teacher cannot read another teacher's rows even by asking the
-- API directly with a crafted request — the separation stops being a promise the
-- browser makes and becomes one the database enforces.

-- ---------------------------------------------------------------- classes

create table if not exists public.classes (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references auth.users(id) on delete cascade,
  name        text not null check (length(trim(name)) between 1 and 120),
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);

create index if not exists classes_owner_idx on public.classes (owner_id, sort_order);

-- ---------------------------------------------------------------- sheets
-- One row per class holding the whole gradebook as JSON: students, weeks, extras,
-- cells, notes and the calculation columns. Kept as a single document so a class
-- loads in one request, exactly as the app already expects.

create table if not exists public.sheets (
  class_id    uuid primary key references public.classes(id) on delete cascade,
  owner_id    uuid not null references auth.users(id) on delete cascade,
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------- files
-- Metadata only. The bytes live in the class-files storage bucket.

create table if not exists public.class_files (
  id            uuid primary key default gen_random_uuid(),
  class_id      uuid not null references public.classes(id) on delete cascade,
  owner_id      uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  mime          text,
  size_bytes    bigint,
  storage_path  text not null,
  created_at    timestamptz not null default now()
);

create index if not exists class_files_class_idx on public.class_files (class_id, created_at);

-- ---------------------------------------------------------------- keep updated_at honest

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists sheets_touch on public.sheets;
create trigger sheets_touch before update on public.sheets
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------- row-level security

alter table public.classes     enable row level security;
alter table public.sheets      enable row level security;
alter table public.class_files enable row level security;

-- Each policy is written for one command rather than using "for all", so that an
-- insert can never smuggle in a different owner_id than the caller's.

drop policy if exists classes_select on public.classes;
drop policy if exists classes_insert on public.classes;
drop policy if exists classes_update on public.classes;
drop policy if exists classes_delete on public.classes;

create policy classes_select on public.classes
  for select using (owner_id = auth.uid());
create policy classes_insert on public.classes
  for insert with check (owner_id = auth.uid());
create policy classes_update on public.classes
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy classes_delete on public.classes
  for delete using (owner_id = auth.uid());

drop policy if exists sheets_select on public.sheets;
drop policy if exists sheets_insert on public.sheets;
drop policy if exists sheets_update on public.sheets;
drop policy if exists sheets_delete on public.sheets;

create policy sheets_select on public.sheets
  for select using (owner_id = auth.uid());
create policy sheets_insert on public.sheets
  for insert with check (owner_id = auth.uid());
create policy sheets_update on public.sheets
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy sheets_delete on public.sheets
  for delete using (owner_id = auth.uid());

drop policy if exists class_files_select on public.class_files;
drop policy if exists class_files_insert on public.class_files;
drop policy if exists class_files_update on public.class_files;
drop policy if exists class_files_delete on public.class_files;

create policy class_files_select on public.class_files
  for select using (owner_id = auth.uid());
create policy class_files_insert on public.class_files
  for insert with check (owner_id = auth.uid());
create policy class_files_update on public.class_files
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy class_files_delete on public.class_files
  for delete using (owner_id = auth.uid());

-- ---------------------------------------------------------------- storage
--
-- Create two PRIVATE buckets in the dashboard first: class-files and student-photos.
-- Private matters: a public bucket would serve every student photo to anyone holding
-- the URL, with no login at all.
--
-- These policies key on the first folder of the object path being the teacher's user
-- id, so upload paths must look like:   <auth.uid()>/<class id>/<file>

drop policy if exists teacher_files_rw on storage.objects;
create policy teacher_files_rw on storage.objects
  for all
  using      (bucket_id in ('class-files','student-photos')
              and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id in ('class-files','student-photos')
              and (storage.foldername(name))[1] = auth.uid()::text);
