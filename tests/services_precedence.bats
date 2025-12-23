#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load './helpers.bash'

@test "services precedence: CLI services override DOCKER_SERVICES_LIST" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  # Intentionally wrong service in env — must be ignored because CLI provides a service list.
  export DOCKER_SERVICES_LIST="this-service-does-not-exist"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.healthy.yml up -d --quiet-pull web

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.config.services_target == ["web"]'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}
