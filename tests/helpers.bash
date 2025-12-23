#!/usr/bin/env bash
set -euo pipefail

run_healthcheck_action_sh() {
  local -a cmd=("$@")

  local repo_root
  repo_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

  HC_JSON_FILE="$(mktemp)"

  export DOCKER_HEALTH_REPORT_FORMAT="${DOCKER_HEALTH_REPORT_FORMAT:-json}"
  export DOCKER_HEALTH_REPORT_JSON_FILE="$HC_JSON_FILE"
  export DOCKER_HEALTH_REPORT_FILE="$HC_JSON_FILE"
  export DOCKER_HEALTH_REPORT_OUTPUT_FILE="$HC_JSON_FILE"
  export DOCKER_HEALTH_REPORT_PATH="$HC_JSON_FILE"

  run bash "$repo_root/action.sh" "${cmd[@]}"

  HC_RC="$status"
  HC_STDOUT="$output"

  if [[ -s "$HC_JSON_FILE" ]]; then
    HC_JSON="$(cat "$HC_JSON_FILE")"
    return 0
  fi

  HC_JSON="$(printf '%s\n' "$HC_STDOUT" | awk '
    BEGIN { found=0 }
    {
      if (found==0 && $0 ~ /^[[:space:]]*{/) found=1
      if (found==1) print
    }
  ')"
}

assert_json() {
  local expr="$1"
  [[ -n "${HC_JSON:-}" ]] || { echo "JSON is empty"; return 1; }
  jq -e "$expr" <<<"$HC_JSON" >/dev/null
}