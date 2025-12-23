#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load './helpers.bash'

@test "one-shot: exit 0 is treated as success (service is completed)" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_SERVICES_LIST="oneshot-ok"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.oneshot.yml up -d --quiet-pull oneshot-ok

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.summary.unhealthy == 0'
  assert_json '.summary.completed == 1'
  assert_json '.services["oneshot-ok"] == "completed"'
}

@test "one-shot: non-zero exit code fails the action" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_SERVICES_LIST="oneshot-fail"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.oneshot.yml up -d --quiet-pull oneshot-fail

  assert_failure
  assert_json '.overall.status == "failed"'
  assert_json '.services["oneshot-fail"] == "failed"'
  assert_json '.summary.unhealthy == 1'
}