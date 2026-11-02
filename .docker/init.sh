#!/bin/sh
set -eu

: "${COUCHDB_USER:?Required}"
: "${COUCHDB_PASSWORD:?Required}"
db="${COUCHDB_DATABASE:-obsidiannotes}"
# Deliberately restrict names so they can be used literally in URL paths.
if ! printf '%s\n' "$db" | grep -Eq '^[a-z][a-z0-9_$()+-]*$'; then
  echo 'Invalid database name: use a lowercase initial letter and a-z, 0-9, _, $, (, ), +, -.' >&2
  exit 1
fi

for database in _users _replicator _global_changes "$db"; do
  status=$(curl --silent --show-error --connect-timeout 5 --max-time 30 \
    --user "${COUCHDB_USER}:${COUCHDB_PASSWORD}" \
    --output /tmp/livesync-init-response --write-out '%{http_code}' \
    --request PUT "http://127.0.0.1:5984/${database}")
  case "$status" in
    201|202) echo "Created: $database" ;;
    412) echo "Already exists: $database" ;;
    *) echo "Database initialization failed (HTTP $status): $database" >&2
       cat /tmp/livesync-init-response >&2
       exit 1 ;;
  esac
done
echo 'LiveSync database initialization completed.'
