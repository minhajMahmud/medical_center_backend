#!/bin/sh
set -eu

DB_HOST="${PGHOST:-}"
DB_PORT="${PGPORT:-}"
DB_NAME="${PGDATABASE:-}"
DB_USER="${PGUSER:-}"
DB_PASS="${PGPASSWORD:-}"

if [ -n "${DATABASE_URL:-}" ]; then
  db_url_no_scheme="${DATABASE_URL#*://}"
  db_credentials_and_host="${db_url_no_scheme%%/*}"
  db_path_and_query="${db_url_no_scheme#*/}"
  db_name_from_url="${db_path_and_query%%\?*}"

  if [ "${db_credentials_and_host#*@}" != "${db_credentials_and_host}" ]; then
    db_credentials="${db_credentials_and_host%@*}"
    db_host_port="${db_credentials_and_host#*@}"

    if [ -z "${DB_USER}" ]; then
      DB_USER="${db_credentials%%:*}"
    fi

    if [ -z "${DB_PASS}" ] && [ "${db_credentials#*:}" != "${db_credentials}" ]; then
      DB_PASS="${db_credentials#*:}"
    fi
  else
    db_host_port="${db_credentials_and_host}"
  fi

  if [ -z "${DB_HOST}" ]; then
    DB_HOST="${db_host_port%%:*}"
  fi

  if [ -z "${DB_PORT}" ]; then
    if [ "${db_host_port#*:}" != "${db_host_port}" ]; then
      DB_PORT="${db_host_port#*:}"
    else
      DB_PORT="5432"
    fi
  fi

  if [ -z "${DB_NAME}" ]; then
    DB_NAME="${db_name_from_url}"
  fi
fi

# Map Railway/Postgres variables to Serverpod expected password variable.
if [ -z "${SERVERPOD_PASSWORD_database:-}" ] && [ -n "${DB_PASS}" ]; then
  export SERVERPOD_PASSWORD_database="${DB_PASS}"
fi

if [ -f "config/production.yaml" ]; then
  tmp_config_file="$(mktemp)"
  awk \
    -v host="${DB_HOST}" \
    -v port="${DB_PORT}" \
    -v name="${DB_NAME}" \
    -v user="${DB_USER}" \
    -v require_ssl="${DB_REQUIRE_SSL:-}" '
BEGIN { in_database = 0 }
{
  if ($0 ~ /^database:[[:space:]]*$/) {
    in_database = 1
    print
    next
  }

  if (in_database == 1 && $0 ~ /^[^[:space:]]/) {
    in_database = 0
  }

  if (in_database == 1) {
    if (host != "" && $0 ~ /^  host:/) {
      print "  host: " host
      next
    }
    if (port != "" && $0 ~ /^  port:/) {
      print "  port: " port
      next
    }
    if (name != "" && $0 ~ /^  name:/) {
      print "  name: " name
      next
    }
    if (user != "" && $0 ~ /^  user:/) {
      print "  user: " user
      next
    }
    if (require_ssl != "" && $0 ~ /^  requireSsl:/) {
      print "  requireSsl: " require_ssl
      next
    }
  }

  print
}
' config/production.yaml > "${tmp_config_file}"
  mv "${tmp_config_file}" config/production.yaml
fi

# Optional convenience mapping for service secret.
if [ -z "${SERVERPOD_PASSWORD_serviceSecret:-}" ] && [ -n "${SERVICE_SECRET:-}" ]; then
  export SERVERPOD_PASSWORD_serviceSecret="${SERVICE_SECRET}"
fi

exec ./server --mode="${runmode}" --server-id="${serverid}" --logging="${logging}" --role="${role}"