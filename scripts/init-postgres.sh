#!/bin/bash

set -e

USER=${POSTGRES_USER:-pgadmin}
PASS=${POSTGRES_PASSWORD:-$(pwgen -s -1 16)}
DB=${POSTGRES_DB:-}
EXTENSIONS=${POSTGRES_EXTENSIONS:-}
# PGDATA=$1

echo "First run of PostgreSQL, Initializing PostgreSQL DB in ${PGDATA}..."
su -p postgres -c '/usr/lib/postgresql/${PG_VERSION:?required}/bin/initdb -E utf8 --locale en_US.UTF-8'

cd /var/lib/postgresql
# Start PostgreSQL service
su -p postgres -c '/usr/lib/postgresql/${PG_VERSION:?required}/bin/pg_ctl start'

while ! su - postgres -c 'psql -q -c "select true;"'; do sleep 1; done

# Create user
echo "Creating user: \"$USER\"..."
psql -q -U postgres -c "DROP ROLE IF EXISTS \"$USER\";"
psql -q -U postgres <<-EOF
    CREATE ROLE "$USER" WITH ENCRYPTED PASSWORD '$PASS';
    ALTER ROLE "$USER" WITH ENCRYPTED PASSWORD '$PASS';
    ALTER ROLE "$USER" WITH SUPERUSER;
    ALTER ROLE "$USER" WITH LOGIN;
EOF

# Create the 'template_postgis' template db
"${psql[@]}" <<- 'EOSQL'
CREATE DATABASE template_postgis IS_TEMPLATE true;
EOSQL

# Create dabatase
if [ ! -z "$DB" ]; then
    echo "Creating database: \"$DB\"..."
    psql -q -U postgres <<-EOF
    CREATE DATABASE "$DB" WITH OWNER="$USER" ENCODING='UTF8';
    GRANT ALL ON DATABASE "$DB" TO "$USER";
EOF

    if [[ ! -z "$EXTENSIONS" ]]; then
        for extension in $EXTENSIONS; do
            echo "Installing extension \"$extension\" for database \"$DB\"..."
            psql -q -U postgres "$DB" -c "CREATE EXTENSION IF NOT EXISTS \"$extension\";"
        done
    fi
fi

# Stop PostgreSQL service
su -p postgres -c '/usr/lib/postgresql/${PG_VERSION}/bin/pg_ctl stop -m fast -w'

# Copy the desired configuration files into place
cp -rp /etc/postgresql/*.conf /var/lib/postgresql/data/

echo "========================================================================"
echo "PostgreSQL User: \"$USER\""
echo "PostgreSQL Password: \"$PASS\""
if [ ! -z $DB ]; then
    echo "PostgreSQL Database: \"$DB\""
    if [[ ! -z "$EXTENSIONS" ]]; then
        echo "PostgreSQL Extensions: \"$EXTENSIONS\""
    fi
fi
echo "========================================================================"

rm -f /.firstrun