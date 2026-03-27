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

run_webhdfs_open_internal_roundtrip() {
  docker exec -i hb-kerberos-client bash -s <<'EOF'
set -euo pipefail
payload='smoke-webhdfs-open-internal'
path='/tmp/smoke-webhdfs-open-internal.txt'
printf '%s\n' "${payload}" >/tmp/smoke-webhdfs-open-internal.txt
create_location="$(curl -sS -D - -o /dev/null -X PUT "http://namenode-open:9870/webhdfs/v1${path}?op=CREATE&overwrite=true&user.name=root" | awk '/^Location:/ {print $2}' | tr -d '\r')"
curl -sS -X PUT -H 'Content-Type: application/octet-stream' --data-binary @/tmp/smoke-webhdfs-open-internal.txt "${create_location}" >/dev/null
curl -sS -L "http://namenode-open:9870/webhdfs/v1${path}?op=OPEN&user.name=root"
echo
curl -sS -X DELETE "http://namenode-open:9870/webhdfs/v1${path}?op=DELETE&user.name=root"
EOF
}

run_webhdfs_open_host_roundtrip() {
  local payload_file
  payload_file="$(mktemp)"
  trap 'rm -f "${payload_file}"' RETURN
  printf '%s\n' 'smoke-webhdfs-open-host' >"${payload_file}"

  local path create_location open_location
  path='/tmp/smoke-webhdfs-open-host.txt'
  create_location="$(curl -sS -D - -o /dev/null -X PUT "http://127.0.0.1:9871/webhdfs/v1${path}?op=CREATE&overwrite=true&user.name=root" | awk '/^Location:/ {print $2}' | tr -d '\r')"
  create_location="${create_location/datanode-open.hadoop.local:9865/127.0.0.1:9865}"
  curl -sS -X PUT -H 'Content-Type: application/octet-stream' --data-binary @"${payload_file}" "${create_location}" >/dev/null
  open_location="$(curl -sS -D - -o /dev/null "http://127.0.0.1:9871/webhdfs/v1${path}?op=OPEN&user.name=root" | awk '/^Location:/ {print $2}' | tr -d '\r')"
  open_location="${open_location/datanode-open.hadoop.local:9865/127.0.0.1:9865}"
  curl -sS "${open_location}"
  echo
  curl -sS -X DELETE "http://127.0.0.1:9871/webhdfs/v1${path}?op=DELETE&user.name=root"
}

run_webhdfs_secure_roundtrip() {
  docker exec -i hb-kerberos-client bash -s <<'EOF'
set -euo pipefail
payload='smoke-webhdfs-secure'
path='/tmp/smoke-webhdfs-secure.txt'
cookie='/tmp/smoke-webhdfs-secure.cookie'
printf '%s\n' "${payload}" >/tmp/smoke-webhdfs-secure.txt
kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM
create_location="$(curl --negotiate -u : -c "${cookie}" -b "${cookie}" -sS -D - -o /dev/null -X PUT "http://namenode:9870/webhdfs/v1${path}?op=CREATE&overwrite=true" | awk '/^Location:/ {print $2}' | tr -d '\r')"
curl -sS -X PUT -H 'Content-Type: application/octet-stream' --data-binary @/tmp/smoke-webhdfs-secure.txt "${create_location}" >/dev/null
curl --negotiate -u : -c "${cookie}" -b "${cookie}" -sS -L "http://namenode:9870/webhdfs/v1${path}?op=OPEN"
echo
curl --negotiate -u : -c "${cookie}" -b "${cookie}" -sS -X DELETE "http://namenode:9870/webhdfs/v1${path}?op=DELETE"
kdestroy || true
EOF
}

run_httpfs_open_internal_roundtrip() {
  docker exec -i hb-kerberos-client bash -s <<'EOF'
set -euo pipefail
payload='smoke-httpfs-open-internal'
path='/tmp/smoke-httpfs-open-internal.txt'
printf '%s\n' "${payload}" >/tmp/smoke-httpfs-open-internal.txt
create_location="$(curl -sS -D - -o /dev/null -X PUT "http://httpfs-open:14000/webhdfs/v1${path}?op=CREATE&overwrite=true&user.name=root" | awk '/^Location:/ {print $2}' | tr -d '\r')"
curl -sS -X PUT -H 'Content-Type: application/octet-stream' --data-binary @/tmp/smoke-httpfs-open-internal.txt "${create_location}" >/dev/null
curl -sS "http://httpfs-open:14000/webhdfs/v1${path}?op=OPEN&user.name=root"
echo
curl -sS -X DELETE "http://httpfs-open:14000/webhdfs/v1${path}?op=DELETE&user.name=root"
EOF
}

run_httpfs_open_host_roundtrip() {
  local payload_file
  payload_file="$(mktemp)"
  trap 'rm -f "${payload_file}"' RETURN
  printf '%s\n' 'smoke-httpfs-open-host' >"${payload_file}"

  local path create_location
  path='/tmp/smoke-httpfs-open-host.txt'
  create_location="$(curl -sS -D - -o /dev/null -X PUT "http://127.0.0.1:14001/webhdfs/v1${path}?op=CREATE&overwrite=true&user.name=root" | awk '/^Location:/ {print $2}' | tr -d '\r')"
  curl -sS -X PUT -H 'Content-Type: application/octet-stream' --data-binary @"${payload_file}" "${create_location}" >/dev/null
  curl -sS "http://127.0.0.1:14001/webhdfs/v1${path}?op=OPEN&user.name=root"
  echo
  curl -sS -X DELETE "http://127.0.0.1:14001/webhdfs/v1${path}?op=DELETE&user.name=root"
}

run_httpfs_secure_roundtrip() {
  docker exec -i hb-kerberos-client bash -s <<'EOF'
set -euo pipefail
payload='smoke-httpfs-secure'
path='/tmp/smoke-httpfs-secure.txt'
cookie='/tmp/smoke-httpfs-secure.cookie'
printf '%s\n' "${payload}" >/tmp/smoke-httpfs-secure.txt
kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM
create_location="$(curl --negotiate -u : -c "${cookie}" -b "${cookie}" -sS -D - -o /dev/null -X PUT "http://httpfs.hadoop.local:14000/webhdfs/v1${path}?op=CREATE&overwrite=true" | awk '/^Location:/ {print $2}' | tr -d '\r')"
curl --negotiate -u : -c "${cookie}" -b "${cookie}" -sS -X PUT -H 'Content-Type: application/octet-stream' --data-binary @/tmp/smoke-httpfs-secure.txt "${create_location}" >/dev/null
curl --negotiate -u : -c "${cookie}" -b "${cookie}" -sS "http://httpfs.hadoop.local:14000/webhdfs/v1${path}?op=OPEN"
echo
curl --negotiate -u : -c "${cookie}" -b "${cookie}" -sS -X DELETE "http://httpfs.hadoop.local:14000/webhdfs/v1${path}?op=DELETE"
kdestroy || true
EOF
}

echo "[1/24] Rebuilding and starting the stack"
docker compose down -v --remove-orphans >/dev/null 2>&1 || true
rm -rf ./.data/warehouse/*
docker compose up -d --build

echo "[2/24] Waiting for core services"
wait_for_container hb-kdc healthy
wait_for_container hb-openldap healthy
wait_for_container hb-postgres healthy
wait_for_container hb-hive-metastore healthy
wait_for_container hb-historyserver healthy
wait_for_container hb-httpfs healthy
wait_for_container hb-httpfs-open healthy
wait_for_port 9870
wait_for_port 9871
wait_for_port 10000
wait_for_port 10001
wait_for_port 14000
wait_for_port 14001
wait_for_port 21050
wait_for_port 21051
wait_for_port 19888

echo "[3/24] Waiting for localized demo data seed"
wait_for_container hb-dataset-seed exited
if [[ "$(docker inspect -f '{{.State.ExitCode}}' hb-dataset-seed)" != "0" ]]; then
  echo "hb-dataset-seed failed." >&2
  docker logs hb-dataset-seed >&2 || true
  exit 1
fi

echo "[4/24] Validating KDC principals"
docker exec hb-kdc bash -lc "kadmin.local -q 'listprincs'"

echo "[5/24] Validating Kerberos password and keytab auth"
docker exec hb-kerberos-client bash -lc "printf '%s\n' 'talend123' | kinit talend@EXAMPLE.COM && kdestroy"
docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && klist && kdestroy"

echo "[6/24] Validating Hive with LDAP username/password over Tez"
retry_cmd 12 run_and_expect "Executing on YARN cluster with App id" "| 8    |" -- \
  docker exec hb-kerberos-client bash -lc "hive-jdbc -u 'jdbc:hive2://hive-server2-open:10000/default' -n 'admin' -p 'Admin123$' -e 'select count(*) from demo_sales_en.customers;'"

echo "[7/24] Validating Hive with Kerberos over Tez"
retry_cmd 12 run_and_expect "Executing on YARN cluster with App id" "| 8    |" -- \
  docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && hive-jdbc -u 'jdbc:hive2://hiveserver2.hadoop.local:10000/default;principal=hive/hiveserver2.hadoop.local@EXAMPLE.COM;auth=kerberos' -e 'select count(*) from demo_sales_en.customers;' && kdestroy"

echo "[8/24] Validating Impala with LDAP username/password"
retry_cmd 12 run_and_expect_exact_lines 8 -- \
  docker exec hb-kerberos-client bash -lc "hive-jdbc -u 'jdbc:hive2://impala-daemon-open:21050/default' -n 'admin' -p 'Admin123$' -e 'select count(*) from demo_sales_en.customers;'"

echo "[9/24] Validating Impala with Kerberos"
retry_cmd 12 run_and_expect_exact_lines 8 -- \
  docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && hive-jdbc -u 'jdbc:hive2://impala-daemon:21050/default;principal=impala/impala.hadoop.local@EXAMPLE.COM;auth=kerberos' -e 'select count(*) from demo_ventas_esmx.clientes;' && kdestroy"

echo "[10/24] Validating localized schemas in all languages"
retry_cmd 12 run_and_expect demo_sales_en demo_vendas_ptbr demo_ventas_esmx -- \
  docker exec hb-kerberos-client bash -lc "hive-jdbc -u 'jdbc:hive2://hive-server2-open:10000/default' -n 'admin' -p 'Admin123$' -e 'show databases like \"demo_*\";'"

echo "[11/24] Validating HDFS read/write path"
retry_cmd 12 run_and_expect smoke-hdfs -- \
  docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && printf 'smoke-hdfs\n' >/tmp/smoke-hdfs.txt && /bin/bash /opt/hadoop/bin/hdfs dfs -mkdir -p /tmp/smoke-test && /bin/bash /opt/hadoop/bin/hdfs dfs -put -f /tmp/smoke-hdfs.txt /tmp/smoke-test/input.txt && /bin/bash /opt/hadoop/bin/hdfs dfs -cat /tmp/smoke-test/input.txt && (kdestroy || true)"

echo "[12/24] Validating secure WebHDFS"
retry_cmd 12 run_and_expect "\"pathSuffix\":\"tmp\"" -- \
  docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && curl --negotiate -u : -sS 'http://namenode:9870/webhdfs/v1/?op=LISTSTATUS' && (kdestroy || true)"

echo "[13/24] Validating secure WebHDFS read/write"
retry_cmd 12 run_and_expect "smoke-webhdfs-secure" "\"boolean\":true" -- \
  run_webhdfs_secure_roundtrip

echo "[14/24] Validating open WebHDFS"
retry_cmd 12 run_and_expect "\"pathSuffix\":\"tmp\"" "\"pathSuffix\":\"user\"" -- \
  docker exec hb-kerberos-client bash -lc "curl -sS 'http://namenode-open:9870/webhdfs/v1/?op=LISTSTATUS&user.name=root'"

echo "[15/24] Validating open WebHDFS read/write"
retry_cmd 12 run_and_expect "smoke-webhdfs-open-internal" "\"boolean\":true" -- \
  run_webhdfs_open_internal_roundtrip

echo "[16/24] Validating host-exposed open WebHDFS read/write"
retry_cmd 12 run_and_expect "smoke-webhdfs-open-host" "\"boolean\":true" -- \
  run_webhdfs_open_host_roundtrip

echo "[17/24] Validating open HttpFS"
retry_cmd 12 run_and_expect "\"pathSuffix\":\"tmp\"" -- \
  docker exec hb-kerberos-client bash -lc "curl -sS 'http://httpfs-open:14000/webhdfs/v1/?op=LISTSTATUS&user.name=root'"

echo "[18/24] Validating open HttpFS read/write"
retry_cmd 12 run_and_expect "smoke-httpfs-open-internal" "\"boolean\":true" -- \
  run_httpfs_open_internal_roundtrip

echo "[19/24] Validating host-exposed open HttpFS read/write"
retry_cmd 12 run_and_expect "smoke-httpfs-open-host" "\"boolean\":true" -- \
  run_httpfs_open_host_roundtrip

echo "[20/24] Validating secure HttpFS"
retry_cmd 12 run_and_expect "\"pathSuffix\":\"tmp\"" "\"pathSuffix\":\"user\"" -- \
  docker exec hb-kerberos-client bash -lc "kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM && curl --negotiate -u : -sS 'http://httpfs.hadoop.local:14000/webhdfs/v1/?op=LISTSTATUS' && (kdestroy || true)"

echo "[21/24] Validating secure HttpFS read/write"
retry_cmd 12 run_and_expect "smoke-httpfs-secure" "\"boolean\":true" -- \
  run_httpfs_secure_roundtrip

echo "[22/24] Validating Application History Server"
retry_cmd 12 run_and_expect "\"app\"" -- \
  curl -sS "http://127.0.0.1:19888/ws/v1/applicationhistory/apps"

echo "[23/24] Validating LDAP rejects invalid credentials"
run_and_expect_failure "Invalid Credentials" -- \
  docker exec hb-kerberos-client bash -lc "hive-jdbc -u 'jdbc:hive2://hive-server2-open:10000/default' -n 'admin' -p 'wrongpass' -e 'show databases;'"

echo "[24/24] Validating Kerberos endpoints reject missing tickets"
run_and_expect_failure "No valid credentials provided" "GSS initiate failed" -- \
  docker exec hb-kerberos-client bash -lc "kdestroy >/dev/null 2>&1 || true; if klist -s; then echo 'Kerberos ticket should not exist before the negative-auth test.' >&2; exit 1; fi; hive-jdbc -u 'jdbc:hive2://impala-daemon:21050/default;principal=impala/impala.hadoop.local@EXAMPLE.COM;auth=kerberos' -e 'show databases;'"
echo "[24/24] Expected Kerberos rejection confirmed"

echo "Smoke test completed successfully."
