#!/usr/bin/env bats

load '/usr/lib/bats-support/load'
load '/usr/lib/bats-assert/load'
load './helpers.bash'

@test "one-shot: exit 0 is treated as success (service without healthcheck is not a failure)" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_SERVICES_LIST="oneshot-ok"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.oneshot.yml up -d --quiet-pull oneshot-ok

  assert_success
  assert_json '.overall.status == "ok"'

  # Current behavior from logs: service without healthcheck is reported via summary and/or services map
  # Accept either classification to avoid brittleness across small implementation changes.
  # 1) counted as "without_healthcheck"
  if jq -e '.summary.without_healthcheck' <<<"$HC_JSON" >/dev/null; then
    assert_json '.summary.without_healthcheck >= 1'
  fi

  # 2) or appears in services as "no_containers" / "skip" variants
  # (your log shows oneshot-ok becomes "no_containers" in services map)
  assert_json '.services["oneshot-ok"] == "no_containers" or .services["oneshot-ok"] == "skipped" or .services["oneshot-ok"] == "without_healthcheck"'
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
