#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load './helpers.bash'

@test "timeout: unhealthy service causes action to fail after timeout" {
  # Intentionally small timeout
  export DOCKER_HEALTH_TIMEOUT="5"
  export DOCKER_SERVICES_LIST="slow-broken"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.unhealthy.yml up -d --quiet-pull slow-broken

  assert_failure
  assert_json '.overall.status == "failed"'
  assert_json '.summary.unhealthy == 1'
  assert_json '.services["slow-broken"] == "unhealthy"'
}
