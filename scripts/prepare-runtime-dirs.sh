#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "${ROOT_DIR}/.data/warehouse"
chmod 0777 "${ROOT_DIR}/.data" "${ROOT_DIR}/.data/warehouse"
