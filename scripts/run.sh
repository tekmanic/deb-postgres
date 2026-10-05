#!/bin/bash

set -euo pipefail

# Set data directory environment variable
export PGDATA=/var/lib/postgresql/data

# Initialize first run
if [[ -e /.firstrun ]]; then
    /scripts/init-postgres.sh ${PGDATA}
fi

# Start PostgreSQL only if it is not already running. First-run init leaves
# the instance up (it no longer stops it), so this avoids a stop/restart
# window; on subsequent boots (no /.firstrun) it starts normally.
if ! su -p -s /bin/bash postgres -c "/usr/lib/postgresql/${PG_VERSION}/bin/pg_ctl status" >/dev/null 2>&1; then
    echo "Starting PostgreSQL..."
    su -p -s /bin/bash postgres -c "/usr/lib/postgresql/${PG_VERSION}/bin/pg_ctl start"
fi
while true; do sleep 1000; done
