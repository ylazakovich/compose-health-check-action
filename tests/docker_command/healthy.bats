#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load '../helpers.bash'

@test "docker-command: services taken from command" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.healthy.yml up -d --quiet-pull web"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}

@test "docker-command: fails when services are not provided" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.healthy.yml up -d --quiet-pull"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_failure
  if [[ -n "${HC_JSON:-}" ]]; then
    assert_json '.overall.status == "no_services" or .overall.status == "compose_failed"'
  fi
  assert_output --partial "No services specified. Either:"
}
