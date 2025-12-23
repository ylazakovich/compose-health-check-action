#!/usr/bin/env bats

load '/usr/lib/bats-support/load'
load '/usr/lib/bats-assert/load'
load './helpers.bash'

@test "healthy: overall ok and web is healthy" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_SERVICES_LIST="web"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker-compose.yml up -d --quiet-pull web

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}
