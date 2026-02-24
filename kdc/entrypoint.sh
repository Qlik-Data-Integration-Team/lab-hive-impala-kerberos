#!/usr/bin/env bash
set -euo pipefail

REALM="${KRB5_REALM:-CLOUDERA.LOCAL}"
ADMIN_PW="${KRB5_ADMIN_PASSWORD:-admin123}"
USER_PW="${KRB5_USER_PASSWORD:-cloudera123}"
SERVICE_PW="${KRB5_SERVICE_PASSWORD:-service123}"
DB_FILE="/var/lib/krb5kdc/principal"
STASH_FILE="/etc/krb5kdc/.k5.${REALM}"

if [ ! -f "${DB_FILE}" ]; then
  printf '%s\n%s\n' "$ADMIN_PW" "$ADMIN_PW" | kdb5_util create -s -r "$REALM"
fi

if [ ! -f "${STASH_FILE}" ]; then
  kdb5_util -r "$REALM" -P "$ADMIN_PW" stash -f "${STASH_FILE}"
fi

if [ ! -f "${DB_FILE}" ] || [ ! -f "${STASH_FILE}" ]; then
  echo "Kerberos DB initialization failed. Missing ${DB_FILE} or ${STASH_FILE}."
  exit 1
fi

# Admin principal for remote kadmin usage.
kadmin.local -q "addprinc -pw ${ADMIN_PW} admin/admin@${REALM}" || true
kadmin.local -q "addprinc -pw ${USER_PW} cloudera@${REALM}" || true

# Service principals used by the quickstart node.
kadmin.local -q "addprinc -randkey hdfs/quickstart.cloudera.local@${REALM}" || true
kadmin.local -q "addprinc -randkey yarn/quickstart.cloudera.local@${REALM}" || true
kadmin.local -q "addprinc -randkey mapred/quickstart.cloudera.local@${REALM}" || true
kadmin.local -q "addprinc -randkey HTTP/quickstart.cloudera.local@${REALM}" || true
kadmin.local -q "addprinc -randkey cloudera-scm/quickstart.cloudera.local@${REALM}" || true

mkdir -p /keytabs
kadmin.local -q "ktadd -k /keytabs/hdfs.keytab hdfs/quickstart.cloudera.local@${REALM}"
kadmin.local -q "ktadd -k /keytabs/yarn.keytab yarn/quickstart.cloudera.local@${REALM}"
kadmin.local -q "ktadd -k /keytabs/mapred.keytab mapred/quickstart.cloudera.local@${REALM}"
kadmin.local -q "ktadd -k /keytabs/http.keytab HTTP/quickstart.cloudera.local@${REALM}"
kadmin.local -q "ktadd -k /keytabs/cloudera-scm.keytab cloudera-scm/quickstart.cloudera.local@${REALM}"

echo "*/admin@${REALM} *" > /etc/krb5kdc/kadm5.acl

krb5kdc
exec kadmind -nofork
