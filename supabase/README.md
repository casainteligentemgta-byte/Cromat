# Nube Cromat (Supabase)

1. Crea un proyecto en [supabase.com](https://supabase.com).
2. Authentication → Providers → Email. Al inicio desactiva **Confirm email**.
3. SQL Editor: pega y corre `schema.sql`.
4. Settings → API: copia **Project URL** y **anon public**.
5. En Vercel, variables `SUPABASE_URL` y `SUPABASE_ANON_KEY`, o en la app (admin) **Usuarios → Conectar nube**.

El primer correo que se registre crea la empresa y queda como dueño. El resto entra con un **código de invitación**.
