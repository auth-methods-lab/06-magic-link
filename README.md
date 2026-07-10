# 06 · Magic Link (passwordless por email)

Implementación de autenticación **sin contraseña**: el usuario solo necesita su email. El servidor genera un enlace de un solo uso, lo envía por correo y, al hacer clic, autentica al usuario y crea una sesión.

Los enlaces (tokens) se guardan **hasheados** en PostgreSQL, y las sesiones post-verificación en **Redis**, en base de datos postgres.

---

## 🧠 ¿Cómo funciona este método?

1. El usuario introduce su email en el formulario de login (no hay contraseña).
2. El servidor genera un token aleatorio con `crypto.randomBytes(32)`, lo hashea con SHA-256 y guarda **solo el hash** en PostgreSQL, junto con una expiración de 15 minutos.
3. El servidor envía por email (vía `nodemailer`) un enlace del tipo `https://tuapp.com/auth/verify?token=<token-en-claro>`. El token en claro **nunca** se persiste, solo viaja en el correo.
4. El usuario hace clic en el enlace. El servidor hashea el token recibido y lo busca en la tabla `magic_links`, comprobando que no haya expirado y que no se haya usado antes.
5. Si es válido, se marca como usado (`used_at`), se crea una sesión en Redis (TTL 24h) y se responde con la cookie `sid`, exactamente igual que en `01-session-auth`.
6. Si el email no correspondía a ningún usuario existente, se crea uno nuevo automáticamente al generar el enlace (registro implícito, patrón común en apps passwordless).

A diferencia de `01`, aquí no existe el concepto de contraseña ni de login síncrono: la autenticación se completa en dos pasos separados por el envío del email.

---

## 🗄️ Modelo de datos

### PostgreSQL — `users`

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | Generado con `uuid_generate_v4()` |
| `email` | VARCHAR(255) UNIQUE NOT NULL | |
| `created_at` | TIMESTAMP DEFAULT now() | |
| `updated_at` | TIMESTAMP DEFAULT now() | Auto-actualizado por trigger |

> No existe columna `password_hash`: este método es puramente passwordless.

### PostgreSQL — `magic_links`

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID PK | Generado con `uuid_generate_v4()` |
| `user_id` | UUID FK → `users.id` | `ON DELETE CASCADE` |
| `token_hash` | VARCHAR(64) NOT NULL | SHA-256 del token en claro, indexado |
| `expires_at` | TIMESTAMP NOT NULL | `now() + 15 minutos` |
| `used_at` | TIMESTAMP NULL | `NULL` hasta que se consume |
| `created_at` | TIMESTAMP DEFAULT now() | |

### Redis — `session:<uuid>`

Idéntico al esquema de `01-session-auth`: JSON con TTL automático de 24h.

```json
{
  "userId": "161c0b73-9898-408a-89a2-94069eeed8f7",
  "userAgent": "Mozilla/5.0 ...",
  "ipAddress": "127.0.0.1"
}
```

---

## 🔌 Endpoints

| Método | Ruta | Descripción | Auth |
|---|---|---|---|
| `POST` | `/auth/magic-link` | Genera y envía el enlace de acceso | No |
| `GET` | `/auth/verify` | Verifica el token y crea la sesión | No |
| `POST` | `/auth/logout` | Invalida la sesión actual | Sí |
| `GET` | `/auth/user` | Devuelve el usuario autenticado | Sí |
| `GET` | `/health` | Health check de Postgres, Redis y SMTP | No |

### `POST /auth/magic-link`

```json
// Request
{
  "email": "user@example.com"
}

// Response 200
// Misma respuesta exista o no el usuario, para evitar enumeración de emails
{
  "message": "If this email is registered, a login link has been sent"
}
```

### `GET /auth/verify?token=<token>`

```json
// Response 200
// Set-Cookie: sid=<uuid>; HttpOnly; SameSite=Lax
{
  "message": "Login successful",
  "user": {
    "id": "161c0b73-9898-408a-89a2-94069eeed8f7",
    "email": "user@example.com"
  }
}

// Response 401 (token inválido, expirado o ya usado)
{
  "error": "Invalid or expired link"
}
```

### `POST /auth/logout`

```json
// Response 200
// Elimina la sesión en Redis y limpia la cookie
{
  "message": "Logout successful"
}
```

---

## 🛠️ Stack

- **Node.js + Express**
- **PostgreSQL** — datos de usuarios y tokens de acceso (persistente)
- **Redis** — sesiones con TTL automático (efímero), tras verificar el enlace
- **`nodemailer`** — envío del email con el enlace de acceso
- **`crypto` (Node nativo)** — generación del token (`randomBytes`) y hash del mismo (SHA-256)
- **`cookie-parser`** — lectura de cookies en Express
- **`postgres.js`** — cliente PostgreSQL
- **`redis`** — cliente Redis oficial
- **`zod`** — validación de inputs
- **`cors`** — configuración de CORS

---

## 📂 Estructura del proyecto

```
06-magic-link/
├── src/
│   ├── database/
│   │   ├── database.manager.js   # Singleton Postgres
│   │   └── redis.manager.js      # Singleton Redis
│   ├── mailer/
│   │   └── mailer.manager.js     # Singleton Nodemailer (transporter SMTP)
│   ├── auth/
│   │   ├── auth.controller.js
│   │   ├── auth.middleware.js    # requireAuth
│   │   ├── auth.repository.js   # Queries Postgres (magic_links) + operaciones Redis
│   │   ├── auth.routes.js
│   │   ├── auth.schema.js       # Validación Zod
│   │   └── auth.service.js
│   ├── health/
│   │   ├── health.controller.js
│   │   ├── health.repository.js
│   │   ├── health.routes.js
│   │   └── health.service.js
│   └── index.js
├── .env.example
├── .gitignore
├── .npmrc
├── package.json
└── README.md
```

---

## 🚀 Cómo ejecutar

### 1. Levanta PostgreSQL y Redis

```bash
# PostgreSQL (desde la raíz del repo)
Iniciación externa en el servidor

# Redis
redis-server
```

### 2. Instala dependencias

```bash
cd 06-magic-link
pnpm install
```

### 3. Configura las variables de entorno

```bash
cp .env.example .env
```

```env
HOST=localhost
PORT=3000
APP_BASE_URL=http://localhost:3000

DB_HOST=localhost
DB_PORT=5432
DB_NAME=magic_link_auth
DB_USER=postgres
DB_PASSWORD=
DB_POOL_MAX=10
DB_IDLE_TIMEOUT=30
DB_CONNECT_TIMEOUT=10

REDIS_HOST=localhost
REDIS_PORT=6379

SMTP_HOST=smtp.mailtrap.io
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM="auth-methods-lab <no-reply@example.com>"

MAGIC_LINK_TTL_MINUTES=15
COOKIE_SECRET=change-me-in-production
NODE_ENV=development
```

### 4. Levanta el servidor

```bash
pnpm run dev
```

Disponible en `http://localhost:3000`.

---

## 🔍 Inspeccionar enlaces y sesiones

```bash
# PostgreSQL: ver enlaces generados y su estado
psql -d magic_link_auth -c "SELECT id, user_id, expires_at, used_at FROM magic_links ORDER BY created_at DESC;"

redis-cli

# Ver todas las sesiones activas (tras verificar un enlace)
KEYS session:*

# Ver el contenido de una sesión
GET session:<uuid>

# Ver segundos restantes hasta expiración
TTL session:<uuid>
```

---

## 🔒 Consideraciones de seguridad

- El token nunca se guarda en claro: se hashea con **SHA-256** antes de persistirlo en `magic_links.token_hash`, igual que los refresh tokens de `03-jwt-refresh-tokens`. Si la base de datos se filtra, los enlaces no son reutilizables.
- El token se genera con `crypto.randomBytes(32)` (256 bits de aleatoriedad), imposible de adivinar por fuerza bruta.
- Cada enlace es **de un solo uso**: al verificarlo se marca `used_at`, y cualquier intento posterior con el mismo token se rechaza aunque no haya expirado.
- Expiración corta (15 minutos por defecto) para reducir la ventana de ataque si el email es interceptado.
- La respuesta de `POST /auth/magic-link` es **idéntica** exista o no el email en la base de datos, para evitar enumeración de usuarios.
- Tras verificar el enlace, la sesión creada reutiliza exactamente las mismas garantías de `01-session-auth`: cookie `HttpOnly`, `Secure` en producción, `SameSite=Lax`, y revocación inmediata en logout.
- Se recomienda rate limiting sobre `POST /auth/magic-link` (por IP y por email) para evitar spam de correos y abuso del servicio de envío.

---

## 🏗️ Casos de uso reales

Este patrón es el más adecuado en estos escenarios:

**Apps con fricción mínima en el onboarding**
El usuario no tiene que recordar ni crear una contraseña. Ej: newsletters, herramientas B2B de bajo uso, apps donde el registro rápido importa más que la seguridad máxima.

**Productos donde el email ya es el identificador de confianza**
Si el flujo de negocio ya depende de que el usuario tenga acceso a su bandeja (facturación, notificaciones), el magic link no añade una superficie de ataque nueva significativa.

**Sustitución o refuerzo de contraseñas débiles**
Elimina por completo el riesgo de contraseñas reutilizadas o débiles, un vector de ataque mucho más común que la interceptación de un correo.

**MVPs y herramientas internas**
Evita construir flujos de "olvidé mi contraseña", reseteo, políticas de complejidad, etc. Todo el ciclo de vida de la credencial se reduce a "pedir un enlace".

---

## ✅ Cuándo usar este método (y cuándo no)

**Úsalo cuando:**
- Quieres reducir la fricción de registro/login al mínimo.
- El acceso al email del usuario es un canal fiable y ya forma parte de tu producto.
- Prefieres eliminar la superficie de ataque asociada a contraseñas (reutilización, brute force, credential stuffing).

**Evítalo cuando:**
- El usuario necesita acceso inmediato sin depender de la latencia o disponibilidad del proveedor de email.
- El caso de uso requiere autenticación offline o sin conexión a internet en el momento del login.
- Ya existe 2FA/WebAuthn como método principal y añadir magic link duplicaría la superficie de gestión de identidad sin beneficio claro.

---

## 📄 Licencia
© 2026 Israel Luque. Todos los derechos reservados.
