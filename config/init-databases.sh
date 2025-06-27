#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
until PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U "$POSTGRES_USER" -d postgres -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

# Create databases
PGPASSWORD=$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=1 -h localhost -U "$POSTGRES_USER" -d postgres <<-EOSQL
    SELECT 'CREATE DATABASE pinstr_production' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'pinstr_production')\gexec
    SELECT 'CREATE DATABASE pinstr_production_cache' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'pinstr_production_cache')\gexec
    SELECT 'CREATE DATABASE pinstr_production_queue' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'pinstr_production_queue')\gexec
    SELECT 'CREATE DATABASE pinstr_production_cable' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'pinstr_production_cable')\gexec
    
    GRANT ALL PRIVILEGES ON DATABASE pinstr_production TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE pinstr_production_cache TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE pinstr_production_queue TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE pinstr_production_cable TO $POSTGRES_USER;
EOSQL