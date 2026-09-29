-- Cromat: una empresa, usuarios con rol, datos compartidos y RLS.
-- Pega ESTE ARCHIVO COMPLETO en Supabase → SQL Editor y córrelo (no un fragmento).
-- Auth: Authentication → Providers → Email.
-- Recomendado al inicio: desactivar "Confirm email" para el equipo.

create extension if not exists pgcrypto;

create table if not exists public.cromat_orgs (
  id uuid primary key default gen_random_uuid(),
  nombre text not null default 'Cromat',
  created_at timestamptz not null default now()
);

create table if not exists public.cromat_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  org_id uuid not null references public.cromat_orgs (id) on delete cascade,
  nombre text not null default '',
  usuario text not null default '',
  rol text not null check (rol in ('admin','ventas','operadora','conta','diseno')),
  activo boolean not null default true,
  email text,
  created_at timestamptz not null default now()
);

alter table public.cromat_profiles add column if not exists email text;

create table if not exists public.cromat_invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.cromat_orgs (id) on delete cascade,
  code text not null unique,
  rol text not null check (rol in ('admin','ventas','operadora','conta','diseno')),
  nombre_sugerido text,
  email text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  used_by uuid references auth.users (id),
  used_at timestamptz
);

create table if not exists public.cromat_data (
  org_id uuid not null references public.cromat_orgs (id) on delete cascade,
  key text not null,
  value jsonb not null default 'null'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id),
  primary key (org_id, key)
);

create index if not exists cromat_profiles_org_idx on public.cromat_profiles (org_id);
create index if not exists cromat_invites_org_idx on public.cromat_invites (org_id);
create index if not exists cromat_invites_code_idx on public.cromat_invites (code);

create or replace function public.cromat_rol()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.cromat_profiles
  where user_id = auth.uid() and activo
  limit 1
$$;

create or replace function public.cromat_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select org_id from public.cromat_profiles
  where user_id = auth.uid() and activo
  limit 1
$$;

-- El argumento debe llamarse k: CREATE OR REPLACE no puede renombrarlo si ya existe.
create or replace function public.cromat_can_key(k text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if k = 'crm_audit' then
    return lower(coalesce(auth.email(), '')) = public.cromat_owner_email();
  end if;
  return case public.cromat_rol()
    when 'admin' then k in (
      'crm_clientes','crm_presupuestos','crm_ordenes','crm_costos','crm_catalogo',
      'crm_inventario','crm_movimientos','crm_fondos_config','crm_fondos_audit','crm_conta_config','imp_vals'
    )
    when 'ventas' then k in ('crm_clientes','crm_presupuestos','crm_ordenes','crm_catalogo')
    when 'operadora' then k in ('crm_ordenes','crm_inventario','crm_costos','imp_vals')
    when 'conta' then k in ('crm_movimientos','crm_fondos_config','crm_fondos_audit','crm_conta_config')
    when 'diseno' then k in ('crm_presupuestos','crm_costos','crm_catalogo','imp_vals')
    else false
  end;
end;
$$;

create or replace function public.cromat_bootstrap(p_nombre text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  oid uuid;
  nom text := coalesce(nullif(trim(p_nombre), ''), 'Admin');
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if exists (select 1 from public.cromat_profiles where user_id = auth.uid()) then
    return (select org_id from public.cromat_profiles where user_id = auth.uid());
  end if;
  if exists (select 1 from public.cromat_orgs) then
    raise exception 'invite_required';
  end if;
  insert into public.cromat_orgs (nombre) values ('Cromat') returning id into oid;
  insert into public.cromat_profiles (user_id, org_id, nombre, usuario, rol, activo, email)
  values (
    auth.uid(),
    oid,
    nom,
    split_part(coalesce(auth.email(), 'admin'), '@', 1),
    'admin',
    true,
    auth.email()
  );
  return oid;
end;
$$;

create or replace function public.cromat_redeem_invite(p_code text, p_nombre text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  inv public.cromat_invites%rowtype;
  nom text := coalesce(nullif(trim(p_nombre), ''), '');
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if exists (select 1 from public.cromat_profiles where user_id = auth.uid()) then
    return (select org_id from public.cromat_profiles where user_id = auth.uid());
  end if;
  select * into inv
  from public.cromat_invites
  where upper(code) = upper(trim(p_code)) and used_at is null
  for update;
  if not found then
    raise exception 'invalid_invite';
  end if;
  if nom = '' then
    nom := coalesce(nullif(inv.nombre_sugerido, ''), split_part(coalesce(auth.email(), 'user'), '@', 1));
  end if;
  insert into public.cromat_profiles (user_id, org_id, nombre, usuario, rol, activo, email)
  values (
    auth.uid(),
    inv.org_id,
    nom,
    split_part(coalesce(auth.email(), 'user'), '@', 1),
    inv.rol,
    true,
    auth.email()
  );
  update public.cromat_invites
  set used_by = auth.uid(), used_at = now()
  where id = inv.id;
  return inv.org_id;
end;
$$;

alter table public.cromat_orgs enable row level security;
alter table public.cromat_profiles enable row level security;
alter table public.cromat_invites enable row level security;
alter table public.cromat_data enable row level security;

drop policy if exists cromat_orgs_read on public.cromat_orgs;
create policy cromat_orgs_read on public.cromat_orgs
  for select to authenticated
  using (id = public.cromat_org_id());

drop policy if exists cromat_profiles_read on public.cromat_profiles;
create policy cromat_profiles_read on public.cromat_profiles
  for select to authenticated
  using (org_id = public.cromat_org_id());

drop policy if exists cromat_profiles_admin_update on public.cromat_profiles;
create policy cromat_profiles_admin_update on public.cromat_profiles
  for update to authenticated
  using (org_id = public.cromat_org_id() and public.cromat_rol() = 'admin')
  with check (org_id = public.cromat_org_id() and public.cromat_rol() = 'admin');

drop policy if exists cromat_invites_admin_all on public.cromat_invites;
create policy cromat_invites_admin_all on public.cromat_invites
  for all to authenticated
  using (org_id = public.cromat_org_id() and public.cromat_rol() = 'admin')
  with check (org_id = public.cromat_org_id() and public.cromat_rol() = 'admin');

drop policy if exists cromat_data_select on public.cromat_data;
create policy cromat_data_select on public.cromat_data
  for select to authenticated
  using (org_id = public.cromat_org_id() and public.cromat_can_key(key));

drop policy if exists cromat_data_write on public.cromat_data;
create policy cromat_data_write on public.cromat_data
  for insert to authenticated
  with check (org_id = public.cromat_org_id() and public.cromat_can_key(key));

drop policy if exists cromat_data_update on public.cromat_data;
create policy cromat_data_update on public.cromat_data
  for update to authenticated
  using (org_id = public.cromat_org_id() and public.cromat_can_key(key))
  with check (org_id = public.cromat_org_id() and public.cromat_can_key(key));

drop policy if exists cromat_data_delete on public.cromat_data;
create policy cromat_data_delete on public.cromat_data
  for delete to authenticated
  using (org_id = public.cromat_org_id() and public.cromat_can_key(key));

grant usage on schema public to anon, authenticated;
grant select on public.cromat_orgs to authenticated;
grant select, update on public.cromat_profiles to authenticated;
grant select, insert, update, delete on public.cromat_invites to authenticated;
grant select, insert, update, delete on public.cromat_data to authenticated;
grant execute on function public.cromat_rol() to authenticated;
grant execute on function public.cromat_org_id() to authenticated;
grant execute on function public.cromat_can_key(text) to authenticated;

-- Guarda un bloque de datos de la empresa (evita fallos raros del upsert + RLS).
create or replace function public.cromat_save_data(p_key text, p_value jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  oid uuid := public.cromat_org_id();
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if oid is null then
    raise exception 'no_org';
  end if;
  if not public.cromat_can_key(p_key) then
    raise exception 'forbidden_key';
  end if;
  insert into public.cromat_data (org_id, key, value, updated_at, updated_by)
  values (oid, p_key, coalesce(p_value, 'null'::jsonb), now(), auth.uid())
  on conflict (org_id, key) do update
    set value = excluded.value,
        updated_at = now(),
        updated_by = auth.uid();
end;
$$;

grant execute on function public.cromat_save_data(text, jsonb) to authenticated;
grant execute on function public.cromat_bootstrap(text) to authenticated;
grant execute on function public.cromat_redeem_invite(text, text) to authenticated;

alter table public.cromat_invites add column if not exists email text;

-- Dueño fijo de Cromat
create or replace function public.cromat_owner_email()
returns text
language sql
immutable
as $$
  select 'casainteligentemgta@gmail.com'::text
$$;

alter table public.cromat_profiles add column if not exists email text;

create or replace function public.cromat_ensure_owner()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  oid uuid;
  uid uuid := auth.uid();
  em text := lower(coalesce(auth.email(), ''));
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;
  if em <> public.cromat_owner_email() then
    return public.cromat_org_id();
  end if;

  update public.cromat_profiles
  set rol = 'admin', activo = true, email = coalesce(auth.email(), email)
  where user_id = uid
  returning org_id into oid;
  if found then
    return oid;
  end if;

  select id into oid from public.cromat_orgs order by created_at asc limit 1;
  if oid is null then
    return public.cromat_bootstrap(coalesce(nullif(trim(split_part(auth.email(), '@', 1)), ''), 'Luis Mata'));
  end if;

  insert into public.cromat_profiles (user_id, org_id, nombre, usuario, rol, activo, email)
  values (
    uid,
    oid,
    'Luis Mata',
    split_part(coalesce(auth.email(), 'admin'), '@', 1),
    'admin',
    true,
    auth.email()
  );
  return oid;
end;
$$;

create or replace function public.cromat_protect_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  em text;
begin
  select lower(email) into em from auth.users where id = new.user_id;
  if em is null then
    em := lower(coalesce(new.email, ''));
  end if;
  if em = public.cromat_owner_email() then
    new.rol := 'admin';
    new.activo := true;
    new.email := public.cromat_owner_email();
  end if;
  return new;
end;
$$;

drop trigger if exists cromat_protect_owner on public.cromat_profiles;
create trigger cromat_protect_owner
  before insert or update on public.cromat_profiles
  for each row execute function public.cromat_protect_owner();

grant execute on function public.cromat_owner_email() to authenticated;
grant execute on function public.cromat_ensure_owner() to authenticated;

-- Si la cuenta ya existe, deja el perfil como dueño ahora.
update public.cromat_profiles p
set rol = 'admin', activo = true, email = u.email
from auth.users u
where p.user_id = u.id
  and lower(u.email) = 'casainteligentemgta@gmail.com';

do $$
declare
  uid uuid;
  oid uuid;
begin
  select id into uid from auth.users where lower(email) = 'casainteligentemgta@gmail.com' limit 1;
  if uid is null then
    return;
  end if;
  select id into oid from public.cromat_orgs order by created_at asc limit 1;
  if oid is null then
    return;
  end if;
  insert into public.cromat_profiles (user_id, org_id, nombre, usuario, rol, activo, email)
  values (uid, oid, 'Luis Mata', split_part('casainteligentemgta@gmail.com', '@', 1), 'admin', true, 'casainteligentemgta@gmail.com')
  on conflict (user_id) do update
    set rol = 'admin', activo = true, email = excluded.email;
end;
$$;
