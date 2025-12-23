#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load './helpers.bash'

@test "multi-file compose: override adds healthcheck and service becomes healthy" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_SERVICES_LIST="api"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose \
    -f docker/docker-compose.multi.base.yml \
    -f docker/docker-compose.multi.override.yml \
    up -d --quiet-pull api

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.api == "healthy"'
  assert_json '.summary.healthy == 1'
  assert_json '.summary.unhealthy == 0'
}
