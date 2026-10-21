-- =====================================================================
-- Pégase · Domaine Apolo — installation de la base Supabase
-- À coller une seule fois dans Supabase > SQL Editor > New query > Run
-- (ne contient aucune donnée : les adresses autorisées sont ajoutées à part)
-- =====================================================================

-- 1. Les adresses autorisées et leur rôle (owner = administratrice, editor = utilisatrice)
create table if not exists public.allowed (
  email text primary key,
  role  text not null check (role in ('owner','editor'))
);
alter table public.allowed enable row level security;
drop policy if exists "chacun lit son role" on public.allowed;
create policy "chacun lit son role" on public.allowed
  for select to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email'));

create or replace function public.app_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.allowed where lower(email) = lower(auth.jwt() ->> 'email')
$$;

-- 2. Personne d'autre ne peut créer de compte
create or replace function public.only_allowed_signup() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.allowed where lower(email) = lower(new.email)) then
    raise exception 'Adresse non autorisée';
  end if;
  return new;
end $$;
drop trigger if exists only_allowed_signup on auth.users;
create trigger only_allowed_signup before insert on auth.users
  for each row execute function public.only_allowed_signup();

-- 3. Les données de Pégase (un document = un chemin, comme « agenda/xxx »)
create table if not exists public.docs (
  path       text primary key,
  col        text not null,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create index if not exists docs_col_idx on public.docs (col);
alter table public.docs enable row level security;

-- Lecture : tout le monde autorisé, sauf la partie privée (admin) et les entrées perso (chacune les siennes)
drop policy if exists docs_read on public.docs;
create policy docs_read on public.docs for select to authenticated using (
  case
    when col = 'prive' then public.app_role() = 'owner'
    when col like 'data/users/%' then col = 'data/users/' || auth.uid()::text
    else public.app_role() in ('owner','editor')
  end
);

-- Écriture : prospects et partie privée = administratrice ; le reste = les deux comptes
drop policy if exists docs_insert on public.docs;
create policy docs_insert on public.docs for insert to authenticated with check (
  case
    when col in ('prive','prospects') then public.app_role() = 'owner'
    when col like 'data/users/%' then col = 'data/users/' || auth.uid()::text and public.app_role() is not null
    else public.app_role() in ('owner','editor')
  end
);
drop policy if exists docs_update on public.docs;
create policy docs_update on public.docs for update to authenticated
using (
  case
    when col in ('prive','prospects') then public.app_role() = 'owner'
    when col like 'data/users/%' then col = 'data/users/' || auth.uid()::text
    else public.app_role() in ('owner','editor')
  end
) with check (
  case
    when col in ('prive','prospects') then public.app_role() = 'owner'
    when col like 'data/users/%' then col = 'data/users/' || auth.uid()::text
    else public.app_role() in ('owner','editor')
  end
);
drop policy if exists docs_delete on public.docs;
create policy docs_delete on public.docs for delete to authenticated using (
  case
    when col in ('prive','prospects') then public.app_role() = 'owner'
    when col like 'data/users/%' then col = 'data/users/' || auth.uid()::text
    else public.app_role() in ('owner','editor')
  end
);

-- 4. Mises à jour en direct entre les appareils
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;
