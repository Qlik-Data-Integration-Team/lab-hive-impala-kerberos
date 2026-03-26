#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

CURRENT_BRANCH="$(git branch --show-current)"

if [[ -z "${CURRENT_BRANCH}" ]]; then
  echo "Cannot update: detached HEAD."
  exit 1
fi

UPSTREAM_BRANCH="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

if [[ -z "${UPSTREAM_BRANCH}" ]]; then
  echo "Cannot update: branch '${CURRENT_BRANCH}' has no upstream configured."
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  echo "Cannot update: working tree has local changes."
  echo "Commit, stash, or discard them before running ./update.sh."
  exit 1
fi

echo "Fetching ${UPSTREAM_BRANCH}..."
git fetch --prune

LOCAL_HEAD="$(git rev-parse HEAD)"
UPSTREAM_HEAD="$(git rev-parse "${UPSTREAM_BRANCH}")"

if [[ "${LOCAL_HEAD}" == "${UPSTREAM_HEAD}" ]]; then
  echo "Already up to date with ${UPSTREAM_BRANCH}."
  exit 0
fi

echo "Fast-forwarding ${CURRENT_BRANCH} to ${UPSTREAM_BRANCH}..."
git pull --ff-only

echo "Update complete."
