#!/usr/bin/env bats

load '../bats-support/load'
load '../bats-assert/load'
load '../helpers.bash'

@test "unhealthy: slow-broken becomes unhealthy and action fails" {
  export DOCKER_HEALTH_TIMEOUT="10"
  export DOCKER_SERVICES_LIST="slow-broken"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.unhealthy.yml up -d slow-broken

  assert_failure
  assert_json '.overall.status == "failed"'
  assert_json '.services["slow-broken"] == "unhealthy"'
  assert_json '.summary.unhealthy >= 1'

  # Optional diagnostics checks from stdout (until diagnostics move into JSON)
  assert_output --partial "Last 25 health probe outputs"
  assert_output --partial "Last 25 container log lines"
}

@test "unhealthy: respects DOCKER_HEALTH_LOG_LINES for diagnostics" {
  export DOCKER_HEALTH_TIMEOUT="10"
  export DOCKER_HEALTH_LOG_LINES="3"
  export DOCKER_SERVICES_LIST="slow-broken"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.unhealthy.yml up -d slow-broken

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
  assert_equal "$container_count" "3"
}
