#!/usr/bin/env bash
set -euo pipefail

REALM="${KRB5_REALM:-EXAMPLE.COM}"
ADMIN_PW="${KRB5_ADMIN_PASSWORD:-admin123}"
TALEND_PW="${KRB5_TALEND_PASSWORD:-talend123}"
DB_FILE="/var/lib/krb5kdc/principal"
STASH_FILE="/etc/krb5kdc/.k5.${REALM}"

if [ ! -f "${DB_FILE}" ]; then
  printf '%s\n%s\n' "$ADMIN_PW" "$ADMIN_PW" | kdb5_util create -s -r "$REALM"
fi

if [ ! -f "${STASH_FILE}" ]; then
  kdb5_util -r "$REALM" -P "$ADMIN_PW" stash -f "${STASH_FILE}"
fi

kadmin.local -q "addprinc -pw ${ADMIN_PW} admin/admin@${REALM}" || true
kadmin.local -q "addprinc -pw ${TALEND_PW} talend@${REALM}" || true

mkdir -p /keytabs

add_service_principal() {
  local service="$1"
  local host="$2"
  kadmin.local -q "addprinc -randkey ${service}/${host}@${REALM}" || true
}

ktadd_many() {
  local keytab="$1"
  shift
  local principal

  rm -f "${keytab}"
  for principal in "$@"; do
    kadmin.local -q "ktadd -k ${keytab} ${principal}"
  done
}

hive_hosts=(
  localhost
  metastore
  metastore.hadoop.local
  hiveserver2
  hiveserver2.hadoop.local
  hiveserver2-open
  hiveserver2-open.hadoop.local
)

http_hosts=(
  localhost
  127.0.0.1
  namenode
  namenode.hadoop.local
  hb-namenode.hbnet
  datanode
  datanode.hadoop.local
  hb-datanode.hbnet
  resourcemanager
  resourcemanager.hadoop.local
  hb-resourcemanager.hbnet
  historyserver
  historyserver.hadoop.local
  hb-historyserver.hbnet
  httpfs
  httpfs.hadoop.local
  hb-httpfs.hbnet
  impala-statestored
  impala-statestored-open
  impala-catalogd
  impala-catalogd-open
  impala.hadoop.local
  impala-open.hadoop.local
  172.30.0.14
  172.30.0.16
  172.30.0.17
)

hdfs_hosts=(
  namenode
  namenode.hadoop.local
  hb-namenode.hbnet
  datanode
  datanode.hadoop.local
  hb-datanode.hbnet
)

yarn_hosts=(
  resourcemanager
  resourcemanager.hadoop.local
  hb-resourcemanager.hbnet
  nodemanager
  nodemanager.hadoop.local
  hb-nodemanager.hbnet
)

mapred_hosts=(
  historyserver
  historyserver.hadoop.local
  hb-historyserver.hbnet
)

httpfs_hosts=(
  httpfs
  httpfs.hadoop.local
  hb-httpfs.hbnet
)

impala_hosts=(
  localhost
  127.0.0.1
  impala-statestored
  impala-statestored-open
  impala-catalogd
  impala-catalogd-open
  impala.hadoop.local
  impala-open.hadoop.local
  172.30.0.14
  172.30.0.16
  172.30.0.17
)

for host in "${hive_hosts[@]}"; do
  add_service_principal hive "${host}"
done

for host in "${http_hosts[@]}"; do
  add_service_principal HTTP "${host}"
done

for host in "${hdfs_hosts[@]}"; do
  add_service_principal hdfs "${host}"
done

for host in "${yarn_hosts[@]}"; do
  add_service_principal yarn "${host}"
done

for host in "${mapred_hosts[@]}"; do
  add_service_principal mapred "${host}"
done

for host in "${httpfs_hosts[@]}"; do
  add_service_principal httpfs "${host}"
done

for host in "${impala_hosts[@]}"; do
  add_service_principal impala "${host}"
done

ktadd_many /keytabs/hive.service.keytab \
  "hive/localhost@${REALM}" \
  "hive/metastore@${REALM}" \
  "hive/metastore.hadoop.local@${REALM}" \
  "hive/hiveserver2@${REALM}" \
  "hive/hiveserver2.hadoop.local@${REALM}" \
  "hive/hiveserver2-open@${REALM}" \
  "hive/hiveserver2-open.hadoop.local@${REALM}"

ktadd_many /keytabs/http.service.keytab \
  "HTTP/localhost@${REALM}" \
  "HTTP/127.0.0.1@${REALM}" \
  "HTTP/namenode@${REALM}" \
  "HTTP/namenode.hadoop.local@${REALM}" \
  "HTTP/hb-namenode.hbnet@${REALM}" \
  "HTTP/datanode@${REALM}" \
  "HTTP/datanode.hadoop.local@${REALM}" \
  "HTTP/hb-datanode.hbnet@${REALM}" \
  "HTTP/resourcemanager@${REALM}" \
  "HTTP/resourcemanager.hadoop.local@${REALM}" \
  "HTTP/hb-resourcemanager.hbnet@${REALM}" \
  "HTTP/historyserver@${REALM}" \
  "HTTP/historyserver.hadoop.local@${REALM}" \
  "HTTP/hb-historyserver.hbnet@${REALM}" \
  "HTTP/httpfs@${REALM}" \
  "HTTP/httpfs.hadoop.local@${REALM}" \
  "HTTP/hb-httpfs.hbnet@${REALM}" \
  "HTTP/impala-statestored@${REALM}" \
  "HTTP/impala-statestored-open@${REALM}" \
  "HTTP/impala-catalogd@${REALM}" \
  "HTTP/impala-catalogd-open@${REALM}" \
  "HTTP/impala.hadoop.local@${REALM}" \
  "HTTP/impala-open.hadoop.local@${REALM}" \
  "HTTP/172.30.0.14@${REALM}" \
  "HTTP/172.30.0.16@${REALM}" \
  "HTTP/172.30.0.17@${REALM}"

ktadd_many /keytabs/hdfs.service.keytab \
  "hdfs/namenode@${REALM}" \
  "hdfs/namenode.hadoop.local@${REALM}" \
  "hdfs/hb-namenode.hbnet@${REALM}" \
  "hdfs/datanode@${REALM}" \
  "hdfs/datanode.hadoop.local@${REALM}" \
  "hdfs/hb-datanode.hbnet@${REALM}"

ktadd_many /keytabs/yarn.service.keytab \
  "yarn/resourcemanager@${REALM}" \
  "yarn/resourcemanager.hadoop.local@${REALM}" \
  "yarn/hb-resourcemanager.hbnet@${REALM}" \
  "yarn/nodemanager@${REALM}" \
  "yarn/nodemanager.hadoop.local@${REALM}" \
  "yarn/hb-nodemanager.hbnet@${REALM}"

ktadd_many /keytabs/mapred.service.keytab \
  "mapred/historyserver@${REALM}" \
  "mapred/historyserver.hadoop.local@${REALM}" \
  "mapred/hb-historyserver.hbnet@${REALM}"

ktadd_many /keytabs/httpfs.service.keytab \
  "httpfs/httpfs@${REALM}" \
  "httpfs/httpfs.hadoop.local@${REALM}" \
  "httpfs/hb-httpfs.hbnet@${REALM}"

ktadd_many /keytabs/impala.service.keytab \
  "impala/localhost@${REALM}" \
  "impala/127.0.0.1@${REALM}" \
  "impala/impala-statestored@${REALM}" \
  "impala/impala-statestored-open@${REALM}" \
  "impala/impala-catalogd@${REALM}" \
  "impala/impala-catalogd-open@${REALM}" \
  "impala/impala.hadoop.local@${REALM}" \
  "impala/impala-open.hadoop.local@${REALM}" \
  "impala/172.30.0.14@${REALM}" \
  "impala/172.30.0.16@${REALM}" \
  "impala/172.30.0.17@${REALM}"

# Optional client keytab for scripted tests.
# Preserve the configured password so both password auth and keytab auth work.
kadmin.local -q "ktadd -norandkey -k /keytabs/talend.user.keytab talend@${REALM}"

# Dev-only: allow service containers running as non-root users to read keytabs.
chmod 0644 /keytabs/*.keytab

echo "*/admin@${REALM} *" > /etc/krb5kdc/kadm5.acl

krb5kdc
exec kadmind -nofork
