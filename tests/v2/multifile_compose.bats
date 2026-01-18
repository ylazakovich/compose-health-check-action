#!/usr/bin/env bats

load '../bats-support/load'
load '../bats-assert/load'
load '../helpers.bash'

@test "docker-command: override adds healthcheck and service becomes healthy" {
  export INPUT_TIMEOUT="60"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.multi.base.yml -f docker/docker-compose.multi.override.yml up -d --quiet-pull api"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.api == "healthy"'
  assert_json '.summary.healthy == 1'
  assert_json '.summary.unhealthy == 0'
}
