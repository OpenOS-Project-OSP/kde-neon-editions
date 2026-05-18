#!/usr/bin/env sh
# bootstrap-scripts.sh — resolve SCRIPTS_DIR for CI jobs.
#
# Option A (CI): clone kde-neon-editions via CI_JOB_TOKEN and use its
#   ci-templates/scripts/ as the authoritative script source.
# Option B (fallback): use the local scripts/ copies in the edition repo.
#
# Usage (source this file, do not execute it):
#   . "$(dirname "$0")/bootstrap-scripts.sh"   # from local scripts/
#   . /tmp/bootstrap-scripts.sh                # after curl/wget
#
# After sourcing, SCRIPTS_DIR is set and exported.

KNE_REPO="https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.com/openos-project/kde-ecosystem-deving/neon-deving/kde-neon-editions.git"
KNE_CLONE="/tmp/kde-neon-editions"
KNE_SCRIPTS="${KNE_CLONE}/kde-neon-editions/ci-templates/scripts"

if [ -n "${CI_JOB_TOKEN:-}" ] && [ ! -d "${KNE_CLONE}" ] && command -v git >/dev/null 2>&1; then
  echo "==> Cloning kde-neon-editions scripts (Option A)"
  git clone --depth=1 "${KNE_REPO}" "${KNE_CLONE}" 2>/dev/null || true
fi

if [ -d "${KNE_SCRIPTS}" ]; then
  SCRIPTS_DIR="${KNE_SCRIPTS}"
  echo "==> SCRIPTS_DIR (Option A): ${SCRIPTS_DIR}"
else
  SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
  echo "==> SCRIPTS_DIR (Option B fallback): ${SCRIPTS_DIR}"
fi

export SCRIPTS_DIR
