#!/usr/bin/env bash
set -euo pipefail

_strip_ansi() {
  sed -r 's/\x1B\[[0-9;?]*[ -/]*[@-~]//g'
}

_extract_last_json_object() {
  perl -0777 -ne '
    my $s = $_;

    # strip ANSI just in case (дублируем защиту)
    $s =~ s/\e\[[0-9;?]*[ -\/]*[@-~]//g;

    my $best = "";
    my $start = -1;
    my $depth = 0;

    my @c = split(//, $s);
    for (my $i=0; $i<@c; $i++) {
      my $ch = $c[$i];
      if ($ch eq "{") {
        if ($depth == 0) { $start = $i; }
        $depth++;
      } elsif ($ch eq "}") {
        if ($depth > 0) {
          $depth--;
          if ($depth == 0 && $start >= 0) {
            my $cand = substr($s, $start, $i - $start + 1);
            $best = $cand; # сохраняем последний завершённый объект
            $start = -1;
          }
        }
      }
    }

    print $best;
  '
}

_hc_reset_compose_tracking() {
  HC_COMPOSE_PROJECT=""
  HC_COMPOSE_FILES_ARGS=()
  HC_JSON_FILE=""
  HC_RC=""
  HC_STDOUT_RAW=""
  HC_STDOUT=""
  HC_JSON=""
}

_hc_is_docker_compose_cmd() {
  local -a cmd=("$@")
  [[ "${#cmd[@]}" -ge 2 ]] || return 1
  [[ "${cmd[0]}" == "docker" && "${cmd[1]}" == "compose" ]]
}

_hc_collect_compose_files_args() {
  local -a cmd=("$@")
  HC_COMPOSE_FILES_ARGS=()

  local i=0
  while [[ $i -lt ${#cmd[@]} ]]; do
    case "${cmd[$i]}" in
      -f|--file)
        if [[ $((i+1)) -lt ${#cmd[@]} ]]; then
          HC_COMPOSE_FILES_ARGS+=("${cmd[$i]}" "${cmd[$((i+1))]}")
          i=$((i+2))
          continue
        fi
        ;;
    esac
    i=$((i+1))
  done
}

_hc_make_project_name() {
  # Bats sets BATS_TEST_NAME; keep name docker-compose friendly.
  # Add PID + RANDOM to avoid collisions across parallel runs.
  local base="${BATS_TEST_NAME:-test}"
  base="$(printf '%s' "$base" | tr -c '[:alnum:]' '_' | tr '[:upper:]' '[:lower:]')"
  echo "hc_${base}_${$}_${RANDOM}"
}

_hc_compose_down_last_project() {
  # Never fail teardown
  local prev_extglob_state
  prev_extglob_state="$(shopt -p extglob)"
  shopt -s extglob
  local previous_errexit_state="$-"
  set +e

  if [[ -n "${HC_COMPOSE_PROJECT:-}" ]]; then
    docker compose -p "$HC_COMPOSE_PROJECT" "${HC_COMPOSE_FILES_ARGS[@]}" down -v --remove-orphans >/dev/null 2>&1
  fi

  if [[ -n "${HC_JSON_FILE:-}" && -f "${HC_JSON_FILE:-}" ]]; then
    rm -f "$HC_JSON_FILE" >/dev/null 2>&1
  fi

  if [[ $previous_errexit_state == *e* ]]; then
    set -e
  fi
  eval "$prev_extglob_state"
}

# Bats automatically calls teardown() after EACH test if it exists.
teardown() {
  _hc_compose_down_last_project
  _hc_reset_compose_tracking
}

run_healthcheck_action_sh() {
  local -a cmd=("$@")

  local repo_root
  repo_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

  # Reset tracking for this run
  _hc_reset_compose_tracking

  HC_JSON_FILE="$(mktemp)"

  export DOCKER_HEALTH_REPORT_FORMAT="${DOCKER_HEALTH_REPORT_FORMAT:-json}"

  export DOCKER_HEALTH_REPORT_JSON_FILE="$HC_JSON_FILE"
  export DOCKER_HEALTH_REPORT_FILE="$HC_JSON_FILE"
  export DOCKER_HEALTH_REPORT_OUTPUT_FILE="$HC_JSON_FILE"
  export DOCKER_HEALTH_REPORT_PATH="$HC_JSON_FILE"

  # If this is `docker compose ...`, inject unique project name and remember -f args for teardown.
  if _hc_is_docker_compose_cmd "${cmd[@]}"; then
    HC_COMPOSE_PROJECT="$(_hc_make_project_name)"

    # Collect compose file args for teardown from the original command.
    _hc_collect_compose_files_args "${cmd[@]}"

    # Rebuild command with `-p <project>` injected right after `docker compose`
    local -a rewritten=( "docker" "compose" "-p" "$HC_COMPOSE_PROJECT" )
    local i=2
    while [[ $i -lt ${#cmd[@]} ]]; do
      rewritten+=( "${cmd[$i]}" )
      i=$((i+1))
    done
    cmd=( "${rewritten[@]}" )
  fi

  run bash "$repo_root/entrypoint.sh" "${cmd[@]}"

  HC_RC="$status"
  HC_STDOUT_RAW="$output"
  HC_STDOUT="$(printf '%s' "$HC_STDOUT_RAW" | _strip_ansi)"

  if [[ -s "$HC_JSON_FILE" ]]; then
    HC_JSON="$(cat "$HC_JSON_FILE" | _strip_ansi)"
    return 0
  fi

  HC_JSON="$(printf '%s' "$HC_STDOUT" | _extract_last_json_object)"
}

assert_json() {
  local expr="$1"
  [[ -n "${HC_JSON:-}" ]] || { echo "JSON is empty"; return 1; }
  jq -e "$expr" <<<"$HC_JSON" >/dev/null
}
