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

@test "compose-files: supports compose-profiles with multiple profiles" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_COMPOSE_FILES="docker/docker-compose.profiles.yml"
  export INPUT_COMPOSE_PROFILES="default extra"
  export INPUT_ADDITIONAL_COMPOSE_ARGS="--quiet-pull"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
  assert_json '.services.worker == "healthy"'
  assert_json '.services.sidecar == "healthy"'
}
