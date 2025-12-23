#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load './helpers.bash'

@test "no-services: fails with guidance message" {
  export DOCKER_HEALTH_TIMEOUT="10"
  export DOCKER_SERVICES_LIST=""
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose \
    -f docker-compose.no-services.yml \
    up -d --quiet-pull

  assert_failure

  # JSON may be absent in this early-fail path; if present, validate status.
  if [[ -n "${HC_JSON:-}" ]]; then
    assert_json '.overall.status == "no_services" or .overall.status == "compose_failed"'
  fi

  assert_output --partial "No services specified. Either:"
  assert_output --partial "pass services in docker compose command"
  assert_output --partial "or set DOCKER_SERVICES_LIST environment variable"
}

@test "no services: fails when no services are provided and DOCKER_SERVICES_LIST is not set" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  # Note: no service names after `up -d`
  run_healthcheck_action_sh docker compose \
    -f docker/docker-compose.healthy.yml \
    up -d --quiet-pull

  assert_failure

  # JSON may be absent in this early-fail path; if present, validate status.
  if [[ -n "${HC_JSON:-}" ]]; then
    assert_json '.overall.status == "no_services" or .overall.status == "compose_failed"'
  fi

  assert_output --partial "No services specified. Either:"
  assert_output --partial "pass services in docker compose command"
  assert_output --partial "or set DOCKER_SERVICES_LIST environment variable"
}
