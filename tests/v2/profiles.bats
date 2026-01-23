#!/usr/bin/env bats

load '../bats-support/load'
load '../bats-assert/load'
load '../helpers.bash'

@test "docker-command: supports profiles before up" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.profiles.yml --profile default --profile extra up -d"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
  assert_json '.services.worker == "healthy"'
  assert_json '.services.sidecar == "healthy"'
}

@test "docker-command: accepts short -p flag (project name)" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.profiles.yml -p shortproj up -d"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
  assert_json '.services.worker == null'
  assert_json '.services.sidecar == null'
}
