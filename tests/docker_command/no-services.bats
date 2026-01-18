#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load '../helpers.bash'

@test "docker-command: fails when no services are provided and INPUT_SERVICES is not set" {
  export INPUT_TIMEOUT="60"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.healthy.yml up -d --quiet-pull"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_failure

  if [[ -n "${HC_JSON:-}" ]]; then
    assert_json '.overall.status == "no_services" or .overall.status == "compose_failed"'
  fi

  assert_output --partial "No services specified. Either:"
  assert_output --partial "pass services in docker compose command"
  assert_output --partial "or set DOCKER_SERVICES_LIST environment variable"
}
