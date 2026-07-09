#!/bin/sh

set -e
ENCODED_PASSWORD=$(python3 -c "import urllib.parse, os; print(urllib.parse.quote(os.environ['DB_PASSWORD'], safe=''))")
export DATABASE_URL="postgres://${DB_USERNAME}:${ENCODED_PASSWORD}@${DB_HOST}:5432/${DB_NAME}?sslmode=require"
exec "$@"