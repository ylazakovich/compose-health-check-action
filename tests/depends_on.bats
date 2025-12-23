#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load './helpers.bash'

@test "depends_on: db -> api -> web reaches healthy state (service_healthy conditions)" {
  export DOCKER_HEALTH_TIMEOUT="90"
  export DOCKER_SERVICES_LIST="db api web"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.depends-on.yml up -d --quiet-pull

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.db == "healthy"'
  assert_json '.services.api == "healthy"'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}
