# Nube Cromat (Supabase)

Cromat entra con **Supabase Auth (correo + clave)**. Las cuentas ya creadas en Authentication y `cromat_profiles` se reutilizan tal cual: no hay que volver a registrarlas ni resetear claves.

Al abrir [cromat.xyz](https://cromat.xyz) se ve la pantalla de inicio. La app (finanzas, salarios, configuración) solo aparece después de autenticarse. Si faltan `SUPABASE_URL` y `SUPABASE_ANON_KEY`, la pantalla de inicio avisa y no muestra el sistema.

## Cómo crear un usuario nuevo

1. Entra como administrador (engranaje → Usuarios).
2. Escribe el correo, elige el rol y pulsa **Enviar**. Se crea una invitación.
3. La persona abre el enlace (o pulsa **Me invitaron**), usa **ese mismo correo** y una clave de 8+ caracteres.
4. Si la cuenta ya existe en Authentication, no la borres ni le cambies la clave: basta con que tenga fila en `cromat_profiles` (o que redima la invitación).

No uses el SQL Editor para borrar o recrear `auth.users` de gente que ya entra.

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

## Elis Cuba

Correo: **eliscubamoran@gmail.com**. Rol: Ventas.

La cuenta de Authentication ya está. Para dejarla en el equipo, en supabase.com → SQL Editor pega y corre `crear-elis.sql` (o vuelve a pegar este `schema.sql`). Luego entra en [cromat-sandy.vercel.app](https://cromat-sandy.vercel.app) con **Ya tengo cuenta**. La clave no se guarda en este repo.

## Pendiente del dueño (producción)

Estos pasos **no** los corre el código solo. Hay que hacerlos a mano:

1. **Supabase → SQL Editor**: pega y corre `migrations/20261104120000_auditoria_seguridad.sql`. No borra cuentas ni datos. Cierra el EXECUTE público de las funciones y ajusta permisos de Contabilidad.
2. **Supabase → Authentication → Providers → Email**: activa **Leaked password protection**.
3. **Vercel → Settings → Environment Variables**: copia `SUPABASE_URL` y `SUPABASE_ANON_KEY` también a **Preview** (hoy solo están en Production). Sin eso, los deploys de PR no pueden iniciar sesión.
4. No pegues `service_role` en Vercel ni en Cromat.
