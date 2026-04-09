-- Create audit function
CREATE OR REPLACE FUNCTION audit_delete_operation()
RETURNS TRIGGER AS $body$
BEGIN
  INSERT INTO "DeleteAuditLog" (table_name, deleted_rows, deleted_ids, deleted_by, operation_context)
  VALUES (TG_TABLE_NAME, 1, ARRAY[COALESCE(OLD.id::TEXT, 'unknown')], current_user, 'DELETED');
  RETURN OLD;
END;
$body$ LANGUAGE plpgsql;

-- Drop and recreate triggers on all tables
DROP TRIGGER IF EXISTS audit_user_deletes ON "User";
CREATE TRIGGER audit_user_deletes BEFORE DELETE ON "User" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

DROP TRIGGER IF EXISTS audit_game_request_deletes ON "GameRequest";
CREATE TRIGGER audit_game_request_deletes BEFORE DELETE ON "GameRequest" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

DROP TRIGGER IF EXISTS audit_session_deletes ON "ScheduledSession";
CREATE TRIGGER audit_session_deletes BEFORE DELETE ON "ScheduledSession" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

DROP TRIGGER IF EXISTS audit_user_profile_deletes ON "UserProfile";
CREATE TRIGGER audit_user_profile_deletes BEFORE DELETE ON "UserProfile" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

DROP TRIGGER IF EXISTS audit_availability_deletes ON "UserAvailability";
CREATE TRIGGER audit_availability_deletes BEFORE DELETE ON "UserAvailability" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

DROP TRIGGER IF EXISTS audit_preference_deletes ON "UserGamePreference";
CREATE TRIGGER audit_preference_deletes BEFORE DELETE ON "UserGamePreference" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

DROP TRIGGER IF EXISTS audit_notification_deletes ON "UserNotifications";
CREATE TRIGGER audit_notification_deletes BEFORE DELETE ON "UserNotifications" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

DROP TRIGGER IF EXISTS audit_friends_deletes ON "UserFriends";
CREATE TRIGGER audit_friends_deletes BEFORE DELETE ON "UserFriends" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

DROP TRIGGER IF EXISTS audit_session_token_deletes ON "UserSession";
CREATE TRIGGER audit_session_token_deletes BEFORE DELETE ON "UserSession" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

DROP TRIGGER IF EXISTS audit_email_verification_deletes ON "EmailVerification";
CREATE TRIGGER audit_email_verification_deletes BEFORE DELETE ON "EmailVerification" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

DROP TRIGGER IF EXISTS audit_game_deletes ON "Game";
CREATE TRIGGER audit_game_deletes BEFORE DELETE ON "Game" FOR EACH ROW EXECUTE FUNCTION audit_delete_operation();

-- Create TRUNCATE prevention
CREATE OR REPLACE FUNCTION prevent_table_truncate()
RETURNS EVENT_TRIGGER AS $body$
BEGIN
  RAISE EXCEPTION 'TRUNCATE is BLOCKED! This database is protected against accidental deletion.';
END;
$body$ LANGUAGE plpgsql;

DROP EVENT TRIGGER IF EXISTS prevent_truncate_trigger;
CREATE EVENT TRIGGER prevent_truncate_trigger ON ddl_command_start WHEN TAG IN ('TRUNCATE') EXECUTE FUNCTION prevent_table_truncate();
