#!/usr/bin/env bash
set -euo pipefail

cat >/usr/local/bin/hive-jdbc <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export HIVE_HOME=/opt/hive
export HADOOP_HOME=/opt/hadoop
export KRB5CCNAME="${KRB5CCNAME:-FILE:/tmp/krb5cc_0}"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djavax.security.auth.useSubjectCredsOnly=false"
exec /opt/hive/bin/beeline "$@"
EOF

chmod +x /usr/local/bin/hive-jdbc

if [[ "$#" -gt 0 ]]; then
  exec "$@"
fi

exec tail -f /dev/null
