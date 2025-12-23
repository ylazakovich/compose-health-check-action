#!/usr/bin/env bash
set -euo pipefail

# Runs the same path your composite action uses:
#   bash action.sh <docker compose ...>
#
# Captures:
# - $HC_RC          : exit code from action.sh
# - $HC_STDOUT      : combined stdout/stderr
# - $HC_JSON_FILE   : path to generated JSON report (may be empty or missing)
# - $HC_JSON        : JSON content (if file exists)
#
run_healthcheck_action_sh() {
  local -a cmd=("$@")

  # Make sure we're in repo root (BATS sets $BATS_TEST_DIRNAME)
  local repo_root
  repo_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

  local json_tmp out_tmp
  json_tmp="$(mktemp)"
  out_tmp="$(mktemp)"

  # Enable JSON report generation
  export DOCKER_HEALTH_REPORT_FORMAT="${DOCKER_HEALTH_REPORT_FORMAT:-json}"
  export DOCKER_HEALTH_REPORT_JSON_FILE="$json_tmp"

  # Run action.sh exactly like composite step does
  set +e
  (cd "$repo_root" && bash "./action.sh" "${cmd[@]}") >"$out_tmp" 2>&1
  HC_RC=$?
  set -e

  HC_STDOUT="$(cat "$out_tmp")"
  rm -f "$out_tmp"

  HC_JSON_FILE="$json_tmp"
  if [[ -s "$HC_JSON_FILE" ]]; then
    HC_JSON="$(cat "$HC_JSON_FILE")"
  else
    HC_JSON=""
  fi
}

# Simple helpers for assertions
assert_stdout_contains() {
  local needle="$1"
  if ! grep -Fq "$needle" <<<"$HC_STDOUT"; then
    echo "Expected stdout to contain: $needle" >&2
    echo "---- stdout ----" >&2
    echo "$HC_STDOUT" >&2
    exit 1
  fi
}

assert_stdout_matches_regex() {
  local regex="$1"
  if ! grep -Eq "$regex" <<<"$HC_STDOUT"; then
    echo "Expected stdout to match regex: $regex" >&2
    echo "---- stdout ----" >&2
    echo "$HC_STDOUT" >&2
    exit 1
  fi
}

assert_json() {
  local jq_expr="$1"
  if [[ -z "${HC_JSON:-}" ]]; then
    echo "Expected JSON report, but it is empty/missing. File: ${HC_JSON_FILE:-<none>}" >&2
    echo "---- stdout ----" >&2
    echo "$HC_STDOUT" >&2
    exit 1
  fi
  jq -e "$jq_expr" <<<"$HC_JSON" >/dev/null
}