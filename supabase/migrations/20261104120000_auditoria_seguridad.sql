-- Auditoría de producción Cromat.
-- NO se aplica sola. El dueño debe pegarla en Supabase → SQL Editor y correrla.
-- No borra cuentas, claves ni filas de datos.

-- 1) search_path fijo en el correo del dueño
create or replace function public.cromat_owner_email()
returns text
language sql
immutable
set search_path = public
as $$
  select 'casainteligentemgta@gmail.com'::text
$$;

-- 2) Contabilidad necesita escribir OP (deshacer cobros)
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
    when 'conta' then k in (
      'crm_movimientos','crm_fondos_config','crm_fondos_audit','crm_conta_config','crm_ordenes'
    )
    when 'diseno' then k in ('crm_presupuestos','crm_costos','crm_catalogo','imp_vals')
    else false
  end;
end;
$$;

-- 3) Lectura extra: Contabilidad arma cobros, CxC y desglose sin poder editar presupuestos ni costos
create or replace function public.cromat_can_read_key(k text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.cromat_can_key(k) then
    return true;
  end if;
  if public.cromat_rol() = 'conta' then
    return k in ('crm_ordenes','crm_presupuestos','crm_costos');
  end if;
  return false;
end;
$$;

drop policy if exists cromat_data_select on public.cromat_data;
create policy cromat_data_select on public.cromat_data
  for select to authenticated
  using (org_id = public.cromat_org_id() and public.cromat_can_read_key(key));

-- 4) unlock_login: solo confirma correos de la empresa (perfil, invitación o dueño)
create or replace function public.cromat_unlock_login(p_email text)
returns void
language plpgsql
security definer
set search_path = auth, public
as $$
declare
  em text := lower(trim(coalesce(p_email, '')));
  ok boolean := false;
begin
  if em = '' or position('@' in em) = 0 then
    return;
  end if;
  if em = public.cromat_owner_email() then
    ok := true;
  end if;
  if not ok then
    select true into ok
    from public.cromat_profiles p
    where lower(trim(coalesce(p.email, ''))) = em
    limit 1;
  end if;
  if not ok then
    select true into ok
    from public.cromat_invites i
    where lower(trim(coalesce(i.email, ''))) = em
    limit 1;
  end if;
  if not ok then
    return;
  end if;
  update auth.users
  set email_confirmed_at = coalesce(email_confirmed_at, now())
  where lower(email) = em;
end;
$$;

-- 5) Equipo: solo el administrador (el resto ya lee cromat_profiles de su org)
create or replace function public.cromat_equipo()
returns table (
  user_id uuid,
  nombre text,
  usuario text,
  email text,
  rol text,
  activo boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.cromat_rol() is distinct from 'admin' then
    return;
  end if;
  return query
  select
    p.user_id,
    p.nombre,
    p.usuario,
    coalesce(nullif(trim(p.email), ''), u.email, '')::text,
    p.rol,
    p.activo
  from public.cromat_profiles p
  left join auth.users u on u.id = p.user_id
  where p.org_id = public.cromat_org_id()
  order by p.nombre;
end;
$$;

-- 6) Quitar EXECUTE público (Postgres lo otorga por defecto)
revoke all on function public.cromat_rol() from public, anon;
revoke all on function public.cromat_org_id() from public, anon;
revoke all on function public.cromat_can_key(text) from public, anon;
revoke all on function public.cromat_can_read_key(text) from public, anon;
revoke all on function public.cromat_bootstrap(text) from public, anon;
revoke all on function public.cromat_redeem_invite(text, text) from public, anon;
revoke all on function public.cromat_equipo() from public, anon;
revoke all on function public.cromat_save_data(text, jsonb) from public, anon;
revoke all on function public.cromat_owner_email() from public, anon;
revoke all on function public.cromat_ensure_owner() from public, anon;
revoke all on function public.cromat_protect_owner() from public, anon, authenticated;
revoke all on function public.cromat_auto_confirm_auth_user() from public, anon, authenticated;
revoke all on function public.cromat_unlock_login(text) from public;

grant execute on function public.cromat_rol() to authenticated;
grant execute on function public.cromat_org_id() to authenticated;
grant execute on function public.cromat_can_key(text) to authenticated;
grant execute on function public.cromat_can_read_key(text) to authenticated;
grant execute on function public.cromat_bootstrap(text) to authenticated;
grant execute on function public.cromat_redeem_invite(text, text) to authenticated;
grant execute on function public.cromat_equipo() to authenticated;
grant execute on function public.cromat_save_data(text, jsonb) to authenticated;
grant execute on function public.cromat_owner_email() to authenticated;
grant execute on function public.cromat_ensure_owner() to authenticated;
grant execute on function public.cromat_unlock_login(text) to anon, authenticated;

do $$
begin
  revoke all on function public.cromat_auto_join_team(text) from public, anon;
  grant execute on function public.cromat_auto_join_team(text) to authenticated;
exception when undefined_function then
  null;
end;
$$;
