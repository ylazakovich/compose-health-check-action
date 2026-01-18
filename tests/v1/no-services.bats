#!/usr/bin/env bats

load '../bats-support/load'
load '../bats-assert/load'
load '../helpers.bash'

@test "no-services: uses all services when DOCKER_SERVICES_LIST is empty" {
  export DOCKER_HEALTH_TIMEOUT="10"
  export DOCKER_SERVICES_LIST=""
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose \
    -f docker/docker-compose.healthy.yml \
    up -d --quiet-pull

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}

@test "no services: uses all services when DOCKER_SERVICES_LIST is not set" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_HEALTH_REPORT_FORMAT="json"
  unset DOCKER_SERVICES_LIST

  # Note: no service names after `up -d`
  run_healthcheck_action_sh docker compose \
    -f docker/docker-compose.healthy.yml \
    up -d --quiet-pull

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}
