#!/bin/bash
# Verify PGDG trixie package availability for the deb-postgres upgrade.
set -e
export DEBIAN_FRONTEND=noninteractive
P=/etc
apt-get update -q
apt-get install -y wget ca-certificates gnupg
wget -qO /root/pgdg.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
gpg --yes --batch --dearmor -o $P/apt/trusted.gpg.d/pgdg.gpg /root/pgdg.asc
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt trixie-pgdg main' > $P/apt/sources.list.d/pgdg.list
apt-get update -q
for p in postgresql-18 postgresql-client-18 postgresql-contrib-18 \
         postgresql-18-postgis-3 postgresql-18-pgrouting3 postgresql-18-pgtap \
         postgresql-18-pg-cron postgresql-18-pgjwt postgresql-18-pgnet \
         postgresql-18-pgvector postgresql-18-pgmq postgresql-18-pgml \
         postgresql-18-plv8; do
  v=$(apt-cache policy "$p" 2>/dev/null | grep Candidate | awk '{print $2}')
  echo "$p: ${v:-NOT AVAILABLE}"
done
