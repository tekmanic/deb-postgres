#!/bin/bash

# Set data directory environment variable
export PGDATA=/var/lib/postgresql/data

# Initialize first run
if [[ -e /.firstrun ]]; then
    /scripts/init-postgres.sh ${PGDATA}
fi

# Start PostgreSQL
echo "Starting PostgreSQL..."
su -p postgres -c '/usr/lib/postgresql/${PG_VERSION}/bin/pg_ctl start'
while true; do sleep 1000; done