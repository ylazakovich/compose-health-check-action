#!/usr/bin/env bats

load '/usr/lib/bats-support/load'
load '/usr/lib/bats-assert/load'
load './helpers.bash'

@test "one-shot: exit 0 is treated as success" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_SERVICES_LIST="oneshot_ok"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.oneshot.yml up -d --quiet-pull oneshot_ok

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.oneshot_ok == "completed"'
  assert_json '.summary.failed == 0'
}

@test "one-shot: non-zero exit code fails the action" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_SERVICES_LIST="oneshot_fail"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.oneshot.yml up -d --quiet-pull oneshot_fail

  assert_failure
  assert_json '.overall.status == "failed"'
  assert_json '.services.oneshot_fail == "failed"'
  assert_json '.summary.failed == 1'
}
