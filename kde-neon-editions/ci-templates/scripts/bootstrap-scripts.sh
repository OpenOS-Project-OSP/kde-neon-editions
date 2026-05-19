#!/usr/bin/env sh
# bootstrap-scripts.sh — resolve SCRIPTS_DIR for CI jobs.
#
# Option A (CI): clone kde-neon-editions via CI_JOB_TOKEN and use its
#   ci-templates/scripts/ as the authoritative script source.
# Option B (fallback): use the local scripts/ copies in the edition repo.
#
# Usage (source this file, do not execute it):
#   . scripts/bootstrap-scripts.sh
#
# After sourcing, SCRIPTS_DIR is set and exported.

KNE_REPO="https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.com/openos-project/kde-ecosystem-deving/neon-deving/kde-neon-editions.git"
KNE_CLONE="/tmp/kde-neon-editions"
KNE_SCRIPTS="${KNE_CLONE}/kde-neon-editions/ci-templates/scripts"

if [ -n "${CI_JOB_TOKEN:-}" ] && command -v git >/dev/null 2>&1; then
  # Always re-clone if the scripts directory is missing (handles stale /tmp state)
  if [ ! -d "${KNE_SCRIPTS}" ]; then
    rm -rf "${KNE_CLONE}"
    echo "==> Cloning kde-neon-editions scripts (Option A)"
    git clone --depth=1 "${KNE_REPO}" "${KNE_CLONE}" 2>/dev/null || true
  fi
fi

if [ -d "${KNE_SCRIPTS}" ]; then
  SCRIPTS_DIR="${KNE_SCRIPTS}"
  echo "==> SCRIPTS_DIR (Option A): ${SCRIPTS_DIR}"
else
  # Option B: fall back to the local scripts/ directory in the edition repo.
  # This file is sourced (not executed), so $0 is the shell binary — not this
  # script's path. Use CI_PROJECT_DIR when available (GitLab CI sets it
  # automatically), otherwise assume the caller's working directory is the
  # repo root.
  if [ -n "${CI_PROJECT_DIR:-}" ]; then
    SCRIPTS_DIR="${CI_PROJECT_DIR}/scripts"
  else
    SCRIPTS_DIR="$(pwd)/scripts"
  fi
  echo "==> SCRIPTS_DIR (Option B fallback): ${SCRIPTS_DIR}"
fi

export SCRIPTS_DIR
