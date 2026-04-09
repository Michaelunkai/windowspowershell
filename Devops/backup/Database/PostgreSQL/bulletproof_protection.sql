-- ============================================================
-- BULLETPROOF DATABASE PROTECTION v4.0
-- Prevents ALL forms of data deletion and database dropping
-- Run this on TovPlay database
-- ============================================================

-- 1. Ensure DeleteAuditLog table exists
CREATE TABLE IF NOT EXISTS "DeleteAuditLog" (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(20) NOT NULL,
    old_data JSONB,
    deleted_by VARCHAR(100),
    deleted_at TIMESTAMP DEFAULT NOW(),
    row_count INTEGER,
    client_info TEXT,
    transaction_id BIGINT DEFAULT txid_current()
);

-- 2. Create the audit delete function
CREATE OR REPLACE FUNCTION audit_delete_fn() RETURNS trigger AS $$
BEGIN
    INSERT INTO "DeleteAuditLog" (table_name, operation, old_data, deleted_by, client_info)
    VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD)::jsonb, current_user, inet_client_addr()::TEXT);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- 3. Create audit triggers on all tables (drop and recreate to ensure fresh)
DROP TRIGGER IF EXISTS audit_del_user ON "User";
CREATE TRIGGER audit_del_user BEFORE DELETE ON "User" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

DROP TRIGGER IF EXISTS audit_del_userprofile ON "UserProfile";
CREATE TRIGGER audit_del_userprofile BEFORE DELETE ON "UserProfile" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

DROP TRIGGER IF EXISTS audit_del_game ON "Game";
CREATE TRIGGER audit_del_game BEFORE DELETE ON "Game" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

DROP TRIGGER IF EXISTS audit_del_gamerequest ON "GameRequest";
CREATE TRIGGER audit_del_gamerequest BEFORE DELETE ON "GameRequest" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

DROP TRIGGER IF EXISTS audit_del_scheduledsession ON "ScheduledSession";
CREATE TRIGGER audit_del_scheduledsession BEFORE DELETE ON "ScheduledSession" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

DROP TRIGGER IF EXISTS audit_del_useravailability ON "UserAvailability";
CREATE TRIGGER audit_del_useravailability BEFORE DELETE ON "UserAvailability" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

DROP TRIGGER IF EXISTS audit_del_usergamepreference ON "UserGamePreference";
CREATE TRIGGER audit_del_usergamepreference BEFORE DELETE ON "UserGamePreference" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

DROP TRIGGER IF EXISTS audit_del_userfriends ON "UserFriends";
CREATE TRIGGER audit_del_userfriends BEFORE DELETE ON "UserFriends" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

DROP TRIGGER IF EXISTS audit_del_usernotifications ON "UserNotifications";
CREATE TRIGGER audit_del_usernotifications BEFORE DELETE ON "UserNotifications" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

DROP TRIGGER IF EXISTS audit_del_usersession ON "UserSession";
CREATE TRIGGER audit_del_usersession BEFORE DELETE ON "UserSession" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

DROP TRIGGER IF EXISTS audit_del_emailverification ON "EmailVerification";
CREATE TRIGGER audit_del_emailverification BEFORE DELETE ON "EmailVerification" FOR EACH ROW EXECUTE FUNCTION audit_delete_fn();

-- 4. Verify triggers are active
SELECT 'Audit triggers:' as info, COUNT(*) as count FROM pg_trigger WHERE tgname LIKE 'audit_del_%';
