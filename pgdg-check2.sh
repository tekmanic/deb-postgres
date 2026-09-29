#!/bin/bash
# Show which postgresql-NN-* packages exist for each extension family.
set -e
export DEBIAN_FRONTEND=noninteractive
P=/etc
apt-get update -q
apt-get install -y wget ca-certificates gnupg
wget -qO /root/pgdg.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
gpg --yes --batch --dearmor -o $P/apt/trusted.gpg.d/pgdg.gpg /root/pgdg.asc
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt trixie-pgdg main' > $P/apt/sources.list.d/pgdg.list
apt-get update -q
apt-cache showpkg postgresql-18-postgis-3 2>/dev/null | head -3
echo '--- pgrouting ---'
apt-cache search -n pgrouting
echo '--- pg_cron ---'
apt-cache search -n pg-cron
echo '--- pgjwt ---'
apt-cache search -n pgjwt
echo '--- pgnet ---'
apt-cache search -n pgnet
echo '--- pgmq ---'
apt-cache search -n pgmq
echo '--- pgml ---'
apt-cache search -n pgml
echo '--- plv8 ---'
apt-cache search -n plv8
echo '--- pgvector ---'
apt-cache search -n pgvector
echo '--- pgtap ---'
apt-cache search -n pgtap
echo '--- contrib ---'
apt-cache search -n 'postgresql-contrib'
echo '--- postgresql-18 core ---'
apt-cache search -n '^postgresql-18'
echo '--- pg_cron candidate versions ---'
for n in pg-cron pgjwt pgnet pgmq plv8 pgrouting3; do
  echo "== $n =="
  apt-cache search -n "postgresql-.*-$n"
done
