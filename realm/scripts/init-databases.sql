-- Create additional database for the central service.
-- This script runs as part of PostgreSQL's docker-entrypoint-initdb.d
-- (only on first init when postgres_data volume is empty).
--
-- The POSTGRES_USER (macula_realm) already exists and owns macula_realm_prod.
-- We create the central database and grant access to the same user.

SELECT 'CREATE DATABASE macula_central_prod'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'macula_central_prod')\gexec

GRANT ALL PRIVILEGES ON DATABASE macula_central_prod TO macula_realm;
