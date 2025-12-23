#!/usr/bin/env bats

load '/usr/lib/bats-support/load'
load '/usr/lib/bats-assert/load'
load './helpers.bash'

@test "no-services: fails with guidance message" {
  export DOCKER_HEALTH_TIMEOUT="10"
  export DOCKER_SERVICES_LIST=""
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker-compose-NOT-FOUND.yml up -d

  assert_failure

  # JSON may be absent in this early-fail path; if present, validate status.
  if [[ -n "${HC_JSON:-}" ]]; then
    assert_json '.overall.status == "no_services" or .overall.status == "compose_failed"'
  fi

  assert_output --partial "No services specified. Either:"
  assert_output --partial "pass services in docker compose command"
  assert_output --partial "or set DOCKER_SERVICES_LIST environment variable"
}
