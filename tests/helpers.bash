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