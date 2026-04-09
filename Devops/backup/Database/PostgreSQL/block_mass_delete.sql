-- MASS DELETE PROTECTION: Block deletion of more than 5 rows at once
-- This prevents accidental "DELETE FROM table" without WHERE clause
-- Contact Michael for special permission to delete more than 5 rows

CREATE OR REPLACE FUNCTION block_mass_delete()
RETURNS TRIGGER AS $func$
DECLARE
    row_count INTEGER;
BEGIN
    -- Count how many rows will be deleted
    GET DIAGNOSTICS row_count = ROW_COUNT;

    -- If deleting more than 5 rows, block it
    IF row_count > 5 THEN
        RAISE EXCEPTION 'MASS DELETE BLOCKED: Attempting to delete % rows from %. Contact Michael for special permission.', row_count, TG_TABLE_NAME;
    END IF;

    RETURN OLD;
END;
$func$ LANGUAGE plpgsql;

-- Alternative: Block DELETE without WHERE clause using statement-level trigger
CREATE OR REPLACE FUNCTION audit_and_limit_delete()
RETURNS TRIGGER AS $func$
BEGIN
    -- Log the deletion attempt
    INSERT INTO "DeleteAuditLog" (table_name, operation, old_data, deleted_by, deleted_at, row_count, client_info)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        row_to_json(OLD)::text,
        current_user,
        NOW(),
        1,
        inet_client_addr()::text
    );
    RETURN OLD;
END;
$func$ LANGUAGE plpgsql;

SELECT 'MASS DELETE AUDIT FUNCTION CREATED' as status;
