#!/usr/bin/env bash
set -euo pipefail

CONFIG_SOURCE_DIR="${CONFIG_SOURCE_DIR:-/config-resources}"
TARGET_DIR="${HADOOP_CONF_TARGET_DIR:-/etc/hadoop}"

if [[ -d "${CONFIG_SOURCE_DIR}" ]]; then
  shopt -s nullglob
  for file in "${CONFIG_SOURCE_DIR}"/*; do
    if [[ -f "${file}" ]]; then
      cp "${file}" "${TARGET_DIR}/$(basename "${file}")"
    fi
  done
fi

if [[ -n "${KINIT_PRINCIPAL:-}" && -n "${KINIT_KEYTAB:-}" ]]; then
  kinit -k -t "${KINIT_KEYTAB}" "${KINIT_PRINCIPAL}"
fi

exec /entrypoint.sh "$@"
