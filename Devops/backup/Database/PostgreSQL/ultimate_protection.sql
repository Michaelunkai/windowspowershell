-- =========================================
-- ULTIMATE DATABASE PROTECTION - BULLETPROOF
-- =========================================

-- 1. Create protection status table
CREATE TABLE IF NOT EXISTS db_protection_ultimate (
    id SERIAL PRIMARY KEY,
    protection_type VARCHAR(50),
    table_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    active BOOLEAN DEFAULT TRUE
);

-- 2. Create comprehensive audit log
CREATE TABLE IF NOT EXISTS ultimate_audit_log (
    id SERIAL PRIMARY KEY,
    operation VARCHAR(20),
    table_name VARCHAR(100),
    old_data JSONB,
    new_data JSONB,
    user_name VARCHAR(100) DEFAULT CURRENT_USER,
    timestamp TIMESTAMP DEFAULT NOW(),
    client_ip VARCHAR(50)
);

-- 3. Block TRUNCATE function
CREATE OR REPLACE FUNCTION block_truncate_ultimate()
RETURNS event_trigger AS $$
BEGIN
    RAISE EXCEPTION 'TRUNCATE BLOCKED! Database protection active. Contact admin.';
END;
$$ LANGUAGE plpgsql;

-- 4. Create event trigger to block TRUNCATE
DROP EVENT TRIGGER IF EXISTS block_truncate_trigger;
CREATE EVENT TRIGGER block_truncate_trigger ON ddl_command_start
    WHEN TAG IN ('TRUNCATE TABLE')
    EXECUTE FUNCTION block_truncate_ultimate();

-- 5. Universal DELETE audit trigger function
CREATE OR REPLACE FUNCTION audit_delete_ultimate()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO ultimate_audit_log (operation, table_name, old_data, user_name, timestamp)
    VALUES ('DELETE', TG_TABLE_NAME, row_to_json(OLD)::jsonb, CURRENT_USER, NOW());
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- 6. Apply DELETE audit triggers to critical tables
DROP TRIGGER IF EXISTS audit_delete_User ON "User";
CREATE TRIGGER audit_delete_User BEFORE DELETE ON "User" FOR EACH ROW EXECUTE FUNCTION audit_delete_ultimate();

DROP TRIGGER IF EXISTS audit_delete_UserProfile ON "UserProfile";
CREATE TRIGGER audit_delete_UserProfile BEFORE DELETE ON "UserProfile" FOR EACH ROW EXECUTE FUNCTION audit_delete_ultimate();

DROP TRIGGER IF EXISTS audit_delete_Game ON "Game";
CREATE TRIGGER audit_delete_Game BEFORE DELETE ON "Game" FOR EACH ROW EXECUTE FUNCTION audit_delete_ultimate();

DROP TRIGGER IF EXISTS audit_delete_GameRequest ON "GameRequest";
CREATE TRIGGER audit_delete_GameRequest BEFORE DELETE ON "GameRequest" FOR EACH ROW EXECUTE FUNCTION audit_delete_ultimate();

DROP TRIGGER IF EXISTS audit_delete_ScheduledSession ON "ScheduledSession";
CREATE TRIGGER audit_delete_ScheduledSession BEFORE DELETE ON "ScheduledSession" FOR EACH ROW EXECUTE FUNCTION audit_delete_ultimate();

DROP TRIGGER IF EXISTS audit_delete_UserAvailability ON "UserAvailability";
CREATE TRIGGER audit_delete_UserAvailability BEFORE DELETE ON "UserAvailability" FOR EACH ROW EXECUTE FUNCTION audit_delete_ultimate();

DROP TRIGGER IF EXISTS audit_delete_UserFriends ON "UserFriends";
CREATE TRIGGER audit_delete_UserFriends BEFORE DELETE ON "UserFriends" FOR EACH ROW EXECUTE FUNCTION audit_delete_ultimate();

DROP TRIGGER IF EXISTS audit_delete_UserNotifications ON "UserNotifications";
CREATE TRIGGER audit_delete_UserNotifications BEFORE DELETE ON "UserNotifications" FOR EACH ROW EXECUTE FUNCTION audit_delete_ultimate();

DROP TRIGGER IF EXISTS audit_delete_UserGamePreference ON "UserGamePreference";
CREATE TRIGGER audit_delete_UserGamePreference BEFORE DELETE ON "UserGamePreference" FOR EACH ROW EXECUTE FUNCTION audit_delete_ultimate();

DROP TRIGGER IF EXISTS audit_delete_EmailVerification ON "EmailVerification";
CREATE TRIGGER audit_delete_EmailVerification BEFORE DELETE ON "EmailVerification" FOR EACH ROW EXECUTE FUNCTION audit_delete_ultimate();

-- 7. Revoke dangerous permissions
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM PUBLIC;

-- 8. Log protection activation
INSERT INTO db_protection_ultimate (protection_type, table_name)
VALUES ('ULTIMATE_PROTECTION', 'ALL_TABLES');

SELECT 'ULTIMATE PROTECTION DEPLOYED' as status;
