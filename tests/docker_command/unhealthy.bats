#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
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
