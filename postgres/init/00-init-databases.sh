#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE hactt_logs OWNER $POSTGRES_USER;
    CREATE USER kong WITH PASSWORD 'kong';
    CREATE DATABASE kong OWNER kong;
EOSQL
