CREATE SCHEMA IF NOT exists extensions;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements with schema extensions;
CREATE EXTENSION IF NOT EXISTS uuid-ossp with schema extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto with schema extensions;
CREATE EXTENSION IF NOT EXISTS postgis with schema extensions;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch with schema extensions;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder with schema extensions;
--this one is optional if you want to use the rules based standardizer (pagc_normalize_address)
CREATE EXTENSION IF NOT EXISTS address_standardizer with schema extensions;