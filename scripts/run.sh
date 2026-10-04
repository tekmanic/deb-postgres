#!/bin/bash

set -euo pipefail

# Set data directory environment variable
export PGDATA=/var/lib/postgresql/data

# Initialize first run
if [[ -e /.firstrun ]]; then
    /scripts/init-postgres.sh ${PGDATA}
fi

# Start PostgreSQL
echo "Starting PostgreSQL..."
# -p preserves the environment (PGDATA); -s /bin/bash selects the shell explicitly
su -p -s /bin/bash postgres -c '/usr/lib/postgresql/${PG_VERSION}/bin/pg_ctl start'
while true; do sleep 1000; done
