-- TRUNCATE PROTECTION: Block all TRUNCATE operations
-- Only superuser can bypass this protection
-- Contact Michael for special permission

CREATE OR REPLACE FUNCTION block_truncate()
RETURNS TRIGGER AS $func$
BEGIN
    RAISE EXCEPTION 'TRUNCATE BLOCKED: Contact Michael for special permission. Table: %', TG_TABLE_NAME;
    RETURN NULL;
END;
$func$ LANGUAGE plpgsql;

-- Apply triggers to all critical tables
DROP TRIGGER IF EXISTS block_truncate_user ON "User";
CREATE TRIGGER block_truncate_user BEFORE TRUNCATE ON "User" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_game ON "Game";
CREATE TRIGGER block_truncate_game BEFORE TRUNCATE ON "Game" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_gamerequest ON "GameRequest";
CREATE TRIGGER block_truncate_gamerequest BEFORE TRUNCATE ON "GameRequest" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_session ON "ScheduledSession";
CREATE TRIGGER block_truncate_session BEFORE TRUNCATE ON "ScheduledSession" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_profile ON "UserProfile";
CREATE TRIGGER block_truncate_profile BEFORE TRUNCATE ON "UserProfile" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_availability ON "UserAvailability";
CREATE TRIGGER block_truncate_availability BEFORE TRUNCATE ON "UserAvailability" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_friends ON "UserFriends";
CREATE TRIGGER block_truncate_friends BEFORE TRUNCATE ON "UserFriends" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_gamepref ON "UserGamePreference";
CREATE TRIGGER block_truncate_gamepref BEFORE TRUNCATE ON "UserGamePreference" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

DROP TRIGGER IF EXISTS block_truncate_notifications ON "UserNotifications";
CREATE TRIGGER block_truncate_notifications BEFORE TRUNCATE ON "UserNotifications" FOR EACH STATEMENT EXECUTE FUNCTION block_truncate();

SELECT 'TRUNCATE PROTECTION INSTALLED ON 9 CRITICAL TABLES' as status;
