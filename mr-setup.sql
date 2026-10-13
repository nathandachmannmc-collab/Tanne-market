-- TANNE CLAN M/R LIBRARY — Supabase setup
-- Run this entire file in Supabase Dashboard > SQL Editor > New query.
-- Files are publicly downloadable; only signed-in users can upload into their own folder.
-- This does NOT expose the Supabase service_role key. Use only the public anon/publishable key in index.html.

create extension if not exists pgcrypto;

create table if not exists public.mr_projects (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null check (char_length(author_name) between 1 and 32),
  title text not null check (char_length(title) between 2 and 80),
  project_type text not null check (project_type in ('mod', 'resourcepack')),
  summary text not null check (char_length(summary) between 1 and 180),
  description text not null check (char_length(description) between 1 and 5000),
  game_versions text not null default '' check (char_length(game_versions) <= 100),
  loader text not null default 'Vanilla' check (char_length(loader) <= 30),
  icon_path text not null,
  file_path text not null,
  file_name text not null check (char_length(file_name) <= 255),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.mr_projects enable row level security;

grant select on public.mr_projects to anon, authenticated;
grant insert, update, delete on public.mr_projects to authenticated;

drop policy if exists "M/R projects are publicly readable" on public.mr_projects;
create policy "M/R projects are publicly readable"
  on public.mr_projects for select to anon, authenticated
  using (true);

drop policy if exists "Signed-in users can publish their own M/R projects" on public.mr_projects;
create policy "Signed-in users can publish their own M/R projects"
  on public.mr_projects for insert to authenticated
  with check (
    auth.uid() = author_id
    and char_length(title) between 2 and 80
    and project_type in ('mod', 'resourcepack')
  );

drop policy if exists "Authors can edit their own M/R projects" on public.mr_projects;
create policy "Authors can edit their own M/R projects"
  on public.mr_projects for update to authenticated
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

drop policy if exists "Authors can delete their own M/R projects" on public.mr_projects;
create policy "Authors can delete their own M/R projects"
  on public.mr_projects for delete to authenticated
  using (auth.uid() = author_id);

-- Public bucket for icons and download files. Maximum file size: 100 MiB.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('mr-files', 'mr-files', true, 104857600, null)
on conflict (id) do update
set public = true,
    file_size_limit = 104857600,
    allowed_mime_types = null;

drop policy if exists "M/R files are publicly readable" on storage.objects;
create policy "M/R files are publicly readable"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'mr-files');

drop policy if exists "Signed-in users can upload to their own M/R folder" on storage.objects;
create policy "Signed-in users can upload to their own M/R folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'mr-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Signed-in users can update their own M/R files" on storage.objects;
create policy "Signed-in users can update their own M/R files"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'mr-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'mr-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Signed-in users can delete their own M/R files" on storage.objects;
create policy "Signed-in users can delete their own M/R files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'mr-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
