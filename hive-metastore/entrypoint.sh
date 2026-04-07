#!/usr/bin/env bash
set -euo pipefail

export HIVE_CONF_DIR=/opt/hive/conf
if [ -d "${HIVE_CUSTOM_CONF_DIR:-}" ]; then
  find "${HIVE_CUSTOM_CONF_DIR}" -type f -exec ln -sfn {} "${HIVE_CONF_DIR}"/ \;
  export HADOOP_CONF_DIR="${HIVE_CONF_DIR}"
  export TEZ_CONF_DIR="${HIVE_CONF_DIR}"
fi

export HADOOP_CLIENT_OPTS="${HADOOP_CLIENT_OPTS:-} -Xmx1G ${SERVICE_OPTS:-}"

if [[ -n "${KINIT_PRINCIPAL:-}" && -n "${KINIT_KEYTAB:-}" ]]; then
  if command -v kinit >/dev/null 2>&1; then
    kinit -k -t "${KINIT_KEYTAB}" "${KINIT_PRINCIPAL}"
  else
    echo "WARNING: kinit not available; continuing without shell pre-auth." >&2
  fi
fi

# Bootstrap the schema with the stock Hive schematool when the DB is empty.
if ! /opt/hive/bin/schematool -dbType postgres -info >/dev/null 2>&1; then
  /opt/hive/bin/schematool -dbType postgres -initSchema
fi

if command -v psql >/dev/null 2>&1; then
  export PGPASSWORD="${METASTORE_DB_PASSWORD:-hive123}"
  psql \
    -h "${METASTORE_DB_HOST:-postgres}" \
    -p "${METASTORE_DB_PORT:-5432}" \
    -U "${METASTORE_DB_USER:-hive}" \
    -d "${METASTORE_DB_NAME:-metastore}" <<'SQL'
ALTER TABLE "CTLGS" ADD COLUMN IF NOT EXISTS "CREATE_TIME" bigint;
UPDATE "CTLGS" SET "CREATE_TIME" = 0 WHERE "CREATE_TIME" IS NULL;
ALTER TABLE "CTLGS" ALTER COLUMN "CREATE_TIME" SET DEFAULT 0;
ALTER TABLE "CTLGS" ALTER COLUMN "CREATE_TIME" SET NOT NULL;

ALTER TABLE "DBS" ADD COLUMN IF NOT EXISTS "CREATE_TIME" bigint;
ALTER TABLE "DBS" ADD COLUMN IF NOT EXISTS "DATACONNECTOR_NAME" character varying(128);
ALTER TABLE "DBS" ADD COLUMN IF NOT EXISTS "DB_MANAGED_LOCATION_URI" character varying(4000);
ALTER TABLE "DBS" ADD COLUMN IF NOT EXISTS "REMOTE_DBNAME" character varying(128);
ALTER TABLE "DBS" ADD COLUMN IF NOT EXISTS "TYPE" character varying(16);
UPDATE "DBS" SET "CREATE_TIME" = 0 WHERE "CREATE_TIME" IS NULL;
UPDATE "DBS" SET "CTLG_NAME" = 'hive' WHERE "CTLG_NAME" IS NULL;
ALTER TABLE "DBS" ALTER COLUMN "CREATE_TIME" SET DEFAULT 0;
ALTER TABLE "DBS" ALTER COLUMN "CREATE_TIME" SET NOT NULL;
ALTER TABLE "DBS" ALTER COLUMN "CTLG_NAME" SET DEFAULT 'hive';
ALTER TABLE "DBS" ALTER COLUMN "CTLG_NAME" SET NOT NULL;

ALTER TABLE "TBLS" ADD COLUMN IF NOT EXISTS "WRITE_ID" bigint;
UPDATE "TBLS" SET "WRITE_ID" = 0 WHERE "WRITE_ID" IS NULL;
ALTER TABLE "TBLS" ALTER COLUMN "WRITE_ID" SET DEFAULT 0;
ALTER TABLE "TBLS" ALTER COLUMN "WRITE_ID" SET NOT NULL;

ALTER TABLE "TAB_COL_STATS" ADD COLUMN IF NOT EXISTS "ENGINE" character varying(128);
ALTER TABLE "PART_COL_STATS" ADD COLUMN IF NOT EXISTS "ENGINE" character varying(128);
SQL
fi

HIVE_COMPAT_LIBS=(
  /opt/hive/lib/javax.jdo-3.2.0-m3.jar
  /opt/hive/lib/jdo-api-3.0.1.jar
)

exec java \
  -Xmx1G \
  ${SERVICE_OPTS:-} \
  -cp "${HIVE_CONF_DIR}:$(IFS=:; echo "${HIVE_COMPAT_LIBS[*]}"):/opt/impala-lib/*" \
  org.apache.hadoop.hive.metastore.HiveMetaStore \
  -p 9083
