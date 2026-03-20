#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

wait_for_container() {
  local name="$1"
  local wanted="$2"
  local attempts="${3:-60}"
  local i
  local status

  for ((i=1; i<=attempts; i++)); do
    status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$name" 2>/dev/null || true)"
    if [[ "${status}" == "${wanted}" ]]; then
      return 0
    fi
    sleep 5
  done

  echo "Timed out waiting for ${name} to become ${wanted}. Current status: ${status:-missing}" >&2
  return 1
}

wait_for_port() {
  local port="$1"
  local attempts="${2:-30}"
  local i

  for ((i=1; i<=attempts; i++)); do
    if nc -z 127.0.0.1 "${port}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  echo "Timed out waiting for port ${port}" >&2
  return 1
}

retry_cmd() {
  local attempts="$1"
  shift
  local i

  for ((i=1; i<=attempts; i++)); do
    if "$@"; then
      return 0
    fi
    sleep 5
  done

  return 1
}

echo "[1/7] Rebuilding and starting the stack"
docker compose down -v --remove-orphans >/dev/null 2>&1 || true
docker compose up -d --build

echo "[2/7] Waiting for core services"
wait_for_container hb-kdc healthy
wait_for_container hb-openldap healthy
wait_for_container hb-postgres healthy
wait_for_container hb-hive-metastore healthy
wait_for_port 10000
wait_for_port 10001
wait_for_port 21050
wait_for_port 21051

echo "[3/7] Validating KDC principals"
docker exec hb-kdc bash -lc "kadmin.local -q 'listprincs'"

echo "[4/7] Validating Kerberos password and keytab auth"
docker exec hb-kerberos-client bash -lc "printf '%s\n' 'talend123' | kinit talend@EXAMPLE.COM && kdestroy"
docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && klist && kdestroy"

echo "[5/7] Validating Hive with LDAP username/password"
retry_cmd 12 docker exec hb-kerberos-client bash -lc "hive-jdbc -u 'jdbc:hive2://hive-server2-open:10000/default' -n 'admin' -p 'Admin123$' -e 'show databases;'"

echo "[6/7] Validating Impala with LDAP username/password"
retry_cmd 12 docker exec hb-kerberos-client bash -lc "hive-jdbc -u 'jdbc:hive2://impala-daemon-open:21050/default' -n 'admin' -p 'Admin123$' -e 'show databases;'"

echo "[7/7] Validating Hive with Kerberos"
retry_cmd 12 docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && hive-jdbc -u 'jdbc:hive2://hive-server2:10000/default;principal=hive/localhost@EXAMPLE.COM;auth=kerberos' -e 'show databases;' && kdestroy"

echo "Smoke test completed successfully."
