#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUTPUT_DIR="${SCRIPT_DIR}/exported-configs"
LOCAL_KEYTAB_PATH="${SCRIPT_DIR}/talend.user.keytab"
KDC_CONTAINER_NAME="${KDC_CONTAINER_NAME:-hb-kdc}"
KDC_KEYTAB_PATH="${KDC_KEYTAB_PATH:-/keytabs/talend.user.keytab}"

OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"

usage() {
  cat <<'EOF'
Uso:
  ./export-current-stack-configs.sh [--output-dir DIR]

Descrição:
  Extrai dos stacks Docker em execução os arquivos:
  - core-site.xml
  - hdfs-site.xml
  - yarn-site.xml
  - hive-site.xml
  - mapred-site.xml
  - talend.user.keytab

  Gera dois pacotes separados:
  - um .tar.gz para o stack kerberos
  - um .tar.gz para o stack open
EOF
}

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "comando obrigatório não encontrado: $1"
}

container_running() {
  local container_name="$1"
  local running

  running="$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null || true)"
  [[ "$running" == "true" ]]
}

copy_config() {
  local container_name="$1"
  local source_path="$2"
  local target_path="$3"

  docker cp "${container_name}:${source_path}" "$target_path"
}

copy_keytab() {
  local target_path="$1"

  if [[ -f "$LOCAL_KEYTAB_PATH" ]]; then
    cp "$LOCAL_KEYTAB_PATH" "$target_path"
  elif container_running "$KDC_CONTAINER_NAME"; then
    docker cp "${KDC_CONTAINER_NAME}:${KDC_KEYTAB_PATH}" "$target_path"
  else
    fail "keytab não encontrada em ${LOCAL_KEYTAB_PATH} e container ${KDC_CONTAINER_NAME} não está em execução"
  fi

  chmod 0600 "$target_path"
}

export_stack() {
  local stack="$1"
  local hive_container=""
  local export_dir=""
  local archive_path=""

  case "$stack" in
    kerberos)
      hive_container="hb-impala-daemon"
      ;;
    open)
      hive_container="hb-impala-daemon-open"
      ;;
    *)
      fail "stack inválido em export_stack: $stack"
      ;;
  esac

  container_running "$hive_container" || fail "container não está em execução: $hive_container"
  container_running "hb-resourcemanager" || fail "container não está em execução: hb-resourcemanager"
  container_running "hb-historyserver" || fail "container não está em execução: hb-historyserver"

  export_dir="${OUTPUT_DIR%/}/${stack}-${TIMESTAMP}"
  archive_path="${OUTPUT_DIR%/}/${stack}-configs-${TIMESTAMP}.tar.gz"

  mkdir -p "$export_dir"

  copy_config "$hive_container" "/opt/impala/conf/core-site.xml" "${export_dir}/core-site.xml"
  copy_config "$hive_container" "/opt/impala/conf/hdfs-site.xml" "${export_dir}/hdfs-site.xml"
  copy_config "$hive_container" "/opt/impala/conf/hive-site.xml" "${export_dir}/hive-site.xml"
  copy_config "hb-resourcemanager" "/etc/hadoop/yarn-site.xml" "${export_dir}/yarn-site.xml"
  copy_config "hb-historyserver" "/etc/hadoop/mapred-site.xml" "${export_dir}/mapred-site.xml"
  copy_keytab "${export_dir}/talend.user.keytab"

  tar -C "$export_dir" -czf "$archive_path" \
    core-site.xml \
    hdfs-site.xml \
    yarn-site.xml \
    hive-site.xml \
    mapred-site.xml \
    talend.user.keytab

  log "Stack exportado: $stack"
  log "Diretório: $export_dir"
  log "Arquivo: $archive_path"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      [[ $# -ge 2 ]] || fail "faltou valor para --output-dir"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "argumento inválido: $1"
      ;;
  esac
done

require_cmd docker
require_cmd tar

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

export_stack "kerberos"
export_stack "open"
