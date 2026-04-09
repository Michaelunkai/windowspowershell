-- TovPlay Enterprise Database Protection v4.0
-- Installed: 2025-12-15
-- Contact: Michael for special permission

-- ============================================
-- 1. CREATE READ-ONLY USER FOR TEAM ACCESS
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tovplay_readonly') THEN
        CREATE USER tovplay_readonly WITH PASSWORD 'ReadOnly2025!Secure';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE "TovPlay" TO tovplay_readonly;
GRANT USAGE ON SCHEMA public TO tovplay_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO tovplay_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO tovplay_readonly;

-- Revoke all dangerous permissions from readonly user
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM tovplay_readonly;

-- ============================================
-- 2. REVOKE DANGEROUS PERMISSIONS FROM MAIN USER
-- ============================================
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM "raz@tovtech.org";

-- ============================================
-- 3. BLOCK TRUNCATE ON ALL CRITICAL TABLES
-- ============================================
CREATE OR REPLACE FUNCTION block_truncate()
RETURNS TRIGGER AS $func$
BEGIN
    RAISE EXCEPTION 'TRUNCATE BLOCKED: Contact Michael for special permission. Table: %, User: %, IP: %',
        TG_TABLE_NAME, current_user, inet_client_addr();
    RETURN NULL;
END;
$func$ LANGUAGE plpgsql;

-- Apply to all critical tables
DROP TRIGGER IF EXISTS block_truncate_trigger ON "User";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "User" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_trigger ON "Game";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "Game" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_trigger ON "GameRequest";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "GameRequest" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_trigger ON "ScheduledSession";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "ScheduledSession" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_trigger ON "UserProfile";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "UserProfile" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_trigger ON "UserAvailability";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "UserAvailability" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_trigger ON "UserFriends";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "UserFriends" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_trigger ON "UserGamePreference";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "UserGamePreference" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_trigger ON "UserNotifications";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "UserNotifications" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_trigger ON "EmailVerification";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "EmailVerification" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_trigger ON "UserSession";
CREATE TRIGGER block_truncate_trigger BEFORE TRUNCATE ON "UserSession" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

-- ============================================
-- 4. BLOCK MASS DELETE (more than 5 rows at once)
-- ============================================
CREATE OR REPLACE FUNCTION block_mass_delete()
RETURNS TRIGGER AS $func$
DECLARE
    delete_count INTEGER;
BEGIN
    -- Get count of rows being deleted
    SELECT COUNT(*) INTO delete_count FROM old_table;

    IF delete_count > 5 THEN
        RAISE EXCEPTION 'MASS DELETE BLOCKED: Attempting to delete % rows from %. Contact Michael for permission. User: %, IP: %',
            delete_count, TG_TABLE_NAME, current_user, inet_client_addr();
    END IF;

    RETURN NULL;
END;
$func$ LANGUAGE plpgsql;

-- Apply mass delete protection to User table
DROP TRIGGER IF EXISTS block_mass_delete_user ON "User";
CREATE TRIGGER block_mass_delete_user
    AFTER DELETE ON "User"
    REFERENCING OLD TABLE AS old_table
    FOR EACH STATEMENT
    EXECUTE FUNCTION block_mass_delete();

-- ============================================
-- 5. COMPREHENSIVE AUDIT LOGGING
-- ============================================
CREATE TABLE IF NOT EXISTS "AuditLog" (
    id SERIAL PRIMARY KEY,
    event_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    table_name TEXT,
    operation TEXT,
    row_data JSONB,
    user_name TEXT DEFAULT current_user,
    client_ip TEXT DEFAULT inet_client_addr()::TEXT,
    application TEXT DEFAULT current_setting('application_name', true),
    session_user TEXT DEFAULT session_user
);

CREATE OR REPLACE FUNCTION audit_changes()
RETURNS TRIGGER AS $func$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO "AuditLog" (table_name, operation, row_data)
        VALUES (TG_TABLE_NAME, 'DELETE', row_to_json(OLD)::jsonb);
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO "AuditLog" (table_name, operation, row_data)
        VALUES (TG_TABLE_NAME, 'UPDATE', jsonb_build_object('old', row_to_json(OLD), 'new', row_to_json(NEW)));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO "AuditLog" (table_name, operation, row_data)
        VALUES (TG_TABLE_NAME, 'INSERT', row_to_json(NEW)::jsonb);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$func$ LANGUAGE plpgsql;

-- Apply audit triggers to critical tables
DROP TRIGGER IF EXISTS audit_user ON "User";
CREATE TRIGGER audit_user AFTER INSERT OR UPDATE OR DELETE ON "User" FOR EACH ROW EXECUTE FUNCTION audit_changes();

DROP TRIGGER IF EXISTS audit_game ON "Game";
CREATE TRIGGER audit_game AFTER INSERT OR UPDATE OR DELETE ON "Game" FOR EACH ROW EXECUTE FUNCTION audit_changes();

DROP TRIGGER IF EXISTS audit_gamerequest ON "GameRequest";
CREATE TRIGGER audit_gamerequest AFTER INSERT OR UPDATE OR DELETE ON "GameRequest" FOR EACH ROW EXECUTE FUNCTION audit_changes();

DROP TRIGGER IF EXISTS audit_session ON "ScheduledSession";
CREATE TRIGGER audit_session AFTER INSERT OR UPDATE OR DELETE ON "ScheduledSession" FOR EACH ROW EXECUTE FUNCTION audit_changes();

-- ============================================
-- 6. CONNECTION LOGGING
-- ============================================
CREATE TABLE IF NOT EXISTS "ConnectionLog" (
    id SERIAL PRIMARY KEY,
    event_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_name TEXT,
    client_ip TEXT,
    application TEXT,
    action TEXT
);

-- ============================================
-- 7. UPDATE PROTECTION STATUS
-- ============================================
UPDATE "ProtectionStatus" SET
    protection_enabled = true,
    last_verified = NOW(),
    version = '4.0'
WHERE id = 1;

-- ============================================
-- 8. GRANT SELECT ON NEW TABLES TO READONLY
-- ============================================
GRANT SELECT ON "AuditLog" TO tovplay_readonly;
GRANT SELECT ON "ConnectionLog" TO tovplay_readonly;
