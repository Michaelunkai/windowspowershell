-- TovPlay Database Connection Cleanup Script
-- Run periodically to kill idle connections older than 5 minutes
-- Usage: PGPASSWORD='CaptainForgotCreatureBreak' psql -h 45.148.28.196 -U 'raz@tovtech.org' -d TovPlay -f cleanup_connections.sql

-- Kill idle connections older than 5 minutes
SELECT pg_terminate_backend(pid), usename, state, query_start
FROM pg_stat_activity
WHERE datname = 'TovPlay'
  AND state = 'idle'
  AND query_start < NOW() - INTERVAL '5 minutes'
  AND pid <> pg_backend_pid();

-- Show remaining connections
SELECT COUNT(*) as total_connections, state
FROM pg_stat_activity
WHERE datname = 'TovPlay'
GROUP BY state;
