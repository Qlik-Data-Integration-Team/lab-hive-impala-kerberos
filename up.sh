#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

./scripts/prepare-runtime-dirs.sh
docker compose up -d --build "$@"
docker compose ps
if [[ "$#" -eq 0 ]]; then
  ./scripts/wait-for-dataset-seed.sh
fi
./sync-keytab.sh
