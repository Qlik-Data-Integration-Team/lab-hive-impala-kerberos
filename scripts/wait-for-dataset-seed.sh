#!/usr/bin/env bash
set -euo pipefail

container_name="${1:-hb-dataset-seed}"
attempts="${2:-120}"

for ((i=1; i<=attempts; i++)); do
  status="$(docker inspect -f '{{.State.Status}}' "${container_name}" 2>/dev/null || true)"
  if [[ "${status}" == "exited" ]]; then
    exit_code="$(docker inspect -f '{{.State.ExitCode}}' "${container_name}")"
    if [[ "${exit_code}" == "0" ]]; then
      echo "${container_name} completed successfully."
      exit 0
    fi
    echo "${container_name} failed with exit code ${exit_code}." >&2
    docker logs "${container_name}" >&2 || true
    exit 1
  fi
  sleep 5
done

echo "Timed out waiting for ${container_name} to complete." >&2
docker logs "${container_name}" >&2 || true
exit 1
