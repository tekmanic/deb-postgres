-- Reference extension set for deb-postgres.
-- Apply to a database with: psql -U <user> -d <db> -f extensions.sql
--
-- Note: pg_cron is cluster-wide and must be created in the database named by
-- cron.database_name (default here: 'postgres'), not per-database:
--   psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements with schema extensions;
CREATE EXTENSION IF NOT EXISTS uuid-ossp with schema extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto with schema extensions;
CREATE EXTENSION IF NOT EXISTS postgis with schema extensions;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch with schema extensions;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder with schema extensions;
--this one is optional if you want to use the rules based standardizer (pagc_normalize_address)
CREATE EXTENSION IF NOT EXISTS address_standardizer with schema extensions;
CREATE EXTENSION IF NOT EXISTS vector with schema extensions;
CREATE EXTENSION IF NOT EXISTS pgjwt with schema extensions;
CREATE EXTENSION IF NOT EXISTS pg_net with schema extensions;
CREATE EXTENSION IF NOT EXISTS pgmq with schema extensions;
CREATE EXTENSION IF NOT EXISTS pgrouting with schema extensions;
CREATE EXTENSION IF NOT EXISTS pgtap with schema extensions;
