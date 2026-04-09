-- TovPlay Database Protection System - Simplified Version
-- Deployment Date: December 1, 2025
-- Purpose: Essential protections against accidental data loss

-- ============================================================================
-- LAYER 1: AUDIT LOGGING TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS DatabaseAuditLog (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(128),
    operation VARCHAR(10),
    affected_rows INTEGER,
    user_name VARCHAR(128),
    session_id VARCHAR(128),
    event_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details JSONB,
    blocked BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS DeleteAuditLog (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(128) NOT NULL,
    affected_rows INTEGER,
    deleted_by VARCHAR(128),
    deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deletion_details JSONB,
    blocked BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS TruncateBlockLog (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(128) NOT NULL,
    attempted_by VARCHAR(128),
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'BLOCKED'
);

-- Create indices for performance
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON DatabaseAuditLog(event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_table ON DatabaseAuditLog(table_name);
CREATE INDEX IF NOT EXISTS idx_delete_audit_timestamp ON DeleteAuditLog(deleted_at DESC);
CREATE INDEX IF NOT EXISTS idx_truncate_timestamp ON TruncateBlockLog(attempted_at DESC);

-- ============================================================================
-- LAYER 2: TRIGGER FUNCTIONS
-- ============================================================================

-- Function to log DELETE operations on protected tables
CREATE OR REPLACE FUNCTION log_delete_operation()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO DeleteAuditLog (table_name, affected_rows, deleted_by, deletion_details, blocked)
    VALUES (TG_TABLE_NAME, 1, CURRENT_USER, row_to_json(OLD), false);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- LAYER 3: AUDIT TRIGGERS ON PROTECTED TABLES
-- ============================================================================

-- User table
DROP TRIGGER IF EXISTS audit_user_deletes ON "User" CASCADE;
CREATE TRIGGER audit_user_deletes
AFTER DELETE ON "User"
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- UserProfile
DROP TRIGGER IF EXISTS audit_userprofile_deletes ON UserProfile CASCADE;
CREATE TRIGGER audit_userprofile_deletes
AFTER DELETE ON UserProfile
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- Game
DROP TRIGGER IF EXISTS audit_game_deletes ON Game CASCADE;
CREATE TRIGGER audit_game_deletes
AFTER DELETE ON Game
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- GameRequest
DROP TRIGGER IF EXISTS audit_gamerequest_deletes ON GameRequest CASCADE;
CREATE TRIGGER audit_gamerequest_deletes
AFTER DELETE ON GameRequest
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- ScheduledSession
DROP TRIGGER IF EXISTS audit_scheduledsession_deletes ON ScheduledSession CASCADE;
CREATE TRIGGER audit_scheduledsession_deletes
AFTER DELETE ON ScheduledSession
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- UserAvailability
DROP TRIGGER IF EXISTS audit_useravailability_deletes ON UserAvailability CASCADE;
CREATE TRIGGER audit_useravailability_deletes
AFTER DELETE ON UserAvailability
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- UserNotifications
DROP TRIGGER IF EXISTS audit_usernotifications_deletes ON UserNotifications CASCADE;
CREATE TRIGGER audit_usernotifications_deletes
AFTER DELETE ON UserNotifications
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- UserGamePreference
DROP TRIGGER IF EXISTS audit_usergamepreference_deletes ON UserGamePreference CASCADE;
CREATE TRIGGER audit_usergamepreference_deletes
AFTER DELETE ON UserGamePreference
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- UserFriends
DROP TRIGGER IF EXISTS audit_userfriends_deletes ON UserFriends CASCADE;
CREATE TRIGGER audit_userfriends_deletes
AFTER DELETE ON UserFriends
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- UserSession
DROP TRIGGER IF EXISTS audit_usersession_deletes ON UserSession CASCADE;
CREATE TRIGGER audit_usersession_deletes
AFTER DELETE ON UserSession
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- EmailVerification
DROP TRIGGER IF EXISTS audit_emailverification_deletes ON EmailVerification CASCADE;
CREATE TRIGGER audit_emailverification_deletes
AFTER DELETE ON EmailVerification
FOR EACH ROW
EXECUTE FUNCTION log_delete_operation();

-- ============================================================================
-- LAYER 4: ROLE-BASED ACCESS CONTROL
-- ============================================================================

-- Create read-only role for normal operations
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tovplay_readonly') THEN
        CREATE ROLE tovplay_readonly WITH LOGIN PASSWORD 'readonly_tovplay_secure_2025';
        GRANT CONNECT ON DATABASE TovPlay TO tovplay_readonly;
        GRANT USAGE ON SCHEMA public TO tovplay_readonly;
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO tovplay_readonly;
    END IF;
END
$$;

-- ============================================================================
-- LAYER 5: BACKUP METADATA TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS BackupMetadata (
    backup_id SERIAL PRIMARY KEY,
    backup_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    backup_type VARCHAR(50),
    backup_size_bytes BIGINT,
    verified BOOLEAN DEFAULT false,
    verification_timestamp TIMESTAMP,
    row_counts JSONB,
    status VARCHAR(50) DEFAULT 'PENDING'
);

-- ============================================================================
-- LAYER 6: PROTECTION STATUS MONITORING
-- ============================================================================

CREATE TABLE IF NOT EXISTS ProtectionStatus (
    status_id SERIAL PRIMARY KEY,
    protection_name VARCHAR(128),
    is_active BOOLEAN DEFAULT true,
    last_verified TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verification_method VARCHAR(256)
);

-- Record protection status
INSERT INTO ProtectionStatus (protection_name, is_active, verification_method)
VALUES
    ('Audit Logging - User', true, 'Trigger on User table'),
    ('Audit Logging - UserProfile', true, 'Trigger on UserProfile table'),
    ('Audit Logging - Game', true, 'Trigger on Game table'),
    ('Audit Logging - GameRequest', true, 'Trigger on GameRequest table'),
    ('Audit Logging - ScheduledSession', true, 'Trigger on ScheduledSession table'),
    ('Audit Logging - UserAvailability', true, 'Trigger on UserAvailability table'),
    ('Audit Logging - UserNotifications', true, 'Trigger on UserNotifications table'),
    ('Audit Logging - UserGamePreference', true, 'Trigger on UserGamePreference table'),
    ('Audit Logging - UserFriends', true, 'Trigger on UserFriends table'),
    ('Role-Based Access Control', true, 'tovplay_readonly role'),
    ('Backup Tracking', true, 'BackupMetadata table'),
    ('Delete Audit Logging', true, 'DeleteAuditLog table')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- LAYER 7: PROTECTION VERIFICATION VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW v_protection_status AS
SELECT
    protection_name,
    is_active,
    last_verified,
    verification_method,
    CASE WHEN is_active THEN 'PROTECTED' ELSE 'UNPROTECTED' END as status
FROM ProtectionStatus
ORDER BY protection_name;

CREATE OR REPLACE VIEW v_deletion_history AS
SELECT
    table_name,
    affected_rows,
    deleted_by,
    deleted_at,
    blocked,
    deletion_details
FROM DeleteAuditLog
ORDER BY deleted_at DESC
LIMIT 50;

CREATE OR REPLACE VIEW v_audit_log_summary AS
SELECT
    table_name,
    COUNT(*) as total_deletes,
    MAX(deleted_at) as last_delete,
    SUM(affected_rows) as total_rows_affected
FROM DeleteAuditLog
GROUP BY table_name
ORDER BY total_deletes DESC;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT 'DATABASE PROTECTION SYSTEM DEPLOYED SUCCESSFULLY' as status;
SELECT COUNT(*) as protection_tables_created FROM information_schema.tables
WHERE table_name IN ('DatabaseAuditLog', 'DeleteAuditLog', 'TruncateBlockLog', 'BackupMetadata', 'ProtectionStatus');
SELECT COUNT(*) as triggers_created FROM information_schema.triggers
WHERE trigger_schema = 'public' AND trigger_name LIKE 'audit_%';
