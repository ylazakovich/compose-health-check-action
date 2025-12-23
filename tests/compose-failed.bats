#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load './helpers.bash'

@test "compose_failed: docker compose command fails and diagnostics are printed" {
  export DOCKER_HEALTH_TIMEOUT="10"
  export DOCKER_SERVICES_LIST="empty"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.compose_failed.yml up -d empty

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
