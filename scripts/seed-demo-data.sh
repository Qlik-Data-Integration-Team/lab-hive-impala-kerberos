#!/usr/bin/env bash
set -euo pipefail

wait_for_query() {
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

run_hive_ldap() {
  hive-jdbc -u "jdbc:hive2://hive-server2-open:10000/default" -n "admin" -p 'Admin123$' "$@"
}

run_impala_ldap() {
  hive-jdbc -u "jdbc:hive2://impala-daemon-open:21050/default" -n "admin" -p 'Admin123$' "$@"
}

run_impala_ldap_python() {
  local sql="$1"

  python3 - "$sql" <<'PY'
import sys
from impala.dbapi import connect

sql = sys.argv[1]
conn = connect(
    host="impala-daemon-open",
    port=21050,
    auth_mechanism="LDAP",
    user="admin",
    password="Admin123$",
)
cur = conn.cursor()
cur.execute(sql)
try:
    cur.fetchall()
except Exception:
    pass
cur.close()
conn.close()
PY
}

run_impala_kerberos() {
  kinit -k -t /keytabs/talend.user.keytab talend@EXAMPLE.COM >/dev/null
  trap 'kdestroy >/dev/null 2>&1 || true' RETURN
  hive-jdbc -u "jdbc:hive2://impala-daemon:21050/default;principal=impala/impala.hadoop.local@EXAMPLE.COM;auth=kerberos" "$@"
}

best_effort_impala_catalog_sync() {
  if ! run_impala_ldap_python "invalidate metadata"; then
    echo "WARNING: Impala LDAP catalog refresh failed. Hive datasets were loaded, but Impala may not list them." >&2
    echo "WARNING: The current Impala + metastore combination is reporting a catalog initialization incompatibility." >&2
    return 1
  fi

  if ! run_impala_kerberos -e "invalidate metadata;" >/dev/null; then
    echo "WARNING: Impala Kerberos catalog refresh failed. Hive datasets were loaded, but Impala may not list them." >&2
    return 1
  fi

  if ! wait_for_query 12 run_impala_ldap_python "show tables in demo_sales_en"; then
    echo "WARNING: Impala LDAP did not observe demo_sales_en after metadata refresh." >&2
    return 1
  fi

  if ! wait_for_query 12 run_impala_ldap_python "show tables in demo_vendas_ptbr"; then
    echo "WARNING: Impala LDAP did not observe demo_vendas_ptbr after metadata refresh." >&2
    return 1
  fi

  if ! wait_for_query 12 run_impala_ldap_python "show tables in demo_ventas_esmx"; then
    echo "WARNING: Impala LDAP did not observe demo_ventas_esmx after metadata refresh." >&2
    return 1
  fi

  if ! wait_for_query 12 run_impala_kerberos -e "show tables in demo_sales_en;" >/dev/null; then
    echo "WARNING: Impala Kerberos did not observe demo_sales_en after metadata refresh." >&2
    return 1
  fi

  if ! wait_for_query 12 run_impala_kerberos -e "show tables in demo_vendas_ptbr;" >/dev/null; then
    echo "WARNING: Impala Kerberos did not observe demo_vendas_ptbr after metadata refresh." >&2
    return 1
  fi

  if ! wait_for_query 12 run_impala_kerberos -e "show tables in demo_ventas_esmx;" >/dev/null; then
    echo "WARNING: Impala Kerberos did not observe demo_ventas_esmx after metadata refresh." >&2
    return 1
  fi

  return 0
}

echo "Waiting for Hive LDAP endpoint"
wait_for_query 24 run_hive_ldap -e "show databases;" >/dev/null

echo "Waiting for Impala LDAP endpoint"
wait_for_query 24 run_impala_ldap -e "show databases;" >/dev/null

echo "Waiting for Impala Kerberos endpoint"
wait_for_query 24 run_impala_kerberos -e "show databases;" >/dev/null

echo "Loading localized demo datasets"
run_hive_ldap -f /datasets/demo_sales_en.sql
run_hive_ldap -f /datasets/demo_vendas_ptbr.sql
run_hive_ldap -f /datasets/demo_ventas_esmx.sql

echo "Waiting for Impala catalogs to observe Hive metastore changes"
impala_catalog_ready=false
if best_effort_impala_catalog_sync; then
  impala_catalog_ready=true
fi

echo "Validating localized demo datasets"
run_hive_ldap -e "show tables in demo_sales_en;"
if [[ "${impala_catalog_ready}" == "true" ]]; then
  run_impala_ldap -e "show tables in demo_vendas_ptbr;"
  run_impala_kerberos -e "show tables in demo_ventas_esmx;"
fi

echo "Demo dataset seed completed successfully."
