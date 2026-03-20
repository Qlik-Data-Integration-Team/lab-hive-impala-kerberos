#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

TARGET_FILE="${ROOT_DIR}/talend.user.keytab"
CONTAINER_NAME="${CONTAINER_NAME:-hb-kdc}"
SOURCE_FILE="${SOURCE_FILE:-/keytabs/talend.user.keytab}"
ATTEMPTS="${ATTEMPTS:-30}"

for ((i=1; i<=ATTEMPTS; i++)); do
  if docker inspect -f '{{.State.Status}}' "${CONTAINER_NAME}" >/dev/null 2>&1; then
    status="$(docker inspect -f '{{.State.Status}}' "${CONTAINER_NAME}")"
    if [[ "${status}" == "running" ]] && docker cp "${CONTAINER_NAME}:${SOURCE_FILE}" "${TARGET_FILE}" >/dev/null 2>&1; then
      chmod 0600 "${TARGET_FILE}"
      echo "Synchronized ${TARGET_FILE}"
      exit 0
    fi
  fi
  sleep 2
done

echo "Could not synchronize ${TARGET_FILE} from ${CONTAINER_NAME}:${SOURCE_FILE}" >&2
exit 1
