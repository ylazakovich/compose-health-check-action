#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load './helpers.bash'

@test "docker-command: services taken from command" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.healthy.yml up -d --quiet-pull web"
  export INPUT_SERVICES=""

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
}

@test "docker-command: services taken from INPUT_SERVICES when not in command" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.healthy.yml up -d --quiet-pull"
  export INPUT_SERVICES="web"

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
}
