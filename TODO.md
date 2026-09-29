# Project: deb-postgres Upgrade (Trixie + PostgreSQL 18 + Extensions)

## Status: Not Started
**Branch:** `upgrade-trixie-pg18` (to be created from `main`)
**Reference repo:** `../deb-wordpress` (Trixie, hardened Dockerfile, modern CI, spec/TODO/README conventions)
**Last updated:** 2026-09-28

## Goal
Compare deb-postgres against deb-wordpress, upgrade deb-postgres to follow the same conventions (Debian Trixie base, PostgreSQL 18, hardened Dockerfile, modern CI, spec/TODO docs), install the requested extension set, and update README.md.

**Requested extensions (9):** postgis, pgvector, postgresml (pgml), pgmq, pg_cron, pgjwt, pg_net, pgrouting, pgtap

---

## 0. Comparison: deb-postgres (current) vs deb-wordpress (reference)

| Area | deb-postgres (current) | deb-wordpress (target convention) | Action |
|---|---|---|---|
| Base image | `debian:bullseye-slim` (EOL) | Debian Trixie (13) | → `debian:trixie-slim` |
| PostgreSQL | 14.1 built from source (LLVM/clang-11, gcc-10, arm64 CFLAGS) | n/a (MariaDB via apt) | → PostgreSQL 18 from PGDG apt (`postgresql-18` 18.3-1.pgdg13+1) |
| Build system | Ansible playbook baked into image (`ansible/` dir, ~10 task files) | Direct `RUN apt-get` with `set -eux`, `--no-install-recommends` | → Remove `ansible/`, direct apt + pinned source builds |
| Extensions | postgis 3.1.4, pgrouting 3.3.0, pgtap 1.1.0, pg_cron 1.4.1, pgjwt (unpinned `master`), plv8 (commit-pinned) — mostly source-built | n/a | → 5 via PGDG apt, 4 source-built (pgjwt, pg_net, pgmq, pgml), drop plv8 |
| Hardening | None (no noninteractive, no `--no-install-recommends`, no setuid strip) | `ARG DEBIAN_FRONTEND=noninteractive`, `--no-install-recommends`, `find / -xdev -perm /6000 -type f -exec chmod a-s {} +`, apt cleanup | → Adopt all |
| Entrypoint | `scripts/run.sh` (initdb → pg_ctl → sleep loop) | nitro init (multi-service: apache + mariadb) | → Keep `run.sh` (single service; nitro not needed) — document decision |
| Makefile | `build`/`run`/`clean` only | `.PHONY`, `scan` (trivy), `slim` | → Add `.PHONY` + `scan` |
| CI | `checkout@v2`, `login-action@v1`, `retry@v2.4.0`, `CR_PAT`, no `permissions:` block, no boot test | `checkout@v7`, `login-action@v4`, `retry@v4.0.0`, `GH_TOKEN`, `permissions: contents:read packages:write`, boot-test workflow, `dockerhub-description@v5` | → Modernize both workflows + add boot-test |
| Dependabot | None | `.github/dependabot.yml` (docker + github-actions, weekly) | → Add |
| Docs | Minimal README (module list only) | README with Overview / Key Features / Usage / env table / Notes + `spec.md` + `TODO.md` | → Rewrite README, add `spec.md`, this `TODO.md` |
| Version pinning | Checksums in `ansible/vars.yml` (several stale) | `ENV WORDPRESS_VERSION` + `WORDPRESS_SHA1`, verified with `sha1sum -c` | → Pin PG 18 + every source extension (tag + sha256) |

### PGDG trixie package availability
Verified 2026-09-18 against the `trixie-pgdg` snapshot (data: `~/.zeroclaw/agents/radix/workspace/.tmp-pgdg/Packages.json`).

| Extension | PGDG trixie package | Version (snapshot) | Install method |
|---|---|---|---|
| postgis | `postgresql-18-postgis-3` (+ `-scripts`) | 3.6.2 | apt |
| pgvector | `postgresql-18-pgvector` | 0.8.4 | apt |
| pg_cron | `postgresql-18-cron` | 1.6.7 | apt |
| pgrouting | `postgresql-18-pgrouting` (+ `-scripts`) | 4.0.1 | apt |
| pgtap | `postgresql-18-pgtap` | 1.3.4 | apt |
| pgjwt | — (not in PGDG) | pin release tag | source: `make && make install` |
| pg_net | — (not in PGDG) | pin release tag | source: `make && make install` |
| pgmq | — (not in PGDG) | pin release tag | source: `make && make install` |
| pgml (postgresml) | — (not in PGDG) | pin release tag | source: `make && make install` (needs Rust toolchain) |

Notes:
- `postgresql-contrib-18` does **not** exist — contrib modules ship inside `postgresql-18`.
- `plv8` is absent from the trixie-pgdg snapshot and is **not** in the requested list → remove (call out in README).
- Re-verify availability at build time (step 1.1); versions may have moved since the snapshot.

---

## 1. Phase 1 — Dockerfile (base + postgres + extensions)

- [ ] 1.1 Re-verify PGDG trixie availability: run the old `pgdg-check.sh` logic in a throwaway container (or rebuild the check) and confirm the 5 apt packages + versions from the table above.
- [ ] 1.2 Rewrite `Dockerfile`:
  - `FROM debian:trixie-slim`
  - Keep `LABEL org.opencontainers.image.authors="tekmanic"`
  - `ARG DEBIAN_FRONTEND=noninteractive`
  - Add PGDG repo: fetch `https://www.postgresql.org/media/keys/ACCC4CF8.asc`, dearmor to `/etc/apt/trusted.gpg.d/pgdg.gpg`, add `deb [signed-by=/etc/apt/trusted.gpg.d/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt trixie-pgdg main`
  - `apt-get install -y --no-install-recommends postgresql-18 postgresql-client-18 postgresql-server-dev-18`
  - `apt-get install -y --no-install-recommends postgresql-18-postgis-3 postgresql-18-postgis-3-scripts postgresql-18-pgrouting postgresql-18-pgrouting-scripts postgresql-18-pgtap postgresql-18-cron postgresql-18-pgvector`
  - Drop the package's default cluster so the image keeps its custom layout: `pg_dropcluster 18 main` (package postinst creates `/var/lib/postgresql/18/main`; image uses `PGDATA=/var/lib/postgresql/data`)
  - Source builds (each: fetch pinned tarball → verify sha256 → `make && make install`):
    - pgjwt (`michelp/pgjwt`) — pin release tag (old image built unpinned `master`)
    - pg_net (`pgnet/pg_net`) — pin release tag
    - pgmq (`cyberdelia/pgmq`) — pin release tag
    - pgml (`postgresml/pgml`) — pin release tag; install Rust toolchain (rustup, minimal profile) in a `builder` stage, remove after install
  - Prefer a multi-stage build (deb-wordpress convention): compile source extensions in `builder`, copy installed files into the final stage; otherwise single-stage with full toolchain cleanup
  - `ENV PG_VERSION=18` (replaces `PG_VERSION 14`); drop `POSTGIS_VERSION` env (now 3.6.2 via apt)
  - Keep: `ADD scripts /scripts`, `chmod +x`, `touch /.firstrun`, locale setup (`locales` package + `localedef -i en_US -f UTF-8 en_US.UTF-8`), `ENTRYPOINT ["/scripts/run.sh"]`, `EXPOSE 5432`
  - Hardening (mirror deb-wordpress): `apt-get autoremove && apt-get autoclean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*`; `find / -xdev -perm /6000 -type f -exec chmod a-s {} +`
  - Remove: `COPY ansible/`, `apt install ansible`, `default-jdk-headless` (leftover — pljava was never actually installed), all source-build toolchain packages, the manual binary-symlink step (PGDG client package already provides `/usr/bin/psql` etc.)
- [ ] 1.3 Pin versions: `ARG`s/`ENV`s for each source extension's version + sha256 (deb-wordpress convention: `WORDPRESS_VERSION` / `WORDPRESS_SHA1` + `sha1sum -c`).
- [ ] 1.4 Document the nitro decision in the README (single service → keep `run.sh`; nitro only pays off for multi-service images).

## 2. Phase 2 — Config files

- [ ] 2.1 Move `ansible/files/postgresql.conf.j2` → `etc/postgresql/postgresql.conf` (plain file, no templating) and fix:
  - **Duplicate `shared_preload_libraries` bug:** line 722 (`pg_stat_statements, pgaudit, plpgsql, plpgsql_check, pg_cron, pg_net`) is overridden by line 794 (`pg_stat_statements` only) — last assignment wins, so pg_cron/pg_net were silently NOT preloaded. Replace with a single line: `shared_preload_libraries = 'pg_stat_statements, pg_cron, pg_net'`
  - Remove references to libraries that are not installed (`pgaudit`, `plpgsql_check`)
  - Add: `cron.database_name = 'postgres'`
  - Keep: `listen_addresses='0.0.0.0'`, `wal_level=logical`, `password_encryption=scram-sha-256`, csvlog to `/var/log/postgresql`, `compute_query_id=on`, `pg_stat_statements.max=10000`, `unix_socket_directories='/var/run/postgresql'`
- [ ] 2.2 Move `ansible/files/pg_hba.conf.j2` → `etc/postgresql/pg_hba.conf` — keep current rules (local peer, `127.0.0.1/32 trust`, `::1/128 scram-sha-256`, root map, `0.0.0.0/0 scram-sha-256`) — dev-friendly.
- [ ] 2.3 Move `ansible/files/pg_ident.conf.j2` → `etc/postgresql/pg_ident.conf` — keep the `root_as_postgres` map.
- [ ] 2.4 `COPY etc/postgresql/ /etc/postgresql/` in the Dockerfile (keep the init-time copy into `PGDATA` in `init-postgres.sh`).
- [ ] 2.5 Delete the `ansible/` directory entirely (`playbook.yml`, `tasks/`, `files/`, `vars.yml`) once 2.1–2.3 are done.

## 3. Phase 3 — Scripts

- [ ] 3.1 `scripts/run.sh`: keep structure (firstrun guard → init → `pg_ctl start` → sleep loop); confirm it uses `${PG_VERSION}` (now 18).
- [ ] 3.2 `scripts/init-postgres.sh`: fix bugs:
  - Line 31: `"${psql[@]}"` references an undefined array → use `psql -q -U postgres`
  - `pwgen -s -1 16` → `pwgen` is not installed in the image → use `openssl rand -base64 16`
  - `su -p postgres` → `su -s /bin/bash postgres -c` (consistent with deb-wordpress's `su -s /bin/bash -c ... www-data`)
  - Add `set -euo pipefail` (deb-wordpress convention)
  - Keep: `POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB`/`POSTGRES_EXTENSIONS` env handling, `template_postgis` creation, per-extension `CREATE EXTENSION` loop, credential banner, `rm -f /.firstrun`
- [ ] 3.3 `scripts/extensions.sql`: add the new extensions (schema `extensions`): `vector`, `pgjwt`, `pg_net`, `pgmq`, `pgml`, `pgrouting`, `pgtap`; keep postgis + `postgis_tiger_geocoder` + `address_standardizer` + contrib set (`pg_stat_statements`, `uuid-ossp`, `pgcrypto`, `fuzzystrmatch`). Note: `pg_cron` is cluster-wide — create it in the `postgres` db, not per-database.
- [ ] 3.4 `scripts/sanity-test.sh`: fix invalid `print .` lines (34, 52 — bash has no `print` builtin; use `echo .`); keep the rest.
- [ ] 3.5 `scripts/init-postgis.sh`: now redundant (postgis via apt + `extensions.sql`) → remove. Keep `scripts/update-postgis.sh` (useful for `ALTER EXTENSION ... UPDATE` upgrades).
- [ ] 3.6 Remove untracked research artifacts: `pgdg-check.sh`, `pgdg-check2.sh`, `.pgdg-check.sh`, `.probe/` (findings are captured in this TODO.md).

## 4. Phase 4 — Makefile + CI (mirror deb-wordpress)

- [ ] 4.1 `Makefile`:
  - Add `.PHONY: all build run scan clean`
  - Add `scan:` target → `trivy image --severity HIGH,CRITICAL deb-postgres:latest > scanresults`
  - Update `run:` example: `-e POSTGRES_EXTENSIONS='postgis vector pg_cron pgjwt pg_net pgmq pgrouting pgtap'`
  - Keep `-p 5433:5432` and the `clean` target
- [ ] 4.2 `.github/workflows/docker-manual-triggered-test.yaml`: bump `actions/checkout@v7`, `docker/login-action@v4`, `nick-invision/retry@v4.0.0`; add `permissions: contents:read packages:write`; use `${{ secrets.GH_TOKEN }}` for GHCR (mirror deb-wordpress).
- [ ] 4.3 `.github/workflows/docker-tag-triggered-prod.yaml`: same bumps + `peter-evans/dockerhub-description@v5`; keep the tag-identify logic (or adopt deb-wordpress's branch-or-tag variant).
- [ ] 4.4 Add `.github/workflows/boot-test.yml` (mirror deb-wordpress): build → `docker run -d -p 5432:5432` → wait for `pg_isready` (timeout 60s) → SQL checks: `SELECT extname FROM pg_extension` contains all 9; `SELECT PostGIS_full_version();`; `SELECT vector_version();`; `SELECT jobid FROM cron.job LIMIT 1;` (proves pg_cron preloaded).
- [ ] 4.5 Add `.github/dependabot.yml` (copy from deb-wordpress: docker + github-actions, weekly).

## 5. Phase 5 — Docs

- [ ] 5.1 Rewrite `README.md` (deb-wordpress structure):
  - Title + one-liner: "PostgreSQL 18 database image based on Debian Trixie Slim with useful extensions added."
  - **Overview** (dev-friendly postgres; keep the Supabase note for production)
  - **Key Features** (Modern Base: Trixie; PostgreSQL 18 via PGDG; 9 extensions; hardened; first-run init via env vars)
  - **Usage** (`docker run` example with `POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB`/`POSTGRES_EXTENSIONS`, `-p 5433:5432`, volume for `/var/lib/postgresql/data`)
  - **Configuration env vars** table (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_EXTENSIONS`, `PG_VERSION`)
  - **Extensions** table (name, version, source: PGDG apt / source, link)
  - **Notes** (pg_cron requires `shared_preload_libraries` — preconfigured; data dir; port; plv8 removed in this release)
  - Keep the PayPal donation footer
- [ ] 5.2 Add `spec.md` (mirror deb-wordpress structure: Vision & Goals, System Architecture, Implementation Details, Roadmap & Validation) — part of "similar conventions".
- [ ] 5.3 Keep this `TODO.md` as the task tracker (deb-wordpress convention).

## 6. Phase 6 — Verification

- [ ] 6.1 `make build` (`docker build -t deb-postgres:latest .`) — must succeed on amd64 (and arm64 if the host supports it).
- [ ] 6.2 `make run` → wait for boot → `docker exec -it deb-postgres psql -U myuser -d mydb -c "SELECT extname, extversion FROM pg_extension ORDER BY 1;"` → expect: `pg_cron`, `pgjwt`, `pg_net`, `pgmq`, `pgml`, `postgis`, `pgrouting`, `pgtap`, `vector` (+ contrib defaults).
- [ ] 6.3 Spot checks:
  - `SELECT PostGIS_full_version();`
  - `SELECT vector_version();`
  - `SELECT jobid FROM cron.job LIMIT 1;` (proves pg_cron is preloaded)
  - `SELECT * FROM pgmq.create('test');`
  - pgml: at minimum `CREATE EXTENSION pgml;` succeeds (full `pgml.predict` needs a model)
- [ ] 6.4 `make scan` (trivy) — no new HIGH/CRITICAL vs baseline.
- [ ] 6.5 Restart test: `docker restart deb-postgres` → data persists, extensions still load (`shared_preload_libraries` intact).
- [ ] 6.6 `make clean`.

## 7. Phase 7 — Commit & PR

- [ ] 7.1 Commit on `upgrade-trixie-pg18` with clear messages (deb-wordpress style: `build: ...`, `ci: ...`, `docs: ...`, `chore: ...`).
- [ ] 7.2 Push branch, open PR to `main` (deb-wordpress flow: one PR per upgrade, e.g. #6/#7/#10).
- [ ] 7.3 Update this `TODO.md`: check off completed items, set Status: Complete.

---

## Risks & open questions

1. **pgml build cost** — needs the Rust toolchain; the largest build-time addition. Mitigation: multi-stage build, pinned release, sha256 verification.
2. **pgjwt/pg_net/pgmq pinning** — the old image built pgjwt from `master` (unpinned, non-reproducible). Pin to release tags + sha256.
3. **plv8 removal** — not in the requested list and not in the trixie-pgdg snapshot. Default: remove; call out in the README.
4. **Nitro** — deb-wordpress uses nitro for 2 services; postgres is a single service. Default: keep `run.sh`, document the decision.
5. **contrib package** — `postgresql-contrib-18` does not exist; contrib ships inside `postgresql-18`.
6. **Old config bug** — `postgresql.conf.j2` had two `shared_preload_libraries` lines; the last one (pg_stat_statements only) won, silently disabling pg_cron/pg_net. Fixed in step 2.1.
7. **arm64** — the old build had arm64-specific CFLAGS/LLVM paths; PGDG apt packages are prebuilt for both arches, so that logic can be removed. Verify on arm64 if needed.

## Definition of Done
- [ ] Image builds cleanly on Trixie with PG 18 (PGDG) and all 9 requested extensions loadable.
- [ ] `make scan` reports no new HIGH/CRITICAL.
- [ ] CI (manual test, tag prod, boot-test, dependabot) mirrors deb-wordpress.
- [ ] README.md + spec.md updated; TODO.md all checked off; PR open against `main`.
