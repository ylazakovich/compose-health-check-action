#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load '../helpers.bash'

@test "docker-command: CLI services override INPUT_SERVICES" {
  export INPUT_TIMEOUT="60"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_SERVICES="this-service-does-not-exist"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.healthy.yml up -d --quiet-pull web"

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.config.services_target == ["web"]'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}
