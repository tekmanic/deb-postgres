# Project Specification: deb-postgres

## 1. Vision & Goals (B - Background)
`deb-postgres` is a Docker image providing a developer-friendly PostgreSQL environment with a curated set of extensions preinstalled. Unlike stock PostgreSQL images, it ships with spatial (PostGIS), vector (pgvector), queue (pgmq), scheduling (pg_cron), JWT (pgjwt), and HTTP (pg_net) capabilities out of the box, enabling "single-container" database deployments for development, testing, and ephemeral environments.

### Primary Objectives
- **Zero-Config Startup:** Provide a fully functional PostgreSQL 18 instance with extensions in one container.
- **Isolation:** Allow multiple parallel instances on a single host without port or data conflicts.
- **Reproducibility:** Every source-built extension is pinned to an exact tag/commit and verified with sha256.
- **Security Hardening:** Modern base image and container security best practices.

---

## 2. System Architecture (M - Model)

### Component Stack
- **OS:** Debian Trixie (13) Slim
- **Database:** PostgreSQL 18 (PGDG apt, prebuilt)
- **Extensions (apt):** postgis 3.6.x, pgvector 0.8.x, pg_cron 1.6.x, pgrouting 4.0.x, pgtap 1.3.x
- **Extensions (source, pinned):** pgjwt (commit-pinned), pg_net 0.20.5, pgmq 1.13.0
- **Process Model:** `run.sh` entrypoint (single service — nitro init is not needed; see TODO.md)

### Data Flow & Persistence
- **Ephemeral Layer:** Server binaries, extensions, and configuration live in the image.
- **Persistent Layer:** `/var/lib/postgresql/data` is the intended volume mount point, preserving the cluster across container recreation.
- **Initialization:** On first boot (`/.firstrun` present), `init-postgres.sh` runs `initdb`, starts the server, creates the user/database/extensions from environment variables, installs the configuration files, and removes the first-run marker.

---

## 3. Implementation Details (A - Analysis)

### Environment Configuration
The system is configured via the following primary environment variables:
- `POSTGRES_USER` / `POSTGRES_PASSWORD`: credentials for the created superuser role.
- `POSTGRES_DB`: database to create, owned by the role.
- `POSTGRES_EXTENSIONS`: space-separated list of extensions to create in `POSTGRES_DB` (`pg_cron` is special-cased into the `postgres` database, as it is cluster-wide).

### Build Strategy
- **Multi-stage Dockerfile:** a `builder` stage compiles the source extensions against `postgresql-server-dev-18` headers; only the installed `.so`/`.control`/`.sql` files are copied into the final slim stage.
- **Checksum verification:** each source tarball is verified with `sha256sum -c` before build (deb-wordpress convention).
- **Known limitation:** pgml (postgresml) cannot be built for PG18 — upstream v2.10.0 targets pgrx 0.12.9 (PG ≤ 17). Tracked in TODO.md.

### Configuration
- `etc/postgresql/postgresql.conf` — single `shared_preload_libraries = 'pg_stat_statements, pg_cron, pg_net'` (the legacy config had a duplicate assignment that silently disabled pg_cron/pg_net), `cron.database_name = 'postgres'`, `wal_level = logical`, `password_encryption = scram-sha-256`, csvlog to `/var/log/postgresql`.
- `etc/postgresql/pg_hba.conf` — dev-friendly: local peer, loopback trust, external scram-sha-256.
- `etc/postgresql/pg_ident.conf` — `root_as_postgres` map for passwordless root access.

---

## 4. Roadmap & Validation (D - Delivery)

### Current Phase: Trixie + PG18 Upgrade
- [x] **Base Image Upgrade:** Debian Bullseye → Trixie.
- [x] **PostgreSQL Upgrade:** 14.1 (source build) → 18 (PGDG apt).
- [x] **Build System:** Ansible playbook → direct apt + pinned source builds.
- [x] **Extension Set:** postgis, pgvector, pg_cron, pgrouting, pgtap (apt) + pgjwt, pg_net, pgmq (source). plv8 removed; pgml deferred (PG18 unsupported upstream).
- [x] **CI/CD:** modernized workflows, boot-test, dependabot.
- [ ] **Re-add pgml** once upstream supports PostgreSQL 18.

### Success Criteria
1. Image builds cleanly on Trixie with PG 18 and all included extensions loadable.
2. First-run init creates the user, database, and requested extensions.
3. `pg_cron` is preloaded and functional (`cron.job` queryable in the `postgres` db).
4. `make scan` (trivy) reports no new HIGH/CRITICAL findings.
5. Container restart preserves data and extension state.
