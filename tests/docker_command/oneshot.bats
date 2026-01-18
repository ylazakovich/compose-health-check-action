#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load '../helpers.bash'

@test "docker-command: exit 0 is treated as success (service is completed)" {
  export INPUT_TIMEOUT="60"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.oneshot.yml up -d --quiet-pull oneshot-ok"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.summary.unhealthy == 0'
  assert_json '.summary.completed == 1'
  assert_json '.services["oneshot-ok"] == "completed"'
}

@test "docker-command: non-zero exit code fails the action" {
  export INPUT_TIMEOUT="60"
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.oneshot.yml up -d --quiet-pull oneshot-fail"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_failure
  assert_json '.overall.status == "failed"'
  assert_json '.services["oneshot-fail"] == "failed"'
  assert_json '.summary.unhealthy == 1'
}
