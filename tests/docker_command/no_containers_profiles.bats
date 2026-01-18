#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load '../helpers.bash'

@test "docker-command: target includes a service that was not started (reported as no_containers)" {
  export INPUT_TIMEOUT="60"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.no-containers.yml up -d --quiet-pull main"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.summary.no_containers >= 1'

  assert_json '.services.main == "healthy"'
  assert_json '(.services.ghost == "no_containers") or (.services.ghost == "skipped") or (.services.ghost == "no_containers")'
}
