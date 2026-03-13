#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-./exported-conf}"

require_container() {
  local container_name="$1"
  if ! docker inspect "$container_name" >/dev/null 2>&1; then
    echo "Container not found: $container_name" >&2
    exit 1
  fi
}

copy_config() {
  local container_name="$1"
  local source_path="$2"
  local target_name="$3"

  docker cp "${container_name}:${source_path}" "${OUT_DIR}/${target_name}"
}

mkdir -p "$OUT_DIR"

require_container "hb-impala-daemon"
require_container "hb-resourcemanager"
require_container "hb-historyserver"

copy_config "hb-impala-daemon" "/opt/impala/conf/core-site.xml" "core-site.xml"
copy_config "hb-impala-daemon" "/opt/impala/conf/hdfs-site.xml" "hdfs-site.xml"
copy_config "hb-impala-daemon" "/opt/impala/conf/hive-site.xml" "hive-site.xml"
copy_config "hb-resourcemanager" "/etc/hadoop/yarn-site.xml" "yarn-site.xml"
copy_config "hb-historyserver" "/etc/hadoop/mapred-site.xml" "mapred-site.xml"

echo "Arquivos exportados para: ${OUT_DIR}"
ls -lh "$OUT_DIR"
