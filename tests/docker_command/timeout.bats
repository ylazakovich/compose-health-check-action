#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load '../helpers.bash'

@test "docker-command: unhealthy service causes action to fail after timeout" {
  export INPUT_TIMEOUT="5"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.unhealthy.yml up -d --quiet-pull slow-broken"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_failure
  assert_json '.overall.status == "failed"'
  assert_json '.summary.unhealthy == 1'
  assert_json '.services["slow-broken"] == "unhealthy"'
}
