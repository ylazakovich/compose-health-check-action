#!/usr/bin/env bats

load '../bats-support/load'
load '../bats-assert/load'
load '../helpers.bash'

@test "docker-command: slow-broken becomes unhealthy and action fails" {
  export INPUT_TIMEOUT="10"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.unhealthy.yml up -d slow-broken"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_failure
  assert_json '.overall.status == "failed"'
  assert_json '.services["slow-broken"] == "unhealthy"'
  assert_json '.summary.unhealthy >= 1'

  assert_output --partial "Last 25 health probe outputs"
  assert_output --partial "Last 25 container log lines"
}

@test "docker-command: respects log-lines input for diagnostics" {
  export INPUT_TIMEOUT="10"
  export INPUT_LOG_LINES="3"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.unhealthy.yml up -d slow-broken"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_failure
  assert_output --partial "Last 3 health probe outputs"
  assert_output --partial "Last 3 container log lines"

  local probe_count
  probe_count="$(printf '%s\n' "$HC_STDOUT" | awk '
/^    Last 3 health probe outputs:/ {inside=1; next}
inside && /^    Last [0-9]+ container log lines:/ {inside=0}
inside { if ($0 ~ /^      /) c++ }
END { print c+0 }
')"
  assert_equal "$probe_count" "3"

  local container_count
  container_count="$(printf '%s\n' "$HC_STDOUT" | awk '
/^    Last 3 container log lines:/ {inside=1; next}
inside && /^$/ {inside=0}
inside { if ($0 ~ /^      /) c++ }
END { print c+0 }
')"
  # Container logs may have fewer lines than requested depending on service output.
  if (( container_count < 1 || container_count > 3 )); then
    echo "Expected 1..3 container log lines, got $container_count"
    return 1
  fi
}
