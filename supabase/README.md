# Nube Cromat (Supabase)

## Qué hacer con Project URL y anon

Son las dos únicas claves que Cromat necesita. Están en [supabase.com](https://supabase.com) → tu proyecto → **Project Settings → API**.

| Qué ves en Supabase | Qué es | Dónde va |
|---|---|---|
| **Project URL** | `https://xxxxx.supabase.co` | Variable `SUPABASE_URL` en Vercel, o Usuarios → Conectar nube |
| **anon public** | JWT largo que empieza `eyJ…` | Variable `SUPABASE_ANON_KEY` en Vercel, o el campo anon |
| **service_role** | Clave secreta de administrador | **No la copies. No la pegues en Cromat ni en Vercel.** |

La **anon** es pública a propósito: la app del celular la usa con las reglas RLS. La **service_role** salta esas reglas; si se filtra, cualquiera lee o borra la empresa.

Para que **todo el equipo** entre a la misma nube:

1. Vercel → Settings → Environment Variables → Production:
   - `SUPABASE_URL` = Project URL
   - `SUPABASE_ANON_KEY` = anon public
2. Redeploy (o un commit nuevo). El build las inyecta en `index.html`.

Pegarlas solo en **Usuarios → Conectar nube** deja la nube **en ese teléfono**. Sirve para probar; el resto del equipo seguiría en local.

## Primera vez

1. Crea el proyecto en Supabase.
2. Authentication → Providers → Email. **Desactiva Confirm email** (el SMTP gratis bloquea invitados desde el primer intento con «excediste el número de intentos»).
3. SQL Editor: pega y corre `schema.sql` (si ya lo corriste, vuelve a pegarlo: confirma cuentas a medias, deja al dueño admin, lista el equipo con correo y permite guardar en `cromat_data`).
4. Configura URL y anon como arriba.
5. En Cromat: entra con **casainteligentemgta@gmail.com**. Ese correo queda como dueño / admin; nadie puede bajarle el rol ni quitarle el acceso. Si esa cuenta ya existía con otro rol, vuelve a pegar `schema.sql` y entra de nuevo: el SQL la deja admin al instante.
6. **Usuarios** → nombre, correo, rol → **Crear invitación y abrir correo**. Se abre el mail con el enlace. También puedes copiar o mandar por WhatsApp.
7. La otra persona abre el enlace, elige **Me invitaron**, pone su correo y una clave de 8+ caracteres.

El enlace es `https://tu-dominio/?invite=CODIGO`. El código también se puede pegar a mano.
