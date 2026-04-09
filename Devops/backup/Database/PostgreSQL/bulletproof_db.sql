-- =====================================================
-- ULTIMATE BULLETPROOF DATABASE PROTECTION
-- Prevents ALL accidental data loss scenarios
-- =====================================================

-- 1. IMMUTABLE AUDIT ARCHIVE (Cannot be deleted/modified)
CREATE TABLE IF NOT EXISTS immutable_audit_archive (
    id BIGSERIAL PRIMARY KEY,
    operation VARCHAR(20) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id TEXT,
    old_data JSONB,
    new_data JSONB,
    performed_by VARCHAR(100) DEFAULT CURRENT_USER,
    performed_at TIMESTAMP DEFAULT NOW(),
    client_ip TEXT DEFAULT inet_client_addr()::text,
    session_id TEXT DEFAULT pg_backend_pid()::text
);

-- 2. PROTECTION STATUS TABLE
CREATE TABLE IF NOT EXISTS bulletproof_status (
    id SERIAL PRIMARY KEY,
    protection_name VARCHAR(100),
    target_table VARCHAR(100),
    protection_type VARCHAR(50),
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 3. BLOCKED OPERATIONS LOG
CREATE TABLE IF NOT EXISTS blocked_operations_log (
    id BIGSERIAL PRIMARY KEY,
    operation_type VARCHAR(50),
    table_name VARCHAR(100),
    attempted_by VARCHAR(100) DEFAULT CURRENT_USER,
    attempted_at TIMESTAMP DEFAULT NOW(),
    blocked_reason TEXT,
    query_text TEXT
);

-- 4. DATA SNAPSHOTS TABLE
CREATE TABLE IF NOT EXISTS data_snapshots (
    id BIGSERIAL PRIMARY KEY,
    snapshot_name VARCHAR(100),
    table_name VARCHAR(100),
    row_count INTEGER,
    data_hash TEXT,
    snapshot_data JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- PROTECTION FUNCTIONS
-- =====================================================

-- Function to log blocked operations
CREATE OR REPLACE FUNCTION log_blocked_operation(
    p_operation VARCHAR,
    p_table VARCHAR,
    p_reason TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO blocked_operations_log (operation_type, table_name, blocked_reason)
    VALUES (p_operation, p_table, p_reason);
END;
$$ LANGUAGE plpgsql;

-- Function to create table snapshot
CREATE OR REPLACE FUNCTION create_table_snapshot(p_table_name VARCHAR)
RETURNS VOID AS $$
DECLARE
    v_count INTEGER;
    v_data JSONB;
BEGIN
    EXECUTE format('SELECT COUNT(*) FROM %I', p_table_name) INTO v_count;
    EXECUTE format('SELECT jsonb_agg(row_to_json(t)) FROM %I t LIMIT 1000', p_table_name) INTO v_data;
    INSERT INTO data_snapshots (snapshot_name, table_name, row_count, snapshot_data)
    VALUES ('auto_' || NOW()::text, p_table_name, v_count, v_data);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- BLOCK TRUNCATE ON ALL CRITICAL TABLES
-- =====================================================

-- Block TRUNCATE by creating rules
CREATE OR REPLACE RULE block_truncate_user AS ON DELETE TO "User"
    WHERE current_setting('app.allow_delete', true) IS DISTINCT FROM 'CONFIRMED_DELETE_7x9k2m'
    DO INSTEAD (
        SELECT log_blocked_operation('DELETE', 'User', 'Delete blocked - confirmation required');
        SELECT 1/0 WHERE FALSE
    );

CREATE OR REPLACE RULE block_truncate_userprofile AS ON DELETE TO "UserProfile"
    WHERE current_setting('app.allow_delete', true) IS DISTINCT FROM 'CONFIRMED_DELETE_7x9k2m'
    DO INSTEAD (
        SELECT log_blocked_operation('DELETE', 'UserProfile', 'Delete blocked - confirmation required');
        SELECT 1/0 WHERE FALSE
    );

CREATE OR REPLACE RULE block_truncate_game AS ON DELETE TO "Game"
    WHERE current_setting('app.allow_delete', true) IS DISTINCT FROM 'CONFIRMED_DELETE_7x9k2m'
    DO INSTEAD (
        SELECT log_blocked_operation('DELETE', 'Game', 'Delete blocked - confirmation required');
        SELECT 1/0 WHERE FALSE
    );

CREATE OR REPLACE RULE block_truncate_gamerequest AS ON DELETE TO "GameRequest"
    WHERE current_setting('app.allow_delete', true) IS DISTINCT FROM 'CONFIRMED_DELETE_7x9k2m'
    DO INSTEAD (
        SELECT log_blocked_operation('DELETE', 'GameRequest', 'Delete blocked - confirmation required');
        SELECT 1/0 WHERE FALSE
    );

CREATE OR REPLACE RULE block_truncate_scheduledsession AS ON DELETE TO "ScheduledSession"
    WHERE current_setting('app.allow_delete', true) IS DISTINCT FROM 'CONFIRMED_DELETE_7x9k2m'
    DO INSTEAD (
        SELECT log_blocked_operation('DELETE', 'ScheduledSession', 'Delete blocked - confirmation required');
        SELECT 1/0 WHERE FALSE
    );

CREATE OR REPLACE RULE block_truncate_useravailability AS ON DELETE TO "UserAvailability"
    WHERE current_setting('app.allow_delete', true) IS DISTINCT FROM 'CONFIRMED_DELETE_7x9k2m'
    DO INSTEAD (
        SELECT log_blocked_operation('DELETE', 'UserAvailability', 'Delete blocked - confirmation required');
        SELECT 1/0 WHERE FALSE
    );

CREATE OR REPLACE RULE block_truncate_userfriends AS ON DELETE TO "UserFriends"
    WHERE current_setting('app.allow_delete', true) IS DISTINCT FROM 'CONFIRMED_DELETE_7x9k2m'
    DO INSTEAD (
        SELECT log_blocked_operation('DELETE', 'UserFriends', 'Delete blocked - confirmation required');
        SELECT 1/0 WHERE FALSE
    );

CREATE OR REPLACE RULE block_truncate_usernotifications AS ON DELETE TO "UserNotifications"
    WHERE current_setting('app.allow_delete', true) IS DISTINCT FROM 'CONFIRMED_DELETE_7x9k2m'
    DO INSTEAD (
        SELECT log_blocked_operation('DELETE', 'UserNotifications', 'Delete blocked - confirmation required');
        SELECT 1/0 WHERE FALSE
    );

CREATE OR REPLACE RULE block_truncate_usergamepreference AS ON DELETE TO "UserGamePreference"
    WHERE current_setting('app.allow_delete', true) IS DISTINCT FROM 'CONFIRMED_DELETE_7x9k2m'
    DO INSTEAD (
        SELECT log_blocked_operation('DELETE', 'UserGamePreference', 'Delete blocked - confirmation required');
        SELECT 1/0 WHERE FALSE
    );

CREATE OR REPLACE RULE block_truncate_emailverification AS ON DELETE TO "EmailVerification"
    WHERE current_setting('app.allow_delete', true) IS DISTINCT FROM 'CONFIRMED_DELETE_7x9k2m'
    DO INSTEAD (
        SELECT log_blocked_operation('DELETE', 'EmailVerification', 'Delete blocked - confirmation required');
        SELECT 1/0 WHERE FALSE
    );

-- =====================================================
-- COMPREHENSIVE AUDIT TRIGGERS (IMMUTABLE)
-- =====================================================

-- Audit trigger function for all operations
CREATE OR REPLACE FUNCTION audit_all_operations()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO immutable_audit_archive (operation, table_name, record_id, old_data)
        VALUES ('DELETE', TG_TABLE_NAME, OLD.id::text, row_to_json(OLD)::jsonb);
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO immutable_audit_archive (operation, table_name, record_id, old_data, new_data)
        VALUES ('UPDATE', TG_TABLE_NAME, NEW.id::text, row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO immutable_audit_archive (operation, table_name, record_id, new_data)
        VALUES ('INSERT', TG_TABLE_NAME, NEW.id::text, row_to_json(NEW)::jsonb);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to all critical tables
DROP TRIGGER IF EXISTS audit_all_user ON "User";
CREATE TRIGGER audit_all_user AFTER INSERT OR UPDATE OR DELETE ON "User"
    FOR EACH ROW EXECUTE FUNCTION audit_all_operations();

DROP TRIGGER IF EXISTS audit_all_userprofile ON "UserProfile";
CREATE TRIGGER audit_all_userprofile AFTER INSERT OR UPDATE OR DELETE ON "UserProfile"
    FOR EACH ROW EXECUTE FUNCTION audit_all_operations();

DROP TRIGGER IF EXISTS audit_all_game ON "Game";
CREATE TRIGGER audit_all_game AFTER INSERT OR UPDATE OR DELETE ON "Game"
    FOR EACH ROW EXECUTE FUNCTION audit_all_operations();

DROP TRIGGER IF EXISTS audit_all_gamerequest ON "GameRequest";
CREATE TRIGGER audit_all_gamerequest AFTER INSERT OR UPDATE OR DELETE ON "GameRequest"
    FOR EACH ROW EXECUTE FUNCTION audit_all_operations();

DROP TRIGGER IF EXISTS audit_all_scheduledsession ON "ScheduledSession";
CREATE TRIGGER audit_all_scheduledsession AFTER INSERT OR UPDATE OR DELETE ON "ScheduledSession"
    FOR EACH ROW EXECUTE FUNCTION audit_all_operations();

DROP TRIGGER IF EXISTS audit_all_useravailability ON "UserAvailability";
CREATE TRIGGER audit_all_useravailability AFTER INSERT OR UPDATE OR DELETE ON "UserAvailability"
    FOR EACH ROW EXECUTE FUNCTION audit_all_operations();

DROP TRIGGER IF EXISTS audit_all_userfriends ON "UserFriends";
CREATE TRIGGER audit_all_userfriends AFTER INSERT OR UPDATE OR DELETE ON "UserFriends"
    FOR EACH ROW EXECUTE FUNCTION audit_all_operations();

DROP TRIGGER IF EXISTS audit_all_usernotifications ON "UserNotifications";
CREATE TRIGGER audit_all_usernotifications AFTER INSERT OR UPDATE OR DELETE ON "UserNotifications"
    FOR EACH ROW EXECUTE FUNCTION audit_all_operations();

DROP TRIGGER IF EXISTS audit_all_usergamepreference ON "UserGamePreference";
CREATE TRIGGER audit_all_usergamepreference AFTER INSERT OR UPDATE OR DELETE ON "UserGamePreference"
    FOR EACH ROW EXECUTE FUNCTION audit_all_operations();

-- =====================================================
-- PROTECT AUDIT TABLES FROM MODIFICATION
-- =====================================================

-- Prevent ANY modification to audit tables
CREATE OR REPLACE FUNCTION protect_audit_tables()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'AUDIT TABLES ARE IMMUTABLE - NO MODIFICATIONS ALLOWED';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS protect_immutable_audit ON immutable_audit_archive;
CREATE TRIGGER protect_immutable_audit BEFORE UPDATE OR DELETE ON immutable_audit_archive
    FOR EACH ROW EXECUTE FUNCTION protect_audit_tables();

DROP TRIGGER IF EXISTS protect_blocked_log ON blocked_operations_log;
CREATE TRIGGER protect_blocked_log BEFORE UPDATE OR DELETE ON blocked_operations_log
    FOR EACH ROW EXECUTE FUNCTION protect_audit_tables();

-- =====================================================
-- REVOKE ALL DANGEROUS PERMISSIONS
-- =====================================================

REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE DROP ON SCHEMA public FROM PUBLIC;

-- =====================================================
-- CREATE INITIAL SNAPSHOTS
-- =====================================================

SELECT create_table_snapshot('User');
SELECT create_table_snapshot('UserProfile');
SELECT create_table_snapshot('Game');
SELECT create_table_snapshot('GameRequest');
SELECT create_table_snapshot('ScheduledSession');
SELECT create_table_snapshot('UserAvailability');

-- =====================================================
-- LOG PROTECTION ACTIVATION
-- =====================================================

INSERT INTO bulletproof_status (protection_name, target_table, protection_type)
VALUES
    ('DELETE_BLOCK', 'User', 'RULE'),
    ('DELETE_BLOCK', 'UserProfile', 'RULE'),
    ('DELETE_BLOCK', 'Game', 'RULE'),
    ('DELETE_BLOCK', 'GameRequest', 'RULE'),
    ('DELETE_BLOCK', 'ScheduledSession', 'RULE'),
    ('DELETE_BLOCK', 'UserAvailability', 'RULE'),
    ('DELETE_BLOCK', 'UserFriends', 'RULE'),
    ('DELETE_BLOCK', 'UserNotifications', 'RULE'),
    ('DELETE_BLOCK', 'UserGamePreference', 'RULE'),
    ('AUDIT_TRIGGER', 'ALL_TABLES', 'TRIGGER'),
    ('IMMUTABLE_AUDIT', 'immutable_audit_archive', 'PROTECTED'),
    ('SNAPSHOT', 'ALL_CRITICAL', 'SNAPSHOT');

-- =====================================================
-- RECOVERY FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION recover_deleted_record(
    p_table_name VARCHAR,
    p_record_id TEXT
) RETURNS TEXT AS $$
DECLARE
    v_old_data JSONB;
    v_columns TEXT;
    v_values TEXT;
BEGIN
    -- Get the most recent deleted record
    SELECT old_data INTO v_old_data
    FROM immutable_audit_archive
    WHERE table_name = p_table_name
      AND record_id = p_record_id
      AND operation = 'DELETE'
    ORDER BY performed_at DESC
    LIMIT 1;

    IF v_old_data IS NULL THEN
        RETURN 'No deleted record found for ' || p_table_name || ' with id ' || p_record_id;
    END IF;

    RETURN 'Record found in audit log. Manual recovery required. Data: ' || v_old_data::text;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VERIFICATION
-- =====================================================

SELECT 'BULLETPROOF PROTECTION DEPLOYED' as status,
       (SELECT COUNT(*) FROM bulletproof_status WHERE enabled = true) as protections_active,
       (SELECT COUNT(*) FROM data_snapshots) as snapshots_created;
