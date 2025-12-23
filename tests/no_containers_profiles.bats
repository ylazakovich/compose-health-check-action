#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'
load './helpers.bash'

@test "no_containers: target includes a service that was not started (reported as no_containers)" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  # We target both, but will start only `main`
  export DOCKER_SERVICES_LIST="main ghost"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.no-containers.yml up -d --quiet-pull main

  # Current action behavior: no_containers does NOT fail the run
  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.summary.no_containers >= 1'

  # Ensure main is healthy and ghost is accounted for
  assert_json '.services.main == "healthy"'
  assert_json '(.services.ghost == "no_containers") or (.services.ghost == "skipped") or (.services.ghost == "no_containers")'
}
