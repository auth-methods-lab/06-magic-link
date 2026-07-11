-- =============================================================================
-- 06-magic-link · schema.sql
-- Esquema PostgreSQL para autenticación passwordless por email (magic link)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Extensiones
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- Función reutilizable: auto-actualiza `updated_at` en cada UPDATE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- Tabla: users
-- No existe columna password_hash: este método es puramente passwordless.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4 (),
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_users_set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Tabla: magic_links
-- Guarda únicamente el hash SHA-256 del token; el token en claro solo
-- viaja por email y nunca se persiste.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS magic_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4 (),
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Búsqueda del token al verificar el enlace (GET /auth/verify?token=...)
CREATE UNIQUE INDEX IF NOT EXISTS idx_magic_links_token_hash ON magic_links (token_hash);

-- Listar/purgar enlaces por usuario (p. ej. invalidar enlaces previos al pedir uno nuevo)
CREATE INDEX IF NOT EXISTS idx_magic_links_user_id ON magic_links (user_id);

-- Purga o consulta de enlaces expirados
CREATE INDEX IF NOT EXISTS idx_magic_links_expires_at ON magic_links (expires_at);

-- -----------------------------------------------------------------------------
-- Comentarios de documentación (opcional, útil en psql \d+)
-- -----------------------------------------------------------------------------
COMMENT ON TABLE users IS 'Usuarios del sistema. Sin password_hash: autenticación 100% passwordless.';

COMMENT ON TABLE magic_links IS 'Enlaces de un solo uso para login passwordless por email.';

COMMENT ON COLUMN magic_links.token_hash IS 'SHA-256 del token en claro enviado por email. El token en claro nunca se persiste.';

COMMENT ON COLUMN magic_links.expires_at IS 'now() + MAGIC_LINK_TTL_MINUTES (15 min por defecto) en el momento de creación.';

COMMENT ON COLUMN magic_links.used_at IS 'NULL hasta que el enlace se consume; una vez usado, no puede reutilizarse.';
