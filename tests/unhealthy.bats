#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load './helpers.bash'

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
