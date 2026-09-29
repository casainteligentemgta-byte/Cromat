-- Pega ESTO en Supabase → SQL Editor y dale Run.
-- Desbloquea a Vane (y a cualquier invitado cuyo correo no se confirmó).

update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now())
where email_confirmed_at is null;

update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now())
where lower(email) = 'vanerodriguezpacheco@gmail.com';
