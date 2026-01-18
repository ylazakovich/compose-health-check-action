#!/usr/bin/env bats

load '../bats-support/load'
load '../bats-assert/load'
load '../helpers.bash'

@test "docker-command: db -> api -> web reaches healthy state (service_healthy conditions)" {
  export INPUT_TIMEOUT="90"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.depends-on.yml up -d --quiet-pull db api web"

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.db == "healthy"'
  assert_json '.services.api == "healthy"'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}
