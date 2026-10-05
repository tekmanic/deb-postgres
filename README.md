# deb-postgres

PostgreSQL 18 database image based on Debian Trixie Slim with useful extensions added.

The inspiration for this image comes from [frodenas postgres](https://github.com/frodenas/docker-postgresql) but updated for PostgreSQL 18 (installed from the official [PGDG](https://wiki.postgresql.org/wiki/Apt) apt repository) and Debian Trixie.

## Overview
This repository is designed for creating developer-friendly PostgreSQL environments. It allows you to run multiple isolated PostgreSQL instances in parallel without conflicts, making it ideal for development and testing.

This is intended to be a developer friendly postgres; if a production image is required, we suggest [Supabase](https://github.com/supabase/postgres).

## Key Features
- **Modern Base:** Upgraded to Debian Trixie (13) for the latest security and package updates.
- **PostgreSQL 18:** Installed from the PGDG apt repository — prebuilt server, no source build of PostgreSQL itself.
- **Extensions:** 8 extensions included — 5 via PGDG apt (postgis, pgvector, pg_cron, pgrouting, pgtap) and 3 built from pinned, checksum-verified source (pgjwt, pg_net, pgmq).
- **Security Hardened:** `DEBIAN_FRONTEND=noninteractive`, `--no-install-recommends`, apt cleanup, and setuid/setgid bit stripping to reduce attack surface.
- **First-Run Init:** On first boot the image initializes the data directory and creates the user, database, and requested extensions from environment variables.

## Usage

To run a new instance:

```bash
docker run -d \
    --name deb-postgres \
    -p 5433:5432 \
    -e POSTGRES_USER=myuser \
    -e POSTGRES_PASSWORD=mypassword \
    -e POSTGRES_DB=mydb \
    -e POSTGRES_EXTENSIONS='postgis vector pg_cron pgjwt pg_net pgmq pgrouting pgtap' \
    -v pg-data:/var/lib/postgresql/data \
    deb-postgres:latest
```

### Configuration Environment Variables
| Variable | Description | Default |
|-----------|-------------|---------|
| `POSTGRES_USER` | Username for the created superuser role | `pgadmin` |
| `POSTGRES_PASSWORD` | Password for the created role (random if unset) | *(random)* |
| `POSTGRES_DB` | Database to create (owned by `POSTGRES_USER`) | *(none)* |
| `POSTGRES_EXTENSIONS` | Space-separated list of extensions to create in `POSTGRES_DB` | *(none)* |
| `PG_VERSION` | Major PostgreSQL version (used to locate server binaries) | `18` |

### Extensions
| Extension | Version | Source | Link |
|-----------|---------|--------|------|
| postgis | 3.6.4 | PGDG apt | [postgis.net](https://postgis.net/) |
| pgvector | 0.8.6 | PGDG apt | [github.com/pgvector/pgvector](https://github.com/pgvector/pgvector) |
| pg_cron | 1.6.8 | PGDG apt | [github.com/citusdata/pg_cron](https://github.com/citusdata/pg_cron) |
| pgrouting | 4.0.1 | PGDG apt | [pgrouting.org](https://pgrouting.org/) |
| pgtap | 1.3.4 | PGDG apt | [pgtap.org](https://pgtap.org/) |
| pgjwt | f3d82fd (commit) | source (pinned) | [github.com/michelp/pgjwt](https://github.com/michelp/pgjwt) |
| pg_net | 0.20.5 | source (pinned) | [github.com/supabase/pg_net](https://github.com/supabase/pg_net) |
| pgmq | 1.13.0 | source (pinned) | [github.com/pgmq/pgmq](https://github.com/pgmq/pgmq) |

### Notes
- **pg_cron** requires `pg_cron` in `shared_preload_libraries` and can only be created in the database named by `cron.database_name`. Both are preconfigured (`shared_preload_libraries = 'pg_stat_statements, pg_cron, pg_net'`, `cron.database_name = 'postgres'`); first-run init creates it in the `postgres` database automatically when listed in `POSTGRES_EXTENSIONS`.
- **Data directory:** `/var/lib/postgresql/data` — mount a volume there to persist data across container recreation.
- **Port:** 5432 (mapped to 5433 in the example above).
- **plv8** was removed in this release: it is not in the requested extension set and is not available in the PGDG trixie repository.
- **pgml (postgresml)** is not included in this release: the latest upstream release (v2.10.0, Jan 2025) is built on pgrx 0.12.9, which only supports up to PostgreSQL 17, and no prebuilt binaries are published. It can be re-added once upstream supports PG18 (see `TODO.md`).
- A `template_postgis` template database (with postgis preinstalled) is created on first run; use it with `CREATE DATABASE mydb TEMPLATE template_postgis;`.
- `scripts/extensions.sql` is a reference script listing the full extension set for manual application.

---
If you appreciate this work, please consider buying me a beer! :D
[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/donate?hosted_button_id=KKQ4LNMEDVUPN)
