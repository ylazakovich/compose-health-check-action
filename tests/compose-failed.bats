#!/usr/bin/env bats

load '/usr/lib/bats-support/load'
load '/usr/lib/bats-assert/load'
load './helpers.bash'

@test "compose-failed: docker compose command fails and diagnostics are printed" {
  export DOCKER_HEALTH_TIMEOUT="10"
  export DOCKER_SERVICES_LIST="empty"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker-compose-NOT-FOUND.yml up -d empty

  assert_failure

  if [[ -n "${HC_JSON:-}" ]]; then
    assert_json '.overall.status == "compose_failed"'
  fi

  assert_output --partial "Diagnostics summary"
  assert_output --partial "docker-compose-NOT-FOUND.yml"
  assert_output --partial "docker compose output (last 25 lines)"
  assert_output --partial "docker compose ls (all projects)"
  assert_output --partial "docker ps --all (global)"
}
