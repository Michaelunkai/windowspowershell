-- ============================================================
-- ULTIMATE DATABASE PROTECTION SYSTEM v2
-- TovPlay Production Database
-- Created: Dec 2, 2025
-- Purpose: PREVENT ALL DATA LOSS FOREVER
-- ============================================================

-- 1. Delete Audit Log Table
DROP TABLE IF EXISTS "DeleteAuditLog" CASCADE;
CREATE TABLE "DeleteAuditLog" (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(50) NOT NULL,
    old_data JSONB,
    deleted_by VARCHAR(100) DEFAULT current_user,
    deleted_at TIMESTAMP DEFAULT NOW(),
    row_count INTEGER DEFAULT 1,
    client_info TEXT DEFAULT inet_client_addr()::TEXT
);

-- 2. Backup Log Table
DROP TABLE IF EXISTS "BackupLog" CASCADE;
CREATE TABLE "BackupLog" (
    id SERIAL PRIMARY KEY,
    backup_time TIMESTAMP DEFAULT NOW(),
    backup_type VARCHAR(50),
    status VARCHAR(20) DEFAULT 'success'
);

-- 3. Universal Delete Audit Function
CREATE OR REPLACE FUNCTION audit_delete_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $body$
BEGIN
    INSERT INTO "DeleteAuditLog" (table_name, operation, old_data, deleted_by)
    VALUES (TG_TABLE_NAME, 'DELETE', row_to_json(OLD)::jsonb, current_user);
    RETURN OLD;
END;
$body$;

-- 4. Create Triggers for ALL Tables

-- User table
DROP TRIGGER IF EXISTS audit_del_User ON "User";
CREATE TRIGGER audit_del_User
    BEFORE DELETE ON "User"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- UserProfile table
DROP TRIGGER IF EXISTS audit_del_UserProfile ON "UserProfile";
CREATE TRIGGER audit_del_UserProfile
    BEFORE DELETE ON "UserProfile"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- Game table
DROP TRIGGER IF EXISTS audit_del_Game ON "Game";
CREATE TRIGGER audit_del_Game
    BEFORE DELETE ON "Game"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- GameRequest table
DROP TRIGGER IF EXISTS audit_del_GameRequest ON "GameRequest";
CREATE TRIGGER audit_del_GameRequest
    BEFORE DELETE ON "GameRequest"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- ScheduledSession table
DROP TRIGGER IF EXISTS audit_del_ScheduledSession ON "ScheduledSession";
CREATE TRIGGER audit_del_ScheduledSession
    BEFORE DELETE ON "ScheduledSession"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- UserAvailability table
DROP TRIGGER IF EXISTS audit_del_UserAvailability ON "UserAvailability";
CREATE TRIGGER audit_del_UserAvailability
    BEFORE DELETE ON "UserAvailability"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- UserGamePreference table
DROP TRIGGER IF EXISTS audit_del_UserGamePreference ON "UserGamePreference";
CREATE TRIGGER audit_del_UserGamePreference
    BEFORE DELETE ON "UserGamePreference"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- UserFriends table
DROP TRIGGER IF EXISTS audit_del_UserFriends ON "UserFriends";
CREATE TRIGGER audit_del_UserFriends
    BEFORE DELETE ON "UserFriends"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- UserNotifications table
DROP TRIGGER IF EXISTS audit_del_UserNotifications ON "UserNotifications";
CREATE TRIGGER audit_del_UserNotifications
    BEFORE DELETE ON "UserNotifications"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- UserSession table
DROP TRIGGER IF EXISTS audit_del_UserSession ON "UserSession";
CREATE TRIGGER audit_del_UserSession
    BEFORE DELETE ON "UserSession"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- EmailVerification table
DROP TRIGGER IF EXISTS audit_del_EmailVerification ON "EmailVerification";
CREATE TRIGGER audit_del_EmailVerification
    BEFORE DELETE ON "EmailVerification"
    FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- 5. TRUNCATE Prevention Function
CREATE OR REPLACE FUNCTION block_truncate_fn()
RETURNS event_trigger
LANGUAGE plpgsql
AS $body$
BEGIN
    INSERT INTO "DeleteAuditLog" (table_name, operation, deleted_by)
    VALUES ('SYSTEM', 'TRUNCATE_BLOCKED', current_user);

    RAISE EXCEPTION 'TRUNCATE IS BLOCKED! Database protection is active.';
END;
$body$;

-- 6. Create Event Trigger to Block TRUNCATE
DROP EVENT TRIGGER IF EXISTS block_truncate_trigger;
CREATE EVENT TRIGGER block_truncate_trigger
    ON ddl_command_start
    WHEN TAG IN ('TRUNCATE TABLE')
    EXECUTE FUNCTION block_truncate_fn();

-- 7. Grant permissions
GRANT SELECT, INSERT ON "DeleteAuditLog" TO PUBLIC;
GRANT SELECT, INSERT ON "BackupLog" TO PUBLIC;
GRANT USAGE, SELECT ON SEQUENCE "DeleteAuditLog_id_seq" TO PUBLIC;
GRANT USAGE, SELECT ON SEQUENCE "BackupLog_id_seq" TO PUBLIC;

-- 8. Verification
SELECT 'PROTECTION INSTALLED' as status;
SELECT COUNT(*) as trigger_count FROM pg_trigger WHERE tgname LIKE 'audit_del_%';
