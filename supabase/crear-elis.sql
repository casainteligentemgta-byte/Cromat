-- Pega ESTO en supabase.com → SQL Editor y dale Run.
-- Mete a Elis Cuba al equipo (la cuenta de correo ya existe).
-- Correo: eliscubamoran@gmail.com
-- Rol: Ventas. El dueño puede cambiarlo en Cromat → Usuarios.

do $$
declare
  uid uuid;
  oid uuid;
begin
  select id into uid from auth.users where lower(email) = 'eliscubamoran@gmail.com' limit 1;
  if uid is null then
    raise exception 'No está eliscubamoran@gmail.com en Authentication.';
  end if;

  update auth.users
  set email_confirmed_at = coalesce(email_confirmed_at, now())
  where id = uid;

  select id into oid from public.cromat_orgs order by created_at asc limit 1;
  if oid is null then
    raise exception 'No hay empresa. Entra primero con el dueño y vuelve a correr este SQL.';
  end if;

  insert into public.cromat_profiles (user_id, org_id, nombre, usuario, rol, activo, email)
  values (uid, oid, 'Elis Cuba', 'eliscubamoran', 'ventas', true, 'eliscubamoran@gmail.com')
  on conflict (user_id) do update
    set nombre = excluded.nombre,
        usuario = excluded.usuario,
        activo = true,
        email = excluded.email;
end;
$$;
