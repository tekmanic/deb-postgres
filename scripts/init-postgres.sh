#!/bin/bash

set -euo pipefail

USER=${POSTGRES_USER:-pgadmin}
PASS=${POSTGRES_PASSWORD:-$(openssl rand -base64 16)}
DB=${POSTGRES_DB:-}
EXTENSIONS=${POSTGRES_EXTENSIONS:-}
# PGDATA=$1

# Initialize the data directory only if it is empty (idempotent re-runs:
# if a previous init died partway, we resume instead of failing on
# "directory exists but is not empty").
if [ -z "$(ls -A /var/lib/postgresql/data 2>/dev/null)" ]; then
    echo "First run of PostgreSQL, Initializing PostgreSQL DB in ${PGDATA}..."
    su -p -s /bin/bash postgres -c "/usr/lib/postgresql/${PG_VERSION:?required}/bin/initdb -E utf8 --locale en_US.UTF-8"
fi

# Install the configuration files BEFORE the first start so that
# shared_preload_libraries (pg_cron, pg_net) and cron.database_name are
# in effect while the extensions are created below.
cp -rp /etc/postgresql/*.conf /var/lib/postgresql/data/

cd /var/lib/postgresql
# Start PostgreSQL service
su -p -s /bin/bash postgres -c "/usr/lib/postgresql/${PG_VERSION:?required}/bin/pg_ctl start"

while ! su -p -s /bin/bash postgres -c 'psql -q -c "select true;"'; do sleep 1; done

# Create user
echo "Creating user: \"$USER\"..."
psql -q -U postgres -c "DROP ROLE IF EXISTS \"$USER\";"
psql -q -U postgres <<-EOF
    CREATE ROLE "$USER" WITH ENCRYPTED PASSWORD '$PASS';
    ALTER ROLE "$USER" WITH ENCRYPTED PASSWORD '$PASS';
    ALTER ROLE "$USER" WITH SUPERUSER;
    ALTER ROLE "$USER" WITH LOGIN;
EOF

# Create the 'template_postgis' template db (postgis preinstalled;
# use with: CREATE DATABASE mydb TEMPLATE template_postgis;)
if [ "$(psql -q -t -A -U postgres -c "SELECT 1 FROM pg_database WHERE datname = 'template_postgis';")" != "1" ]; then
    psql -q -U postgres -c "CREATE DATABASE template_postgis;"
fi
psql -q -U postgres -d template_postgis -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# Create database
if [ ! -z "$DB" ]; then
    if [ "$(psql -q -t -A -U postgres -c "SELECT 1 FROM pg_database WHERE datname = '$DB';")" != "1" ]; then
        echo "Creating database: \"$DB\"..."
        psql -q -U postgres <<-EOF
        CREATE DATABASE "$DB" WITH OWNER="$USER" ENCODING='UTF8';
        GRANT ALL ON DATABASE "$DB" TO "$USER";
EOF
    fi

    if [[ ! -z "$EXTENSIONS" ]]; then
        for extension in $EXTENSIONS; do
            if [ "$extension" = "pg_cron" ]; then
                # pg_cron is cluster-wide: it can only be created in the
                # database named by cron.database_name (here: 'postgres')
                echo "Installing extension \"pg_cron\" in database \"postgres\" (cluster-wide)..."
                psql -q -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
            else
                # pgjwt's control file declares requires='pgcrypto' —
                # make sure the dependency exists before creating it.
                if [ "$extension" = "pgjwt" ]; then
                    psql -q -U postgres "$DB" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
                fi
                echo "Installing extension \"$extension\" for database \"$DB\"..."
                psql -q -U postgres "$DB" -c "CREATE EXTENSION IF NOT EXISTS \"$extension\";"
            fi
        done
    fi
fi

# Stop PostgreSQL service
su -p -s /bin/bash postgres -c "/usr/lib/postgresql/${PG_VERSION}/bin/pg_ctl stop -m fast -w"

echo "========================================================================"
echo "PostgreSQL User: \"$USER\""
echo "PostgreSQL Password: \"$PASS\""
if [ ! -z "$DB" ]; then
    echo "PostgreSQL Database: \"$DB\""
    if [[ ! -z "$EXTENSIONS" ]]; then
        echo "PostgreSQL Extensions: \"$EXTENSIONS\""
    fi
fi
echo "========================================================================"

rm -f /.firstrun
