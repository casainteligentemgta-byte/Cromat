-- Cromat: una empresa, usuarios con rol, datos compartidos y RLS.
-- Correr en Supabase → SQL Editor (una vez).
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
  created_at timestamptz not null default now()
);

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

create or replace function public.cromat_can_key(k text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case public.cromat_rol()
    when 'admin' then k in (
      'crm_clientes','crm_presupuestos','crm_ordenes','crm_costos','crm_catalogo',
      'crm_inventario','crm_movimientos','crm_cuentas_pagar','crm_fondos_config','crm_fondos_audit','crm_conta_config','imp_vals'
    )
    when 'ventas' then k in ('crm_clientes','crm_presupuestos','crm_ordenes','crm_catalogo')
    when 'operadora' then k in ('crm_ordenes','crm_inventario','crm_costos','imp_vals')
    when 'conta' then k in ('crm_ordenes','crm_movimientos','crm_cuentas_pagar','crm_fondos_config','crm_fondos_audit','crm_conta_config')
    when 'diseno' then k in ('crm_presupuestos','crm_costos','crm_catalogo','imp_vals')
    else false
  end
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
  insert into public.cromat_profiles (user_id, org_id, nombre, usuario, rol, activo)
  values (
    auth.uid(),
    oid,
    nom,
    split_part(coalesce(auth.email(), 'admin'), '@', 1),
    'admin',
    true
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
  insert into public.cromat_profiles (user_id, org_id, nombre, usuario, rol, activo)
  values (
    auth.uid(),
    inv.org_id,
    nom,
    split_part(coalesce(auth.email(), 'user'), '@', 1),
    inv.rol,
    true
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
grant execute on function public.cromat_bootstrap(text) to authenticated;
grant execute on function public.cromat_redeem_invite(text, text) to authenticated;

alter table public.cromat_invites add column if not exists email text;
