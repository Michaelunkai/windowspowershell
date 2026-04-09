-- Create a restricted app user for TovPlay
-- This user can only SELECT, INSERT, UPDATE, DELETE on tables
-- It CANNOT DROP tables or databases

-- Create the role if it doesn't exist
CREATE ROLE tovplay_app WITH LOGIN PASSWORD 'TovPlayApp2025!Secure';

-- Grant CONNECT on database
GRANT CONNECT ON DATABASE "TovPlay" TO tovplay_app;

-- Grant USAGE on schema
GRANT USAGE ON SCHEMA public TO tovplay_app;

-- Grant SELECT, INSERT, UPDATE, DELETE on all existing tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO tovplay_app;

-- Grant USAGE on all sequences (for auto-increment IDs)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO tovplay_app;

-- Make sure future tables also get these permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tovplay_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO tovplay_app;
