#!/usr/bin/env bash
# sync-upstream.sh — pull latest commits from kde-groups/neon into a
# tracking branch in this repo.
#
# Source repos live at:
#   gitlab.com/openos-project/kde-ecosystem-deving/kde-groups/neon
#
# Uses CI_JOB_TOKEN to fetch from the internal GitLab group (no PAT needed).
# Uses GITLAB_TOKEN for push if set; falls back to CI_JOB_TOKEN otherwise.
# CI_JOB_TOKEN can push to the job's own project without extra setup.
#
# Required environment variables:
#   UPSTREAM_REPO_URL   — e.g. https://gitlab.com/openos-project/kde-ecosystem-deving/kde-groups/neon/neon/seeds.git
#   UPSTREAM_BRANCH     — e.g. Neon/release
#   CI_PROJECT_URL      — set automatically by GitLab CI
#   CI_JOB_TOKEN        — set automatically by GitLab CI (used for fetch and push fallback)
#   GITLAB_TOKEN        — optional: project access token with write_repository scope;
#                         if unset, CI_JOB_TOKEN is used for push instead
set -euo pipefail

: "${UPSTREAM_REPO_URL:?UPSTREAM_REPO_URL must be set}"
: "${UPSTREAM_BRANCH:?UPSTREAM_BRANCH must be set}"
: "${CI_PROJECT_URL:?CI_PROJECT_URL must be set}"

TRACKING_BRANCH="upstream/${UPSTREAM_BRANCH}"

# Build authenticated fetch URL using CI_JOB_TOKEN (works for any repo on
# the same GitLab instance without needing a separate PAT)
if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
  FETCH_URL="${UPSTREAM_REPO_URL/https:\/\//https://gitlab-ci-token:${CI_JOB_TOKEN}@}"
else
  # Local/manual run — use URL as-is (requires SSH key or credential helper)
  FETCH_URL="${UPSTREAM_REPO_URL}"
fi

echo "==> Fetching ${UPSTREAM_BRANCH} from kde-groups/neon"
git remote add upstream "${FETCH_URL}" 2>/dev/null || \
  git remote set-url upstream "${FETCH_URL}"

# Fetch without depth limit — a shallow fetch cannot be pushed as a new branch
# to a repo that has no prior history for that ref.
git fetch upstream "${UPSTREAM_BRANCH}"

echo "==> Updating tracking branch: ${TRACKING_BRANCH}"
git checkout -B "${TRACKING_BRANCH}" FETCH_HEAD

# Unshallow the working repo so git can push the new branch without the
# "shallow update not allowed" rejection from the remote.
git fetch --unshallow origin 2>/dev/null || true

# Push back to origin.
# Prefer GITLAB_TOKEN (project access token) if set; fall back to CI_JOB_TOKEN.
# CI_JOB_TOKEN can push to the job's own project without extra setup.
if [[ -n "${GITLAB_TOKEN:-}" ]]; then
  PUSH_TOKEN="${GITLAB_TOKEN}"
  echo "==> Pushing via GITLAB_TOKEN"
else
  : "${CI_JOB_TOKEN:?CI_JOB_TOKEN must be set when GITLAB_TOKEN is absent}"
  PUSH_TOKEN="${CI_JOB_TOKEN}"
  echo "==> Pushing via CI_JOB_TOKEN (GITLAB_TOKEN not set)"
fi

ORIGIN_URL="${CI_PROJECT_URL/https:\/\//https://gitlab-ci-token:${PUSH_TOKEN}@}"
git push "${ORIGIN_URL}" "${TRACKING_BRANCH}" --force

echo "==> Sync complete: ${TRACKING_BRANCH} updated"
