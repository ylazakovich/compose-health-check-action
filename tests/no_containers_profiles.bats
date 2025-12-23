#!/usr/bin/env bats

load '/usr/lib/bats-support/load'
load '/usr/lib/bats-assert/load'
load './helpers.bash'

@test "no_containers: profiled service is not started and reported as no_containers" {
  export DOCKER_HEALTH_TIMEOUT="60"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  # Target only the service that should actually run
  export DOCKER_SERVICES_LIST="main"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.profiles.yml up -d --quiet-pull main

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.config.services_target == ["main"]'
  assert_json '.services.main == "healthy"'
  assert_json '.summary.unhealthy == 0'

  # The profiled service exists in config but container is not created (profile not enabled)
  # Depending on detection, it might appear in services map as no_containers.
  assert_json '(.services.optional == "no_containers") or (.summary.no_containers >= 1)'
}
