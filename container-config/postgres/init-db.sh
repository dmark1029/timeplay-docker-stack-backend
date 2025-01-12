#!/bin/bash
set -e

APPLICATION_NAME="${APPLICATION_NAME:-}"
SCHEMA_NAME="${APPLICATION_NAME}"

POSTGRES_DB=${POSTGRES_DB:-"localhost"}

APPLICATION_USERNAME="${POSTGRES_APP_USERNAME}"
APPLICATION_PASSWORD="${POSTGRES_APP_PASSWORD}"
READONLY_USERNAME="${POSTGRES_RO_USERNAME}"
READONLY_PASSWORD="${POSTGRES_RO_PASSWORD}"

# See https://aws.amazon.com/blogs/database/managing-postgresql-users-and-roles/
#       privileges are added based on the user that creates the tables
psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
    REVOKE CREATE ON SCHEMA public FROM PUBLIC;
    REVOKE ALL ON DATABASE "${POSTGRES_DB}" FROM PUBLIC;

    -- Create the application schema
    CREATE SCHEMA IF NOT EXISTS ${SCHEMA_NAME};

    -- Create btree_gist extension
    CREATE EXTENSION btree_gist;

    -- Create application user
    CREATE USER ${APPLICATION_USERNAME} WITH PASSWORD '${APPLICATION_PASSWORD}';

    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${APPLICATION_USERNAME};
    GRANT USAGE, CREATE ON SCHEMA ${SCHEMA_NAME} TO ${APPLICATION_USERNAME};
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ${SCHEMA_NAME} TO ${APPLICATION_USERNAME};
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA ${SCHEMA_NAME} TO ${APPLICATION_USERNAME};

    -- Create readonly user
    CREATE USER ${READONLY_USERNAME} WITH PASSWORD '${READONLY_PASSWORD}';

    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${READONLY_USERNAME};
    GRANT USAGE ON SCHEMA ${SCHEMA_NAME} TO ${READONLY_USERNAME};
    GRANT SELECT ON ALL TABLES IN SCHEMA ${SCHEMA_NAME} TO ${READONLY_USERNAME};

    -- This sets the default permissions for tables created by "APPLICATION_USERNAME"
    ALTER DEFAULT PRIVILEGES FOR ROLE ${APPLICATION_USERNAME} IN SCHEMA ${SCHEMA_NAME} GRANT SELECT ON TABLES TO ${READONLY_USERNAME};
EOSQL
