#!/bin/sh
set -eu

# Map Railway/Postgres variables to Serverpod expected password variable.
if [ -z "${SERVERPOD_PASSWORD_database:-}" ] && [ -n "${PGPASSWORD:-}" ]; then
  export SERVERPOD_PASSWORD_database="${PGPASSWORD}"
fi

if [ -z "${SERVERPOD_PASSWORD_database:-}" ] && [ -n "${DATABASE_URL:-}" ]; then
  parsed_password="$(echo "${DATABASE_URL}" | sed -n 's#^[a-zA-Z0-9+.-]*://[^:]*:\([^@]*\)@.*#\1#p')"
  if [ -n "${parsed_password}" ]; then
    export SERVERPOD_PASSWORD_database="${parsed_password}"
  fi
fi

# Optional convenience mapping for service secret.
if [ -z "${SERVERPOD_PASSWORD_serviceSecret:-}" ] && [ -n "${SERVICE_SECRET:-}" ]; then
  export SERVERPOD_PASSWORD_serviceSecret="${SERVICE_SECRET}"
fi

exec ./server --mode="${runmode}" --server-id="${serverid}" --logging="${logging}" --role="${role}"