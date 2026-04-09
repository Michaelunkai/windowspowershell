-- TovPlay Critical Protection: DROP DATABASE Prevention
-- This MUST be run on the 'postgres' database (not TovPlay)
-- Executed as: PGPASSWORD='...' psql -h 45.148.28.196 -U 'raz@tovtech.org' -d postgres < drop_database_protection.sql

-- 1. Create event trigger function to block DROP DATABASE
CREATE OR REPLACE FUNCTION prevent_drop_database()
RETURNS event_trigger AS $$
DECLARE
    obj record;
BEGIN
    FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        IF obj.object_type = 'database' THEN
            RAISE EXCEPTION 'CRITICAL SECURITY: DROP DATABASE BLOCKED. Database: %. User: %. IP: %. Contact Michael Fedorovsky immediately.',
                obj.object_identity, current_user, inet_client_addr();
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 2. Create event trigger for DROP DATABASE attempts
DROP EVENT TRIGGER IF EXISTS block_drop_database CASCADE;
CREATE EVENT TRIGGER block_drop_database
    ON sql_drop
    EXECUTE FUNCTION prevent_drop_database();

-- 3. Make event trigger permanent and enabled
ALTER EVENT TRIGGER block_drop_database ENABLE;

-- 4. Verify trigger exists
SELECT evtname, evtenabled FROM pg_event_trigger WHERE evtname = 'block_drop_database';
