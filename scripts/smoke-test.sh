#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

./scripts/prepare-runtime-dirs.sh

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

run_and_expect() {
  local expected=()
  local output
  local needle

  while [[ "$#" -gt 0 && "$1" != "--" ]]; do
    expected+=("$1")
    shift
  done

  shift

  output="$("$@" 2>&1)" || {
    printf '%s\n' "${output}"
    return 1
  }

  printf '%s\n' "${output}"

  for needle in "${expected[@]}"; do
    if ! grep -Fq -- "${needle}" <<<"${output}"; then
      return 1
    fi
  done
}

run_and_expect_exact_lines() {
  local expected=()
  local output
  local needle

  while [[ "$#" -gt 0 && "$1" != "--" ]]; do
    expected+=("$1")
    shift
  done

  shift

  output="$("$@" 2>&1)" || {
    printf '%s\n' "${output}"
    return 1
  }

  printf '%s\n' "${output}"

  for needle in "${expected[@]}"; do
    if ! grep -Fqx -- "${needle}" <<<"${output}"; then
      return 1
    fi
  done
}

run_and_expect_failure() {
  local expected=()
  local output
  local needle

  while [[ "$#" -gt 0 && "$1" != "--" ]]; do
    expected+=("$1")
    shift
  done

  shift

  if output="$("$@" 2>&1)"; then
    printf '%s\n' "${output}"
    return 1
  fi

  printf '%s\n' "${output}"

  for needle in "${expected[@]}"; do
    if ! grep -Fq -- "${needle}" <<<"${output}"; then
      return 1
    fi
  done
}

echo "[1/13] Rebuilding and starting the stack"
docker compose down -v --remove-orphans >/dev/null 2>&1 || true
rm -rf ./.data/warehouse/*
docker compose up -d --build

echo "[2/13] Waiting for core services"
wait_for_container hb-kdc healthy
wait_for_container hb-openldap healthy
wait_for_container hb-postgres healthy
wait_for_container hb-hive-metastore healthy
wait_for_port 10000
wait_for_port 10001
wait_for_port 21050
wait_for_port 21051

echo "[3/13] Waiting for localized demo data seed"
wait_for_container hb-dataset-seed exited
if [[ "$(docker inspect -f '{{.State.ExitCode}}' hb-dataset-seed)" != "0" ]]; then
  echo "hb-dataset-seed failed." >&2
  docker logs hb-dataset-seed >&2 || true
  exit 1
fi

echo "[4/13] Validating KDC principals"
docker exec hb-kdc bash -lc "kadmin.local -q 'listprincs'"

echo "[5/13] Validating Kerberos password and keytab auth"
docker exec hb-kerberos-client bash -lc "printf '%s\n' 'talend123' | kinit talend@EXAMPLE.COM && kdestroy"
docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && klist && kdestroy"

echo "[6/13] Validating Hive with LDAP username/password"
retry_cmd 12 run_and_expect "Acme Retail" -- \
  docker exec hb-kerberos-client bash -lc "hive-jdbc -u 'jdbc:hive2://hive-server2-open:10000/default' -n 'admin' -p 'Admin123$' -e 'select customer_id, customer_name from demo_sales_en.customers limit 1;'"

echo "[7/13] Validating Hive with Kerberos"
retry_cmd 12 run_and_expect "1001" "ENVIADO" -- \
  docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && hive-jdbc -u 'jdbc:hive2://hive-server2:10000/default;principal=hive/localhost@EXAMPLE.COM;auth=kerberos' -e 'select pedido_id, status_pedido from demo_vendas_ptbr.pedidos limit 1;' && kdestroy"

echo "[8/13] Validating Impala with LDAP username/password"
retry_cmd 12 run_and_expect_exact_lines 8 -- \
  docker exec hb-kerberos-client bash -lc "hive-jdbc -u 'jdbc:hive2://impala-daemon-open:21050/default' -n 'admin' -p 'Admin123$' -e 'select count(*) from demo_sales_en.customers;'"

echo "[9/13] Validating Impala with Kerberos"
retry_cmd 12 run_and_expect_exact_lines 8 -- \
  docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && hive-jdbc -u 'jdbc:hive2://impala-daemon:21050/default;principal=impala/impala.hadoop.local@EXAMPLE.COM;auth=kerberos' -e 'select count(*) from demo_ventas_esmx.clientes;' && kdestroy"

echo "[10/13] Validating localized schemas in all languages"
retry_cmd 12 run_and_expect demo_sales_en demo_vendas_ptbr demo_ventas_esmx -- \
  docker exec hb-kerberos-client bash -lc "hive-jdbc -u 'jdbc:hive2://hive-server2-open:10000/default' -n 'admin' -p 'Admin123$' -e 'show databases like \"demo_*\";'"

echo "[11/13] Validating HDFS read/write path"
retry_cmd 12 run_and_expect smoke-hdfs -- \
  docker exec hb-namenode /bin/bash -c 'export PATH=/opt/hadoop-3.2.1/bin:$PATH; printf "smoke-hdfs\n" >/tmp/smoke-hdfs.txt; hdfs dfs -mkdir -p /tmp/smoke-test; hdfs dfs -put -f /tmp/smoke-hdfs.txt /tmp/smoke-test/input.txt; hdfs dfs -cat /tmp/smoke-test/input.txt'

echo "[12/13] Validating LDAP rejects invalid credentials"
run_and_expect_failure "Error validating the login" -- \
  docker exec hb-kerberos-client bash -lc "hive-jdbc -u 'jdbc:hive2://hive-server2-open:10000/default' -n 'admin' -p 'wrongpass' -e 'show databases;'"

echo "[13/13] Validating Kerberos endpoints reject missing tickets"
run_and_expect_failure "GSS initiate failed" -- \
  docker exec hb-kerberos-client bash -lc "kdestroy >/dev/null 2>&1 || true; hive-jdbc -u 'jdbc:hive2://impala-daemon:21050/default;principal=impala/impala.hadoop.local@EXAMPLE.COM;auth=kerberos' -e 'show databases;'"

echo "Smoke test completed successfully."
