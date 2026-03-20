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

# Service principals for HiveServer2 and Impala.
kadmin.local -q "addprinc -randkey hive/localhost@${REALM}" || true
kadmin.local -q "addprinc -randkey HTTP/localhost@${REALM}" || true

# Impala uses host-based service principals for internal RPCs. Include internal
# service hosts plus localhost (for host-side client tests).
for host in localhost impala-statestored impala-catalogd impala.hadoop.local; do
  kadmin.local -q "addprinc -randkey impala/${host}@${REALM}" || true
done

mkdir -p /keytabs
kadmin.local -q "ktadd -k /keytabs/hive.service.keytab hive/localhost@${REALM}"
kadmin.local -q "ktadd -k /keytabs/http.service.keytab HTTP/localhost@${REALM}"
for host in localhost impala-statestored impala-catalogd impala.hadoop.local; do
  kadmin.local -q "ktadd -k /keytabs/impala.service.keytab impala/${host}@${REALM}"
done

# Optional client keytab for scripted tests.
# Preserve the configured password so both password auth and keytab auth work.
kadmin.local -q "ktadd -norandkey -k /keytabs/talend.user.keytab talend@${REALM}"

# Dev-only: allow service containers running as non-root users to read keytabs.
chmod 0644 /keytabs/*.keytab

echo "*/admin@${REALM} *" > /etc/krb5kdc/kadm5.acl

krb5kdc
exec kadmind -nofork
