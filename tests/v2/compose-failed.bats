#!/usr/bin/env bats

load '../bats-support/load'
load '../bats-assert/load'
load '../helpers.bash'

@test "docker-command: docker compose command fails and diagnostics are printed" {
  export INPUT_TIMEOUT="10"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.compose_failed.yml up -d empty"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_failure

  if [[ -n "${HC_JSON:-}" ]]; then
    assert_json '.overall.status == "compose_failed"'
  fi

  assert_output --partial "Diagnostics summary"
  assert_output --partial "docker-compose.compose_failed.yml"
  assert_output --partial "docker compose output (last 25 lines)"
  assert_output --partial "docker compose ls (all projects)"
  assert_output --partial "docker ps --all (global)"
}
