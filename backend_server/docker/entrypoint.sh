#!/bin/sh
set -eu

DB_HOST="${PGHOST:-}"
DB_PORT="${PGPORT:-}"
DB_NAME="${PGDATABASE:-}"
DB_USER="${PGUSER:-}"
DB_PASS="${PGPASSWORD:-}"
DB_PASS_SOURCE=""
DB_PASS_FROM_URL="false"

if [ -n "${PGPASSWORD:-}" ]; then
  DB_PASS_SOURCE="PGPASSWORD"
fi

url_decode() {
  # Decode percent-encoded values from connection URLs (e.g. Railway DATABASE_URL).
  # shellcheck disable=SC2001
  encoded="$(printf '%s' "$1" | sed 's/%/\\x/g')"
  printf '%b' "${encoded}"
}

if [ -z "${DB_PASS}" ]; then
  DB_PASS="${POSTGRES_PASSWORD:-${DATABASE_PASSWORD:-${DB_PASSWORD:-}}}"
  if [ -n "${DB_PASS}" ]; then
    if [ -n "${POSTGRES_PASSWORD:-}" ]; then
      DB_PASS_SOURCE="POSTGRES_PASSWORD"
    elif [ -n "${DATABASE_PASSWORD:-}" ]; then
      DB_PASS_SOURCE="DATABASE_PASSWORD"
    elif [ -n "${DB_PASSWORD:-}" ]; then
      DB_PASS_SOURCE="DB_PASSWORD"
    fi
  fi
fi

# Fallback to Serverpod-specific password env vars if no DB password was resolved yet.
if [ -z "${DB_PASS}" ]; then
  DB_PASS="${SERVERPOD_PASSWORD_database:-${SERVERPOD_PASSWORD_DATABASE:-${SERVERPOD_DATABASE_PASSWORD:-}}}"
  if [ -n "${DB_PASS}" ]; then
    if [ -n "${SERVERPOD_PASSWORD_database:-}" ]; then
      DB_PASS_SOURCE="SERVERPOD_PASSWORD_database"
    elif [ -n "${SERVERPOD_PASSWORD_DATABASE:-}" ]; then
      DB_PASS_SOURCE="SERVERPOD_PASSWORD_DATABASE"
    else
      DB_PASS_SOURCE="SERVERPOD_DATABASE_PASSWORD"
    fi
  fi
fi

DB_URL="${DATABASE_URL:-${DATABASE_PRIVATE_URL:-${DATABASE_PUBLIC_URL:-${POSTGRES_URL:-${PGURL:-}}}}}"

if [ -n "${DB_URL}" ]; then
  db_url_no_scheme="${DB_URL#*://}"
  db_credentials_and_host="${db_url_no_scheme%%/*}"
  db_path_and_query="${db_url_no_scheme#*/}"
  db_name_from_url="${db_path_and_query%%\?*}"

  if [ "${db_credentials_and_host#*@}" != "${db_credentials_and_host}" ]; then
    db_credentials="${db_credentials_and_host%@*}"
    db_host_port="${db_credentials_and_host#*@}"

    db_user_from_url="${db_credentials%%:*}"

    db_user_decoded="$(url_decode "${db_user_from_url}")"
    if [ -n "${db_user_decoded}" ]; then
      DB_USER="${db_user_decoded}"
    fi

    if [ "${db_credentials#*:}" != "${db_credentials}" ]; then
      db_pass_decoded="$(url_decode "${db_credentials#*:}")"
      if [ -n "${db_pass_decoded}" ]; then
        DB_PASS="${db_pass_decoded}"
        DB_PASS_SOURCE="DB_URL"
        DB_PASS_FROM_URL="true"
      fi
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
    DB_NAME="$(url_decode "${db_name_from_url}")"
  fi
fi

# Map resolved DB password to Serverpod expected password variable.
# Always export when we have a resolved password to avoid stale env values.
if [ -n "${DB_PASS}" ]; then
  export SERVERPOD_PASSWORD_database="${DB_PASS}"
fi

DB_SOURCE="config/production.yaml"
if [ -n "${DB_URL}" ]; then
  DB_SOURCE="DB_URL"
elif [ -n "${PGHOST:-}${PGPORT:-}${PGDATABASE:-}${PGUSER:-}${PGPASSWORD:-}" ]; then
  DB_SOURCE="PG* env vars"
fi

if [ -z "${DB_PASS_SOURCE}" ]; then
  if [ -n "${SERVERPOD_PASSWORD_database:-}" ]; then
    DB_PASS_SOURCE="SERVERPOD_PASSWORD_database"
  elif [ -n "${SERVERPOD_PASSWORD_DATABASE:-}" ]; then
    DB_PASS_SOURCE="SERVERPOD_PASSWORD_DATABASE"
  elif [ -n "${SERVERPOD_DATABASE_PASSWORD:-}" ]; then
    DB_PASS_SOURCE="SERVERPOD_DATABASE_PASSWORD"
  else
    DB_PASS_SOURCE="config/passwords.yaml"
  fi
fi

if [ -f "config/production.yaml" ]; then
  tmp_config_file="$(mktemp)"
  awk \
    -v host="${DB_HOST}" \
    -v port="${DB_PORT}" \
    -v name="${DB_NAME}" \
    -v user="${DB_USER}" \
    -v password="${DB_PASS}" \
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
    if (password != "" && $0 ~ /^  password:/) {
      print "  password: " password
      next
    }
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

# Optional convenience mapping for auth/service secrets.
# Prefer explicit Serverpod password env vars when already provided.
if [ -z "${SERVERPOD_PASSWORD_jwtSecret:-}" ]; then
  if [ -n "${JWT_SECRET:-}" ]; then
    export SERVERPOD_PASSWORD_jwtSecret="${JWT_SECRET}"
  elif [ -n "${AUTH_JWT_SECRET:-}" ]; then
    export SERVERPOD_PASSWORD_jwtSecret="${AUTH_JWT_SECRET}"
  elif [ -n "${SERVICE_SECRET:-}" ]; then
    export SERVERPOD_PASSWORD_jwtSecret="${SERVICE_SECRET}"
  fi
fi

if [ -z "${SERVERPOD_PASSWORD_serviceSecret:-}" ]; then
  if [ -n "${SERVICE_SECRET:-}" ]; then
    export SERVERPOD_PASSWORD_serviceSecret="${SERVICE_SECRET}"
  elif [ -n "${SERVERPOD_SERVICE_SECRET:-}" ]; then
    export SERVERPOD_PASSWORD_serviceSecret="${SERVERPOD_SERVICE_SECRET}"
  elif [ -n "${JWT_SECRET:-}" ]; then
    export SERVERPOD_PASSWORD_serviceSecret="${JWT_SECRET}"
  fi
fi

# Keep both secrets aligned if only one side is set.
if [ -z "${SERVERPOD_PASSWORD_jwtSecret:-}" ] && [ -n "${SERVERPOD_PASSWORD_serviceSecret:-}" ]; then
  export SERVERPOD_PASSWORD_jwtSecret="${SERVERPOD_PASSWORD_serviceSecret}"
fi

if [ -z "${SERVERPOD_PASSWORD_serviceSecret:-}" ] && [ -n "${SERVERPOD_PASSWORD_jwtSecret:-}" ]; then
  export SERVERPOD_PASSWORD_serviceSecret="${SERVERPOD_PASSWORD_jwtSecret}"
fi

echo "[entrypoint] DB config source: ${DB_SOURCE}" >&2
echo "[entrypoint] DB password source: ${DB_PASS_SOURCE}" >&2
echo "[entrypoint] DB password came from URL: ${DB_PASS_FROM_URL}" >&2
echo "[entrypoint] DB password length: ${#DB_PASS}" >&2
echo "[entrypoint] JWT secret provided: $( [ -n "${SERVERPOD_PASSWORD_jwtSecret:-}" ] && echo true || echo false )" >&2
echo "[entrypoint] Service secret provided: $( [ -n "${SERVERPOD_PASSWORD_serviceSecret:-}" ] && echo true || echo false )" >&2
echo "[entrypoint] DB host: ${DB_HOST:-<from config>}" >&2
echo "[entrypoint] DB port: ${DB_PORT:-<from config>}" >&2
echo "[entrypoint] DB name: ${DB_NAME:-<from config>}" >&2
echo "[entrypoint] DB user: ${DB_USER:-<from config>}" >&2
echo "[entrypoint] DB require SSL override: ${DB_REQUIRE_SSL:-<from config>}" >&2

exec ./server --mode="${runmode}" --server-id="${serverid}" --logging="${logging}" --role="${role}"